#!/usr/bin/env bash
set -euo pipefail
# Succeeds on the third call in this directory.
count_file="${FLAKY_COUNT:-.flaky-count}"
n=0
if [[ -f "${count_file}" ]]; then
  n="$(cat "${count_file}")"
fi
n=$((n + 1))
printf '%s\n' "${n}" > "${count_file}"
if (( n < 3 )); then
  echo "flaky: fail ${n}" >&2
  exit 1
fi
echo "flaky: ok ${n}"
