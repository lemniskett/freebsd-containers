#!/bin/sh
set -e

PUID="${PUID:-1001}"
PGID="${PGID:-1001}"

# "login" runs the interactive mode (log in, pick favorites, set up Telegram),
# which is steamidled with no arguments; anything else is passed straight through
if [ "${1:-}" = login ]; then
    set --
fi

# Already non-root (e.g. started with --user): nothing to remap, just run
if [ "$(id -u)" -ne 0 ]; then
    exec /usr/local/bin/bun /app/dist/index.js "$@"
fi

case "$PUID$PGID" in
    ''|*[!0-9]*) echo "PUID and PGID must be numeric" >&2; exit 1 ;;
esac

# Remap group, then user, only if they differ from the current values.
# freebsd-runtime has no cut/stat/awk, so parse with the shell and find.
# groupmod/usermod don't reject IDs already in use (e.g. PGID=20 is "staff").
group=$(pw groupshow app)    # app:*:<gid>:<members>
gid=${group#*:*:}
if [ "${gid%%:*}" != "$PGID" ]; then
    pw groupmod app -g "$PGID"
fi
if [ "$(id -u app)" != "$PUID" ] || [ "$(id -g app)" != "$PGID" ]; then
    pw usermod app -u "$PUID" -g app
fi

# Fix ownership of /data only when the top level is wrong (avoids slow recursive chown on every start)
if [ -z "$(find /data -maxdepth 0 -user "$PUID" -group "$PGID")" ]; then
    chown -R "$PUID:$PGID" /data
fi

# Drop privileges and replace this shell, so steamidled is PID 1 and receives signals
exec su-exec app:app /usr/local/bin/bun /app/dist/index.js "$@"
