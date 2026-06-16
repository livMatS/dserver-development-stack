#!/usr/bin/env bash
# Create the dtool-bucket and make it publicly readable.
# Replaces the minio-init container in the docker stack.
set -o errexit
set -o pipefail
set -o nounset

mc alias set dserver-local http://127.0.0.1:9000 minioadmin minioadmin
mc mb --ignore-existing dserver-local/dtool-bucket
mc anonymous set public dserver-local/dtool-bucket
echo "==> MinIO bucket 'dtool-bucket' ready."
