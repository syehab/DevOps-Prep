# SRE: SLOs + Observability + Incidents

## In one sentence

SRE titles (and most Lead roles) want you to define what "healthy" means with numbers (SLIs and SLOs), alert on it, and run calm incidents.

## What employers ask for

- SLIs, SLOs, and alerts that page on user pain, not CPU
- Dashboards: metrics, logs, traces in one story. Observability as code in Git. Bounded labels only
- Incident response: detect, mitigate, communicate, RCA. Then actions with owners, tracked to done
- Error-budget policy: the written next step when the budget is gone (pause risky releases)
- ORR before launch: SEE, ACT, SURVIVE. Postmortem findings become new checklist items
- Safe releases (Day-34), including more than one production region and follow-the-sun on-call
- Synthetic checks and runbooks. AI services get the same SLOs, plus model quality and token cost
- Edge baseline: CDN or WAF in front, origin only through the CDN, Zero Trust by identity
- System health and business health both need dashboards and owners

## Mental model

```text
SLI = what you measure   ("% of requests under 500 ms that succeed")
        ↓
SLO = the target         ("99.9% over 30 days")
        ↓
Error budget = 100% minus SLO
        ↓
Budget burning fast? → page a human
Budget healthy?      → ship features
Budget gone?         → pause risky releases, shift time to reliability
                       (resume when the budget recovers)
```

Incident loop:

```text
Detect → Assess impact → Mitigate (stop the pain)
      → Find cause → Fix → RCA → Actions with owners → Done
```

Mitigate before root cause. Roll back first, understand later. A postmortem is not done when the write-up is filed. Each action has an owner, a due date, and a done state. Track those actions like any other ticket. An open action from last quarter is still an incident waiting to happen.

An ORR asks one question before launch: can this team run the service tonight? Each item needs an owner and a proof, not a slide that says "we will monitor it."

```text
SEE     → SLO-based alerts + dashboards
ACT     → a runbook per alert + a named on-call owner
SURVIVE → capacity headroom · graceful degradation
          · a tested rollback · a load test
              ↑
Postmortem findings become new checklist items
```

The error-budget policy is the written next step when the budget is gone: pause risky releases, shift time to reliability work, and resume feature work only when the budget recovers. In an interview, tell one story where that data changed a release decision.

Follow-the-sun on-call means the next region takes the pager when this one sleeps. Ship the same artifact to every production region. The handoff is a ritual with a runbook, not a chat at 3 AM. Day-34 covers the release. Day-39 covers the second region.

## The edge is the first hop

The request path starts before your load balancer. A CDN or WAF at the edge answers DNS, finishes TLS, applies rate limits, then forwards only what is allowed. Lock the origin so the public internet cannot reach it. Only the CDN talks to it. When users say the site is down, prove this hop first: does the name resolve, does TLS complete, what status does the edge return?

Zero Trust verifies each request by identity, not by VPN location. Product names (Cloudflare One, Akamai) are Look-up. Day-20 maps Azure Monitor to CloudWatch and Prometheus.

## Bounded labels only

```text
metric + labels = one series
user ID · request ID · full URL → no bound → cost and slowness
```

Use only bounded labels (status code, method, region, short path). Put high-cardinality detail in logs and traces. Day-20 states the rule. Day-35 makes you count the series.

> **Remember:** Bounded labels stay on metrics. User IDs, request IDs, and full URLs belong in logs and traces.

**Exit check:** Why does a `user_id` label explode cost, and where do you put that ID instead?

## System health is not business health

```text
System: latency, errors, saturation → does the service work?
Business: orders, sign-ups, payments/min → do users get value?
```

A healthy cluster with zero payments is still an incident. Day-20 shows this: CPU is fine, orders created equals zero. Page the people who own that number.

> **Remember:** A business dip with healthy systems is still an incident. Check it.

**Exit check:** Pods are healthy and p95 is fine, but payments per minute dropped to zero. Is that an incident, and who do you page?

## Remember

> **Alert on symptoms users feel (errors, latency), not on causes (CPU). Causes are for dashboards, symptoms are for pages.**

> **An ORR proves you can see, act, and survive before launch. The error-budget policy is the written next step when the budget is gone. A postmortem is not done until its actions are done.**

## Study these days first

1. [Day-20/01-concepts.md](../../Day-20/01-concepts.md) - the core lesson, read this first
2. [Day-08/01-concepts.md](../../Day-08/01-concepts.md) - IaC is how dashboards and alerts become reviewable
3. [Day-03/01-concepts.md](../../Day-03/01-concepts.md) - the request path; the edge is the first hop
4. [Day-18/01-concepts.md](../../Day-18/01-concepts.md) - verify the caller by identity, not by network location
5. [Day-35/01-concepts.md](../../Day-35/01-concepts.md) - hands-on project, including high-cardinality cost
6. [Day-34/01-concepts.md](../../Day-34/01-concepts.md) - safe deployments, canary with health signals, rollback
7. [Day-41/01-concepts.md](../../Day-41/01-concepts.md) - full incident simulation

## Common interview question

**Q: Walk an ORR for a new checkout API. Then say what you do when the error budget burns out.**

Outline:
1. SEE: SLO-based alerts and one dashboard that shows user pain. Pick SLIs users feel (success rate, p95).
2. ACT: a runbook per alert and a named on-call owner. Follow-the-sun if you run more than one region.
3. SURVIVE: capacity headroom, graceful degradation, a tested rollback, a load test.
4. Policy: pause risky releases, shift time to reliability work, resume when the budget recovers.
5. After the first incident: actions have owners and a done state. The next ORR includes the miss.

## Honest gap note

Sezzle-style JDs name Prometheus or Datadog daily use, sometimes Golang. If your base is Azure Monitor, map the concepts (metrics, queries, alert rules are the same shape) and say which tools you have used hands-on. Concepts transfer, invented tool years do not.

## Source tags

Sezzle SRE · EPAM Senior SRE · EPAM Senior SRE (Grafana + EKS) · Fundraise Up DevOps · EPAM Senior AI DevOps/SRE · Turkey / Central Asia Senior SRE (edge, CDN, Zero Trust) · 2026-10-13 market (observability as code, token cost) · 2026-10-23 market (ORR, error budget policy) · 2026-10-26 market (cardinality, health vs business) · 2026-10-27 market (incident-to-done, follow-the-sun, origin lock)
