#!/bin/sh
# usage: scripts/changed-images.sh [<base commit>]
#
#   $ scripts/changed-images.sh origin/master
#
# Prints the images to build (top-level directories with a Containerfile), one per
# line. With a base commit, only images with files changed between it and HEAD.
# Prints every image when shared build files changed, or when there is no usable
# base (manual run, new branch, base no longer in history).
set -eu

all=$(find . -mindepth 2 -maxdepth 2 -name Containerfile -not -path './.*' | cut -d/ -f2 | sort)
base=${1:-}

# GitHub sends an all-zero SHA as "before" for a newly created branch
case "$base" in
    *[!0]*) ;;
    *) base= ;;
esac

if [ -z "$base" ] || ! git cat-file -e "$base^{commit}" 2>/dev/null; then
    printf '%s\n' "$all"
    exit 0
fi

# Three dots: changes on HEAD's side since the merge base, so force pushes and PRs work too
changed=$(git diff --name-only "$base"...HEAD)

# These affect how every image is built
if printf '%s\n' "$changed" | grep -qxE 'scripts/build\.sh|\.github/workflows/build\.yml'; then
    printf '%s\n' "$all"
    exit 0
fi

for image in $all; do
    printf '%s\n' "$changed" | while IFS= read -r file; do
        case "$file" in
            "$image"/*) echo "$image"; break ;;
        esac
    done
done
