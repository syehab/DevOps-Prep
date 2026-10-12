# SRE: SLOs + Observability + Incidents

## In one sentence

SRE titles (and most Lead roles) want you to define what "healthy" means with numbers (SLIs and SLOs), alert on it, and run calm incidents.

## What employers ask for

- SLIs and SLOs: pick user-facing measurements and set targets
- Alerts that page on user pain, not on every CPU blip
- Dashboards: metrics, logs, traces in one story
- Incident response: detect, mitigate, communicate, write the RCA
- Error budgets: use the data to decide features vs reliability work
- Safe releases: progressive delivery with health gates and automatic rollback (Day-34 below covers this)
- Synthetic checks (scripted probes that act like a user) and runbooks for known failures
- AI services too: same SLOs and on-call, plus one extra signal, is the model's output still good? Watch quality next to latency and errors
- Edge and Zero Trust as an SRE skill: prove the first hop (CDN, WAF, DNS, TLS) before you debug the cluster. Zero Trust verifies each request by identity, not by VPN location. Product names are Look-up

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

## The edge is the first hop

The request path starts before your load balancer. A CDN or WAF at the edge answers DNS, finishes the TLS handshake, applies rate limits and bot rules, then forwards only what is allowed. When users say the site is down, prove this hop first: does the name resolve, does TLS complete, what status does the edge return? Then walk inward.

Zero Trust means verify every request by identity, not by network location. A VPN trusts anyone who joined the network. ZTNA checks who the caller is on each request, whether they sit in the office or at home. Product suites (Cloudflare One: Access, Tunnel, WARP, Secure Web Gateway; Akamai CDN, WAF, Edge DNS) are Look-up items. Know the idea. Look up the product when a JD names it.

| Concept | Azure | AWS / open source |
|:--|:--|:--|
| Metrics + alerts | Azure Monitor | CloudWatch / Prometheus |
| Dashboards | Azure Monitor / Grafana | Grafana / Datadog |
| Logs | Log Analytics | CloudWatch Logs / Loki |
| Traces | Application Insights | Tempo / OpenTelemetry |

## Remember

> **Alert on symptoms users feel (errors, latency), not on causes (CPU). Causes are for dashboards, symptoms are for pages.**

## Study these days first

1. [Day-20-L20-Observability-Production-Incident.md](../../Day-20-L20-Observability-Production-Incident.md) - the core lesson, read this first
2. [Day-3-L03-Networking-Fundamentals.md](../../Day-3-L03-Networking-Fundamentals.md) - the request path; the edge is the first hop
3. [Day-18-L18-Identity-Secrets-Cloud-Security-v2.md](../../Day-18-L18-Identity-Secrets-Cloud-Security-v2.md) - verify the caller by identity, not by network location
4. [Day-35-Production-Project-05-Observability-Incident-Response-Clean-Style.md](../../Day-35-Production-Project-05-Observability-Incident-Response-Clean-Style.md) - hands-on project
5. [Day-34-Production-Project-04-Reliability-Safe-Deployments-Failure-Containment.md](../../Day-34-Production-Project-04-Reliability-Safe-Deployments-Failure-Containment.md) - safe deployments, canary with health signals, rollback
6. [Day-41-Production-Simulation-01-Production-Deployment-Incident-Clean-Style.md](../../Day-41-Production-Simulation-01-Production-Deployment-Incident-Clean-Style.md) - full incident simulation

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

Sezzle SRE · EPAM Senior SRE · EPAM Senior SRE (Grafana + EKS) · Fundraise Up DevOps · EPAM Senior AI DevOps/SRE · Turkey / CA Senior SRE (edge, CDN, Zero Trust)
