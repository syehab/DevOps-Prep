# 01 — Stuck state lock

**Timer:** 15 minutes.

## Symptom

```text
Error: Error acquiring the state lock
Error message: resource temporarily unavailable
Lock Info:
  ID:        ...
  Operation: OperationTypeApply
```

A second apply started while the first still holds the lock.

## Setup

```bash
bash drills/terraform-live-debug/01-lock-stuck/setup.sh /tmp/tf-debug-lock
cd /tmp/tf-debug-lock
terraform init
terraform apply -auto-approve &
sleep 2
terraform apply -auto-approve
```

## Hints

1. Read the lock **ID** and **Who**. Do not `rm terraform.tfstate`.
2. The first apply is still running. Wait, or `terraform force-unlock ID` only if that process is dead.
3. `-lock=false` hides the bug.

## Solution

<details>
<summary>Open after the timer or after you tried the hints.</summary>

The first apply runs `sleep 20` under `terraform_data`. The second apply exits 1 with `Error acquiring the state lock`. Wait for the first apply. Then `terraform apply` is a no-op.

`force-unlock` is for a **dead** holder (CI job killed). If the holder is alive, you corrupt two writes.

Remote sibling: Day 29 `use_lockfile = true` on S3.

</details>
