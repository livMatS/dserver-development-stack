#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

# Activate Python virtual environment
source /venv/bin/activate

exec "$@"
