#!/bin/bash
# End-to-end smoke test for the dserver signed-URL upload/download flow.
#
# Requires the docker compose stack to be running (docker compose up -d)
# and curl, jq, python3 on the host.
#
# Exercises:
#   1. token acquisition
#   2. POST /signed-urls/upload  (proto-dataset creation, pinned URLs)
#   3. tamper rejection: uploading wrong content must fail (Content-MD5)
#   4. item + README upload with pinned headers
#   5. POST /signed-urls/upload-complete (freeze + registration)
#   6. dataset appears in POST /uris search
#   7. GET /signed-urls/dataset + content download and MD5 verification
#
# Environment overrides:
#   DSERVER_URL  (default http://localhost:5000)
#   BASE_URI     (default s3://dtool-bucket)
#   DSERVER_TOKEN (default: signed locally with the stack's JWT key;
#                  requires PyJWT in $PYTHON)
#   PYTHON       (default python3)
#   STORAGE_CONNECT_TO (default minio:9000:localhost:9000 — routes the
#                  container-internal storage hostname to the host-mapped
#                  port without invalidating SigV4 signatures)

set -euo pipefail

DSERVER_URL=${DSERVER_URL:-http://localhost:5000}
BASE_URI=${BASE_URI:-s3://dtool-bucket}
PYTHON=${PYTHON:-python3}
STORAGE_CONNECT_TO=${STORAGE_CONNECT_TO:-minio:9000:localhost:9000}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Storage requests go to the URL exactly as signed, but connect to the
# host-mapped port (Host header and thus the signature stay intact).
STORAGE_CURL=(curl --connect-to "$STORAGE_CONNECT_TO")

say()  { printf '\033[1;34m== %s\033[0m\n' "$*"; }
fail() { printf '\033[1;31mFAIL: %s\033[0m\n' "$*"; exit 1; }

urlencode() { "$PYTHON" -c "import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=''))" "$1"; }

say "Acquiring token"
if [ -z "${DSERVER_TOKEN:-}" ]; then
    DSERVER_TOKEN=$("$PYTHON" - <<PYTHON_SCRIPT
import os
import jwt
from datetime import datetime, timedelta, timezone

key_file = os.environ.get(
    'JWT_PRIVATE_KEY_FILE', '${SCRIPT_DIR}/../compose/dserver/jwt/jwt_key')
with open(key_file) as f:
    private_key = f.read()
now = datetime.now(timezone.utc)
print(jwt.encode(
    {'sub': 'admin', 'iat': now, 'exp': now + timedelta(hours=1),
     'fresh': True},
    private_key, algorithm='RS256'))
PYTHON_SCRIPT
)
fi
TOKEN=$DSERVER_TOKEN
[ -n "$TOKEN" ] || fail "could not acquire token"
AUTH=(-H "Authorization: Bearer $TOKEN")

UUID=$(python3 -c "import uuid; print(uuid.uuid4())")
DATASET_URI="$BASE_URI/$UUID"
NAME="e2e-smoke-test"
CONTENT="e2e smoke test content $UUID"
MD5=$(printf '%s' "$CONTENT" | python3 -c "import hashlib,sys; print(hashlib.md5(sys.stdin.buffer.read()).hexdigest())")
SIZE=$(printf '%s' "$CONTENT" | wc -c | tr -d ' ')
NOW=$(python3 -c "import time; print(time.time())")

say "Requesting upload URLs for $DATASET_URI"
UPLOAD_RESPONSE=$(curl -sf -X POST \
    "$DSERVER_URL/signed-urls/upload/$(urlencode "$BASE_URI")" \
    "${AUTH[@]}" -H "Content-Type: application/json" \
    -d @- <<JSON
{
  "uuid": "$UUID",
  "name": "$NAME",
  "creator_username": "admin",
  "frozen_at": $NOW,
  "hash_function": "md5sum_hexdigest",
  "items": [{"relpath": "data.txt", "size_in_bytes": $SIZE,
             "hash": "$MD5", "utc_timestamp": $NOW}],
  "tags": ["e2e"],
  "annotations": {"purpose": "smoke-test"},
  "overlays": {}
}
JSON
) || fail "upload URL request failed"

README_URL=$(jq -r '.upload_urls.readme' <<<"$UPLOAD_RESPONSE")
ITEM_URL=$(jq -r '.upload_urls.items | to_entries[0].value.url' <<<"$UPLOAD_RESPONSE")
ITEM_HEADER_ARGS=()
while IFS= read -r header; do
    ITEM_HEADER_ARGS+=(-H "$header")
done < <(jq -r '.upload_urls.items | to_entries[0].value.headers
                | to_entries[] | "\(.key): \(.value)"' <<<"$UPLOAD_RESPONSE")
[ -n "$ITEM_URL" ] && [ "$ITEM_URL" != "null" ] || fail "no item upload URL"
[ ${#ITEM_HEADER_ARGS[@]} -gt 0 ] || fail "no pinned headers returned"

say "Verifying tampered content is rejected by storage"
TAMPER_STATUS=$("${STORAGE_CURL[@]}" -s -o /dev/null -w '%{http_code}' -X PUT \
    "${ITEM_HEADER_ARGS[@]}" --data-binary "TAMPERED CONTENT" "$ITEM_URL")
case "$TAMPER_STATUS" in
    4*) ;;  # BadDigest / SignatureDoesNotMatch expected
    *) fail "tampered upload was not rejected (HTTP $TAMPER_STATUS)" ;;
esac

say "Uploading item and README"
"${STORAGE_CURL[@]}" -sf -X PUT "${ITEM_HEADER_ARGS[@]}" \
    --data-binary "$CONTENT" "$ITEM_URL" > /dev/null \
    || fail "item upload failed"
"${STORAGE_CURL[@]}" -sf -X PUT -H "Content-Type: text/plain; charset=utf-8" \
    --data-binary "description: e2e smoke test" "$README_URL" > /dev/null \
    || fail "README upload failed"

say "Signaling upload complete"
COMPLETE_RESPONSE=$(curl -sf -X POST "$DSERVER_URL/signed-urls/upload-complete" \
    "${AUTH[@]}" -H "Content-Type: application/json" \
    -d "{\"uri\": \"$DATASET_URI\"}") || fail "upload-complete failed"
STATUS=$(jq -r '.status' <<<"$COMPLETE_RESPONSE")
REGISTERED_NAME=$(jq -r '.name' <<<"$COMPLETE_RESPONSE")
[ "$STATUS" = "registered" ] || fail "unexpected status: $STATUS"
[ "$REGISTERED_NAME" = "$NAME" ] || fail "dataset registered as '$REGISTERED_NAME', expected '$NAME'"

say "Looking up the dataset by UUID"
FOUND=$(curl -sf "$DSERVER_URL/uuids/$UUID" "${AUTH[@]}" | jq -r '.[0].uri')
[ "$FOUND" = "$DATASET_URI" ] || fail "dataset not found by UUID (got: $FOUND)"

say "Fetching signed read URLs and verifying content"
READ_RESPONSE=$(curl -sf \
    "$DSERVER_URL/signed-urls/dataset/$(urlencode "$DATASET_URI")" \
    "${AUTH[@]}") || fail "signed read URL request failed"
ITEM_READ_URL=$(jq -r '.item_urls | to_entries[0].value' <<<"$READ_RESPONSE")
DOWNLOADED=$("${STORAGE_CURL[@]}" -sf "$ITEM_READ_URL") || fail "item download failed"
[ "$DOWNLOADED" = "$CONTENT" ] || fail "downloaded content differs"
DOWNLOADED_MD5=$(printf '%s' "$DOWNLOADED" | python3 -c "import hashlib,sys; print(hashlib.md5(sys.stdin.buffer.read()).hexdigest())")
[ "$DOWNLOADED_MD5" = "$MD5" ] || fail "MD5 mismatch after round-trip"

say "PASS: full signed-URL upload/download cycle OK ($DATASET_URI)"
