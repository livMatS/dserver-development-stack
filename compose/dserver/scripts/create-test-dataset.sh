#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

echo "==> Creating a test dataset in S3 bucket..."

# Create a temporary directory for the dataset
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

cd "$TEMP_DIR"

echo "==> Creating proto dataset..."
dtool create test-dataset

cd test-dataset

echo "==> Adding some test files..."
echo "Hello, dtool!" > data/hello.txt
echo "This is a test dataset for dserver development." > data/readme.txt
echo '{"key": "value", "number": 42}' > data/config.json

echo "==> Adding README content..."
cat > README.yml << 'EOF'
description: Test dataset for dserver development
project: dserver-development-stack
owners:
  - name: Developer
    email: dev@example.com
creation_date: "2024-01-01"
EOF

echo "==> Freezing dataset..."
dtool freeze .

echo "==> Copying dataset to S3..."
DATASET_URI=$(dtool cp . s3://dtool-bucket)

echo "==> Test dataset created!"
echo "    URI: $DATASET_URI"

echo "==> Indexing dataset in dserver..."
flask base_uri index s3://dtool-bucket

echo "==> Done! The test dataset should now be visible in dserver."
