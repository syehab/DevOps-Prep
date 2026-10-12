# Day 3 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 3 teaches the request path, not a cloud product. This lab walks that path on your machine with real commands. You prove name, IP, route, ICMP, TLS and HTTP status, and local listeners. You do not create Azure or AWS resources.

---

## Goal

Walk one public name from DNS to HTTP, then prove a local listener on your own machine. Write which networking question each command answers. Finish by curling a closed local port and comparing **connection refused** with a **timeout**.

When you finish, you can say where a request stopped, and why. You can also explain why a listening process is not the same as a working traffic path.

---

## What you need

You need a Linux shell (your laptop or a VM). You do not need Azure, AWS, Docker, or a cluster. Cost stays at ₹0.

Use these commands. They come from the lesson or from common Linux networking tools. Do not invent extra flags.

- `nslookup` or `getent hosts` for name → IP
- `ip route` or `ip r` for the routing table
- `ping` for ICMP reachability
- `curl -I` or `curl -vI` for TLS and HTTP status
- `ss -lntp` for local listeners
- `python3` so you can start a short local HTTP listener
- optional `traceroute` or `tracepath` if the package is already installed

`ip` and `ss` come from **iproute2**. If your environment does not have them, skip those steps and write “command missing” in your notes. If `traceroute` or `tracepath` is missing, skip that step. Do not substitute a command you have not used.

Time box: 45 to 75 minutes. Stop when the notes file, the verify list, and the break-and-fix comparison are complete.

---

## Steps

1. Create a notes file named `day-03-path-notes.md` in a folder you control. Put the date at the top. Write one sentence: you will walk `example.com` from name to HTTP, then prove a local listener.

2. Resolve the name. Run one of these. Prefer `nslookup` if it is present. Use `getent hosts` if `nslookup` is missing.

```bash
nslookup example.com
```

```bash
getent hosts example.com
```

Copy one IPv4 address into your notes. Write the question this step answers: **who is the destination?** This is name → IP only. It does not prove that traffic can reach that IP.

3. Inspect routes. Run one of these:

```bash
ip route
```

```bash
ip r
```

Find the default route, often a line that starts with `default via`. Write the gateway address in your notes. Write the question this step answers: **does a valid path to other networks exist from this machine?**

4. Test ICMP. Limit the count so `ping` stops:

```bash
ping -c 4 example.com
```

Write whether replies arrived. Write the question this step answers: **does this host reply to ICMP?** A failed ping does not prove HTTPS is down. Firewalls often block ICMP and still allow TCP 443.

5. Test the edge with HTTP. Run one of these:

```bash
curl -I https://example.com
```

```bash
curl -vI https://example.com
```

`-I` asks for headers only (an HTTP HEAD). `-v` prints the handshake. From the output, record three facts: did name resolution appear, did TLS complete, and what HTTP status came back. That is the edge check from the lesson. Write the question: **does the edge complete TLS and return a status?**

6. List local listeners:

```bash
ss -lntp
```

`-l` lists listening sockets. `-n` prints numeric ports. `-t` is TCP. `-p` shows the process when you have permission. Write two or three lines you see, or write that the command is missing. Write the question: **is anything listening on this machine?** Listening is not the same as “a remote client can connect.”

7. Start a local HTTP listener so you have a port you control. In one terminal:

```bash
python3 -m http.server 8765
```

Leave it running. In a second terminal, prove the listener and then fetch headers:

```bash
ss -lntp
```

```bash
curl -I http://127.0.0.1:8765
```

Confirm `ss` shows port `8765` and that `curl` returns an HTTP status. Write: this proves **correct IP + correct port + a process that answers**. Record the status code.

8. Optional path trace. If `traceroute` or `tracepath` is installed, run one:

```bash
traceroute example.com
```

```bash
tracepath example.com
```

Read the hop list. Write where the path goes, or where it stops. If neither command exists, skip this step and write “skipped — traceroute/tracepath not installed.” Do not install a package only for this lab unless you already know your package manager.

9. In your notes, map each command to one question. Use this list:

```text
nslookup / getent hosts  →  who is the destination (name → IP)?
ip route / ip r          →  does a valid path exist?
ping                     →  does this host reply to ICMP?
curl -I / curl -vI       →  does TLS complete, and what HTTP status returns?
ss -lntp                 →  is anything listening here?
traceroute / tracepath   →  where along the path did packets stop?
```

Do not merge these into one “network is down” line. The lesson is the split.

---

## Verify

Read your notes out loud as if you are in an interview. Start at the name and stop at HTTP. You should not jump to “restart the app.”

Check these points:

- You recorded an IP from DNS before you talked about routes or curl.
- You found a default route, or you wrote that `ip` was missing.
- `ping` and `curl` are separate answers in your notes.
- `curl -I` or `curl -vI` against `https://example.com` shows an HTTP status.
- `ss -lntp` (when present) showed the Python listener on `8765` while it was running.
- `curl -I http://127.0.0.1:8765` returned headers from the process you started.
- Optional traceroute is either in the notes or marked skipped.

If a box is only a command with no question next to it, add the question before you stop.

---

## Break and fix

Keep the Python listener running on `8765`. Now curl a **closed** local port on purpose:

```bash
curl -vI --max-time 5 http://127.0.0.1:8766
```

Port `8766` has no listener. The kernel should reject the TCP connect. Expect **connection refused** (curl often prints `Failed to connect` and `Connection refused`). That error means: the IP was reachable, a route existed, and nothing accepted the port. It is not a DNS failure.

Next, compare that with a **timeout**. Use the documentation address `192.0.2.1` (TEST-NET-1). It is not a host you run. Packets typically get no TCP reply:

```bash
curl -vI --connect-timeout 5 http://192.0.2.1
```

`--connect-timeout` stops curl after five seconds if the handshake never starts. Expect a timeout, not connection refused. A timeout means the packet was dropped or never answered. A refused connect means a host answered “closed.”

Write both errors in your notes, side by side:

```text
127.0.0.1:8766  →  connection refused  →  host reached, port closed
192.0.2.1       →  timeout             →  no TCP answer
```

Then curl the open port again and confirm it still works:

```bash
curl -I http://127.0.0.1:8765
```

The fix is not a config change. The fix is to use the error to name the layer. Refused points at listen/port. Timeout points at route, firewall drop, or an unreachable next hop. Put the Python listener back in your mental path: process running, port listening, HTTP answering.

---

## Clean up

Stop the Python process you started. In the terminal that runs `http.server`, press Ctrl+C. Confirm it is gone:

```bash
ss -lntp
```

Port `8765` should no longer list that process. You created no cloud resources. Keep `day-03-path-notes.md` in your notes. Do not commit secrets; this file should not contain passwords, keys, or account IDs.

There is no resource group, VPC, or cluster to delete today.

---

## Interview story

I do not treat “the network” as one thing. I walk a path: name → edge → IP → route → firewall → listener → application. I prove DNS with `nslookup` or `getent hosts`, the route with `ip route`, ICMP with `ping`, and TLS plus HTTP status with `curl -I` or `curl -vI`. `ss -lntp` tells me what listens locally; it does not tell me a remote client can connect. Connection refused means the host answered and the port is closed. A timeout means nothing answered. I stop at the first failed layer and investigate that layer.
