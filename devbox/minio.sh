#!/usr/bin/env bash
# MinIO S3-compatible object storage service.
# Credentials and CORS are configured via MINIO_* env vars (see devbox.json).
set -o errexit
set -o pipefail
set -o nounset

ROOT="${DEVBOX_PROJECT_ROOT:?DEVBOX_PROJECT_ROOT not set}"

exec minio server "$ROOT/.devbox-data/minio" \
    --address 127.0.0.1:9000 \
    --console-address 127.0.0.1:9001
