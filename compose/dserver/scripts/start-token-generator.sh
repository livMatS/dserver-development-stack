#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

echo "==> Starting simple JWT token generator service..."
echo "    This is a development-only token generator!"
echo "    Access at http://localhost:5001/token"

# Simple Flask app that generates JWT tokens for development
python << 'PYTHON_SCRIPT'
import os
import jwt
from datetime import datetime, timedelta, timezone
from flask import Flask, request, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

# Load private key for signing tokens
private_key_file = os.environ.get('JWT_PRIVATE_KEY_FILE', '/app/compose/dserver/jwt/jwt_key')
with open(private_key_file, 'r') as f:
    PRIVATE_KEY = f.read()

@app.route('/token', methods=['POST', 'OPTIONS'])
def get_token():
    """Generate a JWT token for development/testing."""
    if request.method == 'OPTIONS':
        return '', 200

    # For development, accept any username/password
    data = request.get_json() or {}
    username = data.get('username', 'admin')

    # Create JWT token
    payload = {
        'sub': username,
        'iat': datetime.now(timezone.utc),
        'exp': datetime.now(timezone.utc) + timedelta(hours=24),
        'fresh': True
    }

    token = jwt.encode(payload, PRIVATE_KEY, algorithm='RS256')

    return jsonify({'token': token})

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'ok'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001)
PYTHON_SCRIPT
