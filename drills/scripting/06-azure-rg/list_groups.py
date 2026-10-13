#!/usr/bin/env python3
"""List Azure resource groups from a fixture. SDK is optional and not required."""

from __future__ import annotations

import argparse
import json
import sys


def names_from_fixture(path: str) -> list[str]:
    with open(path, encoding="utf-8") as handle:
        data = json.load(handle)
    return sorted(str(g["name"]) for g in data.get("value", []))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixture", required=True)
    args = parser.parse_args()
    for name in names_from_fixture(args.fixture):
        print(name)
    return 0


if __name__ == "__main__":
    sys.exit(main())
