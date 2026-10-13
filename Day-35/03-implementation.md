# Day 35 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 35 is the **harder sibling of Day 20**. Day 20 installed kube-prometheus-stack and a two-window burn-rate rule. This Day puts a **Grafana dashboard in Git**, proves a **high-cardinality** label is a cost and reliability bug, and keeps the SLO math in the ShopSphere repo. You do not start again in `/tmp`.

Work in **your ShopSphere repository** on cluster `shopsphere` if it still has the monitoring namespace. If Helm is gone, the JSON and the cardinality script still complete the Day.

---

## Goal

Commit a Grafana dashboard JSON that answers four questions: is the catalog up, what is the success ratio, what is p95 latency, and is the error budget burning. Then add a `user_id` label on purpose, count the series, and remove that label. When you finish, you can say why a dashboard that lives only in the Grafana UI is not observability as code.

Time box: 60 to 90 minutes.

---

## Capstone stage

| Path in ShopSphere | What it adds beyond Day 20 |
|:--|:--|
| `observability/grafana/shopsphere-catalog.json` | Dashboard as code |
| `observability/grafana/dashboard-cm.yaml` | ConfigMap the sidecar can load |
| `observability/cardinality/count_series.py` | Local proof that `user_id` explodes series |
| `docs/day-35-obs.md` | Series count, SLO score, dashboard uid |

---

## What you need

```bash
python3 --version
curl --version
command -v kubectl
command -v helm
```

Python 3.12 is enough for the cardinality script and the catalog API. Grafana and Prometheus are optional if Day 20's stack is still installed. If `kubectl -n monitoring get deploy` fails, stay on the local path. Do not create AKS to host Grafana.

---

## Cost

| Path | Estimated USD |
|:--|:--|
| Local Python + dashboard JSON | **0.00** |
| Grafana on kind (Day 20 stack still up) | **0.00** (laptop RAM) |
| Managed Grafana / Azure Monitor workspace | **Do not create** today |

Do not write "cost stays at INR 0" if you open a paid workspace.

---

## Steps

1. Open ShopSphere. Create the folders.

```bash
mkdir -p observability/grafana observability/cardinality docs
```

2. Write the dashboard. Put this in `observability/grafana/shopsphere-catalog.json`. `schemaVersion` 39 is a real Grafana 10/11 schema. The uid must stay stable so Git updates replace the same dashboard.

```json
{
  "uid": "shopsphere-catalog",
  "title": "ShopSphere catalog",
  "schemaVersion": 39,
  "version": 1,
  "timezone": "browser",
  "refresh": "30s",
  "time": { "from": "now-1h", "to": "now" },
  "templating": { "list": [] },
  "annotations": { "list": [] },
  "panels": [
    {
      "id": 1,
      "type": "stat",
      "title": "shopsphere_up",
      "gridPos": { "h": 4, "w": 6, "x": 0, "y": 0 },
      "targets": [
        { "expr": "shopsphere_up", "refId": "A" }
      ]
    },
    {
      "id": 2,
      "type": "timeseries",
      "title": "Success ratio",
      "gridPos": { "h": 8, "w": 12, "x": 6, "y": 0 },
      "targets": [
        {
          "expr": "sum(rate(shopsphere_http_requests_total{code!~\"5..\"}[5m])) / clamp_min(sum(rate(shopsphere_http_requests_total[5m])), 1e-9)",
          "refId": "A",
          "legendFormat": "success"
        }
      ]
    },
    {
      "id": 3,
      "type": "timeseries",
      "title": "p95 latency (if histogram exists)",
      "gridPos": { "h": 8, "w": 12, "x": 0, "y": 8 },
      "targets": [
        {
          "expr": "histogram_quantile(0.95, sum(rate(shopsphere_http_request_duration_seconds_bucket[5m])) by (le))",
          "refId": "A"
        }
      ]
    },
    {
      "id": 4,
      "type": "stat",
      "title": "Fast burn vs 99.9% budget",
      "gridPos": { "h": 4, "w": 6, "x": 12, "y": 8 },
      "targets": [
        {
          "expr": "(sum(rate(shopsphere_http_requests_total{code=~\"5..\"}[5m])) / clamp_min(sum(rate(shopsphere_http_requests_total[5m])), 1e-9)) / 0.001",
          "refId": "A"
        }
      ]
    }
  ]
}
```

Validate the file:

```bash
python3 -c "import json; json.load(open('observability/grafana/shopsphere-catalog.json')); print('dashboard json ok')"
```

Expected: `dashboard json ok`.

3. Wrap it in a ConfigMap so the Grafana sidecar can load it. Label `grafana_dashboard: "1"` is the label kube-prometheus-stack uses when sidecar is on.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: shopsphere-catalog-dash
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  shopsphere-catalog.json: |
```

Paste the JSON under that key, or mount the file. If the stack is up:

```bash
kubectl -n monitoring create configmap shopsphere-catalog-dash \
  --from-file=shopsphere-catalog.json=observability/grafana/shopsphere-catalog.json \
  --dry-run=client -o yaml | kubectl label --local -f - grafana_dashboard=1 -o yaml | kubectl apply -f -
```

If monitoring is missing, keep the JSON. Write `grafana apply skipped` in the notes.

4. Prove high cardinality locally. Write `observability/cardinality/count_series.py`.

```python
"""Count Prometheus series if you label by user_id versus by code only."""

from __future__ import annotations


def series_count(users: int, codes: int, paths: int, extra_label: bool) -> int:
    if extra_label:
        return users * codes * paths
    return codes * paths


def main() -> None:
    users = 10_000
    codes = 3
    paths = 4
    with_user = series_count(users, codes, paths, True)
    without_user = series_count(users, codes, paths, False)
    print("with user_id=%d" % with_user)
    print("code+path only=%d" % without_user)
    assert with_user == 120_000
    assert without_user == 12
    print("cardinality check ok")


if __name__ == "__main__":
    main()
```

```bash
python3 observability/cardinality/count_series.py
```

Expected:

```text
with user_id=120000
code+path only=12
cardinality check ok
```

Write in `docs/day-35-obs.md`: a `user_id` label on a RED metric is how a demo cluster runs out of memory. Put user identity in logs or traces, not on the request counter.

5. If Prometheus is up, apply a recording rule that **forbids** the bad label in the SLO. Keep Day 20's burn-rate rule. Add a comment in that file: `do not add user_id`.

6. SLO math on the catalog API. Start the ShopSphere API if it is not running.

```bash
python3 app/main.py &
echo $! > /tmp/shopsphere-api.pid
sleep 1
ok=0
n=100
for i in $(seq 1 "$n"); do
  code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8080/health)
  if [ "$code" = "200" ]; then ok=$((ok + 1)); fi
done
python3 -c "print('availability=%.2f' % ($ok / $n))"
kill "$(cat /tmp/shopsphere-api.pid)"
```

Expected: `availability=1.00` on `/health`. If you add a failing `/order` as in the old Day 35 script, score that path against a 99% SLO. The mental model is the same: successes / requests.

---

## Verify

- `shopsphere-catalog.json` loads with Python `json.load` and has uid `shopsphere-catalog`.
- Four panels exist: up, success ratio, p95, burn.
- `count_series.py` printed `120000` versus `12`.
- Notes say dashboards live in Git, not only in the Grafana UI.
- You did not add `user_id` to the PrometheusRule.

---

## Break and fix

### Failure 1 — high-cardinality label

Change `count_series.py` so `extra_label` is always True in the "without" path. The assert fails. Restore the function. That fail is the interview: you can compute series before you ship the metric.

### Failure 2 — dashboard only in the UI

Export a dashboard from Grafana (or imagine you clicked Save). If the uid is empty, the next import creates a **second** dashboard. Set `"uid": "shopsphere-catalog"` and commit. Diagnose with `jq .uid observability/grafana/shopsphere-catalog.json`.

---

## Stretch

- Add a Grafana folder provision file (`apiVersion: 1`, `providers:`).
- Add `histogram_quantile` only after the app emits a histogram. A broken panel is worse than a missing panel.

---

## Clean up

Stop the Python API if you started it. Keep the JSON and the script. If you created a ConfigMap in `monitoring`, you may leave it. Uninstall kube-prometheus-stack only when you are done with observability week (`helm uninstall kps -n monitoring`).

---

## Interview story

**Situation:** Day 20 gave ShopSphere burn-rate alerts, but the dashboard still lived in a browser session and a teammate wanted `user_id` on the RED metric. **Task:** Put the dashboard in Git and prove the label would create 120,000 series. **Action:** I committed `shopsphere-catalog.json` with a stable uid and four panels. I ran `count_series.py` (10,000 users × 3 codes × 4 paths) and kept `user_id` on logs. I scored `/health` at 100/100 so the SLI math stayed visible without Prometheus. **Result:** I can say observability as code means alerts and dashboards review like Terraform, and high cardinality is a design choice, not a surprise invoice.

---

## Self-score checklist

- [ ] Dashboard JSON validates and has a uid.
- [ ] I can name the four panels without opening Grafana.
- [ ] Cardinality script printed 120000 vs 12.
- [ ] I broke the script assert and I restored it.
- [ ] Files live in ShopSphere, not only under `/tmp`.

**Executed in the authoring VM:** `json.load` of this dashboard shape, `count_series.py` asserts. **Not executed:** Grafana UI import, ConfigMap sidecar reload, live Prometheus queries.
