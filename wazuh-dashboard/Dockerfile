# Wazuh dashboard on Debian 12, for arm64 CPUs older than ARMv8.2 (Raspberry Pi 4).
# Port of wazuh-docker v4.14.10 build-docker-images/wazuh-dashboard (GPLv2):
# same files and start-up scripts; Debian packages instead of Amazon Linux.
# Build context: the repository root.
FROM debian:12 AS builder

ARG WAZUH_VERSION
ARG WAZUH_TAG_REVISION=1
ARG INSTALL_DIR=/usr/share/wazuh-dashboard
ENV DEBIAN_FRONTEND=noninteractive

COPY common/wazuh-apt.sh /
RUN bash /wazuh-apt.sh && \
    apt-get install -y --no-install-recommends libcap2-bin openssl && \
    apt-get install -y wazuh-dashboard=${WAZUH_VERSION}-${WAZUH_TAG_REVISION}

RUN mkdir -p $INSTALL_DIR/data/wazuh && chmod -R 775 $INSTALL_DIR/data/wazuh && \
    mkdir -p $INSTALL_DIR/data/wazuh/config && chmod -R 775 $INSTALL_DIR/data/wazuh/config && \
    mkdir -p $INSTALL_DIR/data/wazuh/logs && chmod -R 775 $INSTALL_DIR/data/wazuh/logs
COPY wazuh-dashboard/config/wazuh.yml $INSTALL_DIR/data/wazuh/config/
RUN for n in $INSTALL_DIR/node/bin/node $INSTALL_DIR/node/fallback/bin/node; do \
      if [ -e "$n" ]; then setcap 'cap_net_bind_service=-ep' "$n"; fi; \
    done

COPY wazuh-dashboard/config/config.sh wazuh-dashboard/config/config.yml /
WORKDIR /
RUN bash config.sh

################################################################################
FROM debian:12

ENV USER="wazuh-dashboard" \
    GROUP="wazuh-dashboard" \
    NAME="wazuh-dashboard" \
    INSTALL_DIR="/usr/share/wazuh-dashboard"

ENV PATTERN="" \
    CHECKS_PATTERN="" \
    CHECKS_TEMPLATE="" \
    CHECKS_API="" \
    CHECKS_SETUP="" \
    APP_TIMEOUT="" \
    API_SELECTOR="" \
    IP_SELECTOR="" \
    IP_IGNORE="" \
    WAZUH_MONITORING_ENABLED="" \
    WAZUH_MONITORING_FREQUENCY="" \
    WAZUH_MONITORING_SHARDS="" \
    WAZUH_MONITORING_REPLICAS=""

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ca-certificates && \
    rm -rf /var/lib/apt/lists/*

RUN getent group $GROUP || groupadd -r -g 1000 $GROUP
RUN useradd --system \
            --uid 1000 \
            --no-create-home \
            --home-dir $INSTALL_DIR \
            --gid $GROUP \
            --shell /usr/sbin/nologin \
            --comment "$USER user" \
            $USER

COPY wazuh-dashboard/config/entrypoint.sh /
COPY wazuh-dashboard/config/wazuh_app_config.sh /
RUN chmod 700 /entrypoint.sh /wazuh_app_config.sh && chown 1000:1000 /*.sh

COPY --from=builder --chown=1000:1000 $INSTALL_DIR $INSTALL_DIR

RUN mkdir -p /usr/share/wazuh-dashboard/plugins/wazuh/public/assets/custom && \
    chown 1000:1000 /usr/share/wazuh-dashboard/plugins/wazuh/public/assets/custom

WORKDIR $INSTALL_DIR
USER wazuh-dashboard

EXPOSE 443

ENTRYPOINT [ "/entrypoint.sh" ]
