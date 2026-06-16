#!/usr/bin/env bash
# Build the Python virtual environment with all dserver packages in editable
# mode. Mirrors compose/dserver/scripts/make-venv.sh but installs into a
# project-local .venv instead of the /venv docker volume.
set -o errexit
set -o pipefail
set -o nounset

ROOT="${DEVBOX_PROJECT_ROOT:?DEVBOX_PROJECT_ROOT not set}"
VENV="$ROOT/.venv"

echo "==> Creating Python virtual environment..."
python -m venv "$VENV"
# shellcheck disable=SC1091
source "$VENV/bin/activate"

echo "==> Upgrading pip..."
# Pin setuptools < 81: dtool-cli (and other dtool packages) still import the
# legacy pkg_resources module, which setuptools removed in v81.
pip install --upgrade pip wheel "setuptools<81"

echo "==> Installing dtoolcore..."
pip install -e "$ROOT/dtoolcore"

echo "==> Installing dtool-s3..."
pip install -e "$ROOT/dtool-s3"

echo "==> Installing the dtool CLI meta-package (from PyPI)..."
# The 'dtool' meta-package pulls dtool-cli, dtool-create (create/freeze/cp),
# dtool-info (ls/summary) and the other standard CLI plugins. Installing only
# dtool-cli + dtool-info (as the docker make-venv did) leaves create/freeze/cp
# missing, so the test-dataset helper and the README's push workflow fail.
pip install dtool

echo "==> Installing dservercore..."
pip install -e "$ROOT/dservercore"

echo "==> Installing dserver-search-plugin-mongo..."
pip install -e "$ROOT/dserver-search-plugin-mongo"

echo "==> Installing dserver-retrieve-plugin-mongo..."
pip install -e "$ROOT/dserver-retrieve-plugin-mongo"

echo "==> Installing dserver-dependency-graph-plugin..."
pip install -e "$ROOT/dserver-dependency-graph-plugin"

echo "==> Installing dserver-signed-url-plugin..."
pip install -e "$ROOT/dserver-signed-url-plugin"

echo "==> Installing dserver-token-generator-plugin-oauth2..."
pip install -e "$ROOT/dserver-token-generator-plugin-oauth2"

echo "==> Installing additional dependencies..."
pip install gunicorn psycopg2-binary PyJWT requests authlib httpx python-dotenv flask-cors

echo "==> Virtual environment setup complete!"
touch "$VENV/VENV-READY"
