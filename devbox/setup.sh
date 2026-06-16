#!/usr/bin/env bash
# One-time environment preparation, run from the devbox init_hook.
# Everything here is guarded so repeated shell entries are cheap.
set -o errexit
set -o pipefail
set -o nounset

ROOT="${DEVBOX_PROJECT_ROOT:?DEVBOX_PROJECT_ROOT not set}"

# --------------------------------------------------------------------------
# Runtime data directories (gitignored) replace the docker named volumes.
# --------------------------------------------------------------------------
mkdir -p "$ROOT/.devbox-data/postgres" \
         "$ROOT/.devbox-data/mongo" \
         "$ROOT/.devbox-data/minio"

# --------------------------------------------------------------------------
# JWT keys (generated at runtime, gitignored)
# --------------------------------------------------------------------------
JWT_DIR="$ROOT/jwt"
mkdir -p "$JWT_DIR"
if [ ! -f "$JWT_DIR/jwt_key" ]; then
    echo "==> Generating JWT RSA key pair..."
    openssl genrsa -out "$JWT_DIR/jwt_key" 2048
    openssl rsa -in "$JWT_DIR/jwt_key" -pubout -out "$JWT_DIR/jwt_key.pub"
    chmod 600 "$JWT_DIR/jwt_key"
    chmod 644 "$JWT_DIR/jwt_key.pub"
fi

# --------------------------------------------------------------------------
# Python virtual environment (replaces the dserver-build-venv container)
# --------------------------------------------------------------------------
if [ ! -f "$ROOT/.venv/VENV-READY" ]; then
    echo "==> Building Python virtual environment (first run, this can take a while)..."
    bash "$ROOT/devbox/setup-venv.sh"
fi

# --------------------------------------------------------------------------
# Node dependencies (replaces the webapp image build)
# --------------------------------------------------------------------------
if [ ! -d "$ROOT/dserver-client-js/node_modules" ] || \
   [ ! -d "$ROOT/dtool-lookup-webapp/dtool-lookup-webapp/node_modules" ]; then
    echo "==> Installing Node dependencies (first run, this can take a while)..."
    bash "$ROOT/devbox/setup-webapp.sh"
fi
