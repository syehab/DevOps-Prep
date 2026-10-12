# Day 35 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 35 teaches observability as evidence of user impact, not as a CPU graph. This lab runs a small Python HTTP server on your laptop. `/` returns HTTP 200. `/order` first returns HTTP 500 and writes one JSON log line per request. You measure status and latency with `curl -w`. You score availability against a 99% SLO on 100 curls. You then change `/order` so it returns 200 and you prove recovery with the same curl command.

Work only in a temporary directory that you create for this lab. Do not run the server inside the DevOps-Prep course repository. You do not need Prometheus, Grafana, Kubernetes, or a cloud account.

---

## Goal

Start a local Python process that listens on `127.0.0.1:8080`. Prove `/` returns 200 while `/order` returns 500. Read the JSON log line for the failed order. Run 100 curls against `/order` and compute availability. Write an SLO of 99 successful responses out of 100. Record a short incident timeline.

Replace a noisy CPU alert in your notes with an alert on HTTP 500 rate. Change the handler so `/order` returns 200. Run 100 curls again and confirm the SLO holds. When you finish, you can explain structured logs, SLO math, and why you page on 500s rather than on CPU.

Time box: 45 to 75 minutes. Cost stays at ₹0. Stop when `/order` returns 200, the SLO note exists, the timeline exists, and the Python process is stopped.

---

## What you need

You need Python 3 and `curl`. Check both first:

```bash
python3 --version
curl --version
```

You do not need Docker, kind, Azure, or AWS. `python3` already includes `http.server` and `json`. Plain `python3 -m http.server` always returns 200, so it cannot simulate this failure by itself. The script below subclasses `BaseHTTPRequestHandler` and prints one JSON object per request.

Create the lab under `/tmp`, not under this course clone. The server writes `app.log` in the working directory. You must be able to delete that directory when you clean up.

Keep a notes file named `day-35-obs-lab.md` in the same temp directory. Record curl output, log lines, the SLO score, the alert rewrite, and the timeline. Do not paste secrets. This lab should not create any.

---

## Steps

1. Create a throwaway directory and enter it. Use a unique folder name so you do not collide with another lab. Confirm the path is under `/tmp`.

```bash
LAB_DIR="/tmp/day-35-obs-lab-$$"
mkdir -p "$LAB_DIR"
cd "$LAB_DIR"
pwd
```

2. Write `app.py`. This handler returns HTTP 500 for `/order` and HTTP 200 for every other path. It binds only to `127.0.0.1` on port `8080`. Each request prints one JSON line with `timestamp`, `level`, `service`, `request_id`, `operation`, `path`, and `status`. That is structured logging from the lesson. Do not add passwords, tokens, or personal data to the log.

```python
import json
import time
import uuid
from http.server import BaseHTTPRequestHandler, HTTPServer

FAIL_ORDER = True

class Handler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        return

    def do_GET(self):
        path = self.path.split("?")[0]
        request_id = uuid.uuid4().hex[:8]
        if path == "/order" and FAIL_ORDER:
            code = 500
            body = b'{"ok":false,"error":"OrderCreateFailed"}\n'
        else:
            code = 200
            body = b'{"ok":true}\n'
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("X-Request-Id", request_id)
        self.end_headers()
        self.wfile.write(body)
        rec = {
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "level": "ERROR" if code >= 500 else "INFO",
            "service": "shopsphere-api",
            "environment": "lab",
            "request_id": request_id,
            "operation": "createOrder" if path == "/order" else "health",
            "path": path,
            "status": code,
            "error_type": "OrderCreateFailed" if code >= 500 else "",
            "message": "order failed" if code >= 500 else "ok",
        }
        print(json.dumps(rec), flush=True)

HTTPServer(("127.0.0.1", 8080), Handler).serve_forever()
```

3. Start the server in the background. Send stdout and stderr to `app.log` so you can read the JSON lines later. Save the process id.

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

4. Curl the healthy path first. `curl -w` prints the HTTP status and the total time after the body. Discard the body with `-o /dev/null` so the status line is easy to read. You should see `200` and a small `time=` value.

```bash
curl -s -o /dev/null -w '%{http_code} time=%{time_total}\n' http://127.0.0.1:8080/
```

Copy that line into `day-35-obs-lab.md`. This is the baseline. The process is up. `/` succeeds. Infrastructure looks fine.

5. Curl `/order`. You should see `500` and a `time=` value. This is the user symptom. Checkout fails while the process still answers `/`.

```bash
curl -s -o /dev/null -w '%{http_code} time=%{time_total}\n' http://127.0.0.1:8080/order
```

Copy that line into the notes. Do not look at CPU. The lesson rule is: start from the failing user action, not from a CPU graph. HTTP 500 on `/order` is the page.

6. Read the JSON log. Each request is one line. You should see `"path": "/"` with `"status": 200` and `"path": "/order"` with `"status": 500`. Copy one failed line into the notes. That line is the evidence. The metric would only say error rate rose. The log names the operation and the request id.

```bash
cat app.log
```

7. Write the SLO in `day-35-obs-lab.md` before you run the batch. Keep it to three lines:

```text
SLI: successful GET /order (HTTP 200) / total GET /order
SLO: 99 successful responses out of 100 curls (99%)
Window: this lab batch of 100 curls
```

The SLI is the measurement. The SLO is the target. You are not writing an SLA. An SLA is a formal commitment with consequences, and this lab has none.

8. Run 100 curls against `/order` while it still returns 500. Write every status and time line to `curl-fail.txt`. Then count how many lines start with `200`.

```bash
for i in $(seq 1 100); do
  curl -s -o /dev/null -w '%{http_code} time=%{time_total}\n' http://127.0.0.1:8080/order
done | tee curl-fail.txt
ok=$(grep -c '^200 ' curl-fail.txt || true)
echo "availability=${ok}/100"
```

You should see `availability=0/100` or a number far below 99. The SLO is missed. Copy the availability line into the notes. A running process with a green `/` path did not protect checkout.

9. Write a short incident timeline in `day-35-obs-lab.md`. Use wall-clock times from your session if you have them. A valid first draft looks like this:

```text
Detect: curl -w showed 500 on /order. / still returned 200.
Evidence: app.log JSON line with operation=createOrder, status=500, level=ERROR.
Impact: SLO 99/100 missed. Batch availability was 0/100.
Recover: set FAIL_ORDER = False, restart, curl /order until 200.
Verify: second batch of 100 curls meets 99/100.
```

Keep the timeline short. Record evidence as you go. Do not rely on memory. This is the start of an incident record, not a full RCA.

10. Write the wrong alert first. Add this block to the notes. This is the break. The lesson says `CPU > 70%` with no user harm is noise.

```text
Alert (noise): CPU > 70% for 5 minutes
Action: none. This lab has no CPU signal and no user-impact threshold.
```

Then replace it with an alert on HTTP 500 rate. Tie the alert to the SLO and to `/order`.

```text
Alert (actionable): HTTP 500 rate on GET /order exceeds 1% of requests for 5 minutes
Impact: checkout fails. SLO of 99/100 is in danger.
First step: read JSON logs for operation=createOrder and compare with the last deploy.
```

Leave both versions in the notes so you can show the rewrite. Page on the 500 rate. Do not page on CPU.

11. Fix `/order`. Stop the process. Change `FAIL_ORDER = True` to `FAIL_ORDER = False` in `app.py`. Start the server again.

```bash
kill "$(cat app.pid)"
sed -i 's/FAIL_ORDER = True/FAIL_ORDER = False/' app.py
python3 app.py >> app.log 2>&1 &
echo $! > app.pid
sleep 1
ps -p "$(cat app.pid)"
```

12. Verify recovery with the same curl command you used to detect the failure. You should see `200` for both `/` and `/order`.

```bash
curl -s -o /dev/null -w '%{http_code} time=%{time_total}\n' http://127.0.0.1:8080/
curl -s -o /dev/null -w '%{http_code} time=%{time_total}\n' http://127.0.0.1:8080/order
```

13. Run 100 curls again. Write the lines to `curl-ok.txt`. Count HTTP 200 responses. Availability should be 100/100, which meets the 99% SLO.

```bash
for i in $(seq 1 100); do
  curl -s -o /dev/null -w '%{http_code} time=%{time_total}\n' http://127.0.0.1:8080/order
done | tee curl-ok.txt
ok=$(grep -c '^200 ' curl-ok.txt || true)
echo "availability=${ok}/100"
```

Copy the new availability line into the notes. Update the Verify line of the timeline. Recovery is proven when `/order` returns 200 and the batch meets 99/100. Recovery is not proven by `ps` showing a Python process.

---

## Verify

Read the notes as if you are on a call. You should name the failed path, the status code, one JSON field that proved it, and the two availability scores.

Check these points:

- `curl -s -o /dev/null -w '%{http_code} time=%{time_total}\n' http://127.0.0.1:8080/` returned 200 while `/order` still returned 500. A running process is not a healthy checkout.
- `app.log` contains JSON lines with `request_id`, `operation`, `path`, and `status`. You did not guess the failure. You read it from curl and from the log.
- The SLO is written as 99 successful `/order` responses out of 100. The failing batch scored below 99. The recovered batch scored 99 or 100.
- The notes contain the noisy CPU alert and the replacement alert on HTTP 500 rate.
- The timeline has detect, evidence, impact, recover, and verify.

If `/order` still returns 500, open `app.py` and confirm `FAIL_ORDER = False`. Then confirm `ps -p "$(cat app.pid)"` shows the new process, not the old one.

---

## Break and fix

You already broke `/order` on purpose in step 2. That is the incident this Day trains.

The alert rewrite in step 10 is the second break. If you skipped it, do it now. Write `CPU > 70%` in the notes. Then replace it with an alert on HTTP 500 rate for `/order`. CPU is not a user symptom here. HTTP 500 rate is.

If you want one more pass, set `FAIL_ORDER = True` again, restart, and curl `/order` once. Confirm 500. Restore `FAIL_ORDER = False`, restart, and curl until `/order` returns 200. Do not treat a process restart as the fix while `FAIL_ORDER` is still `True`. A restart of a broken handler still returns 500. Change the flag, then restart, then verify with curl.

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

If you copied notes you want to keep, move `day-35-obs-lab.md` out before `rm -rf`. You created no Kubernetes objects and no cloud resources, so there is no Deployment, Service, or resource group to delete.

---

## Interview story

I treat a running process as insufficient proof of health. I start a Python server that logs one JSON line per request. `/` returns 200. `/order` returns 500. `curl -w '%{http_code} time=%{time_total}\n'` shows the status and the latency. I score 100 curls against a 99% SLO and miss it while `/order` is broken. I do not page on CPU. I page on HTTP 500 rate for checkout. I write a short timeline, set the handler back to 200, and run 100 curls again. Recovery is the SLO holding, not the fact that Python is still running.
