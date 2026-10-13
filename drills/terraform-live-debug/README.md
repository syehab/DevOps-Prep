# Terraform live-debug drills

Six timed failures on **local** Terraform. Each drill is one symptom, 15 minutes, then hints, then a solution. No cloud account. No gotchas. The setup script is the whole break.

```bash
bash drills/terraform-live-debug/run-all.sh
```

Cost: **USD 0.00**. These drills do not create Azure or AWS resources.

Terraform **1.16.5** and `hashicorp/local` **2.5.3** are the pins the authoring VM used.

## How to run one drill

1. Start a 15-minute timer.
2. Run only that folder's `setup.sh` from a scratch directory **or** from the folder itself (the script `cd`s).
3. Read **Symptom**. Do not open Hints yet.
4. Diagnose with `terraform plan`, `state list`, `state show`, and the error text.
5. Fix. Do not `rm terraform.tfstate` unless the solution says so.
6. If you stick, open Hints, then Solution.

Reset: delete the drill's `.terraform/` and `terraform.tfstate*` in that folder. `run-all.sh` uses `/tmp/tf-debug-*`.

## Scenarios

| # | Folder | Symptom you will see |
|:--|:--|:--|
| 01 | [01-lock-stuck](01-lock-stuck/) | `Error acquiring the state lock` |
| 02 | [02-drift](02-drift/) | Plan wants to update a file you did not change in HCL |
| 03 | [03-import](03-import/) | `random_id` exists, state is empty, plan wants a new ID |
| 04 | [04-moved](04-moved/) | Address rename without destroy/create |
| 05 | [05-state-mv](05-state-mv/) | Same rename, older workflow |
| 06 | [06-provider-conflict](06-provider-conflict/) | `init` fails on provider version |

## Interview use

Pick lock and drift. Talk out loud. A Senior does not delete state to "unblock." A Senior reads the lock ID, then the plan.

> **Remember:** The first command is `plan` or `state list`, not `apply -auto-approve`.

## Not executed in CI

The authoring VM ran `run-all.sh` with Terraform 1.16.5. It did not run a remote S3 `use_lockfile` race. Day 29 is that sibling.
