#!/bin/sh
# usage: genuid.sh <template path>
#
#   $ ./genuid.sh pocketbase
#
# Derives a number between 2000 and 9999 from the template's directory name,
# writes it into the PUID/PGID values in <template path>/Dockerfile, and prints it

if [ -z "$1" ]; then
    echo "usage: $0 <template path>" >&2
    exit 1
fi

dockerfile="$1/Dockerfile"
if [ ! -f "$dockerfile" ]; then
    echo "$dockerfile: not found" >&2
    exit 1
fi

# Hash the directory name only, so "pocketbase", "./pocketbase/" and an absolute path agree
name=$(basename "$1")
hash=$(printf '%s' "$name" | cksum | cut -d' ' -f1)
id=$(( hash % 8000 + 2000 ))

if ! grep -Eq '(PUID|PGID)=[0-9]+' "$dockerfile"; then
    echo "$dockerfile: no PUID=/PGID= values to replace" >&2
    exit 1
fi

# Write through a temp file instead of sed -i, whose syntax differs between BSD and GNU sed
tmp=$(mktemp) || exit 1
trap 'rm -f "$tmp"' EXIT
sed -E "s/(PUID|PGID)=[0-9]+/\1=$id/g" "$dockerfile" > "$tmp" || exit 1
cat "$tmp" > "$dockerfile"

echo "$id"
