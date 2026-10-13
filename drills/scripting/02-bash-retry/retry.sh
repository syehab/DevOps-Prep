#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <command> [args...]" >&2
  exit 2
fi

max="${RETRY_MAX:-3}"
sleep_s="${RETRY_SLEEP:-1}"
n=1
while true; do
  if "$@"; then
    exit 0
  fi
  if (( n >= max )); then
    echo "retry: gave up after ${max} attempts" >&2
    exit 1
  fi
  echo "retry: attempt ${n} failed; sleep ${sleep_s}s" >&2
  sleep "${sleep_s}"
  n=$((n + 1))
done
