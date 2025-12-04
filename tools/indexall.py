#!/usr/bin/env python
"""Index all datasets from a base URI into dserver."""

import argparse
import sys
from urllib.parse import quote

import requests
import dtoolcore
import dtoolcore.utils


def index_datasets(token, base_uri, dserver_url="http://localhost:5000"):
    """Index all frozen datasets from base_uri into dserver.

    Args:
        token: JWT authentication token for dserver
        base_uri: Base URI to scan for datasets (e.g., s3://dtool-bucket)
        dserver_url: URL of the dserver instance
    """
    config_path = dtoolcore.utils.DEFAULT_CONFIG_PATH

    print(f"Scanning for datasets in {base_uri}...")

    # Get the storage broker for the URI scheme
    storage_broker_lookup = dtoolcore._generate_storage_broker_lookup()
    parsed_uri = dtoolcore.utils.generous_parse_uri(base_uri)
    StorageBroker = storage_broker_lookup[parsed_uri.scheme]

    # List all dataset URIs in the bucket
    dataset_uris = list(StorageBroker.list_dataset_uris(base_uri, config_path))

    if not dataset_uris:
        print(f"No datasets found in {base_uri}")
        return 0

    print(f"Found {len(dataset_uris)} dataset(s), indexing...")
    registered_count = 0

    for uri in dataset_uris:
        try:
            # Get admin metadata to check if it's a frozen dataset
            storage_broker = StorageBroker(uri, config_path)
            admin_metadata = storage_broker.get_admin_metadata()

            # Skip proto datasets (unfrozen)
            if admin_metadata.get('type') != 'dataset':
                print(f"  Skipping proto dataset: {uri}")
                continue

            # Get dataset info
            manifest = storage_broker.get_manifest()
            readme = storage_broker.get_readme_content()
            tags = storage_broker.list_tags()

            # Get annotations
            annotations = {}
            for ann_name in storage_broker.list_annotation_names():
                annotations[ann_name] = storage_broker.get_annotation(ann_name)

            # Calculate size info from manifest
            items = manifest.get('items', {})
            number_of_items = len(items)
            size_in_bytes = sum(item.get('size_in_bytes', 0) for item in items.values())

            info = {
                'uuid': admin_metadata.get('uuid'),
                'uri': uri,
                'base_uri': base_uri,
                'name': admin_metadata.get('name'),
                'type': 'dataset',
                'creator_username': admin_metadata.get('creator_username', 'unknown'),
                'frozen_at': str(admin_metadata.get('frozen_at', 0)),
                'created_at': str(admin_metadata.get('created_at', 0)),
                'annotations': annotations,
                'tags': list(tags),
                'readme': readme,
                'manifest': manifest,
                'number_of_items': number_of_items,
                'size_in_bytes': size_in_bytes
            }

            headers = {
                'Authorization': f'Bearer {token}',
                'Content-Type': 'application/json'
            }

            # Use PUT /uris/{uri} endpoint with URL-encoded URI
            encoded_uri = quote(uri, safe='')
            response = requests.put(
                f'{dserver_url}/uris/{encoded_uri}',
                headers=headers,
                json=info
            )

            if response.status_code in (200, 201):
                print(f"  Registered: {info['name']} ({info['uuid']})")
                registered_count += 1
            elif response.status_code == 409:
                print(f"  Already exists: {info['name']} ({info['uuid']})")
                registered_count += 1
            else:
                print(f"  Failed to register {info['name']}: {response.status_code} - {response.text}")

        except Exception as e:
            print(f"  Error indexing {uri}: {e}")

    print(f"Indexing complete! Registered {registered_count} dataset(s).")
    return registered_count


def main():
    parser = argparse.ArgumentParser(
        description="Index all datasets from a base URI into dserver."
    )
    parser.add_argument(
        "token",
        help="JWT authentication token for dserver"
    )
    parser.add_argument(
        "base_uri",
        help="Base URI to scan for datasets (e.g., s3://dtool-bucket)"
    )
    parser.add_argument(
        "--dserver-url",
        default="http://localhost:5000",
        help="URL of the dserver instance (default: http://localhost:5000)"
    )

    args = parser.parse_args()

    try:
        index_datasets(args.token, args.base_uri, args.dserver_url)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()

