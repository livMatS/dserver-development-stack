#!/usr/bin/env bash
# Start the dserver Flask development server.
# Mirrors compose/dserver/scripts/start-dserver.sh, adapted for local paths.
set -o errexit
set -o pipefail
set -o nounset

ROOT="${DEVBOX_PROJECT_ROOT:?DEVBOX_PROJECT_ROOT not set}"
cd "$ROOT"

# shellcheck disable=SC1091
source "$ROOT/.venv/bin/activate"

# Load OAuth2 credentials if a local .env file is present.
if [ -f "$ROOT/.env" ]; then
    set -o allexport
    # shellcheck disable=SC1091
    source "$ROOT/.env"
    set +o allexport
fi

echo "==> Running database migrations..."
# Order matters: apply existing migrations first so the database is at the
# current head, THEN autogenerate + apply a migration for any model changes not
# yet captured by a committed migration (e.g. columns added since). `flask db
# migrate` refuses to run unless the database is already up to date, so it must
# come after the first upgrade — running it first (as the docker stack did)
# silently leaves the schema stale and breaks `flask user add`.
flask db upgrade
flask db migrate -m "sync models with database" || true
flask db upgrade

echo "==> Creating default admin user if not exists..."
flask user add --is_admin admin || echo "    User 'admin' may already exist"

echo "==> Registering S3 base URI..."
flask base_uri add s3://dtool-bucket || echo "    Base URI may already exist"

echo "==> Granting admin access to S3 bucket..."
flask user search_permission admin s3://dtool-bucket || echo "    Permission may already exist"
flask user register_permission admin s3://dtool-bucket || echo "    Permission may already exist"

echo "==> Starting dserver..."
echo "    API:  http://127.0.0.1:5000"
echo "    Docs: http://127.0.0.1:5000/doc/swagger"

exec flask run --host 127.0.0.1 --port 5000 --debug
