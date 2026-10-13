#!/usr/bin/env python3
"""Find Pods whose container restartCount is at or above a threshold."""

from __future__ import annotations

import argparse
import json
import sys
from typing import Any


def load_items(path: str) -> list[dict[str, Any]]:
    with open(path, encoding="utf-8") as handle:
        data = json.load(handle)
    return list(data.get("items", []))


def hot_pods(items: list[dict[str, Any]], threshold: int) -> list[tuple[str, str, int]]:
    found: list[tuple[str, str, int]] = []
    for item in items:
        meta = item.get("metadata") or {}
        name = str(meta.get("name", "?"))
        ns = str(meta.get("namespace", "default"))
        statuses = (item.get("status") or {}).get("containerStatuses") or []
        restarts = max((int(s.get("restartCount") or 0) for s in statuses), default=0)
        if restarts >= threshold:
            found.append((ns, name, restarts))
    return sorted(found, key=lambda row: (-row[2], row[0], row[1]))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("json_path")
    parser.add_argument("--threshold", type=int, default=5)
    args = parser.parse_args()
    rows = hot_pods(load_items(args.json_path), args.threshold)
    for ns, name, restarts in rows:
        print(f"{ns}/{name} restarts={restarts}")
    return 0 if rows else 0


if __name__ == "__main__":
    sys.exit(main())
