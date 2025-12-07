#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

echo "==> Generating JWT keys if they don't exist..."
JWT_DIR="/app/compose/dserver/jwt"
mkdir -p "$JWT_DIR"

if [ ! -f "$JWT_DIR/jwt_key" ]; then
    echo "    Generating RSA key pair..."
    openssl genrsa -out "$JWT_DIR/jwt_key" 2048
    openssl rsa -in "$JWT_DIR/jwt_key" -pubout -out "$JWT_DIR/jwt_key.pub"
    chmod 600 "$JWT_DIR/jwt_key"
    chmod 644 "$JWT_DIR/jwt_key.pub"
    echo "    JWT keys generated."
else
    echo "    JWT keys already exist."
fi

echo "==> Waiting for database to be ready..."
sleep 2

echo "==> Running database migrations..."
flask db init || true  # May already be initialized
flask db migrate -m "Auto migration" || true  # May have nothing to migrate
flask db upgrade

echo "==> Creating default admin user if not exists..."
flask user add --is_admin admin || echo "    User 'admin' may already exist"

echo "==> Registering S3 base URI..."
flask base_uri add s3://dtool-bucket || echo "    Base URI may already exist"

echo "==> Granting admin access to S3 bucket..."
flask user search_permission admin s3://dtool-bucket || echo "    Permission may already exist"
flask user register_permission admin s3://dtool-bucket || echo "    Permission may already exist"

echo "==> Starting dserver with Flask development server..."
echo "    Access the API at http://localhost:5000"
echo "    OpenAPI docs at http://localhost:5000/doc/swagger"

exec flask run --host 0.0.0.0 --port 5000 --debug
