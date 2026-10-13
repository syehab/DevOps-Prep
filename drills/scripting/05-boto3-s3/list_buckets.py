#!/usr/bin/env python3
"""List S3 bucket names from a fixture or, optionally, from boto3."""

from __future__ import annotations

import argparse
import json
import sys
from typing import Any


def names_from_fixture(path: str) -> list[str]:
    with open(path, encoding="utf-8") as handle:
        data = json.load(handle)
    return sorted(str(b["Name"]) for b in data.get("Buckets", []))


def names_from_aws() -> list[str]:
    import boto3  # type: ignore

    client: Any = boto3.client("s3")
    resp = client.list_buckets()
    return sorted(str(b["Name"]) for b in resp.get("Buckets", []))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixture", help="kubectl-style JSON from list_buckets")
    parser.add_argument("--live", action="store_true", help="call AWS (needs credentials)")
    args = parser.parse_args()
    if args.live:
        names = names_from_aws()
    elif args.fixture:
        names = names_from_fixture(args.fixture)
    else:
        print("usage: list_buckets.py --fixture FILE | --live", file=sys.stderr)
        return 2
    for name in names:
        print(name)
    return 0


if __name__ == "__main__":
    sys.exit(main())
