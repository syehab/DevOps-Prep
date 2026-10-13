# Day 2 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 2 teaches the Linux runtime around an application. The old lab inspected the host and wrote notes anywhere. This lab inspects the **ShopSphere catalog process** from Day 1, then records evidence in Git.

Work in **your ShopSphere repository**. Start `app/day01_server.py` (or the capstone starter) so you have a PID and a listen port.

---

## Goal

Collect OS, memory, disk, process, listen-port, and log evidence for the catalog API. Write `docs/runtime.md`. Prove that a missing listen on `8080` is not the same as a missing process.

Time box: 45 to 75 minutes. Cost is **USD 0.00**.

---

## Capstone stage

| Path | Adds |
|:--|:--|
| `docs/runtime.md` | Command output + troubleshooting order |
| `docs/day-02-evidence.md` | PID, port, and the break |

---

## What you need

```bash
uname -a
python3 --version
command -v ss || command -v netstat
```

You do not need Azure, AWS, or Docker. Do not start or stop production services.

---

## Cost

| Path | Estimated USD |
|:--|:--|
| Local inspect | **0.00** |

---

## Steps

1. Open ShopSphere. Start the Day 1 server if it is not running.

```bash
mkdir -p docs
python3 app/day01_server.py
```

If that file is missing, copy it from [Day-01/03-implementation.md](../Day-01/03-implementation.md) first.

2. In a second shell, collect host evidence into `docs/runtime.md`.

```bash
hostname
date -u
uname -a
free -h
df -h
```

Write one sentence: available memory is or is not enough for a JVM (this API is Python; the sentence still trains the habit). Write what happens if a disk hits 100% (logs and writes fail).

3. Find the catalog process and its port.

```bash
ps aux | grep -E 'day01_server|main.py' | grep -v grep
ss -lntp | grep 8080 || netstat -lntp | grep 8080
curl -sS http://127.0.0.1:8080/health
```

Copy PID, the LISTEN line, and the health body into `docs/day-02-evidence.md`.

4. Logs. This process logs to the server terminal (BaseHTTPRequestHandler). Copy two request lines. Then:

```bash
ls /var/log | head
```

Write: logs show what the service observed. They do not by themselves show memory or disk.

5. Troubleshooting order in `docs/runtime.md`:

```text
status (if a unit exists) → logs → process → port → resources → the actual failure
```

`systemctl status` may be missing. Write "not present" if it is. Do not restart a host service.

---

## Verify

- `docs/runtime.md` has `uname`, `free`, `df`, PID, and port 8080.
- `/health` returned `ok` while the process ran.
- Notes say a missing LISTEN is not the same as a missing PID.

---

## Break and fix

### Failure 1 — stop the process

Stop the server. Run `ss -lntp | grep 8080` and `curl`. Expected: no LISTEN, connection refused. Restart. Both return.

### Failure 2 — process up, wrong port

Start the server, then `curl http://127.0.0.1:8081/health`. Expected: connection refused. The PID is healthy. The path is wrong. Write that sentence.

---

## Stretch

- `journalctl -u shopsphere` after you add a systemd unit (optional, do not enable on a shared host).

---

## Clean up

Stop the Python process. Keep the markdown.

---

## Interview story

**Situation:** An interview asked how I debug a silent host. **Task:** Show evidence from a live ShopSphere process. **Action:** I recorded `uname`, `free`, `df`, the catalog PID, and `ss` LISTEN on 8080, then curled `/health`. I stopped the process and saw connection refused. I curled 8081 while 8080 still listened to separate a dead process from a wrong path. **Result:** I can walk process → port → resources → logs without opening a portal.

---

## Self-score checklist

- [ ] PID and port 8080 are in Git.
- [ ] I saw connection refused after stop.
- [ ] I did not restart a host service.

**Executed:** `uname`, `free`, `df`, `ps`, `ss`/`netstat`, `curl` on this class of host. **Not executed:** `journalctl -u myapp`, Azure, AWS.
