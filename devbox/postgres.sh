#!/usr/bin/env bash
# PostgreSQL service. Initializes the data directory on first run, then runs
# postgres in the foreground (process-compose manages the lifecycle).
set -o errexit
set -o pipefail
set -o nounset

ROOT="${DEVBOX_PROJECT_ROOT:?DEVBOX_PROJECT_ROOT not set}"
PGDATA="$ROOT/.devbox-data/postgres"

# The Nix glibc has no host locales, so any inherited LANG/LC_* makes initdb
# fail with "invalid locale settings". Force the always-available C locale.
export LC_ALL=C
export LANG=C

if [ ! -f "$PGDATA/PG_VERSION" ]; then
    echo "==> Initializing PostgreSQL data directory..."
    # Clear any leftovers from a previously failed init (no valid cluster exists
    # yet, so this is safe) — initdb requires an empty target directory.
    rm -rf "${PGDATA:?}/"* 2>/dev/null || true
    # trust auth keeps local development simple; the password in the connection
    # URI is accepted but not verified, matching the docker stack's behaviour.
    initdb -D "$PGDATA" --auth=trust --username=dserver \
        --encoding=UTF8 --locale=C >/dev/null
fi

exec postgres \
    -D "$PGDATA" \
    -c listen_addresses=127.0.0.1 \
    -c port=5432 \
    -c unix_socket_directories="$PGDATA"
