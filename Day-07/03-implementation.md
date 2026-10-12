# Day 7 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 7 teaches how a new version replaces an old version. This lab makes rolling and blue-green visible on your machine. You run two local HTTP servers. You switch traffic by changing which port is live. You do not create cloud resources.

---

## Goal

Serve Version 1 and Version 2 on two local ports. Simulate a rolling replace, then a blue-green traffic switch. Record which port is live in a small file, and send every “user” request through a one-line shell wrapper that reads that file.

When you finish, you can show mixed versions during rolling, and you can show a full switch during blue-green. You can also show connection refused when the live port points at a down instance, then switch back.

---

## What you need

You need a Linux or macOS shell, `python3`, `curl`, and a text editor. You do not need Azure, AWS, Kubernetes, or nginx. Cost stays at ₹0.

Check the tools first. Run these commands. `python3` and `curl` must exist. `docker` is optional. If `docker` is missing, continue with `python3`. Do not install Docker only for this lab.

```bash
command -v python3
python3 --version
command -v curl
command -v docker
```

`python3 -m http.server` is the server this lab uses. It is part of the Python standard library. If `docker` prints a path, you may still follow the Python steps below. Do not pull an image unless you already know the image and will delete the containers in Clean up.

Create a notes file named `day-07-deploy-lab.md` in a folder you control. You will paste command output into that file. Do not put passwords, keys, or account IDs in the file.

Work under `/tmp`, not inside this course repository. The course clone is a real Git repo. Do not start long-running servers from the lesson folder.

Time box: 45 to 75 minutes. Stop when both strategies are recorded, the break-and-fix refused error is in the notes, and the servers are stopped.

---

## Steps

1. Create a throwaway lab directory and two version trees. Put a one-line body in each `index.html` so `curl` can tell v1 from v2.

```bash
LAB=/tmp/day-07-deploy-lab
mkdir -p "$LAB/v1" "$LAB/v2" "$LAB/inst-a" "$LAB/inst-b"
printf 'Version 1\n' > "$LAB/v1/index.html"
printf 'Version 2\n' > "$LAB/v2/index.html"
cp "$LAB/v1/index.html" "$LAB/inst-a/index.html"
cp "$LAB/v1/index.html" "$LAB/inst-b/index.html"
ls -la "$LAB/v1" "$LAB/v2" "$LAB/inst-a" "$LAB/inst-b"
```

Write in the notes: both instances start on Version 1. That is the fleet before a rolling replace.

2. Pick two ports. The lesson uses `8081` (Blue / instance A) and `8082` (Green / instance B). Confirm they are free:

```bash
ss -lntp
```

If `ss` is missing, skip it and write “ss missing” in the notes. If `8081` or `8082` already listens, use `18081` and `18082` instead and keep those numbers in every later command. Write the two ports you will use.

3. Start instance A on port `8081` in the background. Record its PID.

```bash
LAB=/tmp/day-07-deploy-lab
python3 -m http.server 8081 --directory "$LAB/inst-a" >"$LAB/inst-a.log" 2>&1 &
echo $! > "$LAB/inst-a.pid"
cat "$LAB/inst-a.pid"
```

4. Start instance B on port `8082` in the background. Record its PID.

```bash
LAB=/tmp/day-07-deploy-lab
python3 -m http.server 8082 --directory "$LAB/inst-b" >"$LAB/inst-b.log" 2>&1 &
echo $! > "$LAB/inst-b.pid"
cat "$LAB/inst-b.pid"
```

5. Prove both listeners. You should see `Version 1` twice. That is the before state of a rolling deployment: every instance still runs v1.

```bash
ss -lntp
curl -sS http://127.0.0.1:8081/
curl -sS http://127.0.0.1:8082/
```

Paste both bodies into the notes. If a curl fails, read the matching `.log` file and `.pid` file before you continue.

6. Create the traffic wrapper. The wrapper is the load balancer. It does not guess the port. It reads `live-port`.

```bash
LAB=/tmp/day-07-deploy-lab
printf '8081\n' > "$LAB/live-port"
cat > "$LAB/live.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
PORT="$(tr -d '[:space:]' < "$ROOT/live-port")"
echo "live port: ${PORT}" >&2
curl -sS "http://127.0.0.1:${PORT}/"
EOF
chmod +x "$LAB/live.sh"
```

7. Send a user request through the wrapper. Live is still `8081`, so the body must be Version 1.

```bash
/tmp/day-07-deploy-lab/live.sh
cat /tmp/day-07-deploy-lab/live-port
```

Write one line in the notes: the user does not choose a version. The live port chooses the instance.

8. Simulate **rolling**. Replace instance B first. Stop the process on `8082`, copy Version 2 into `inst-b`, and start the server again on the same port.

```bash
LAB=/tmp/day-07-deploy-lab
kill "$(cat "$LAB/inst-b.pid")"
sleep 1
cp "$LAB/v2/index.html" "$LAB/inst-b/index.html"
python3 -m http.server 8082 --directory "$LAB/inst-b" >"$LAB/inst-b.log" 2>&1 &
echo $! > "$LAB/inst-b.pid"
curl -sS http://127.0.0.1:8081/
curl -sS http://127.0.0.1:8082/
/tmp/day-07-deploy-lab/live.sh
```

You should see Version 1 on `8081` and Version 2 on `8082`. Live is still `8081`, so the wrapper still returns Version 1. Write this mixed state in the notes:

```text
During rolling:
8081 → Version 1
8082 → Version 2
live-port → 8081
```

That mix is the rolling trade-off from the lesson. v1 and v2 run together. Health checks and rollback control matter here.

9. Finish the rolling replace. Stop instance A, copy Version 2 into `inst-a`, and start it again.

```bash
LAB=/tmp/day-07-deploy-lab
kill "$(cat "$LAB/inst-a.pid")"
sleep 1
cp "$LAB/v2/index.html" "$LAB/inst-a/index.html"
python3 -m http.server 8081 --directory "$LAB/inst-a" >"$LAB/inst-a.log" 2>&1 &
echo $! > "$LAB/inst-a.pid"
curl -sS http://127.0.0.1:8081/
curl -sS http://127.0.0.1:8082/
```

Both ports should return Version 2. Rolling is complete. Write: rollback would mean putting Version 1 back onto instances you already changed. You cannot only “stop a new server.”

10. Reset for **blue-green**. Blue stays on `8081` with Version 1. Green stays on `8082` with Version 2. You change content without mixing the idea of “replace in place” with “two environments.”

```bash
LAB=/tmp/day-07-deploy-lab
kill "$(cat "$LAB/inst-a.pid")" "$(cat "$LAB/inst-b.pid")"
sleep 1
cp "$LAB/v1/index.html" "$LAB/inst-a/index.html"
cp "$LAB/v2/index.html" "$LAB/inst-b/index.html"
python3 -m http.server 8081 --directory "$LAB/inst-a" >"$LAB/inst-a.log" 2>&1 &
echo $! > "$LAB/inst-a.pid"
python3 -m http.server 8082 --directory "$LAB/inst-b" >"$LAB/inst-b.log" 2>&1 &
echo $! > "$LAB/inst-b.pid"
printf '8081\n' > "$LAB/live-port"
curl -sS http://127.0.0.1:8081/
curl -sS http://127.0.0.1:8082/
/tmp/day-07-deploy-lab/live.sh
```

Blue (`8081`) is Version 1 and live. Green (`8082`) is Version 2 and not live. Deployment of Green already happened. Users have not moved. Write that sentence in the notes. Blue-green separates deploy from the traffic switch.

11. Validate Green before you switch. Curl `8082` directly. Do not change `live-port` yet.

```bash
curl -sS http://127.0.0.1:8082/
```

Confirm the body is Version 2. If Green is wrong, keep live on `8081`. That is the test-on-Green step from the lesson.

12. Switch traffic. Change only the live port file, then use the wrapper. Do not restart Blue.

```bash
printf '8082\n' > /tmp/day-07-deploy-lab/live-port
/tmp/day-07-deploy-lab/live.sh
curl -sS http://127.0.0.1:8081/
```

The wrapper must return Version 2. Direct curl to `8081` must still return Version 1. Blue is the rollback target. Write:

```text
After blue-green switch:
live-port → 8082 → Version 2
Blue 8081 still → Version 1
```

---

## Verify

Read the notes out loud as if you are on a call. You should be able to name two ports, two version strings, and which file makes a port live.

Check these points:

- `command -v docker` was run. Missing docker is fine. The servers are `python3 -m http.server`.
- Rolling had a mixed moment: one port Version 1, the other Version 2.
- During that mix, `live.sh` still followed `live-port`. It did not load-balance by itself.
- Blue-green had both versions running at once. The switch was a file change, not a rebuild.
- After the switch, Blue on `8081` still served Version 1.
- Each `curl` in the notes has a body, not only “it worked.”

If any box is only a strategy name with no port and no body, rerun that curl and paste the output before you stop.

---

## Break and fix

Do this on purpose. Leave live pointing at Green (`8082`). Then stop Green so the live port has no listener.

```bash
LAB=/tmp/day-07-deploy-lab
cat "$LAB/live-port"
kill "$(cat "$LAB/inst-b.pid")"
sleep 1
ss -lntp
curl -v --max-time 5 http://127.0.0.1:8082/ || true
/tmp/day-07-deploy-lab/live.sh || true
```

`--max-time` stops curl after five seconds. Expect **connection refused** (curl often prints `Failed to connect` and `Connection refused`). The IP is local. The route exists. Nothing accepts port `8082`. That is not a DNS failure and not a timeout.

Users are broken because `live-port` still says `8082`. Fix the traffic, not the old binary. Switch live back to Blue:

```bash
LAB=/tmp/day-07-deploy-lab
printf '8081\n' > "$LAB/live-port"
/tmp/day-07-deploy-lab/live.sh
curl -sS http://127.0.0.1:8081/
```

The wrapper must return Version 1 again. Write three lines in the notes:

1. Failure: live pointed at `8082` while the process was down.
2. Evidence: `curl` to `8082` returned connection refused.
3. Fix: write `8081` to `live-port`. Blue still had Version 1.

Do not restart Green to “make the error go away” before you record the refused connect. The lesson is the switch back, not a rebuild of v2.

---

## Clean up

Stop any server you still have. Then confirm the ports are gone.

```bash
LAB=/tmp/day-07-deploy-lab
if [ -f "$LAB/inst-a.pid" ]; then kill "$(cat "$LAB/inst-a.pid")" 2>/dev/null || true; fi
if [ -f "$LAB/inst-b.pid" ]; then kill "$(cat "$LAB/inst-b.pid")" 2>/dev/null || true; fi
sleep 1
ss -lntp
rm -rf "$LAB"
```

Ports `8081` and `8082` should no longer list those Python processes. You created no cloud resources. Keep `day-07-deploy-lab.md` in your notes.

If you started Docker containers instead of Python, list them, stop them, and remove them:

```bash
docker ps
docker stop <container>
docker rm <container>
```

There is no resource group, VPC, or cluster to delete today. If you opened a cloud console out of habit, close it. Create nothing.

---

## Interview story

I do not treat “deploy” as copying a binary. I treat it as moving traffic between versions while I control risk. In rolling, I replace instances in the live fleet, so v1 and v2 run together and rollback means putting v1 back onto servers I already changed. In blue-green, I deploy Green without moving users, then I switch the live pointer. If Green is down, curl gets connection refused. I switch back to Blue, which still serves the old version. Deployment success and application success are different facts.
