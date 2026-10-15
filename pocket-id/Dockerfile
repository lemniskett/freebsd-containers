ARG VERSION=2.18.0

# The frontend's build tool, vite-plus, ships no FreeBSD binaries. Its config
# helpers are plain JS, and its bundled rolldown falls back to rolldown's own
# FreeBSD binding, so the frontend is built through Vite's API instead of `vp`.
FROM docker.io/freebsd/freebsd-toolchain:15.1 AS frontend

ARG VERSION

ENV CI=true \
    ASSUME_ALWAYS_YES=yes

RUN set -ex; \
      fetch -o /tmp/src.tar.gz https://github.com/pocket-id/pocket-id/archive/refs/tags/v${VERSION}.tar.gz; \
      mkdir -p /src; \
      tar -xzf /tmp/src.tar.gz -C /src --strip-components=1

# Node major from .node-version, pnpm version from packageManager
RUN set -ex; \
      node_major=$(cut -d. -f1 /src/.node-version); \
      pkg install -y node${node_major} npm-node${node_major}; \
      pnpm_version=$(node -p "require('/src/package.json').packageManager.split('@')[1].split('+')[0]"); \
      npm install -g pnpm@${pnpm_version}

WORKDIR /src
RUN set -ex; \
      pnpm install --frozen-lockfile --filter pocket-id-frontend

# Put rolldown's FreeBSD binding (matching the version bundled in vite-plus-core)
# next to the loader, which tries ./rolldown-binding.freebsd-x64.node first
WORKDIR /src/frontend
RUN set -ex; \
      core=$(node -p "path.dirname(require.resolve('vite/package.json'))"); \
      rolldown_version=$(node -p "require('${core}/package.json').bundledVersions.rolldown"); \
      loaders=$(grep -rl --include='*.mjs' 'rolldown-binding.freebsd-x64.node' "${core}/dist"); \
      test -n "${loaders}"; \
      tgz=$(cd /tmp && npm pack --silent @rolldown/binding-freebsd-x64@${rolldown_version}); \
      tar -xzf "/tmp/${tgz}" -C /tmp package/rolldown-binding.freebsd-x64.node; \
      for loader in ${loaders}; do \
        cp /tmp/package/rolldown-binding.freebsd-x64.node "$(dirname "${loader}")/"; \
      done

# Equivalent of `vp build`: Vite's app builder (all environments, as SvelteKit needs).
# It runs from a file because SvelteKit's child processes inherit node's flags.
RUN set -ex; \
      printf '%s\n' "import { createBuilder } from 'vite';" "await (await createBuilder()).buildApp();" > build-freebsd.mjs; \
      BUILD_OUTPUT_PATH=dist node build-freebsd.mjs

FROM docker.io/freebsd/freebsd-toolchain:15.1 AS builder

ARG VERSION
ARG GO_VERSION=1.27.1

RUN set -ex; \
      fetch -o /tmp/go.tar.gz https://dl.google.com/go/go${GO_VERSION}.freebsd-amd64.tar.gz; \
      fetch -o /tmp/go.tar.gz.sha256 https://dl.google.com/go/go${GO_VERSION}.freebsd-amd64.tar.gz.sha256; \
      sha256 -c "$(cat /tmp/go.tar.gz.sha256)" /tmp/go.tar.gz; \
      tar -xzf /tmp/go.tar.gz -C /usr/local; \
      mkdir -p /usr/local/bin; \
      ln -sf /usr/local/go/bin/* /usr/local/bin/

COPY --from=frontend /src/backend /src/backend
COPY --from=frontend /src/frontend/dist /src/backend/frontend/dist

RUN set -ex; \
      mkdir -p /app; \
      cd /src/backend/cmd; \
      env CGO_ENABLED=0 go build -trimpath \
        -ldflags "-s -w -X github.com/pocket-id/pocket-id/backend/internal/common.Version=${VERSION} -buildid=${VERSION}" \
        -o /app/pocket-id .
RUN set -ex; \
      fetch -o /tmp/su-exec.tar.gz https://github.com/ncopa/su-exec/archive/refs/heads/master.tar.gz; \
      mkdir -p /tmp/su-exec; \
      tar -xzf /tmp/su-exec.tar.gz -C /tmp/su-exec --strip-components=1; \
      cc -Wall -O2 -o /app/su-exec /tmp/su-exec/su-exec.c

FROM docker.io/freebsd/freebsd-runtime:15.1 AS runner

ENV PUID=3113 \
    PGID=3113 \
    APP_ENV=production \
    UPLOAD_PATH=/data/uploads

RUN set -ex; \
      pw groupadd -n app -g ${PGID}; \
      pw useradd -n app -u ${PUID} -g app -d /data -s /sbin/nologin; \
      mkdir -p /data; \
      chown app:app /data

COPY --from=builder /app/pocket-id /usr/local/bin/pocket-id
COPY --from=builder /app/su-exec /usr/local/bin/su-exec
COPY --chmod=755 entrypoint.sh /entrypoint.sh

# Pocket ID keeps its database and files under ./data, so run from / to land in /data
WORKDIR /
VOLUME /data
EXPOSE 1411
ENTRYPOINT [ "/entrypoint.sh" ]
