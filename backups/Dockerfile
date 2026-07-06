FROM postgres:15

ARG TARGETARCH
ARG SUPERCRONIC_VERSION=v0.2.46

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates curl tar; \
    rm -rf /var/lib/apt/lists/*; \
    case "${TARGETARCH:-amd64}" in \
      amd64) SUPERCRONIC=supercronic-linux-amd64; SUPERCRONIC_SHA1SUM=5bcefed628e32adc08e32634db2d10e9230dbca0 ;; \
      arm64) SUPERCRONIC=supercronic-linux-arm64; SUPERCRONIC_SHA1SUM=639ab81a72771990790df7ee87d9acfe88e5fa83 ;; \
      arm) SUPERCRONIC=supercronic-linux-arm; SUPERCRONIC_SHA1SUM=04be50a960eafa325185d037c9b4ad6cd88a0e0b ;; \
      386) SUPERCRONIC=supercronic-linux-386; SUPERCRONIC_SHA1SUM=7630904df9a240b6e0f8171cac46ec799fbe1ad9 ;; \
      *) echo "Unsupported architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    curl -fsSLo /usr/local/bin/supercronic "https://github.com/aptible/supercronic/releases/download/${SUPERCRONIC_VERSION}/${SUPERCRONIC}"; \
    echo "${SUPERCRONIC_SHA1SUM}  /usr/local/bin/supercronic" | sha1sum -c -; \
    chmod +x /usr/local/bin/supercronic; \
    supercronic -version

COPY backup.sh backup_db_once.sh backup_previews_once.sh backup_once.sh /
RUN chmod +x /backup.sh /backup_db_once.sh /backup_previews_once.sh /backup_once.sh

ENTRYPOINT ["/bin/bash", "/backup.sh"]
