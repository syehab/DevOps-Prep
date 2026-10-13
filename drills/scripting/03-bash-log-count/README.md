# 03 — Count HTTP status codes

**Timer:** 15 minutes.

## Symptom

On-call paste: "catalog is failing." The access log is local. You need counts, not a feeling.

## Task

Write a script that prints `status count` lines plus `total N` from a Common Log Format file. Use `access.log` in this folder.

Expected: `200 4`, `201 1`, `404 1`, `503 2`, `total 8`.

## Hints

1. In this CLF fixture the status is the second field from the end.
2. `awk` plus `sort` is enough. Do not upload the log.
3. `set -euo pipefail` and require the file path.

## Solution

<details>
<summary>Open after the timer or after you tried the hints.</summary>

```bash
bash drills/scripting/03-bash-log-count/count.sh \
  drills/scripting/03-bash-log-count/access.log
```

`503 2` of `total 8` is 25% errors. That is a 250× burn of a 0.1% SLO, not a blip.

</details>
