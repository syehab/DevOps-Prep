# Day 41 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 41 is a **game day** on the ShopSphere stack you already built. A pipeline can report SUCCESS while checkout returns 5xx. You detect the **symptom** (error-budget burn from Day 20), you **mitigate before root cause**, and you write the incident. You use the capstone observability files, not a new `/tmp` server.

Work in **your ShopSphere repository**. You need Day 20's PrometheusRule if you have `kind`. If you do not, you still run the catalog API, inject 5xx, compute the burn against a 99.9 percent SLO, and write the same incident file.

---

## Goal

Write `docs/incidents/INC-001-shopsphere.md` with start time, service, versions, error rate, and the failing business function. Inject 5xx on `/products`. Compute the fast 5-minute burn against a 0.001 error budget (Day 20). Mitigate by rolling back the inject. Then decide rollback versus fix-forward using evidence. Do not page on CPU.

Time box: 60 to 90 minutes.

---

## Capstone stage

| Path in ShopSphere | What it adds |
|:--|:--|
| `docs/incidents/INC-001-shopsphere.md` | Timeline, evidence, mitigate-before-RCA |
| `scripts/game-day-inject.sh` | Local 5xx inject + restore |
| `observability/rules/shopsphere-slo.yaml` | Reuse Day 20 two-window burn (do not invent a CPU page) |
| `docs/day-41-game-day.md` | Burn ratio, mitigate time, cluster-or-local note |

Day 20 installed kube-prometheus-stack. Day 35 put Grafana in Git. This Day **uses** those objects. Do not install a second Prometheus.

---

## What you need

```bash
python3 --version
curl --version
kubectl version --client
kind get clusters
```

Python 3.12 and `curl` are enough for the required inject. `kind` cluster `shopsphere` plus namespace `monitoring` is the preferred path. If `kubectl -n monitoring get prometheusrules` fails, stay local. Do not create AKS for a game day.

The broken-cluster pack in `drills/kubernetes-broken-cluster/` (PR #195) is extra practice after this incident. It is not a substitute for the ShopSphere timeline.

---

## Cost

| Path | Estimated USD | Why |
|:--|:--|:--|
| Local API inject + notes | **0.00** | Laptop only |
| Game day on existing `kind` | **0.00** | RAM |
| Reuse a leftover one-node AKS | **1.50–4.50** per hour | Destroy when the game day ends |
| New cluster, NAT Gateway, or load balancer | **Stop.** | |

Create a budget before any cloud cluster ([../capstone/COST.md](../capstone/COST.md)). Do not write "INR 0" if AKS is running.

---

## Steps

1. Open ShopSphere. Create folders.

```bash
mkdir -p docs/incidents scripts docs
```

Start the incident file **before** you inject. Put UTC time, service `catalog`, environment `dev` or `kind`, and "error rate unknown".

2. Confirm observability exists.

```bash
ls observability/rules/shopsphere-slo.yaml
kubectl -n monitoring get prometheusrules shopsphere-slo
```

If the YAML is missing, copy the two-window rule from [Day-20/03-implementation.md](../Day-20/03-implementation.md) into ShopSphere now. Fast window: 5m burn > `14.4 * 0.001`. Slow window: 1h burn > `6 * 0.001`. Symptom is 5xx ratio, not CPU.

If Prometheus is missing, you will compute the same ratio with `curl` counts. Write `prometheus not running — curl SLI used`.

3. Baseline. Start the catalog if it is not already up.

```bash
python3 app/main.py
```

Second terminal:

```bash
ok=0
n=20
for i in $(seq 1 "$n"); do
  code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8080/products)
  if [ "$code" = "200" ]; then ok=$((ok + 1)); fi
done
python3 -c "print('baseline_success=%.2f' % ($ok / $n))"
```

Expected: `baseline_success=1.00`. Record it. `/products` is the business function. `/health` can stay 200 while products fail. That is the Day 41 lesson.

4. Write `scripts/game-day-inject.sh`. This overlay makes `/products` return 500 without touching Prometheus. It copies `app/main.py`, patches the products branch, and restores from Git.

```bash
#!/usr/bin/env bash
set -euo pipefail
# Inject: /products returns HTTP 500. Restore: git checkout -- app/main.py
mode="${1:-}"
case "$mode" in
  on)
    python3 - <<'PY'
from pathlib import Path
p = Path("app/main.py")
text = p.read_text()
old = '        if self.path == "/products":\n            self._send(200, PRODUCTS)\n            return\n'
new = '        if self.path == "/products":\n            self._send(500, {"error": "game-day"})\n            return\n'
if old not in text:
    raise SystemExit("products branch not found — Day 1 starter main.py required")
p.write_text(text.replace(old, new, 1))
print("inject on: /products -> 500")
PY
    ;;
  off)
    git checkout -- app/main.py
    echo "inject off: app/main.py restored"
    ;;
  *)
    echo "usage: $0 on|off" >&2
    exit 2
    ;;
esac
```

```bash
chmod +x scripts/game-day-inject.sh
./scripts/game-day-inject.sh on
```

Restart the API process so it loads the file. If you used `kind` and a live image, this file change is not enough. For the cluster path, set the Deployment image to a tag that does not exist (Day 16 ImagePullBackOff) **or** apply a ConfigMap that the app reads. The local file inject is the required path.

5. Measure the symptom.

```bash
fail=0
n=20
for i in $(seq 1 "$n"); do
  code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8080/products)
  if [ "$code" != "200" ]; then fail=$((fail + 1)); fi
  echo "$code"
done
python3 -c "ratio=$fail/$n; budget=0.001; print('error_ratio=%.2f' % ratio); print('fast_burn_x=%.1f' % (ratio / budget))"
curl -sS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8080/health
```

Expected: `/products` is `500`. `/health` is still `200`. `error_ratio=1.00`. `fast_burn_x=1000.0` times the 0.001 budget. The 5-minute rule would page. CPU is irrelevant.

If Prometheus is up:

```bash
kubectl -n monitoring port-forward svc/kps-kube-prometheus-st-prometheus 9090:9090
# other terminal
curl -sG http://127.0.0.1:9090/api/v1/query \
  --data-urlencode 'query=ALERTS{alertname="ShopSphereErrorBudgetBurnFast"}'
```

**Not executed** in the authoring environment (no cluster).

6. Mitigate **before** you hunt the Git blame.

```bash
./scripts/game-day-inject.sh off
# restart the API
curl -sS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8080/products
```

Expected: `200`. Record mitigate time in the incident file. Then write root cause: the products handler returned 500 because of a game-day inject. The user symptom was checkout/browse failing, not a missing CPU alert.

7. Fill INC-001. Required sections (prose, not empty headings):

- Detect: how you saw 5xx (curl ratio or Prometheus ALERTS)
- Evidence: `/products` vs `/health`, Deployment image, last Git SHA
- Mitigate: inject off / `kubectl rollout undo` / Git revert
- Verify: success ratio back to 1.00
- RCA: after mitigate
- Prevent: digest pin from Day 33, burn-rate from Day 20, no CPU page as primary

If you have `kind`, also run **one** scenario from `drills/kubernetes-broken-cluster/` after the incident file exists. Do not skip the ShopSphere write-up to play the pack.

---

## Verify

- INC-001 has a timeline and a mitigate-before-RCA order.
- `/products` failed while `/health` stayed 200, or you recorded the cluster equivalent.
- Burn math used 0.001, not CPU percent.
- Inject is off. `app/main.py` matches Git.
- Files live in ShopSphere.

---

## Break and fix

Do both failures.

### Failure 1 — page on CPU

Write an alert `node_cpu_seconds > 80` as the first page. Then delete it. Record: CPU is a cause. The burn-rate rule is the symptom. Day 20 already forbade this. Game day is where people forget.

### Failure 2 — undo a schema-incompatible release

On paper, version N+1 migrated PostgreSQL and then the app failed. `kubectl rollout undo` restores the old image against the new schema. Write why undo is unsafe. The fix is expand-and-contract (Day 34). Mitigate with a forward fix or a dual-write, not a blind undo. Do not run a real migration today.

---

## Stretch

- Port-forward Grafana and watch the Day 35 success-ratio panel during inject. Screenshot stays out of Git if it contains host names you do not want public. Record the uid `shopsphere-catalog`.
- Add `shopsphere_http_requests_total{code=...}` to `app/main.py` so the Day 20 PromQL is literal. Keep cardinality low (no `user_id`).

---

## Clean up

```bash
./scripts/game-day-inject.sh off || git checkout -- app/main.py
# stop the Python API if you started it
```

Do not leave `GAME_DAY` code in `main.py`. Keep INC-001. Uninstall kube-prometheus-stack only if you are done with observability (`helm uninstall kps -n monitoring`). Destroy AKS if you used it.

---

## Interview story

**Situation:** ShopSphere Production had dashboards from Day 20 and Day 35, but I had never run an incident against that stack. **Task:** Game-day a 5xx on the catalog, page on error-budget burn, and mitigate before root cause. **Action:** I wrote INC-001 first, proved `/products` at 200, injected HTTP 500 on that path, and measured `error_ratio=1.00` against a 0.001 budget (about 1000× fast burn) while `/health` stayed 200. I restored `app/main.py` before I wrote RCA. I refused a CPU page as the primary alert and I refused a blind rollout undo across a schema change. **Result:** I can walk detect → evidence → mitigate → verify → RCA on the same observability the capstone already had.

---

## Self-score checklist

- [ ] INC-001 exists with mitigate before RCA.
- [ ] I saw `/products` 5xx while `/health` was 200.
- [ ] Burn math used the 99.9 percent budget.
- [ ] I did not page on CPU as the primary alert.
- [ ] Inject is off and `main.py` is clean.
- [ ] Files live in ShopSphere.

**Executed:** local inject against starter `app/main.py`: `/products` 500, `/health` 200, `error_ratio=1.00`, `fast_burn_x=1000.0`, then restore. **Not executed:** Prometheus `ALERTS` query, Grafana, kind, AKS, `kubectl rollout undo`.
