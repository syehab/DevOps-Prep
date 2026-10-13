#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <plan.json>" >&2
  exit 2
fi

plan="$1"
jq -r '
  .resource_changes
  | map(.change.actions[0])
  | group_by(.)
  | map({action: .[0], count: length})
  | .[]
  | "\(.action) \(.count)"
' "${plan}"
echo -n "creates: "
jq -r '[.resource_changes[] | select(.change.actions[0] == "create") | .address] | join(", ")' "${plan}"
