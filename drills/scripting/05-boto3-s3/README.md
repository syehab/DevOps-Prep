# 05 — S3 inventory (boto3 optional)

**Timer:** 15 minutes.

## Symptom

A Lead asks how many state buckets exist. You do not have `aws` in PATH on this laptop. You still need a script that you can unit-test.

## Task

Write `list_buckets.py` with `--fixture` (required path for this drill) and optional `--live` that calls `boto3.client("s3").list_buckets()`.

```bash
python3 drills/scripting/05-boto3-s3/list_buckets.py \
  --fixture drills/scripting/05-boto3-s3/buckets.json
```

Expected two lines, sorted: `shopsphere-images-dev` then `shopsphere-tfstate-lab-example`.

## Hints

1. The fixture shape matches the AWS `ListBuckets` JSON.
2. Do not put access keys in the script.
3. `--live` is optional. Skip it if `aws sts get-caller-identity` fails.

## Solution

<details>
<summary>Open after the timer or after you tried the hints.</summary>

Fixture mode is the required path. `boto3` 1.35.x is on some machines. The authoring VM had boto3 but **did not** call `--live`.

</details>
