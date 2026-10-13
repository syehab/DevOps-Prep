# 07 — Summarize a Terraform plan JSON

**Timer:** 15 minutes.

## Symptom

A pull-request plan is 2 000 lines. You need create/update/no-op counts and the create addresses. NAT appearing on a Day 28 lab is the finding.

## Task

Write a `jq` script that prints `action count` lines and a `creates:` line from `terraform show -json`.

```bash
bash drills/scripting/07-jq-plan/summary.sh \
  drills/scripting/07-jq-plan/plan.json
```

Expected: `create 2`, `no-op 1`, `update 1`, and `creates: aws_eip.nat[0], aws_nat_gateway.this[0]`.

## Hints

1. `resource_changes[].change.actions[0]` is the primary action.
2. Day 28 keeps `enable_nat = false`. A `create` on `aws_nat_gateway` is a break.

## Solution

<details>
<summary>Open after the timer or after you tried the hints.</summary>

`summary.sh` groups actions and lists create addresses. The fixture is a trimmed `terraform show -json` document (`format_version` 1.2). **Not executed:** a live `terraform plan -out` plus `terraform show -json` against AWS.

</details>
