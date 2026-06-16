#! /bin/bash
# Index all datasets from the configured bucket into dserver.
# Works from any directory: paths are anchored to this script's location.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TOKEN=$(python << PYTHON_SCRIPT
import os
import jwt
from datetime import datetime, timedelta, timezone

private_key_file = os.environ.get(
    'JWT_PRIVATE_KEY_FILE', '${SCRIPT_DIR}/jwt/jwt_key')
with open(private_key_file, 'r') as f:
    private_key = f.read()

payload = {
    'sub': 'admin',
    'iat': datetime.now(timezone.utc),
    'exp': datetime.now(timezone.utc) + timedelta(hours=1),
    'fresh': True
}

token = jwt.encode(payload, private_key, algorithm='RS256')
print(token)
PYTHON_SCRIPT
)

python3 "${SCRIPT_DIR}/tools/indexall.py" "$TOKEN" s3://dtool-bucket
