#!/usr/bin/env bash
# Install Node dependencies for the JS client and the webapp.
# Replaces the steps baked into compose/webapp/Dockerfile. Because everything
# runs in-place, the webapp's "file:../../dserver-client-js" dependency
# resolves to the top-level submodule without any path rewriting.
set -o errexit
set -o pipefail
set -o nounset

ROOT="${DEVBOX_PROJECT_ROOT:?DEVBOX_PROJECT_ROOT not set}"

echo "==> Building dserver-client-js..."
cd "$ROOT/dserver-client-js"
npm install
npm run build

echo "==> Installing dtool-lookup-webapp dependencies..."
cd "$ROOT/dtool-lookup-webapp/dtool-lookup-webapp"
npm install

echo "==> Node dependencies installed."
