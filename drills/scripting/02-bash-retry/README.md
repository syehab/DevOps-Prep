# 02 — Retry with backoff

**Timer:** 15 minutes.

## Symptom

A one-shot `curl` or `terraform apply` fails on a 429 or a lock. You rerun it by hand. A Senior wraps the call.

## Task

Write `retry.sh` that runs a command up to `RETRY_MAX` times (default 3) and sleeps `RETRY_SLEEP` seconds between attempts. Use `flaky.sh` as the command. It fails twice, then succeeds.

## Hints

1. `"$@"` keeps the argument list. Do not eval a string.
2. `set -e` exits when the command fails. Use `if "$@"; then` so you can retry.
3. Reset the flaky counter between runs.

## Solution

<details>
<summary>Open after the timer or after you tried the hints.</summary>

```bash
rm -f /tmp/flaky-count
FLAKY_COUNT=/tmp/flaky-count RETRY_SLEEP=0 \
  bash drills/scripting/02-bash-retry/retry.sh \
  bash drills/scripting/02-bash-retry/flaky.sh
```

Expected: two `retry: attempt` lines, then `flaky: ok 3`, exit 0.

</details>
