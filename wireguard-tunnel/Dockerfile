# WireGuard tunnel sidecar for Wazuh manager pods: dials a customer's UniFi
# WireGuard VPN server so its syslog reaches the manager encrypted.
# Kernel WireGuard (the Pi 4 kernel has it); needs only NET_ADMIN.
# Build context: the repository root.
FROM debian:13-slim

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      wireguard-tools iproute2 nftables procps && \
    rm -rf /var/lib/apt/lists/*

COPY wireguard-tunnel/tunnel.sh /usr/local/bin/tunnel.sh
RUN chmod 755 /usr/local/bin/tunnel.sh

ENTRYPOINT ["/usr/local/bin/tunnel.sh"]
