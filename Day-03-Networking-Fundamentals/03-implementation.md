# Day 3 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 3 teaches the request path. The old lab walked a public name and a local port. This lab still does that. It then pins the same chain to the **ShopSphere catalog** on loopback and writes `docs/request-path.md` in your ShopSphere repository.

---

## Goal

Walk `example.com` from DNS to HTTP. Walk `127.0.0.1:8080` from listen to `/health`. Compare **connection refused** with a **timeout**. Write which question each command answers.

Time box: 45 to 75 minutes. Cost is **USD 0.00**.

---

## Capstone stage

| Path | Adds |
|:--|:--|
| `docs/request-path.md` | DNS → IP → route → TLS/HTTP → local catalog |

---

## What you need

```bash
command -v getent
command -v curl
command -v ping
command -v ip || command -v route
python3 --version
```

`ip` is missing on some hosts. Use `route -n` or `cat /proc/net/route` then. Do not invent a cloud CLI.

---

## Cost

| Path | Estimated USD |
|:--|:--|
| Local DNS + curl | **0.00** |

---

## Steps

1. Open ShopSphere. Start the Day 1 server.

```bash
mkdir -p docs
python3 app/day01_server.py
```

2. Public name.

```bash
getent hosts example.com
nslookup example.com
```

Write: this answers **which IP**.

3. Route.

```bash
ip route
# if ip is missing:
route -n
cat /proc/net/route
```

Write: this answers **which next hop**.

4. ICMP and HTTP.

```bash
ping -c 1 127.0.0.1
curl -sI https://example.com | head -5
```

Write: ICMP answers reachability, not HTTP success. `curl -I` answers TLS and status.

5. Local catalog.

```bash
ss -lntp | grep 8080 || netstat -lntp | grep 8080
curl -sS http://127.0.0.1:8080/health
```

Write the chain: name (loopback) → IP `127.0.0.1` → local route → port 8080 → process → JSON.

6. Copy every answer into `docs/request-path.md`.

---

## Verify

- `getent` returned an IP for `example.com`.
- `curl -I https://example.com` showed HTTP 2xx.
- `/health` returned `ok`.
- Notes name the question each command answers.

Executed on this authoring host: `getent`, `ping 127.0.0.1`, `curl -I https://example.com` → HTTP/2 200, `curl` to a closed port → refused. `ip` was **missing**; `route` and `/proc/net/route` worked.

---

## Break and fix

### Failure 1 — connection refused

```bash
curl -sS http://127.0.0.1:9
```

Expected: `Failed to connect` / connection refused. A process is not listening. Fast fail.

### Failure 2 — timeout

```bash
curl -sS --max-time 3 http://1.1.1.1:81
```

Expected: timeout. A filter or a blackhole dropped the packet. Slow fail. Write: refused ≠ timeout. Do not treat them as the same 5xx.

---

## Stretch

- `openssl s_client -connect example.com:443 -servername example.com </dev/null | head`

---

## Clean up

Stop the Day 1 server. Keep the markdown.

---

## Interview story

**Situation:** A ticket said "the site is down." **Task:** Say where the request stopped. **Action:** I resolved `example.com`, read the route table (`ip` or `route -n`), curled HTTPS, then curled ShopSphere `/health` on 8080. I compared port 9 (refused) with `1.1.1.1:81` (timeout). **Result:** I can name DNS, next hop, and listen separately, and I do not call a timeout a refused connection.

---

## Self-score checklist

- [ ] Public and local paths are in `docs/request-path.md`.
- [ ] I recorded refused vs timeout.
- [ ] I named the question each command answers.

**Executed:** `getent`, `ping`, `curl -I`, refused on `:9`, timeout on `1.1.1.1:81`. **Not executed:** `ip route` (binary missing on the authoring VM), Azure, AWS, `tcpdump`.
