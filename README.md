# dserver-development-stack

Docker Compose stack for developing dserver and the dtool-lookup-webapp.

## Overview

This repository provides a complete development environment for:

- **dserver** - REST API for registering, looking up, and searching dtool dataset metadata
- **dtool-lookup-webapp** - Vue.js web frontend for searching datasets
- **MinIO** - S3-compatible object storage for datasets
- **PostgreSQL** - SQL database for dserver admin metadata
- **MongoDB** - NoSQL database for dataset search and retrieval

## Prerequisites

- Docker and Docker Compose
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

### 2. Start the stack

```bash
docker compose up -d
```

On first run, this will:
- Build the Docker images
- Create a Python virtual environment with all dependencies
- Generate JWT keys for authentication
- Initialize the PostgreSQL and MongoDB databases
- Create the MinIO bucket for datasets
- Start all services

### 3. Verify the services are running

```bash
docker compose ps
```

All services should show as "healthy" or "running".

## Services

| Service | Port | Description |
|---------|------|-------------|
| **dserver** | 5000 | REST API for dataset metadata |
| **token-generator** | 5001 | Development JWT token service |
| **webapp** | 8080 | Vue.js frontend |
| **minio** | 9000 (API), 9001 (Console) | S3-compatible storage |
| **postgres** | 5432 | PostgreSQL database |
| **mongo** | 27017 | MongoDB database |

## Usage

### Access the services

- **dserver API**: http://localhost:5000
- **API Documentation**: http://localhost:5000/doc/swagger (requires authentication)
- **Webapp**: http://localhost:8080
- **MinIO Console**: http://localhost:9001 (credentials: `minioadmin` / `minioadmin`)

### Create a test dataset

To create a sample dataset and index it in dserver:

```bash
docker compose --profile indexer run --rm indexer /scripts/create-test-dataset.sh
```

### Index existing datasets from S3

If you have datasets in the MinIO bucket, index them with:

```bash
docker compose --profile indexer run --rm indexer /scripts/index-datasets.sh
```

### Push datasets from the command line

You can push datasets directly to the MinIO S3 storage from your host machine using the `dtool` command line tool.

#### Prerequisites

Install dtool with S3 support:

```bash
pip install dtool-s3
```

#### Configure dtool

Copy the provided configuration file to your home directory:

```bash
cp dtool.json ~/.config/dtool/dtool.json
```

Or set the environment variables directly:

```bash
export DTOOL_S3_ENDPOINT_dtool-bucket="http://localhost:9000"
export DTOOL_S3_ACCESS_KEY_ID_dtool-bucket="minioadmin"
export DTOOL_S3_SECRET_ACCESS_KEY_dtool-bucket="minioadmin"
export DTOOL_S3_DISABLE_BUCKET_VERSIONING_dtool-bucket=true
```

#### Create and push a dataset

1. Create a proto dataset:

```bash
dtool create my-dataset
```

2. Add data to the dataset:

```bash
cp some-file.txt my-dataset/data/
```

3. Freeze the dataset:

```bash
dtool freeze my-dataset
```

4. Copy the dataset to the S3 storage:

```bash
dtool cp my-dataset s3://dtool-bucket/
```

5. Index the dataset in dserver (so it appears in the webapp):

```bash
docker compose --profile indexer run --rm indexer /scripts/index-datasets.sh
```

#### List datasets on S3

```bash
dtool ls s3://dtool-bucket/
```

#### Fetch a dataset from S3

```bash
dtool cp s3://dtool-bucket/<uuid> ./local-copy/
```

### Get an authentication token

For development, the token generator accepts any username/password:

```bash
curl -X POST http://localhost:5001/token \
  -H "Content-Type: application/json" \
  -d '{"username": "admin", "password": "any"}'
```

Use the returned token in the `Authorization: Bearer <token>` header.

### Access dserver API with authentication

```bash
TOKEN=$(curl -s -X POST http://localhost:5001/token \
  -H "Content-Type: application/json" \
  -d '{"username": "admin"}' | jq -r '.token')

curl -H "Authorization: Bearer $TOKEN" http://localhost:5000/config/info
```

## Development

### Installed packages (editable mode)

The following packages are installed in editable mode, so changes to the code are reflected immediately:

- `dtoolcore` - Core dtool library
- `dtool-s3` - S3 storage backend for dtool
- `dservercore` - dserver core application
- `dserver-retrieve-plugin-mongo` - MongoDB retrieve plugin
- `dserver-dependency-graph-plugin` - Dependency graph extension

### Rebuilding the virtual environment

If you add new dependencies or want to rebuild:

```bash
docker compose down
docker volume rm dserver-development-stack_dserver_venv
docker compose up -d
```

### Viewing logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f dserver
```

### Stopping the stack

```bash
docker compose down
```

To also remove the data volumes:

```bash
docker compose down -v
```

## Configuration

### Environment variables

Key environment variables are set in `docker-compose.yml`. The main ones are:

| Variable | Description |
|----------|-------------|
| `SQLALCHEMY_DATABASE_URI` | PostgreSQL connection string |
| `SEARCH_MONGO_URI` | MongoDB URI for search plugin |
| `RETRIEVE_MONGO_URI` | MongoDB URI for retrieve plugin |
| `JWT_PRIVATE_KEY_FILE` | Path to JWT private key |
| `JWT_PUBLIC_KEY_FILE` | Path to JWT public key |
| `DTOOL_S3_ENDPOINT_dtool-bucket` | MinIO endpoint for the dtool bucket |

### S3/MinIO Configuration

The stack creates a bucket named `dtool-bucket` on MinIO. To access datasets from outside the Docker network (e.g., from the host), add this to your `/etc/hosts`:

```
127.0.0.1 dserver-minio-alias
```

## Submodules

This repository includes the following submodules:

| Submodule | Description |
|-----------|-------------|
| `dtoolcore` | Core Python API for managing datasets |
| `dtool-s3` | S3 storage backend for dtool |
| `dservercore` | dserver Flask application |
| `dserver-retrieve-plugin-mongo` | MongoDB retrieve plugin |
| `dserver-dependency-graph-plugin` | Dependency graph extension |
| `dtool-lookup-webapp` | Vue.js web frontend |

## Troubleshooting

### dserver won't start

Check the logs:
```bash
docker compose logs dserver
```

Common issues:
- Database not ready: Wait for postgres/mongo healthchecks
- Missing search/retrieve plugin: Ensure the venv was built correctly

### Webapp build errors

The webapp may have eslint configuration issues with newer Node.js versions. Check:
```bash
docker compose logs webapp
```

### Permission issues

If you encounter permission issues with volumes, check that the Docker user has access to the mounted directories.

## License

See the LICENSE file for details.
