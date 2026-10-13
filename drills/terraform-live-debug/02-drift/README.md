# 02 — Drift

**Timer:** 15 minutes.

## Symptom

You did not edit `main.tf`. `terraform plan` wants to change `local_file.note`. The file on disk says `drifted`. HCL still says `expected`.

## Setup

```bash
bash drills/terraform-live-debug/02-drift/setup.sh /tmp/tf-debug-drift
cd /tmp/tf-debug-drift
terraform plan
```

## Hints

1. `cat note.txt` then `terraform state show local_file.note`.
2. Decide: restore the file, or change HCL if the edit is the new desired state.
3. Do not apply first "to clean the plan."

## Solution

<details>
<summary>Open after the timer or after you tried the hints.</summary>

Someone wrote `drifted` outside Terraform. Plan shows an update back to `expected`. Restore:

```bash
printf 'expected\n' > note.txt
terraform plan
```

Expected: `No changes`. If the edit was intended, change `content` in HCL and apply once. Day 36 is the longer drift story.

</details>
