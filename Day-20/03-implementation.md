# Day 20 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 20 teaches telemetry and incident response. This lab runs a six-line Python HTTP server on your laptop. `/` returns HTTP 200. `/health` returns HTTP 500. You curl both paths, capture the server logs, and write a five-line incident timeline: detect, hypothesise, test, fix, verify. You page on the symptom users feel (HTTP 500), not on CPU.

Work only in a temporary directory that you create for this lab. Do not run the server inside the DevOps-Prep course repository. You do not need Kubernetes, Prometheus, or a cloud account.

---

## Goal

Start a local Python process that listens on `127.0.0.1:8080`. Prove `/` returns 200 and `/health` returns 500 with `curl -w '%{http_code}'`. Read the request log. Treat the 500 as the incident. Write a five-line timeline. Then change `/health` to return 200 and curl it again.

When you finish, you can explain why a process can be running while a health check fails, why you page on HTTP 500 instead of CPU, and how you verify recovery with the same curl command you used to detect the failure.

Time box: 30 to 45 minutes. Cost stays at ₹0. Stop when `/health` returns 200, the timeline file exists, and the Python process is stopped.

---

## What you need

You need Python 3 and `curl`. Check both first:

```bash
python3 --version
curl --version
```

You do not need Docker, kind, Azure, or AWS. `python3` already includes `http.server`. The six-line script below subclasses `BaseHTTPRequestHandler`. That is enough to return 500 on one path and 200 on another. Plain `python3 -m http.server` always returns 200, so it cannot simulate this failure by itself.

Create the lab under `/tmp`, not under this course clone. The server writes a log file in the working directory. You must be able to delete that directory when you clean up.

Keep a notes file named `day-20-incident-lab.md` in the same temp directory. Record the curl output, the log lines, and the five-line timeline. Do not paste secrets. This lab should not create any.

---

## Steps

1. Create a throwaway directory and enter it. Use a unique folder name so you do not collide with another lab. Confirm the path is under `/tmp`.

```bash
LAB_DIR="/tmp/day-20-obs-lab-$$"
mkdir -p "$LAB_DIR"
cd "$LAB_DIR"
pwd
```

2. Write `app.py`. This six-line script returns HTTP 500 for `/health` and HTTP 200 for every other path. It binds only to `127.0.0.1` on port `8080`.

```python
from http.server import BaseHTTPRequestHandler, HTTPServer
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        c = 500 if self.path.split("?")[0] == "/health" else 200
        self.send_response(c); self.end_headers(); self.wfile.write(b"fail\n" if c == 500 else b"ok\n")
HTTPServer(("127.0.0.1", 8080), H).serve_forever()
```

3. Start the server in the background. Send stdout and stderr to `app.log` so you can read the request log later. Save the process id.

```bash
python3 app.py > app.log 2>&1 &
echo $! > app.pid
cat app.pid
```

Wait one second so the socket is listening. Then confirm the process is still running.

```bash
sleep 1
ps -p "$(cat app.pid)"
```

4. Curl the healthy path first. `curl -w '%{http_code}'` prints the HTTP status code after the body. You should see `ok` and then `200`.

```bash
curl -s -w '%{http_code}' http://127.0.0.1:8080/
echo
```

Copy that output into `day-20-incident-lab.md`. This is the baseline. The process is up. `/` succeeds.

5. Curl `/health`. You should see `fail` and then `500`. This is the symptom. Users (or a load balancer) would feel this as a failed health check.

```bash
curl -s -w '%{http_code}' http://127.0.0.1:8080/health
echo
```

Copy that output into the notes. Do not look at CPU. The lesson rule is: alert on symptoms users feel (errors, latency), not on causes (CPU). HTTP 500 is the page.

6. Read the server log. `BaseHTTPRequestHandler` writes one line per request to stderr, which you redirected to `app.log`.

```bash
cat app.log
```

You should see a `200` line for `/` and a `500` line for `/health`. That log is the evidence. Metrics would say error rate rose. The log says which path failed.

7. Write a five-line incident timeline in `day-20-incident-lab.md`. Use these five verbs, one line each: detect, hypothesise, test, fix, verify. Fill the lines with what you just did. A valid first draft looks like this:

```text
Detect: curl -s -w '%{http_code}' http://127.0.0.1:8080/health returned 500.
Hypothesise: /health is coded to return 500; the process is still running because / returned 200.
Test: app.log shows GET /health 500 and GET / 200. CPU is not the signal.
Fix: change the 500 in app.py to 200, then restart the process.
Verify: curl -s -w '%{http_code}' http://127.0.0.1:8080/health returns 200.
```

Keep the timeline to five lines. This is the start of an incident record, not a full RCA.

8. Leave the 500 in place for a moment. That is the break. The process is still running. `/` is still 200. `/health` is still 500. Write one sentence in the notes: you would page a human on HTTP 500, not on CPU. CPU is not in this lab and does not need to be. The symptom is enough.

9. Fix `/health`. Stop the process. Change `500` to `200` in `app.py` so `/health` returns 200. Start the server again.

```bash
kill "$(cat app.pid)"
sed -i 's/500 if/200 if/' app.py
python3 app.py >> app.log 2>&1 &
echo $! > app.pid
sleep 1
```

10. Verify recovery with the same curl command you used to detect the failure. You should see `ok` and then `200` for both `/` and `/health`.

```bash
curl -s -w '%{http_code}' http://127.0.0.1:8080/
echo
curl -s -w '%{http_code}' http://127.0.0.1:8080/health
echo
cat app.log
```

Copy the new status codes into the notes. Update the Verify line of the timeline if you wrote it before the fix. Recovery is proven when `/health` returns 200, not when the process merely exists.

---

## Verify

Read the notes as if you are on a call. You should name the failed path, the status code, and the log line that proved it.

Check these points:

- `curl -s -w '%{http_code}' http://127.0.0.1:8080/` returned 200 while `/health` still returned 500. A running process is not a healthy service.
- `app.log` recorded both requests. You did not guess the status code. You read it from curl and from the log.
- The timeline has five lines: detect, hypothesise, test, fix, verify.
- You wrote that the page is HTTP 500, not CPU.
- After the fix, `curl -s -w '%{http_code}' http://127.0.0.1:8080/health` returned 200.

If `/health` still returns 500, open `app.py` and confirm the `500 if` line is now `200 if`. Then confirm `ps -p "$(cat app.pid)"` shows the new process, not the old one.

---

## Break and fix

You already broke `/health` on purpose in step 2. That is the incident this Day trains.

If you skipped the pause in step 8, do it now. Put `500` back for `/health`, restart the process, and curl again. Confirm 500. Write the page sentence: HTTP 500 is the symptom. CPU is not. Then restore `200` and curl until `/health` returns 200.

Do not restart the process as the fix while `app.py` still contains `500`. A restart of a broken handler still returns 500. Change the code, then restart, then verify with curl.

---

## Clean up

Stop the Python process, then remove the temp directory. Kill only the pid you saved. Confirm the process is gone before you delete the folder.

```bash
kill "$(cat app.pid)"
sleep 1
ps -p "$(cat app.pid)" || echo "process stopped"
cd /tmp
rm -rf "$LAB_DIR"
```

If `kill` does not stop the process, run `kill -9 "$(cat app.pid)"` once, then confirm with `ps`. Do not leave a listener on port 8080.

If you copied notes you want to keep, move `day-20-incident-lab.md` out before `rm -rf`. You created no Kubernetes objects and no cloud resources, so there is no Deployment, Service, or resource group to delete.

---

## Interview story

I treat a running process as insufficient proof of health. I start a six-line Python server that returns 200 on `/` and 500 on `/health`. `curl -w '%{http_code}'` shows the status code. The request log shows the same 500. I page on that symptom, not on CPU. I write a five-line timeline: detect, hypothesise, test, fix, verify. Then I change the handler to 200, restart, and curl `/health` again. Recovery is the 200, not the fact that Python is still running.
