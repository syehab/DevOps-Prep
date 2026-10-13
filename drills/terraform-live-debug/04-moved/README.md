# 04 — `moved` block

**Timer:** 15 minutes.

## Symptom

You renamed `local_file.old` to `local_file.new`. Without help, plan wants to destroy `old` and create `new`. You must keep the file and the history.

## Setup

```bash
bash drills/terraform-live-debug/04-moved/setup.sh /tmp/tf-debug-moved
cd /tmp/tf-debug-moved
terraform plan
```

The setup already added the `moved` block. If you remove it, you will see the destroy/create. Put it back.

## Hints

1. `moved { from = local_file.old to = local_file.new }` is Terraform 1.1+.
2. `terraform plan` should say it will move the state, then `No changes` to the file.
3. Do not `rm` the state.

## Solution

<details>
<summary>Open after the timer or after you tried the hints.</summary>

With the `moved` block, plan reports a state move and no file replace. Apply once. `terraform state list` shows `local_file.new` only. `note.txt` still says `shopsphere`.

Day 36 uses `moved` on real modules. This drill is the small version.

</details>
