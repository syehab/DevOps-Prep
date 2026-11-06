# Day 35 — Questions and answers

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Then answer each item below before you open the Answer block. After that, do the lab in [03-implementation.md](03-implementation.md).

Write your own answer first. Open the Answer block only after you try. Keep the original numbering.

---

## 1. What question does each telemetry signal answer: metrics, logs, traces?

Answer these without looking at the lesson. If you cannot answer one, reread only that part, then try again.

What question does each telemetry signal answer: metrics, logs, traces?

<details>
<summary>Answer</summary>

Metrics answer what is happening (rate, errors, latency). Logs answer what happened (events and context). Traces answer where this request went.

Together: 5xx rose → log shows `DatabaseTimeout` → trace shows checkout waited on the DB.

</details>

---

## 2. What are the four golden signals?

What are the four golden signals?

<details>
<summary>Answer</summary>

Latency, traffic, errors, saturation. For ShopSphere: requests/minute, p50/p95/p99, HTTP 5xx, and CPU/memory/DB connections/thread pools.

Do not use averages alone.

</details>

---

## 3. Why can an acceptable average latency hide a real problem, and which percentiles do you watch instead?

Why can an acceptable average latency hide a real problem, and which percentiles do you watch instead?

<details>
<summary>Answer</summary>

Average 200 ms can hide p99 at 4 seconds. A slice of users is already failing the SLO.

Watch p50, p95, and p99. Set targets from this service, not a copied number.

</details>

---

## 4. Why should an incident investigation start from user impact rather than CPU graphs?

Why should an incident investigation start from user impact rather than CPU graphs?

<details>
<summary>Answer</summary>

The symptom is “customers cannot place orders,” not “CPU looks interesting.” Map the failing action: login, browse, order, payment.

Then follow that path. CPU-first work often repairs a healthy box.

</details>

---

## 5. What is the difference between an SLI, an SLO, and an SLA?

What is the difference between an SLI, an SLO, and an SLA?

<details>
<summary>Answer</summary>

SLI is the measurement (successful checkouts / total checkouts). SLO is the target (99.9% successful). SLA is the formal commitment with consequences.

Do not use the three words as synonyms.

</details>

---

## 6. What operational decision does an error budget support?

What operational decision does an error budget support?

<details>
<summary>Answer</summary>

Some failure is allowed under the SLO. If the budget burns fast, slow risky releases and do reliability work.

Reliability and delivery speed are one trade-off, not two separate teams.

</details>

---

## 7. What makes an alert actionable, and what has happened operationally when engineers start ignoring alerts?

What makes an alert actionable, and what has happened operationally when engineers start ignoring alerts?

<details>
<summary>Answer</summary>

Good alerts are actionable, relevant, understandable, and tied to impact. `CPU > 70%` with no user harm is noise.

If people ignore alerts, the monitoring system has failed operationally. Prefer checkout error rate or no successful orders.

</details>

---

## 8. What problem does a correlation ID solve, and what does distributed tracing add on top of it?

What problem does a correlation ID solve, and what does distributed tracing add on top of it?

<details>
<summary>Answer</summary>

A request ID joins logs for one call across frontend, API, DB, and payment. Tracing adds spans and timings so you see which hop ate 2.7 of 3.0 seconds.

OpenTelemetry is the common instrumentation model. One user request should be traceable.

</details>

---

## 9. Why is a 99.9% HTTP success rate not proof that the business is healthy?

Why is a 99.9% HTTP success rate not proof that the business is healthy?

<details>
<summary>Answer</summary>

HTTP 200 can still mean orders created at 70%. Watch orders/minute, payment success, checkout completion, cart failures, and login success.

Healthy servers are not healthy checkout.

</details>

---

## 10. During an active incident, what comes first: full root-cause analysis or service recovery? Why?

During an active incident, what comes first: full root-cause analysis or service recovery? Why?

<details>
<summary>Answer</summary>

Restore service and limit impact first. Do not spend 45 minutes on perfect root cause while checkout is down.

RCA continues after users can order again.

</details>

---

## 11. Deployment at 14:00, errors at 14:03 — what does that correlation give you, and what does it not give you?

Deployment at 14:00, errors at 14:03 — what does that correlation give you, and what does it not give you?

<details>
<summary>Answer</summary>

Strong reason to inspect that release. It does not prove the exact bug.

Still read the diff, logs, traces, error types, endpoints, config, and schema. Correlation points; evidence convicts.

</details>

---

## 12. Besides the root cause, what should an RCA contain?

Besides the root cause, what should an RCA contain?

<details>
<summary>Answer</summary>

Impact, start/end, detection path, contributing factors, recovery action, and gaps in detection, process, and recovery. Then corrective and preventive actions.

It is not a blame document.

</details>

---

## 13. Why is high-cardinality telemetry (such as `user_id` as a metric label) a problem?

Why is high-cardinality telemetry (such as `user_id` as a metric label) a problem?

<details>
<summary>Answer</summary>

Using `user_id`, `order_id`, or `request_id` as a metric label explodes series count and cost. Keep those fields in logs and traces.

Ask what you need, how long, who uses it, and what to sample.

</details>

---

## 14. Incident drill: high 5xx rate — decide

At 11:00 AM, ShopSphere starts returning 5xx responses.

Metrics:

```text
Traffic:
Normal

5xx:
Increasing

CPU:
Normal

Memory:
Normal
```

Start with:

```text
Which endpoints?
Which version?
Which instances?
Which dependency?
```

Logs show:

```text
PaymentClient timeout
```

Traces show:

```text
API:
2.8 sec

Database:
120 ms

Payment:
2.5 sec
```

The evidence points toward the payment dependency rather than CPU, memory, or database saturation.

Now decide:

```text
Wait?
Retry?
Circuit-break?
Reduce traffic?
Disable payment-dependent functionality?
Rollback?
```

The correct action depends on the architecture and business requirements.

The lesson is the investigation process, not one universal response.

<details>
<summary>Answer</summary>

Traffic, CPU, and memory are normal. Logs show `PaymentClient timeout`. Trace: API 2.8s, DB 120 ms, payment 2.5s. The payment dependency is the suspect, not saturation.

Then choose wait, bounded retry, circuit-break, shed load, disable payment flow, or rollback from architecture and business rules.

</details>

---

## 15. Incident drill: latency increase — decide

Suppose:

```text
p50:
normal

p95:
increasing

p99:
very high
```

CPU is normal.

Database CPU is normal.

Traces show:

```text
Database:
normal

External API:
slow
```

The average latency may still appear acceptable.

This is why percentiles and traces matter.

Investigate the external dependency before scaling application compute.

Scaling the application may do nothing if the bottleneck is outside the application.

<details>
<summary>Answer</summary>

p50 normal, p95 up, p99 very high. CPU and DB CPU normal. Trace shows a slow external API.

Do not scale app compute. Investigate that dependency. Percentiles and traces beat the average.

</details>

---

## 16. Incident drill: no orders — decide

Suppose:

```text
HTTP success rate:
99.9%

Orders created:
0
```

Infrastructure dashboards look normal.

The application may still be broken.

Trace:

```text
Checkout
 ↓
Order API
 ↓
Order Creation
 ↓
Payment
 ↓
Order Confirmation
```

Logs show:

```text
Order confirmation failed
```

This is a business-logic or dependency problem rather than an infrastructure outage.

This is why business observability matters.

<details>
<summary>Answer</summary>

HTTP success 99.9% and orders created 0. Infrastructure looks fine. Walk checkout → order API → create → payment → confirmation.

Logs such as `Order confirmation failed` are a business or dependency failure. This is why business metrics exist.

</details>

---

## 17. Incident drill: deployment correlation — decide

Suppose:

```text
14:00:
v2 deployed

14:03:
Error rate increases

14:05:
Latency increases

14:07:
Rollback

14:10:
Metrics return to normal
```

This is strong evidence that the deployment is related to the incident.

It does not automatically prove the exact root cause.

You still need application evidence.

Look at:

```text
Release diff
Logs
Traces
Error types
Affected endpoints
Configuration changes
Database changes
```

The Senior/Lead principle is:

**Correlation tells you where to investigate; evidence establishes the cause.**

<details>
<summary>Answer</summary>

v2 at 14:00, errors at 14:03, rollback at 14:07, metrics normal at 14:10. Treat the release as the investigation start, then prove the cause with logs and traces.

Rollback recovered users. RCA still names the defect.

</details>

---

## 18. Incident drill: database saturation — decide

Suppose:

```text
Application:
healthy

Database connections:
near maximum

Latency:
increasing

5xx:
increasing
```

Now the database becomes a strong candidate for the bottleneck.

Investigate:

```text
Connection pool
 ↓
Slow queries
 ↓
Locks
 ↓
Database CPU
 ↓
Database memory
 ↓
Connection limit
```

Do not immediately increase the database size.

First determine what is consuming the capacity.

A connection leak, inefficient query, or sudden traffic increase may require a different fix.

<details>
<summary>Answer</summary>

App “healthy,” connections near max, latency and 5xx up. Walk pool → slow queries → locks → DB CPU/memory → connection limit.

Do not resize first. A leak, a bad query, or a traffic spike need different fixes.

</details>

---

## 19. Five Whys example (checkout / payment timeout)

For a simple incident, use Five Whys.

Example:

```text
Why did checkout fail?
→ Payment requests timed out.

Why did payment requests time out?
→ Payment service became slow.

Why did the application keep waiting?
→ Timeout was too high.

Why was the timeout too high?
→ It was never defined from a service-level requirement.

Why was it never defined?
→ Dependency behavior was not included in the service design review.
```

The final answer may reveal a design or process gap rather than merely “the payment service was slow.”

Do not force Five Whys onto every complex incident.

Use it when it helps uncover contributing causes.

<details>
<summary>Answer</summary>

Checkout failed because payment timed out. Payment was slow. The app waited because the timeout was too high. The timeout was never set from an SLO. Dependency behavior missed the design review.

The last why is often a process gap, not “payment was slow.”

</details>

---

## 20. Corrective vs preventive actions

Separate actions into:

```text
Immediate Fix
Permanent Fix
Prevention
Detection Improvement
Recovery Improvement
```

For example:

```text
Immediate:
Restart / rollback

Permanent:
Fix dependency timeout handling

Prevention:
Add integration test

Detection:
Add dependency latency alert

Recovery:
Document failover procedure
```

This prevents the RCA from ending with:

```text
Restarted application.
```

A restart may restore service while leaving the underlying failure untouched.

<details>
<summary>Answer</summary>

Immediate: rollback or restore the path. Permanent: fix timeout handling. Prevention: integration test. Detection: dependency latency alert. Recovery: document failover.

“Restarted the app” is not an RCA close.

</details>

---

## 21. Hands-on observability (expected outcome)

Instrument ShopSphere so that you can observe:

```text
Request rate
Error rate
Latency
Application health
Database health
Deployment version
```

Add structured application logging.

Add request/correlation IDs.

If practical, add distributed tracing using OpenTelemetry or an equivalent instrumentation approach.

Create a dashboard.

Create at least two actionable alerts.

Then deploy a controlled application change and observe:

```text
Before deployment
During deployment
After deployment
```

The objective is to establish a baseline before introducing failures.

<details>
<summary>Answer</summary>

Instrument request rate, errors, latency, app and DB health, and deploy version. Add structured logs and correlation IDs. Add tracing if practical.

Dashboard plus two actionable alerts. Observe before, during, and after a controlled change.

</details>

---

## 22. Production incident lab (expected outcome)

Run three controlled incidents.

### Incident 1 — Application Error

Introduce a controlled application defect.

Investigate:

```text
Metrics
 ↓
Logs
 ↓
Trace
 ↓
Deployment
```

Recover.

### Incident 2 — Dependency Latency

Simulate or introduce a slow dependency.

Investigate:

```text
Latency percentile
 ↓
Trace
 ↓
Dependency
```

Recover.

### Incident 3 — Database Saturation

Create a safe test condition that increases database load or connection pressure.

Investigate:

```text
Application latency
 ↓
DB connections
 ↓
Database metrics
 ↓
Queries / locks
```

Recover.

Do not create destructive Production incidents.

Use a controlled environment for experiments.

<details>
<summary>Answer</summary>

Incident 1: app defect → metrics → logs → trace → deploy → recover. Incident 2: slow dependency → percentiles → trace → recover. Incident 3: DB pressure → connections/queries/locks → recover.

Use a controlled environment. Do not destroy Production.

</details>

---

## 23. Incident command exercise

For one incident, simulate a small incident-response team.

Roles:

```text
Incident Commander
Technical Lead
Communications
Scribe
```

The Incident Commander coordinates rather than personally executing every technical task.

The Technical Lead investigates the system.

The Communications role keeps stakeholders informed.

The Scribe records the timeline and decisions.

Even if you are alone, practice thinking in these roles.

This is useful preparation for Lead-level operational work.

<details>
<summary>Answer</summary>

Incident Commander coordinates. Technical Lead investigates. Communications updates stakeholders. Scribe records timeline and decisions.

Even alone, think in those roles. The commander does not run every command.

</details>

---

## 24. Senior/Lead observability review

Review ShopSphere with these questions:

```text
Can I detect user-impacting failures?

Can I identify which version is running?

Can I correlate a request across components?

Can I identify the slow dependency?

Can I distinguish infrastructure failure from application failure?

Can I distinguish application failure from business-process failure?

Can I determine when the problem started?

Can I identify what changed?

Can I estimate blast radius?

Can I recover?

Can I explain why recovery worked?

Can I prevent recurrence?

Can I control telemetry cost?

Can I prevent secrets from appearing in telemetry?
```

If the answer is “no,” identify the missing observability capability.

<details>
<summary>Answer</summary>

You must detect user impact, name the running version, and correlate a request. You must find the slow hop and split infra vs app vs business failure. You must mark start time, what changed, blast radius, recovery, prevention, cost, and secret-free telemetry.

Each “no” is a missing capability.

</details>

---

## 25. Dashboard and incident timeline (expected outcome)

Create a ShopSphere Production dashboard with a small number of useful panels.

Start with:

```text
Request Rate
Error Rate
p95 Latency
Application Health
CPU
Memory
Database Connections
Database Health
```

Then add business signals:

```text
Orders/minute
Payment Success Rate
Checkout Success Rate
```

Finally add deployment information:

```text
Current Version
Deployment Time
Image Digest
```

The dashboard should answer:

**Is the system healthy right now?**

and:

**Did something change recently?**

During an incident, create a timeline.

For example:

```text
10:00
Deployment starts

10:03
Deployment completes

10:05
5xx begins increasing

10:07
Alert fires

10:10
Incident declared

10:13
Root cause identified

10:17
Rollback begins

10:20
Error rate returns to normal
```

This timeline helps correlate changes with symptoms.

It also becomes valuable during the later RCA.

Do not rely on memory.

Record evidence as the incident progresses.

<details>
<summary>Answer</summary>

Dashboard: rate, errors, p95, health, CPU, memory, DB, orders/minute, payment success, current version, digest, deploy time.

Timeline example: deploy 10:00, 5xx 10:05, alert 10:07, rollback 10:17, normal 10:20. Write it down. Do not rely on memory.

</details>

---

## 26. Observability security and cost

Telemetry can contain sensitive information.

Review:

```text
Logs
Metrics labels
Trace attributes
Dashboards
Alert messages
Incident documents
```

Avoid exposing:

```text
Passwords
Access tokens
Private keys
Session secrets
Unnecessary personal data
```

Also control who can access Production telemetry.

Observability is part of the security boundary.

Observability has a cost.

Large log volumes, long retention periods, high-cardinality metrics, and excessive trace sampling can become expensive.

Ask:

```text
What do we need?
How long do we need it?
Who needs it?
At what resolution?
What should be sampled?
```

Do not retain every debug log forever.

Do not create a metric label containing an unbounded identifier such as:

```text
request_id
user_id
order_id
```

as a metric dimension.

High-cardinality telemetry can create operational and cost problems.

Use logs and traces for high-cardinality investigation data where appropriate.

<details>
<summary>Answer</summary>

Logs, labels, traces, dashboards, alerts, and RCA docs must not hold passwords, tokens, keys, or extra personal data. Restrict who reads Prod telemetry.

Do not keep every debug log forever. Sample traces. Keep high-cardinality IDs out of metric labels.

</details>

---

## Day 35 Completion Criteria

Complete Day 35 when you can demonstrate:

```text
[ ] Metrics understood
[ ] Logs understood
[ ] Traces understood
[ ] Four golden signals understood
[ ] Percentiles understood
[ ] Structured logging implemented
[ ] Correlation IDs implemented
[ ] Distributed tracing model understood
[ ] Application health separated from infrastructure health
[ ] Business observability understood
[ ] SLI/SLO/SLA distinction understood
[ ] Error budget concept understood
[ ] Actionable alerts created
[ ] Production dashboard created
[ ] Incident timeline practiced
[ ] Incident severity considered from impact
[ ] Incident response process documented
[ ] 5xx incident drill completed
[ ] Latency incident drill completed
[ ] Business failure drill completed
[ ] Database saturation drill completed
[ ] RCA written
[ ] Five Whys practiced
[ ] Corrective/preventive actions documented
[ ] Telemetry security reviewed
[ ] Observability cost reviewed
[ ] Incident command exercise completed
```

The most important completion criterion is:

**When a Production symptom appears, you can use telemetry to move from user impact → affected component → evidence → root cause → safe recovery → prevention.**
