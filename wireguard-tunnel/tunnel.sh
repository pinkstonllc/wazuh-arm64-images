#!/bin/bash
# WireGuard tunnel sidecar for a Wazuh manager pod.
#
# Dials out to a customer's UniFi WireGuard VPN server so the UniFi (and,
# if allowed, other devices at the site) can send syslog to this pod's tunnel
# address. The manager container shares this pod's network and receives the
# syslog on port 514.
#
# Input (mounted from the tenant's wazuh-wireguard Secret, cleaned by
# set-tunnel.sh): /config/wg0.conf with only
#   [Interface] PrivateKey, Address    [Peer] PublicKey, PresharedKey, Endpoint
# Environment:
#   SYSLOG_SOURCES  comma list of addresses/CIDRs allowed to send syslog
#                   through the tunnel (also the tunnel's AllowedIPs)
#   WG_MTU          default 1370 (pod network 1450 minus WireGuard overhead)
#
# Lockdown, whatever happens to the manager container next door:
#   - only SYSLOG_SOURCES are routed into the tunnel (no default route);
#   - inbound on wg0: only syslog (514 udp/tcp) from SYSLOG_SOURCES;
#   - outbound on wg0: replies only. Nothing in this pod can open a
#     connection into the customer's network.
# The UniFi-side firewall rules are the second, independent layer.
#
# This script never exits on errors (only on SIGTERM): a sidecar that
# crash-looped would make the whole pod NotReady and cut off the customer's
# agents. Problems are logged and retried.
set -uo pipefail

CONF=/config/wg0.conf
MTU="${WG_MTU:-1370}"
IFACE=wg0

log() { echo "$(date -u +%FT%TZ) tunnel: $*"; }

get() { sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*//p" "$CONF" | head -1 | tr -d '\r'; }

if [[ "${1:-}" == "--version" ]]; then wg --version; nft --version; exit 0; fi

cleanup() { log "stopping"; ip link del "$IFACE" 2>/dev/null; nft delete table inet wazuh_tunnel 2>/dev/null; exit 0; }
trap cleanup TERM INT

wait_forever() { log "$*; idle (fix the config and restart the pod)"; while true; do sleep 3600 & wait $!; done; }

[[ -r "$CONF" ]] || wait_forever "no $CONF"
PRIV="$(get PrivateKey)"; ADDR="$(get Address)"; PUB="$(get PublicKey)"
PSK="$(get PresharedKey)"; ENDPOINT="$(get Endpoint)"
[[ -n "$PRIV" && -n "$ADDR" && -n "$PUB" && -n "$ENDPOINT" ]] \
  || wait_forever "wg0.conf is missing PrivateKey, Address, PublicKey or Endpoint"
SOURCES="$(echo "${SYSLOG_SOURCES:-}" | tr -d ' ')"
[[ -n "$SOURCES" ]] || wait_forever "SYSLOG_SOURCES is empty"
MYIP="${ADDR%%/*}"; MYIP="${MYIP%%,*}"

setup() {
  ip link del "$IFACE" 2>/dev/null
  ip link add "$IFACE" type wireguard || return 1
  wg set "$IFACE" private-key <(printf '%s\n' "$PRIV") || return 1
  local psk_args=()
  [[ -n "$PSK" ]] && psk_args=(preshared-key <(printf '%s\n' "$PSK"))
  wg set "$IFACE" peer "$PUB" endpoint "$ENDPOINT" persistent-keepalive 25 \
    allowed-ips "$SOURCES" "${psk_args[@]}" || return 1
  ip address add "${MYIP}/32" dev "$IFACE" || return 1
  ip link set "$IFACE" mtu "$MTU" up || return 1
  local cidr
  for cidr in ${SOURCES//,/ }; do ip route replace "$cidr" dev "$IFACE" || return 1; done

  nft -f - <<EOF || return 1
table inet wazuh_tunnel
delete table inet wazuh_tunnel
table inet wazuh_tunnel {
  chain in {
    type filter hook input priority -10; policy accept;
    iifname "$IFACE" ct state established,related accept
    iifname "$IFACE" ip saddr { ${SOURCES} } udp dport 514 accept
    iifname "$IFACE" ip saddr { ${SOURCES} } tcp dport 514 accept
    iifname "$IFACE" counter drop
  }
  chain out {
    type filter hook output priority -10; policy accept;
    oifname "$IFACE" ct state established,related accept
    oifname "$IFACE" counter drop
  }
}
EOF
  return 0
}

until setup; do log "setup failed; retrying in 60 s"; sleep 60 & wait $!; done
log "up: ${MYIP} -> ${ENDPOINT}; syslog accepted from ${SOURCES} (udp/tcp 514); nothing outbound"

# Watch the handshake. WireGuard resolves the endpoint name only once, so
# when the customer's IP changes (dynamic DNS), re-set the endpoint to make
# it resolve again.
last_report=0
while true; do
  sleep 30 & wait $!
  hs="$(wg show "$IFACE" latest-handshakes 2>/dev/null | awk '{print $2}')"
  hs="${hs:-0}"
  now="$(date +%s)"
  if ! ip link show "$IFACE" >/dev/null 2>&1; then
    log "interface gone; rebuilding"; until setup; do sleep 60 & wait $!; done; continue
  fi
  if [[ "$hs" == "0" ]] || (( now - hs > 180 )); then
    # Down: retry (re-resolving the name) every 30 s, but log only every
    # 10 min so a long outage doesn't flood the log.
    if (( now - last_report > 600 )); then
      if [[ "$hs" == "0" ]]; then log "no handshake yet with ${ENDPOINT}; retrying every 30 s"
      else log "tunnel down: last handshake $(( now - hs )) s ago; retrying ${ENDPOINT} every 30 s"; fi
      last_report="$now"
    fi
    wg set "$IFACE" peer "$PUB" endpoint "$ENDPOINT" 2>/dev/null || log "could not resolve ${ENDPOINT}"
    was_down=1
  elif (( ${was_down:-0} )); then
    log "tunnel up: handshake with ${ENDPOINT} $(( now - hs )) s ago"
    was_down=0; last_report="$now"
  elif (( now - last_report > 600 )); then
    rx="$(wg show "$IFACE" transfer | awk '{print $2}')"
    log "ok: last handshake $(( now - hs )) s ago, ${rx:-0} bytes received"
    last_report="$now"
  fi
done
