FROM docker.io/freebsd/freebsd-toolchain:15.1 AS builder

ARG VERSION=v0.40.4 \
      GO_VERSION=1.27.1 \
      GOBIN=/app

RUN set -ex; \
      fetch -o /tmp/go.tar.gz https://dl.google.com/go/go${GO_VERSION}.freebsd-amd64.tar.gz; \
      fetch -o /tmp/go.tar.gz.sha256 https://dl.google.com/go/go${GO_VERSION}.freebsd-amd64.tar.gz.sha256; \
      sha256 -c "$(cat /tmp/go.tar.gz.sha256)" /tmp/go.tar.gz; \
      tar -xzf /tmp/go.tar.gz -C /usr/local; \
      mkdir -p /usr/local/bin; \
      ln -sf /usr/local/go/bin/* /usr/local/bin/
RUN set -ex; \
      mkdir -p /app; \
      env CGO_ENABLED=0 go install -ldflags "-s -w" github.com/pocketbase/pocketbase/examples/base@${VERSION}; \
      mv /app/base /app/pocketbase
RUN set -ex; \
      fetch -o /tmp/su-exec.tar.gz https://github.com/ncopa/su-exec/archive/refs/heads/master.tar.gz; \
      mkdir -p /tmp/su-exec; \
      tar -xzf /tmp/su-exec.tar.gz -C /tmp/su-exec --strip-components=1; \
      cc -Wall -O2 -o /app/su-exec /tmp/su-exec/su-exec.c

FROM docker.io/freebsd/freebsd-runtime:15.1 AS runner

ENV PUID=9085 \
    PGID=9085

RUN set -ex; \
      pw groupadd -n app -g ${PGID}; \
      pw useradd -n app -u ${PUID} -g app -d /data -s /sbin/nologin; \
      mkdir -p /data; \
      chown app:app /data

COPY --from=builder /app/pocketbase /usr/local/bin/pocketbase
COPY --from=builder /app/su-exec /usr/local/bin/su-exec
COPY --chmod=755 entrypoint.sh /entrypoint.sh

WORKDIR /data
VOLUME /data
EXPOSE 8090
ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "serve", "--http=0.0.0.0:8090" ]
