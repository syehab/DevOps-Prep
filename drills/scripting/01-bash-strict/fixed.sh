#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <bucket>" >&2
  exit 2
fi

bucket="$1"
echo "bucket=${bucket}"
