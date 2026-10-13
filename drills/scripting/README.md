# Scripting drills

Eight timed scripts. Each drill is one symptom, 15 minutes, then hints, then a solution. No gotchas. Work in **your ShopSphere repository** under `scripts/` if you want to keep a copy. The fixtures in this pack are enough to finish.

Cost: **USD 0.00**. These drills do not create cloud resources.

```bash
bash drills/scripting/run-all.sh
```

That command runs every fixture path. It does not call AWS or Azure.

## How to run one drill

1. Start a 15-minute timer.
2. Read **Symptom**. Do not open Hints yet.
3. Write or fix the script. Run it against the fixture in that folder.
4. If you stick, open Hints, then Solution.

## Scenarios

| # | Folder | What you write |
|:--|:--|:--|
| 01 | [01-bash-strict](01-bash-strict/) | `set -euo pipefail` |
| 02 | [02-bash-retry](02-bash-retry/) | Retry with backoff |
| 03 | [03-bash-log-count](03-bash-log-count/) | Count HTTP status codes |
| 04 | [04-k8s-restarts](04-k8s-restarts/) | Find Pods with high restarts |
| 05 | [05-boto3-s3](05-boto3-s3/) | S3 inventory (fixture or boto3) |
| 06 | [06-azure-rg](06-azure-rg/) | Resource-group inventory (fixture) |
| 07 | [07-jq-plan](07-jq-plan/) | Summarize a Terraform plan JSON |
| 08 | [08-go-health](08-go-health/) | Optional Go health client |

## Interview use

Pick bash strict mode and the restart finder. Talk out loud. A Senior script fails closed, names its inputs, and does not need a live account to unit-test.

> **Remember:** `set -euo pipefail` first. Then parse. Then call the cloud.

## Not executed in CI

The authoring VM ran `run-all.sh` (bash, python3, jq, go). It did not call AWS STS or Azure Resource Manager. Azure SDK is not required. `boto3` 1.35.x is optional for drill 05.
