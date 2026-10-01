# SRE: SLOs + Observability + Incidents

## In one sentence

SRE titles (and most Lead roles) want you to define what "healthy" means with numbers (SLIs and SLOs), alert on it, and run calm incidents.

## What employers ask for

- SLIs and SLOs: pick user-facing measurements and set targets
- Alerts that page on user pain, not on every CPU blip
- Dashboards: metrics, logs, traces in one story
- Incident response: detect, mitigate, communicate, write the RCA
- Error budgets: use the data to decide features vs reliability work

## Mental model

```text
SLI = what you measure
      ("% of requests under 500 ms that succeed")
        ↓
SLO = the target
      ("99.9% over 30 days")
        ↓
Error budget = 100% minus SLO
      (the failure you are allowed)
        ↓
Budget burning fast? → page a human
Budget healthy?      → ship features
```

Incident loop:

```text
Detect → Assess impact → Mitigate (stop the pain)
      → Find cause → Fix → RCA → Prevent repeat
```

Mitigate before root cause. Roll back first, understand later.

| Concept | Azure | AWS / open source |
|:--|:--|:--|
| Metrics + alerts | Azure Monitor | CloudWatch / Prometheus |
| Dashboards | Azure Monitor / Grafana | Grafana / Datadog |
| Logs | Log Analytics | CloudWatch Logs / Loki |

## Remember

> **Alert on symptoms users feel (errors, latency), not on causes (CPU). Causes are for dashboards, symptoms are for pages.**

## Study these days first

1. [Day-20-L20-Observability-Production-Incident.md](../../Day-20-L20-Observability-Production-Incident.md) - the core lesson, read this first
2. [Day-35-Production-Project-05-Observability-Incident-Response-Clean-Style.md](../../Day-35-Production-Project-05-Observability-Incident-Response-Clean-Style.md) - hands-on project
3. [Day-34-Production-Project-04-Reliability-Safe-Deployments-Failure-Containment.md](../../Day-34-Production-Project-04-Reliability-Safe-Deployments-Failure-Containment.md) - reliability by design
4. [Day-41-Production-Simulation-01-Production-Deployment-Incident-Clean-Style.md](../../Day-41-Production-Simulation-01-Production-Deployment-Incident-Clean-Style.md) - full incident simulation

## Common interview question

**Q: How would you define an SLO for a checkout API?**

Outline:
1. Pick SLIs users feel: success rate and p95 latency.
2. Set a target from real data, not a wish (say 99.9% success over 30 days).
3. Alert on fast error-budget burn, not single failures.
4. Review the SLO with the product team; it is a shared contract.

## Honest gap note

Sezzle-style JDs name Prometheus or Datadog daily use, sometimes Golang. If your base is Azure Monitor, map the concepts (metrics, queries, alert rules are the same shape) and say which tools you have used hands-on. Concepts transfer, invented tool years do not.

## Source tags

Sezzle SRE · EPAM Senior SRE · Fundraise Up DevOps
