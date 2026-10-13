#!/usr/bin/env bash
# Broken on purpose: missing -u, so a typo becomes an empty string.
set -eo pipefail
echo "bucket=${BUCKET_NAM}"
echo "ok"
