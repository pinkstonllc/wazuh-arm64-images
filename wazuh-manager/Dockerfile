# Wazuh manager on Debian 12, for arm64 CPUs older than ARMv8.2 (Raspberry Pi 4).
# Port of wazuh-docker v4.14.10 build-docker-images/wazuh-manager (GPLv2):
# same s6 start-up scripts and files; Debian packages instead of Amazon Linux.
# Build context: the repository root.
FROM debian:12

RUN ln -sf /bin/bash /bin/sh

ARG WAZUH_VERSION
ARG WAZUH_TAG_REVISION=1
ARG FILEBEAT_TEMPLATE_BRANCH
ARG FILEBEAT_VERSION=7.10.2
ARG FILEBEAT_REVISION=2
ARG WAZUH_FILEBEAT_MODULE=wazuh-filebeat-0.5.tar.gz
ARG S6_VERSION="v2.2.0.3"
ARG TARGETARCH
ENV DEBIAN_FRONTEND=noninteractive

COPY common/wazuh-apt.sh /
COPY wazuh-manager/config/permanent_data.env wazuh-manager/config/permanent_data.sh /

RUN bash /wazuh-apt.sh && \
    apt-get install -y --no-install-recommends \
      xz-utils tar gzip openssl findutils procps lsb-release && \
    apt-get install -y wazuh-manager=${WAZUH_VERSION}-${WAZUH_TAG_REVISION} \
                       filebeat=${FILEBEAT_VERSION}-${FILEBEAT_REVISION} && \
    curl -fsSL https://packages.wazuh.com/4.x/filebeat/${WAZUH_FILEBEAT_MODULE} \
      | tar -xz -C /usr/share/filebeat/module && \
    S6_ARCH="amd64" && \
    if [ "${TARGETARCH}" = "arm64" ]; then S6_ARCH="aarch64"; fi && \
    curl --fail --silent -L https://github.com/just-containers/s6-overlay/releases/download/${S6_VERSION}/s6-overlay-${S6_ARCH}.tar.gz \
      -o /tmp/s6-overlay-${S6_ARCH}.tar.gz && \
    tar xzf /tmp/s6-overlay-${S6_ARCH}.tar.gz -C / --exclude="./bin" && \
    tar xzf /tmp/s6-overlay-${S6_ARCH}.tar.gz -C /usr ./bin && \
    rm /tmp/s6-overlay-${S6_ARCH}.tar.gz && \
    rm -f /var/ossec/etc/sslmanager.key /var/ossec/etc/sslmanager.cert && \
    rm -f /etc/apt/sources.list.d/wazuh.list && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

COPY wazuh-manager/config/etc/ /etc/
COPY --chown=root:wazuh wazuh-manager/config/create_user.py /var/ossec/framework/scripts/create_user.py

COPY wazuh-manager/config/filebeat.yml /etc/filebeat/
RUN chmod go-w /etc/filebeat/filebeat.yml

ADD https://raw.githubusercontent.com/wazuh/wazuh/$FILEBEAT_TEMPLATE_BRANCH/extensions/elasticsearch/7.x/wazuh-template.json /etc/filebeat
RUN chmod go-w /etc/filebeat/wazuh-template.json

# Mount directories keep their permissions; then move permanent data aside
# (same as the official image).
RUN mkdir -p /var/ossec/var/multigroups && \
    chown root:wazuh /var/ossec/var/multigroups && \
    chmod 770 /var/ossec/var/multigroups && \
    mkdir -p /var/ossec/agentless && \
    chown root:wazuh /var/ossec/agentless && \
    chmod 770 /var/ossec/agentless && \
    mkdir -p /var/ossec/active-response/bin && \
    chown root:wazuh /var/ossec/active-response/bin && \
    chmod 770 /var/ossec/active-response/bin && \
    chmod 755 /permanent_data.sh && \
    sync && /permanent_data.sh && \
    sync && rm /permanent_data.sh

EXPOSE 55000/tcp 1514/tcp 1515/tcp 514/udp 1516/tcp

ENTRYPOINT [ "/init" ]
