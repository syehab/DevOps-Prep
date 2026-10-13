# 01 — Bash strict mode

**Timer:** 15 minutes.

## Symptom

```bash
bash drills/scripting/01-bash-strict/broken.sh
# prints: bucket=
# exit 0
```

A typo in `BUCKET_NAM` did not stop the script. The empty bucket name would delete or list the wrong thing in a real run.

## Task

Write a script that uses `set -euo pipefail`, takes the bucket as `$1`, and exits non-zero when the name is missing.

## Hints

1. `-u` treats unset variables as errors.
2. `-e` stops on the first failing command. `-o pipefail` makes a failing pipe fail.
3. Do not read a global `BUCKET_NAME` if you can take an argument.

## Solution

<details>
<summary>Open after the timer or after you tried the hints.</summary>

`fixed.sh` uses `set -euo pipefail` and requires `$1`.

```bash
bash drills/scripting/01-bash-strict/broken.sh ; echo exit:$?
bash drills/scripting/01-bash-strict/fixed.sh ; echo exit:$?
bash drills/scripting/01-bash-strict/fixed.sh shopsphere-tfstate
```

Expected: broken exits 0 and prints `bucket=`. Fixed with no args exits 2. Fixed with a name prints `bucket=shopsphere-tfstate`.

</details>
