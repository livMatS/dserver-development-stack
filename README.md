# dserver-development-stack

[devbox](https://www.jetify.com/devbox)-based development stack for dserver and
the dtool-lookup-webapp. Services run as native processes (managed by
[process-compose](https://github.com/F1bonacc1/process-compose)) on top of Nix
packages — no containers required.

## Overview

This repository provides a complete development environment for:

- **dserver** - REST API for registering, looking up, and searching dtool dataset metadata
- **dtool-lookup-webapp** - Vue.js web frontend for searching datasets
- **MinIO** - S3-compatible object storage for datasets
- **PostgreSQL** - SQL database for dserver admin metadata
- **MongoDB** - NoSQL database for dataset search and retrieval

The service topology is defined in `process-compose.yaml`; the toolchain and
environment are defined in `devbox.json`. The launch/init scripts live in
`devbox/`.

## Prerequisites

- [devbox](https://www.jetify.com/devbox) (installs Nix on first use)
- Git

## Installation

### 1. Clone the repository with submodules

```bash
git clone --recursive git@github.com:your-org/dserver-development-stack.git
cd dserver-development-stack
```

If you already cloned without `--recursive`, initialize the submodules:

```bash
git submodule update --init --recursive
```

### 2. Enter the environment

```bash
# MongoDB is distributed under the SSPL and is "unfree" in Nixpkgs,
# so unfree packages must be allowed for the install.
export NIXPKGS_ALLOW_UNFREE=1

devbox shell
```

On first entry this:
- installs all Nix packages (Python, Node, PostgreSQL, MongoDB, MinIO, …),
- builds the Python virtual environment (`.venv`) with every dserver package in
  editable mode,
- installs the Node dependencies for the webapp, and
- generates JWT keys for authentication.

Subsequent entries are fast.

### 3. Start all services

```bash
devbox services up
```

This brings up PostgreSQL, MongoDB, MinIO (with bucket initialization), the
dserver API, and the webapp, respecting health checks and start-up order.
Runtime data is stored under `.devbox-data/` (gitignored); every service binds
to `127.0.0.1` on the ports listed below. Stop the stack with `Ctrl-C` (or
`devbox services stop` from another shell).

## Services

| Service | Port | Description |
|---------|------|-------------|
| **dserver** | 5000 | REST API for dataset metadata (includes token generator) |
| **webapp** | 8080 | Vue.js frontend |
| **minio** | 9000 (API), 9001 (Console) | S3-compatible storage |
| **postgres** | 5432 | PostgreSQL database |
| **mongo** | 27017 | MongoDB database |

## devbox commands

| Command | Description |
|---------|-------------|
| `devbox shell` | Enter the dev environment (builds venv/node deps on first run) |
| `devbox services up` | Start the full stack |
| `devbox services up index-s3` | Also run the on-demand dataset indexer |
| `devbox run index` | Index `s3://dtool-bucket` into dserver |
| `devbox run create-test-dataset` | Create, push and index a sample dataset |
| `devbox run psql` | Open a `psql` shell on the dserver database |
| `devbox run rebuild-venv` | Delete and rebuild `.venv` |
| `devbox run clean-data` | Remove the `.devbox-data/` runtime data |

OAuth2 credentials are read from a local `.env` file — copy `.env.template` to
`.env` and fill it in.

## Usage

### Access the services

- **dserver API**: http://127.0.0.1:5000
- **API Documentation**: http://127.0.0.1:5000/doc/swagger (requires authentication)
- **Webapp**: http://127.0.0.1:8080
- **MinIO Console**: http://127.0.0.1:9001 (credentials: `minioadmin` / `minioadmin`)

### Create a test dataset

To create a sample dataset, push it to MinIO and index it in dserver:

```bash
devbox run create-test-dataset
```

### Index existing datasets from S3

If you have datasets in the MinIO bucket, index them with:

```bash
devbox run index
```

### Push datasets from the command line

You can push datasets directly to the MinIO S3 storage using the `dtool`
command line tool. Inside `devbox shell` the `dtool` CLI is already on the
`PATH`; on a separate host machine, install it with `pip install dtool dtool-s3`.

#### Configure dtool

Copy the provided configuration file to your dtool config directory:

```bash
cp dtool.json ~/.config/dtool/dtool.json
```

Or set the environment variables directly:

```bash
export DTOOL_S3_ENDPOINT_dtool-bucket="http://127.0.0.1:9000"
export DTOOL_S3_ACCESS_KEY_ID_dtool-bucket="minioadmin"
export DTOOL_S3_SECRET_ACCESS_KEY_dtool-bucket="minioadmin"
export DTOOL_S3_DISABLE_BUCKET_VERSIONING_dtool-bucket=true
```

> The per-bucket variable names contain a hyphen (the bucket name). Inside the
> stack these are injected for you by `devbox/with-dtool-s3.sh`; for manual
> `dtool` use, the `~/.config/dtool/dtool.json` route above is simplest.

#### Create and push a dataset

```bash
dtool create my-dataset
cp some-file.txt my-dataset/data/
dtool freeze my-dataset
dtool cp my-dataset s3://dtool-bucket/
```

Then index it so it appears in the webapp:

```bash
devbox run index
```

#### List / fetch datasets on S3

```bash
dtool ls s3://dtool-bucket/
dtool cp s3://dtool-bucket/<uuid> ./local-copy/
```

### Access datasets via dserver (without backend credentials)

The `dtool-dserver` storage broker allows you to access datasets through
dserver without requiring direct S3/Azure credentials.

Install it on the client (`pip install dtool-dserver`) and configure access via
`~/.config/dtool/dtool.json` (set `DSERVER_TOKEN`, see below) or the
`DSERVER_TOKEN` environment variable.

URIs have the form `dserver://<server>/<backend>/<bucket>[/<uuid>]`, where
`<backend>/<bucket>` maps to the storage backend base URI
`<backend>://<bucket>` on the server:

```bash
dtool ls dserver://127.0.0.1:5000/s3/dtool-bucket/
dtool cp dserver://127.0.0.1:5000/s3/dtool-bucket/<uuid> ./local-copy/
dtool cp my-dataset dserver://127.0.0.1:5000/s3/dtool-bucket/
```

**Benefits:**
- No need for S3/Azure credentials on client machines
- Centralized access control through dserver
- Automatic dataset registration on upload

### Get an authentication token

Authentication is provided by the OAuth2 token generator plugin
(`dserver-token-generator-plugin-oauth2`). There are three ways to obtain a
token:

**1. Browser (OAuth2 / ORCID login)** — the webapp's login button drives this.
It redirects through `GET /auth/login` → the provider → `GET /auth/callback`,
and requires `OAUTH2_CLIENT_ID` / `OAUTH2_CLIENT_SECRET` in your `.env`.

**2. Headless API key** — `POST /auth/token` exchanges an API key for a JWT.
This requires `OAUTH2_API_KEY` to be set in the environment:

```bash
curl -X POST http://127.0.0.1:5000/auth/token \
  -H "Content-Type: application/json" \
  -d '{"api_key": "<your-OAUTH2_API_KEY>", "username": "admin"}'
```

**3. Local development (no OAuth provider needed)** — sign a JWT directly with
the server's private key. This is what `indexall.sh` does:

```bash
TOKEN=$(python - <<'PY'
import jwt, datetime
key = open("jwt/jwt_key").read()
print(jwt.encode({
    "sub": "admin", "username": "admin",
    "iat": datetime.datetime.now(datetime.timezone.utc),
    "exp": datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(hours=1),
    "fresh": True,
}, key, algorithm="RS256"))
PY
)

curl -H "Authorization: Bearer $TOKEN" http://127.0.0.1:5000/config/info
```

Use the returned token in the `Authorization: Bearer <token>` header.

> **Note:** Indexing datasets does not need a token — `devbox run index`
> (or the `index-s3` service) uses the `flask base_uri index` CLI directly.

## Development

### Installed packages (editable mode)

The following packages are installed in editable mode (from the submodules), so
changes to the code are reflected immediately:

- `dtoolcore` - Core dtool library
- `dtool-s3` - S3 storage backend for dtool
- `dservercore` - dserver core application
- `dserver-search-plugin-mongo` - MongoDB search plugin
- `dserver-retrieve-plugin-mongo` - MongoDB retrieve plugin
- `dserver-dependency-graph-plugin` - Dependency graph extension
- `dserver-signed-url-plugin` - Signed URL generation for direct S3/Azure access
- `dserver-token-generator-plugin-oauth2` - OAuth2 (e.g. ORCID) JWT token generator

The `dtool` CLI meta-package (and `dtool-dserver`) are installed from PyPI. See
`devbox/setup-venv.sh` for the full list.

### Rebuilding the virtual environment

If you add new dependencies or want to rebuild from scratch:

```bash
devbox run rebuild-venv
```

### Viewing logs

`devbox services up` streams all service logs. To attach to the process-compose
TUI (status, per-process logs, restart controls) from another shell:

```bash
devbox services attach
```

### Stopping the stack

Press `Ctrl-C` in the `devbox services up` terminal, or from another shell:

```bash
devbox services stop
```

To also discard the runtime data (databases, object storage):

```bash
devbox run clean-data
```

## Configuration

### Environment variables

Stack-wide environment variables are set in `devbox.json` (the `env` block);
per-service settings live in `process-compose.yaml`. The main ones are:

| Variable | Description |
|----------|-------------|
| `SQLALCHEMY_DATABASE_URI` | PostgreSQL connection string |
| `SEARCH_MONGO_URI` | MongoDB URI for search plugin |
| `RETRIEVE_MONGO_URI` | MongoDB URI for retrieve plugin |
| `JWT_PRIVATE_KEY_FILE` | Path to JWT private key (`jwt/jwt_key`) |
| `JWT_PUBLIC_KEY_FILE` | Path to JWT public key (`jwt/jwt_key.pub`) |

The per-bucket `DTOOL_S3_*_dtool-bucket` settings contain hyphens, which a
shell `export` (and therefore the `devbox.json` `env` block) cannot represent.
They are injected into the relevant processes by `devbox/with-dtool-s3.sh`.

### S3/MinIO

The stack creates a bucket named `dtool-bucket` on MinIO and makes it publicly
readable. Because everything runs on `127.0.0.1`, datasets are reachable at the
same URLs from both the server and the host — no `/etc/hosts` entry needed.

## Submodules

This repository includes the following submodules:

| Submodule                                 | Description                                       |
|-------------------------------------------|---------------------------------------------------|
| `dtool`                                   | dtool CLI meta-package                             |
| `dtoolcore`                               | Core Python API for managing datasets             |
| `dtool-s3`                                | S3 storage backend for dtool                      |
| `dtool-dserver`                           | Storage broker for accessing datasets via dserver |
| `dservercore`                             | dserver Flask application                         |
| `dserver-search-plugin-mongo`             | MongoDB search plugin                             |
| `dserver-retrieve-plugin-mongo`           | MongoDB retrieve plugin                           |
| `dserver-dependency-graph-plugin`         | Dependency graph extension                        |
| `dserver-notification-plugin`             | Notification extension                            |
| `dserver-signed-url-plugin`               | Signed URL generation plugin                      |
| `dserver-token-generator-plugin-oauth2`   | OAuth2 (ORCID) JWT token generator plugin         |
| `dtool-lookup-webapp`                     | Vue.js web frontend                               |
| `dserver-client-js`                       | JavaScript/TypeScript client library              |

## Troubleshooting

### A service won't start

`devbox services up` prints each service's logs inline (prefixed with the
service name). Look for the failing process there, or use the process-compose
TUI via `devbox services attach`.

Common issues:
- **Database not ready:** dserver waits on the postgres/mongo health checks; on
  the very first run these take a few extra seconds.
- **Stale `.venv`:** rebuild with `devbox run rebuild-venv`.
- **Corrupt runtime data:** reset with `devbox run clean-data`, then restart.

### Unfree package error during install

MongoDB is unfree in Nixpkgs. Export `NIXPKGS_ALLOW_UNFREE=1` before
`devbox shell` / `devbox install`.

## License

See the LICENSE file for details.
