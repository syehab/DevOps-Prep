# 05 — `terraform state mv`

**Timer:** 15 minutes.

## Symptom

Same rename as drill 04. This time there is **no** `moved` block. Plan wants to destroy `local_file.old` and create `local_file.new`.

## Setup

```bash
bash drills/terraform-live-debug/05-state-mv/setup.sh /tmp/tf-debug-state-mv
cd /tmp/tf-debug-state-mv
terraform plan
```

## Hints

1. `terraform state mv local_file.old local_file.new`
2. Then `terraform plan`. The file must stay.
3. Prefer `moved` in Git (drill 04) so every teammate gets the rename. `state mv` is a one-machine fix.

## Solution

<details>
<summary>Open after the timer or after you tried the hints.</summary>

```bash
terraform state mv 'local_file.old' 'local_file.new'
terraform plan
```

Expected: `No changes`. `state list` shows `local_file.new`. Use `moved` in the module when you can. Use `state mv` when you repair one state file.

</details>
