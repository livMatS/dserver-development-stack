#!/usr/bin/env bash
# Exec "$@" with the dtool S3 settings for the dtool-bucket present in the
# environment.
#
# These variable names contain hyphens (the bucket name), which bash cannot
# export and devbox.json's `env` block cannot emit (it sets vars via shell
# export, and POSIX forbids hyphens in identifiers). We inject them with the
# `env` command instead — execve preserves arbitrary names, and bash forwards
# inherited non-identifier variables to its children, so the Python processes
# (dtool / flask) see them via os.environ.
#
# Single source of truth for the S3 settings shared by the dserver service,
# the indexer and the test-dataset helper.
set -o errexit
set -o nounset

exec env \
    "DTOOL_S3_ENDPOINT_dtool-bucket=http://127.0.0.1:9000" \
    "DTOOL_S3_ACCESS_KEY_ID_dtool-bucket=minioadmin" \
    "DTOOL_S3_SECRET_ACCESS_KEY_dtool-bucket=minioadmin" \
    "DTOOL_S3_DISABLE_BUCKET_VERSIONING_dtool-bucket=true" \
    "$@"
