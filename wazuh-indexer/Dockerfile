# Wazuh indexer on Debian 12, for arm64 CPUs older than ARMv8.2 (Raspberry Pi 4).
# Port of wazuh-docker v4.14.10 build-docker-images/wazuh-indexer (GPLv2):
# same files and start-up scripts; Debian packages instead of Amazon Linux.
# Build context: the repository root.
FROM debian:12 AS builder

ARG WAZUH_VERSION
ARG WAZUH_TAG_REVISION=1
ENV DEBIAN_FRONTEND=noninteractive

COPY common/wazuh-apt.sh /
RUN bash /wazuh-apt.sh && \
    apt-get install -y --no-install-recommends openssl xz-utils tar procps findutils && \
    apt-get install -y wazuh-indexer=${WAZUH_VERSION}-${WAZUH_TAG_REVISION}

COPY wazuh-indexer/config/opensearch.yml \
     wazuh-indexer/config/config.yml \
     wazuh-indexer/config/action_groups.yml \
     wazuh-indexer/config/internal_users.yml \
     wazuh-indexer/config/roles_mapping.yml \
     wazuh-indexer/config/roles.yml \
     wazuh-indexer/config/config.sh /

WORKDIR /
RUN bash config.sh

################################################################################
FROM debian:12

ENV USER="wazuh-indexer" \
    GROUP="wazuh-indexer" \
    NAME="wazuh-indexer" \
    INSTALL_DIR="/usr/share/wazuh-indexer"

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      curl ca-certificates hostname procps findutils && \
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

WORKDIR $INSTALL_DIR

COPY wazuh-indexer/config/entrypoint.sh /
COPY wazuh-indexer/config/securityadmin.sh /

RUN chmod 700 /entrypoint.sh && chmod 700 /securityadmin.sh && \
    mkdir -p /usr/share/wazuh-indexer && \
    chown 1000:1000 /usr/share/wazuh-indexer && \
    chown 1000:1000 /*.sh

COPY --from=builder --chown=1000:1000 /usr/share/wazuh-indexer /usr/share/wazuh-indexer
COPY --from=builder --chown=1000:1000 /etc/wazuh-indexer /usr/share/wazuh-indexer/config
COPY --from=builder --chown=1000:1000 /debian/wazuh-indexer/usr/share/wazuh-indexer /usr/share/wazuh-indexer
COPY --from=builder --chown=0:0 /debian/wazuh-indexer/usr/lib/systemd /usr/lib/systemd
COPY --from=builder --chown=0:0 /debian/wazuh-indexer/usr/lib/sysctl.d /usr/lib/sysctl.d
COPY --from=builder --chown=0:0 /debian/wazuh-indexer/usr/lib/tmpfiles.d /usr/lib/tmpfiles.d

RUN mkdir -p /var/lib/wazuh-indexer && chown 1000:1000 /var/lib/wazuh-indexer && \
    mkdir -p /usr/share/wazuh-indexer/logs && chown 1000:1000 /usr/share/wazuh-indexer/logs && \
    mkdir -p /run/wazuh-indexer && chown 1000:1000 /run/wazuh-indexer && \
    mkdir -p /var/log/wazuh-indexer && chown 1000:1000 /var/log/wazuh-indexer && \
    chmod 700 /usr/share/wazuh-indexer && \
    chmod 700 /usr/share/wazuh-indexer/config && \
    chmod 600 /usr/share/wazuh-indexer/config/jvm.options && \
    chmod 600 /usr/share/wazuh-indexer/config/opensearch.yml

USER wazuh-indexer

EXPOSE 9200

ENTRYPOINT ["/entrypoint.sh"]
# Dummy overridable parameter parsed by entrypoint
CMD ["opensearchwrapper"]
