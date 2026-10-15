#!/bin/sh
set -e

PUID="${PUID:-1001}"
PGID="${PGID:-1001}"

# Already non-root (e.g. started with --user): nothing to remap, just run
if [ "$(id -u)" -ne 0 ]; then
    exec /usr/local/bin/pocket-id "$@"
fi

case "$PUID$PGID" in
    ''|*[!0-9]*) echo "PUID and PGID must be numeric" >&2; exit 1 ;;
esac

# Remap group, then user, only if they differ from the current values.
# -o allows IDs already taken in the image (e.g. PGID=20 is "staff" on FreeBSD).
if [ "$(pw groupshow app | cut -d: -f3)" != "$PGID" ]; then
    pw groupmod app -g "$PGID" -o
fi
if [ "$(id -u app)" != "$PUID" ] || [ "$(id -g app)" != "$PGID" ]; then
    pw usermod app -u "$PUID" -g "$PGID" -o
fi

# Fix ownership of /data only when the top level is wrong (avoids slow recursive chown on every start)
if [ "$(stat -f %u:%g /data)" != "$PUID:$PGID" ]; then
    chown -R "$PUID:$PGID" /data
fi

# Drop privileges and replace this shell, so Pocket ID is PID 1 and receives signals
exec su-exec app:app /usr/local/bin/pocket-id "$@"
