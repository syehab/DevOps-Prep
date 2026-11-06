# Day 1 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 1 teaches a mental model, not a cloud product. The old lab was a map in a notes folder with no running process. This lab starts a **live ShopSphere catalog** on your machine, draws the map from that process, then walks one failure with evidence.

Work in **your ShopSphere repository**. The capstone starter API is the preferred app if [../capstone/](../capstone/) is already in your clone. If it is not, use the 20-line server in this lab. Do not make `/tmp` the product home.

---

## Goal

1. Run the catalog API and `curl` `/health` and `/catalog`.
2. Write `docs/system-map.md` that places the live process, CI/CD, Terraform, network, security, observability, reliability, and cost.
3. Walk “API cannot reach the database” with evidence, not a guess.
4. Add a five-row Azure → AWS concept table.

Time box: 45 to 60 minutes. Cost is **USD 0.00**.

---

## Capstone stage

| Path | Adds |
|:--|:--|
| `app/day01_server.py` | Tiny catalog if the starter is not present |
| `docs/system-map.md` | Map drawn from a live `curl` |
| `docs/day-01-failure.md` | Evidence path for API → database |

---

## What you need

```bash
python3 --version
command -v curl
```

You do not need Azure, AWS, Docker, or Terraform today. Those names still appear on the map as **future** boxes.

---

## Cost

| Path | Estimated USD |
|:--|:--|
| Local Python + markdown | **0.00** |
| Cloud account | **Do not open** |

Do not write "INR 0" as a habit for later Days. Today is actually zero because nothing is billed.

---

## Steps

1. Open ShopSphere. Create folders.

```bash
mkdir -p app docs
```

2. If `app/main.py` from the capstone starter already serves `/health`, use it. If it does not exist, write `app/day01_server.py`.

```python
#!/usr/bin/env python3
from http.server import BaseHTTPRequestHandler, HTTPServer
import json

CATALOG = [{"id": "sku-1", "name": "mug"}]


class Handler(BaseHTTPRequestHandler):
    def _send(self, code: int, body: dict) -> None:
        payload = json.dumps(body).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def do_GET(self) -> None:  # noqa: N802
        if self.path == "/health":
            self._send(200, {"status": "ok"})
            return
        if self.path == "/catalog":
            self._send(200, {"items": CATALOG})
            return
        self._send(404, {"error": "not found"})


if __name__ == "__main__":
    HTTPServer(("127.0.0.1", 8080), Handler).serve_forever()
```

3. Start the server. Leave it running.

```bash
python3 app/day01_server.py
```

In a second shell:

```bash
curl -sS http://127.0.0.1:8080/health
curl -sS http://127.0.0.1:8080/catalog
```

Expected: `{"status": "ok"}` and a catalog with `sku-1`. Copy both bodies into `docs/system-map.md` under **Evidence**. Executed on Python 3.12.

4. Write `docs/system-map.md`. Start from the process you just curled, not from a tool list.

Required sections:

- One sentence: who the user is (a shopper) and what they do (list the catalog).
- Text diagram: `User → curl/browser → 127.0.0.1:8080 → catalog process`. Add DNS, load balancer, and a private database as **later** hops. Label today’s hop as loopback.
- Delivery: `Developer → Git → CI/CD → Deploy → Application`. One line: CI/CD moves a reviewed artifact. It does not create the VNet.
- Platform: Terraform with network, compute, and database. One line: Terraform creates the platform. It does not run this Python process.
- Operations wrap: security, observability, reliability, cost. One “why” sentence each. Use the lesson table: compute, networking, IaC, CI/CD, IAM, observability, reliability, FinOps.
- Senior pattern on **one** piece (Terraform or CI/CD): Why, What, How, What can go wrong, How do I know, How do I fix it.
- Azure → AWS table, at least five rows, **concept** on the left.

```text
Concept        Azure                    AWS
Identity       Entra tenant             Organization + IAM
Isolation      Subscription             Account
Network        VNet                     VPC
Kubernetes     AKS                      EKS
Object store   Blob                     S3
```

5. Write `docs/day-01-failure.md` titled “Application cannot connect to the database.”

Today there is no database. That is the point. List the path in order and the evidence you would collect **before** you change anything:

```text
DNS        → what name did the API resolve?
Route      → which next hop?
Port       → is 5432 listening?
Firewall   → NSG / Security Group / local bind
Credentials→ where does the secret live? (not in Git)
Health     → does Postgres accept a connection?
```

Write that you did **not** restart the Python process as the first move.

---

## Verify

- `curl /health` returned `ok` while the server ran.
- The map starts at the user and reaches the process you curled.
- CI/CD and Terraform have different jobs.
- The failure note starts with evidence, not “restart the app.”
- The table uses concepts, not slogans.

Read the map out loud. If a box is only a product name, add the why.

---

## Break and fix

### Failure 1 — stop the process

Stop the server (`Ctrl+C`). Run `curl` again. Expected: connection refused. Write that line in the failure note. The map still has a path. The process is down. Restart. `curl` must work again.

### Failure 2 — erase the network boxes

Remove DNS, load balancer, routes, and firewall from the map. Try to explain how a **cloud** user reaches the API. You cannot. Put them back. Add one sentence: “If I cannot name the path, I do not yet understand the system.”

---

## Stretch

- Point `docs/system-map.md` at the capstone starter instead of `day01_server.py`.
- Add a `/health` check script from `drills/scripting/08-go-health/` when that pack is in your clone.

---

## Clean up

Stop the Python process. Keep the markdown in Git. You created no cloud resources.

```bash
# Ctrl+C in the server shell
```

---

## Interview story

**Situation:** A Senior interview asked how the pieces fit. The old homework was a map with no process. **Task:** Show a live catalog and a map that matches it. **Action:** I ran a 20-line Python server on `127.0.0.1:8080`, curled `/health` and `/catalog`, and placed CI/CD (moves the artifact) next to Terraform (creates the platform). I wrote the database-failure path as DNS → route → port → firewall → credentials → health. I stopped the process on purpose and recorded connection refused. **Result:** I can start at the user without a product slogan, and I can say why a later AKS or EKS box is not today’s runtime.

---

## Self-score checklist

- [ ] `curl /health` succeeded while the server ran.
- [ ] `docs/system-map.md` has the live evidence and the eight lesson areas.
- [ ] Failure note walks evidence first.
- [ ] I stopped the process and saw connection refused.

**Executed:** Python 3.12 `http.server` handler + `curl` (run these on your machine). **Not executed:** Docker, Terraform, Azure, AWS, capstone starter (optional).
