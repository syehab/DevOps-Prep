# 06 — SLO platform

**Timer:** 25 minutes.

## Prompt

ShopSphere Prod SLO is 99.9% success for `GET /catalog` over 30 days. You already have kube-prometheus-stack from Day 20 and Grafana JSON from Day 35. A Lead asks for multi-window burn-rate alerts and a dashboard in Git.

Write `docs/design/06-slo-platform.md`.

## Constraints

- SLO is a user journey, not CPU.
- Fast window + slow window. A 14.4× burn on a short window pages. A 6× burn on a long window tickets.
- Dashboards live in Git (`schemaVersion` 39 if you reuse Day 35).
- Cardinality: do not label every `order_id`.

## Capacity

What fraction of requests may fail at a 14.4× burn of a 0.1% budget? Use `burn_14_4_x_0_001`. Monthly budget minutes at 99.9%? Use `budget_99_9_30d_min`.

## Hints

1. Error budget = `43.2` minutes per 30 days at 99.9%.
2. 14.4 × 0.001 = 1.44% errors. That is the page threshold, not the SLO.
3. Day 35 already has the Grafana + burn-rate lab. This drill is the design story you tell from that lab.

## Solution

<details>
<summary>Open after the timer or after you tried the hints.</summary>

**SLO:** 99.9% of `GET /catalog` responses are 2xx over 30 days. Budget = `43.2` minutes (or the equivalent request fraction).

**Alerts:**

| Window | Burn | Meaning |
|:--|:--|:--|
| 5 m / 1 h | 14.4× | ≈ 1.44% errors now → page |
| 30 m / 6 h | 6× | slower leak → ticket |

**Path:** App emits RED metrics (`requests`, `errors`, `duration`) via OTel or Prometheus. Recording rules compute burn. Alertmanager routes. Grafana dashboard JSON is in Git. A high-cardinality label (`order_id`) is a break: 120 000 series versus 12. Day 35's `count_series.py` is the exhibit.

**Refuse:** page on CPU > 80% as a proxy for the SLO. CPU is a symptom.

**Lab cost:** **USD 0.00** on `kind`. Do not create Azure Monitor / CloudWatch as a second bill for this drill.

</details>
