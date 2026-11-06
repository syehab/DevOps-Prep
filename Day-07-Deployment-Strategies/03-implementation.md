# Day 7 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 7 teaches how a new version replaces an old version. The old lab used two local ports in `/tmp`. This lab still runs that switch so you can see mixed versions. It then writes **Helm values** in ShopSphere for rolling and a canary note. `helm template` is optional.

Work in **your ShopSphere repository**.

---

## Goal

1. Serve v1 and v2 on two loopback ports. Switch the live port through a file.
2. Write `charts/shopsphere/values.yaml` (rolling) and `values-canary.yaml`.
3. Record mixed versions (rolling) versus a full switch (blue-green).

Time box: 45 to 75 minutes. Cost is **USD 0.00**.

---

## Capstone stage

| Path | Adds |
|:--|:--|
| `docs/day-07-deploy.md` | Port switch evidence |
| `charts/shopsphere/values.yaml` | Rolling defaults |
| `charts/shopsphere/values-canary.yaml` | 10% canary note |

---

## What you need

```bash
python3 --version
command -v curl
command -v helm || true
```

Helm is optional. Docker is optional.

---

## Cost

| Path | Estimated USD |
|:--|:--|
| Two local Python servers | **0.00** |
| `helm template` | **0.00** |

---

## Steps

1. Open ShopSphere.

```bash
mkdir -p charts/shopsphere docs
```

2. Start v1 and v2 (two shells, or background).

```bash
python3 - << 'PY' &
from http.server import BaseHTTPRequestHandler, HTTPServer
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        b = b"v1"
        self.send_response(200)
        self.send_header("Content-Length", "2")
        self.end_headers()
        self.wfile.write(b)
    def log_message(self, *a):
        pass
HTTPServer(("127.0.0.1", 8091), H).serve_forever()
PY
python3 - << 'PY' &
from http.server import BaseHTTPRequestHandler, HTTPServer
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        b = b"v2"
        self.send_response(200)
        self.send_header("Content-Length", "2")
        self.end_headers()
        self.wfile.write(b)
    def log_message(self, *a):
        pass
HTTPServer(("127.0.0.1", 8092), H).serve_forever()
PY
printf '8091\n' > /tmp/shopsphere-live.port
```

3. User wrapper:

```bash
curl -sS "http://127.0.0.1:$(cat /tmp/shopsphere-live.port)/"
# rolling: some curls still 8091, some 8092
printf '8092\n' > /tmp/shopsphere-live.port
curl -sS "http://127.0.0.1:$(cat /tmp/shopsphere-live.port)/"
```

Rolling = mixed answers while both live. Blue-green = flip the file; every user sees v2. Copy both into `docs/day-07-deploy.md`. Executed here: `v1` then `v2` after the flip.

4. Helm values (the artifact you keep):

```yaml
# charts/shopsphere/values.yaml
replicaCount: 2
image:
  repository: shopsphere/catalog
  digest: sha256:REPLACE
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 0
    maxSurge: 1
```

```yaml
# charts/shopsphere/values-canary.yaml
canary:
  weight: 10
# Argo Rollouts or two Services. This file is the note. Day 16 wires Helm.
```

If `helm` exists: `helm template shopsphere charts/shopsphere` after you add a Chart.yaml. If Helm is missing, the values files still complete the Day.

---

## Verify

- Live file switch changed `v1` to `v2`.
- Values file has `RollingUpdate` and a digest, not `latest`.
- Canary file names a weight.

---

## Break and fix

### Failure 1 — live port points at a down instance

Stop the v2 server. Keep the file on 8092. `curl` is connection refused. Flip back to 8091. That is a bad blue-green cut.

### Failure 2 — `latest` in values

Put `tag: latest` in `values.yaml`. Replace it with `digest`. Rolling `latest` is not a strategy. It is a moving target.

---

## Stretch

- Add `Chart.yaml` `apiVersion: v2` and `helm template`.
- Day 16 app-of-apps deploys these values.

---

## Clean up

Kill the two Python processes. Keep the chart files.

---

## Interview story

**Situation:** A Lead asked rolling versus blue-green. **Task:** Show both on a laptop, then write Helm values. **Action:** I served v1 and v2 on 8091/8092, flipped `/tmp/shopsphere-live.port`, and saw a full switch. I stopped v2 and got connection refused — a bad cut. I wrote `RollingUpdate` with `maxUnavailable: 0` and a digest, plus a 10% canary note. **Result:** I can say mixed versions are rolling, a flip is blue-green, and `latest` is not a rollout strategy.

---

## Self-score checklist

- [ ] I recorded v1, v2, and refused-on-down.
- [ ] Values pin a digest.
- [ ] I stopped both servers.

**Executed:** two-port switch (`v1` → `v2`) and refused after killing v2. **Not executed:** `helm template`, Argo Rollouts, AKS/EKS rollout.
