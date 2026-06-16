#!/usr/bin/env bash
# MongoDB service with access control enabled. The dserver user is created by
# mongo-init.sh via the localhost exception on first run.
set -o errexit
set -o pipefail
set -o nounset

ROOT="${DEVBOX_PROJECT_ROOT:?DEVBOX_PROJECT_ROOT not set}"

exec mongod \
    --dbpath "$ROOT/.devbox-data/mongo" \
    --bind_ip 127.0.0.1 \
    --port 27017 \
    --auth
