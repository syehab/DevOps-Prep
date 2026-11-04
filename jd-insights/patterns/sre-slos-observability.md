# SRE: SLOs + Observability + Incidents

## In one sentence

SRE titles (and most Lead roles) want you to define what "healthy" means with numbers (SLIs and SLOs), alert on it, and run calm incidents.

## What employers ask for

- SLIs and SLOs: pick user-facing measurements and set targets
- Alerts that page on user pain, not on every CPU blip
- Dashboards: metrics, logs, traces in one story
- Incident response: detect, mitigate, communicate, write the RCA
- Error budgets: the number is 100% minus the SLO. The policy is the written agreement for what happens when the budget burns out
- Operational Readiness Review (ORR): a pre-launch checklist that proves the team can SEE problems, ACT on them, and SURVIVE them. Postmortem findings become new checklist items
- Safe releases: progressive delivery with health gates and automatic rollback (Day-34 below covers this)
- Synthetic checks (scripted probes that act like a user) and runbooks for known failures
- AI services too: same SLOs and on-call, plus one extra signal, is the model's output still good? Watch quality next to latency and errors. Track token usage and model cost as metrics, not as a surprise bill
- Observability as code: dashboards and alert rules live in Terraform (provider) or Crossplane, reviewed in a PR. Keep metric-label cardinality low. Unbounded labels (user_id, request_id) explode series count, cost, and query time. Bring multi-account telemetry into one view
- Edge and Zero Trust as an SRE skill: prove the first hop (CDN, WAF, DNS, TLS) before you debug the cluster. Zero Trust verifies each request by identity, not by VPN location. Product names are Look-up
- System health and business health: latency, errors, and saturation say whether the service works. Orders, sign-ups, and payments per minute say whether users get value. Both need dashboards and alerts, and they have different owners
- OpenTelemetry for traces, metrics, and logs on AKS and Azure Container Apps. Instrument once. Export to Azure Monitor, Datadog, or both. Do not double-instrument the same signal
- Alert-noise reduction as a practice: pages that need a human stay, the rest go to dashboards or get deleted. On-call is a named primary, a handoff, and a page you can run at 3 AM. Write a blameless RCA (fix the system that allowed the mistake)
- SLO and error-budget roadmaps: start with one user-facing SLI, set an SLO, write the budget policy, then add more SLIs. Maturity is a sequence, not a slide
- Alert quality and de-duplication across Prometheus, Grafana, Datadog, and PagerDuty. One user symptom should page once. The same burn in four tools is still one incident
- Three different jobs around AKS: Microsoft Sentinel is a SIEM (security detections on logs). Dynatrace (or any APM) watches user experience. Istio is a service mesh (mTLS between Pods, traffic shifting for a canary). Do not treat them as one product

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

A roadmap is the order you grow this, not a second policy. Pick one SLI users feel. Set an SLO. Write what happens when the budget burns. Only then add more SLIs. A slide with twelve SLOs and no policy is not mature.

```text
One user SLI  →  SLO  →  written budget policy  →  then more SLIs
```

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

## One instrument, two backends

```text
App on AKS or Azure Container Apps
        ↓
OpenTelemetry (traces · metrics · logs)
        ↓
Azure Monitor    and/or    Datadog
```

Instrument once with OpenTelemetry. Export to the backend the org already runs. JDs now name Datadog next to Azure Monitor, not instead of it. On AKS you often run a Collector. On Azure Container Apps the platform holds environment logs and metrics. Your app still emits OpenTelemetry. Do not scrape the same counter twice.

A page that does not need a human is noise. Cut it. On-call is a named primary and a handoff. Write a blameless RCA: fix the system that allowed the mistake. Day-20 already has the structure.

> **Remember:** OpenTelemetry is the language. Azure Monitor and Datadog are two listeners. Speak once. Noise and blame both hide the truth.

**Look-up:** Collector exporters and Container Apps diagnostics. Do not invent a Datadog lab.

## SIEM, APM, and mesh are three jobs

```text
Istio (mesh)         → mTLS between Pods, shift a slice of traffic
Dynatrace / APM      → is the user slow or failing?
Sentinel (SIEM)      → did someone do something they should not?
```

JDs around AKS now name these three in one sentence. They do not replace each other. The mesh encrypts east-west traffic and can send 5 percent of requests to a canary (Day-34 already teaches the canary, Istio is one way to shift). The APM (Dynatrace, Datadog, Application Insights) answers whether users feel pain. The SIEM (Microsoft Sentinel) reads security logs and raises detections. Instrument the app once. Send traces to the APM. Send security events to the SIEM. Do not install three agents that scrape the same counter.

> **Remember:** Mesh moves and encrypts traffic. APM watches users. SIEM watches abuse. Name the job, then the product.

**Look-up:** Sentinel analytics rules, Dynatrace OneAgent, Istio VirtualService. Do not invent a mesh lab.

**Exit check:** A canary is failing and a privileged role was just granted. Which tool pages the SRE, and which tool pages security?

## One symptom, one page

```text
Prometheus rule  ─┐
Grafana alert    ─┤
Datadog monitor  ─┼─►  PagerDuty  →  one page, one owner
Azure Monitor    ─┘
```

JDs now name Prometheus, Grafana, Datadog, and PagerDuty in one breath. That is not four pages for one burn. Deduplicate at the pager: group by service and symptom. Keep the useful signal. Delete the extra page, not the metric. Day-20 already says symptoms page a human and causes stay on dashboards. This card adds the cross-tool rule.

> **Remember:** Four tools can watch one SLO. Only one of them should wake a human.

**Look-up:** PagerDuty event grouping. Do not invent a four-tool lab.

**Exit check:** Checkout 5xx fires in Prometheus and in Datadog. How many pages should PagerDuty send, and what do you group on?

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
8. [Day-17/01-concepts.md](../../Day-17/01-concepts.md) - AKS vs EKS, including the monitoring map
9. [Day-23/01-concepts.md](../../Day-23/01-concepts.md) - Azure Container Apps; same three signals, platform logs you do not scrape yourself

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

E-commerce SRE JDs sometimes name Java application-server operations (Tomcat, JBoss, JVM). Transfer the request path and the SLO. Look up heap and GC when a JD names them. Do not invent an app-server lab.

## Source tags

Sezzle SRE · EPAM Senior SRE · EPAM Senior SRE (Grafana + EKS) · Fundraise Up DevOps · EPAM Senior AI DevOps/SRE · Turkey / Central Asia Senior SRE (edge, CDN, Zero Trust) · 2026-10-13 market (observability as code, token cost) · 2026-10-23 market (ORR, error budget policy) · 2026-10-26 market (cardinality, health vs business) · 2026-10-27 market (incident-to-done, follow-the-sun, origin lock) · 2026-10-29 market (OpenTelemetry on AKS/ACA, Datadog + Azure Monitor, alert noise, blameless RCA) · 2026-11-02 market (Sentinel SIEM vs Dynatrace APM vs Istio mesh) · 2026-11-04 market (SLO / error-budget roadmaps, alert de-duplication, PagerDuty)
