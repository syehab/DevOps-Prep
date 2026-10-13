# Day 20 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 20 teaches telemetry and paging on **symptoms**. The old lab was a six-line Python server in `/tmp`. This lab installs **kube-prometheus-stack** on `kind`, scrapes the ShopSphere `/metrics` path, and adds a **multi-window SLO burn-rate** rule. Day 35 adds Grafana-as-code and cardinality control.

Work in **your ShopSphere repository** on cluster `shopsphere`.

---

## Goal

Install kube-prometheus-stack. Deploy the catalog with a `/metrics` scrape. Apply a PrometheusRule that pages on a fast 5m burn and a slow 1h burn of a 99.9 percent availability SLO. Prove a 500 on `/health` is the symptom you page, not CPU.

Time box: 75 to 90 minutes.

---

## Capstone stage

| Path | Adds |
|:--|:--|
| `observability/kube-prometheus-stack-values.yaml` | Chart values |
| `observability/rules/shopsphere-slo.yaml` | Burn-rate alerts |
| `observability/otel/collector.yaml` | Optional Collector |
| `docs/day-20-slo.md` | Recording of `up` and the rule |

---

## What you need

```bash
helm version
kubectl -n shopsphere get deploy
```

Helm 3.16+. kind cluster with the Day 14 namespace. If Helm cannot pull charts, you still write the rule YAML and a local Python scrape of `/metrics` (USD 0.00).

---

## Cost

kind + the stack: **USD 0.00** (laptop RAM; the stack is heavy — give Docker 4Gi). Do not install this on a one-node AKS lab unless you will destroy it. AKS + the stack can exceed USD 5.

---

## Steps

1. Add values. `observability/kube-prometheus-stack-values.yaml`:

```yaml
grafana:
  enabled: true
alertmanager:
  enabled: true
prometheus:
  prometheusSpec:
    serviceMonitorSelectorNilUsesHelmValues: false
```

2. Install. Pin chart version `69.8.2` if that tag exists on the Helm repo. If `helm search` does not show it, install the current `69.x` and record the version `helm list` prints.

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install kps prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  -f observability/kube-prometheus-stack-values.yaml
kubectl -n monitoring rollout status deploy/kps-grafana --timeout=180s
```

If the install fails on memory, reduce replicas in values (`prometheus.prometheusSpec.replicas: 1` is the default). Do not add a second node.

3. Expose catalog metrics. The starter API already serves `/metrics` as `shopsphere_up 1`. If you still run `nginx:1.27`, add an annotation and skip the custom metric. Prefer the Python image from Day 13 / 37.

ServiceMonitor:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: catalog
  namespace: shopsphere
  labels:
    release: kps
spec:
  selector:
    matchLabels:
      app: catalog
  endpoints:
    - port: http
      path: /metrics
      interval: 15s
```

The Service must name the port `http`. Patch Day 14 `service.yaml` if the port is unnamed.

4. Write `observability/rules/shopsphere-slo.yaml`. SLO: 99.9 percent availability. Error budget is 0.001. Multi-window burn (Google SRE workbook style):

- Fast window 5m, page if burn > 14.4 × budget
- Slow window 1h, page if burn > 6 × budget

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: shopsphere-slo
  namespace: monitoring
  labels:
    release: kps
spec:
  groups:
    - name: shopsphere.slo
      rules:
        - alert: ShopSphereErrorBudgetBurnFast
          expr: |
            (
              sum(rate(shopsphere_http_requests_total{code=~"5.."}[5m]))
              /
              clamp_min(sum(rate(shopsphere_http_requests_total[5m])), 1e-9)
            ) > (14.4 * 0.001)
          for: 2m
          labels:
            severity: page
          annotations:
            summary: Fast burn of the 99.9% availability SLO
        - alert: ShopSphereErrorBudgetBurnSlow
          expr: |
            (
              sum(rate(shopsphere_http_requests_total{code=~"5.."}[1h]))
              /
              clamp_min(sum(rate(shopsphere_http_requests_total[1h])), 1e-9)
            ) > (6 * 0.001)
          for: 15m
          labels:
            severity: page
          annotations:
            summary: Slow burn of the 99.9% availability SLO
```

The starter API does **not** yet emit `shopsphere_http_requests_total`. Add a counter in `app/main.py` (increment on each GET, label `code`) **or** change the rule to `shopsphere_up == 0` for this Day. Prefer the counter. That is the SLI.

If you cannot change the app, use:

```text
shopsphere_up == 0
```

as a stand-in and write that a real SLO uses request success ratio.

```bash
kubectl apply -f observability/rules/shopsphere-slo.yaml
kubectl -n monitoring get prometheusrules
```

5. Optional OpenTelemetry Collector. `observability/otel/collector.yaml` can wait if RAM is tight. A one-container Collector (`otel/opentelemetry-collector-contrib:0.119.0`) that receives OTLP 4317 and exports to Prometheus is enough. Do not add a vendor SaaS.

6. Local fallback (no Helm).

```bash
python3 app/main.py
curl -sS http://127.0.0.1:8080/metrics
```

Expected: `shopsphere_up 1`. Write the two burn-rate formulas in `docs/day-20-slo.md` even if Prometheus is not installed.

---

## Verify

- Chart version is recorded.
- A PrometheusRule with **two** windows exists in Git.
- You can say why CPU is not the page (symptom is user-facing errors).
- `/metrics` returns `shopsphere_up` or the request counter.

---

## Break and fix

### Failure 1 — ServiceMonitor selects nothing

`kubectl -n shopsphere get servicemonitor` exists. Prometheus targets stay empty. Diagnose labels: Service `app: catalog` versus ServiceMonitor `matchLabels`. The `release: kps` label must match the Helm release name.

### Failure 2 — page on CPU

Write an alert `node_cpu > 80`. Then delete it. Record: that is a cause. The burn-rate rules are the symptom. Day 35 will punish high-cardinality labels.

---

## Stretch

- Port-forward Grafana (`kubectl -n monitoring port-forward svc/kps-grafana 3000:80`) and screenshot the empty dashboard. Day 35 puts JSON in Git.
- Add the 6h/3d windows from the SRE workbook.

---

## Clean up

```bash
helm uninstall kps -n monitoring
kubectl delete ns monitoring
```

Keep the YAML. The stack uses a lot of RAM. Do not leave it on a paid AKS node.

---

## Interview story

**Situation:** ShopSphere had logs in a terminal and no SLO. **Task:** Page on user-facing error budget, not on CPU. **Action:** I installed kube-prometheus-stack on kind, scraped `/metrics`, and wrote two PrometheusRule alerts: a 5-minute fast burn and a 1-hour slow burn of a 99.9 percent SLO. I refused a CPU page as the primary alert. **Result:** I can draw SLI → SLO → budget → multi-window burn, and I can uninstall the stack so a laptop stays usable.

---

## Self-score checklist

- [ ] Two-window rule is in Git.
- [ ] I can explain 14.4 × 0.001.
- [ ] I did not page on CPU as the primary alert.
- [ ] I uninstalled the stack or I never installed it and I still wrote the rule.

> **Note:** Helm install of kube-prometheus-stack was **not executed in CI**.
