#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

echo "==> Dataset indexer for S3 bucket"
echo "    This script indexes all datasets in the S3 bucket to dserver"

# Wait for dserver to be available
echo "==> Waiting for dserver to be ready..."
until curl -sf http://dserver:5000/config/info > /dev/null; do
    echo "    Waiting..."
    sleep 2
done
echo "    dserver is ready!"

# Generate a token for authentication
echo "==> Generating admin token..."
JWT_PRIVATE_KEY_FILE="${JWT_PRIVATE_KEY_FILE:-/app/compose/dserver/jwt/jwt_key}"

TOKEN=$(python << PYTHON_SCRIPT
import os
import jwt
from datetime import datetime, timedelta, timezone

private_key_file = os.environ.get('JWT_PRIVATE_KEY_FILE', '/app/compose/dserver/jwt/jwt_key')
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

echo "==> Listing datasets in S3 bucket..."
DATASETS=$(dtool ls s3://dtool-bucket 2>/dev/null || echo "")

if [ -z "$DATASETS" ]; then
    echo "    No datasets found in s3://dtool-bucket"
    echo "    To create a test dataset, run:"
    echo "      docker compose run --rm indexer /scripts/create-test-dataset.sh"
    exit 0
fi

echo "==> Found datasets:"
echo "$DATASETS"

echo "==> Indexing datasets to dserver..."
# Use dtool CLI to get dataset info and register with dserver
while IFS= read -r line; do
    if [ -z "$line" ]; then
        continue
    fi

    # Extract URI from the line (format: "  - <name>  <uri>")
    URI=$(echo "$line" | awk '{print $NF}')

    if [ -z "$URI" ] || [[ ! "$URI" == s3://* ]]; then
        continue
    fi

    echo "    Indexing: $URI"

    # Get dataset info as JSON and register it
    python << PYTHON_INDEX
import os
import json
import requests
import dtoolcore

uri = "$URI"
token = "$TOKEN"
dserver_url = os.environ.get('DSERVER_URL', 'http://dserver:5000')

try:
    # Get dataset
    ds = dtoolcore.DataSet.from_uri(uri)

    # Build registration payload
    info = {
        'uuid': ds.uuid,
        'uri': uri,
        'base_uri': 's3://dtool-bucket',
        'name': ds.name,
        'creator_username': ds._admin_metadata.get('creator_username', 'unknown'),
        'frozen_at': ds._admin_metadata.get('frozen_at', 0),
        'created_at': ds._admin_metadata.get('created_at', 0),
        'annotations': ds.get_annotation('dtool') if 'dtool' in ds.list_annotation_names() else {},
        'tags': list(ds.list_tags()),
        'readme': ds.get_readme_content(),
        'manifest': ds._manifest
    }

    # Register with dserver
    headers = {
        'Authorization': f'Bearer {token}',
        'Content-Type': 'application/json'
    }

    response = requests.post(
        f'{dserver_url}/dataset/register',
        headers=headers,
        json=info
    )

    if response.status_code in (200, 201, 409):
        print(f"      Registered: {ds.name} ({ds.uuid})")
    else:
        print(f"      Failed: {response.status_code} - {response.text}")

except Exception as e:
    print(f"      Error: {e}")
PYTHON_INDEX

done <<< "$DATASETS"

echo "==> Indexing complete!"
