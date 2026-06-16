#!/usr/bin/env bash
# Create the dserver database once postgres is accepting connections.
set -o errexit
set -o pipefail
set -o nounset

export LC_ALL=C
export LANG=C

# Query the always-present 'postgres' maintenance database so the existence
# check never tries (and fails) to connect to a 'dserver' db that isn't there.
if psql -h 127.0.0.1 -p 5432 -U dserver -d postgres -tAc \
        "SELECT 1 FROM pg_database WHERE datname='dserver'" | grep -q 1; then
    echo "==> PostgreSQL database 'dserver' already exists."
else
    echo "==> Creating PostgreSQL database 'dserver'..."
    createdb -h 127.0.0.1 -p 5432 -U dserver dserver
fi
