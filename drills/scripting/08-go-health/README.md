# 08 — Optional Go health client

**Timer:** 15 minutes.

## Symptom

Python is fine. A JD lists Go. You need one tiny client that GETs `/health` and exits 1 on HTTP ≥ 400.

## Task

Write `main.go` that takes a URL, uses a 3-second timeout, prints `status=N body=...`, and exits 1 on a 5xx.

```bash
python3 -m http.server --bind 127.0.0.1 8765 >/tmp/day-script-http.log 2>&1 &
sleep 0.2
go run drills/scripting/08-go-health/main.go http://127.0.0.1:8765/
kill %1
```

Expected: `status=200` and a directory listing body. Exit 0.

## Hints

1. `http.Client{Timeout: 3 * time.Second}` so a hang is not a hang.
2. `io.LimitReader` so a huge body cannot fill memory.
3. This is optional. Drills 01–07 already pass the pack.

## Solution

<details>
<summary>Open after the timer or after you tried the hints.</summary>

`main.go` is the client. The authoring VM ran it against `python3 -m http.server` on 127.0.0.1:8765. Go 1.22.2. **Not executed:** a live ShopSphere `/health` on AKS.

</details>
