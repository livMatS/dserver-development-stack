#!/usr/bin/env bash
# Create the MongoDB root user. On a fresh data directory the localhost
# exception allows creating the first user even with --auth enabled. On
# subsequent runs auth is required and createUser fails harmlessly.
set -o errexit
set -o pipefail
set -o nounset

mongosh --host 127.0.0.1 --port 27017 --quiet admin --eval '
  try {
    db.createUser({
      user: "dserver",
      pwd: "dserver_secret",
      roles: [{ role: "root", db: "admin" }]
    });
    print("==> Created MongoDB user dserver");
  } catch (e) {
    print("==> MongoDB user already initialized (" + e.codeName + ")");
  }
' || true
