#!/usr/bin/env bash
# Run the Vue.js webapp development server with hot reload.
# VUE_APP_* configuration comes from the environment (see devbox.json).
set -o errexit
set -o pipefail
set -o nounset

ROOT="${DEVBOX_PROJECT_ROOT:?DEVBOX_PROJECT_ROOT not set}"
cd "$ROOT/dtool-lookup-webapp/dtool-lookup-webapp"

exec npm run serve -- --host 127.0.0.1 --port 8080
