# 03 — Import

**Timer:** 15 minutes.

## Symptom

`random_id.note` exists in the real world (an ID you must keep). It is **not** in state. `terraform plan` wants to **create** a new ID. Apply would mint new bytes. Anything that stored the old ID would break.

`local_file` does **not** support import on hashicorp/local 2.5.x. This drill uses `random_id`, which does.

## Setup

```bash
bash drills/terraform-live-debug/03-import/setup.sh /tmp/tf-debug-import
cd /tmp/tf-debug-import
cat existing.id
terraform plan
```

`existing.id` is the import ID (the `id` / `b64_url` attribute).

## Hints

1. `terraform import random_id.note "$(cat existing.id)"`
2. Then `terraform plan`. You must see `No changes`.
3. Do not apply the create. That is a new ID.

## Solution

<details>
<summary>Open after the timer or after you tried the hints.</summary>

```bash
terraform import 'random_id.note' "$(cat existing.id)"
terraform plan
terraform state show random_id.note
```

Expected after import: `No changes`. `id` matches `existing.id`.

A cloud twin is `terraform import aws_s3_bucket.state shopsphere-tfstate-…`. Same rule: HCL must match the live object, or the next plan updates it.

</details>
