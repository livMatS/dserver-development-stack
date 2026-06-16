#!/usr/bin/env bash
# Index all datasets in s3://dtool-bucket into dserver.
# Equivalent to the docker stack's `index-s3` profile service.
set -o errexit
set -o pipefail
set -o nounset

ROOT="${DEVBOX_PROJECT_ROOT:?DEVBOX_PROJECT_ROOT not set}"
cd "$ROOT"

# shellcheck disable=SC1091
source "$ROOT/.venv/bin/activate"

echo "==> Indexing all datasets in s3://dtool-bucket..."
flask base_uri index s3://dtool-bucket
echo "==> Indexing complete!"
