#!/bin/sh
# usage: scripts/build.sh <template path>
#
#   $ scripts/build.sh pocketbase
#
# Builds <template path>/Dockerfile with podman on a FreeBSD host and tags it
# <registry>/<name>:latest, plus <registry>/<name>:<VERSION> when the Dockerfile
# has a VERSION= build arg. With PUSH=true, logs in with REGISTRY_USER and
# REGISTRY_PASSWORD and pushes every tag.
#
# REGISTRY defaults to ghcr.io/<GITHUB_REPOSITORY>, e.g. ghcr.io/lemniskett/freebsd-containers.
set -eu

if [ -z "${1:-}" ]; then
    echo "usage: $0 <template path>" >&2
    exit 1
fi

dir=${1%/}
name=$(basename "$dir")
if [ -z "${REGISTRY:-}" ]; then
    : "${GITHUB_REPOSITORY:?set REGISTRY or GITHUB_REPOSITORY}"
    REGISTRY=ghcr.io/$(printf '%s' "$GITHUB_REPOSITORY" | tr '[:upper:]' '[:lower:]')
fi
registry=$REGISTRY
image="$registry/$name"

# First "VERSION=..." assignment, with or without a leading ARG (not GO_VERSION= etc.)
version=$(sed -nE 's/^[[:space:]]*(ARG[[:space:]]+)?VERSION=([^[:space:]\\]+).*/\2/p' "$dir/Dockerfile" | head -n 1)

set -- -t "$image:latest"
if [ -n "$version" ]; then
    set -- "$@" -t "$image:$version"
fi
if [ -n "${GITHUB_REPOSITORY:-}" ]; then
    set -- "$@" --label "org.opencontainers.image.source=${GITHUB_SERVER_URL:-https://github.com}/$GITHUB_REPOSITORY"
fi
if [ -n "${GITHUB_SHA:-}" ]; then
    set -- "$@" --label "org.opencontainers.image.revision=$GITHUB_SHA"
fi

# Host networking lets RUN steps reach the internet without setting up pf NAT
podman build --network=host "$@" "$dir"

if [ "${PUSH:-false}" = true ]; then
    printf '%s' "${REGISTRY_PASSWORD:?}" | podman login --username "${REGISTRY_USER:?}" --password-stdin "${registry%%/*}"
    podman push "$image:latest"
    if [ -n "$version" ]; then
        podman push "$image:$version"
    fi
fi
