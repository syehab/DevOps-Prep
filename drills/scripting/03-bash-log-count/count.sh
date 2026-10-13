#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <access.log>" >&2
  exit 2
fi

log="$1"
if [[ ! -f "${log}" ]]; then
  echo "missing log: ${log}" >&2
  exit 1
fi

awk '{
  code=$(NF-1)
  count[code]++
  total++
}
END {
  for (c in count) printf "%s %d\n", c, count[c]
  printf "total %d\n", total
}' "${log}" | sort
