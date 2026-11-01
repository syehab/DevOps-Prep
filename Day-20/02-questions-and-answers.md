# Day 20 — Questions and answers

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Then answer each item below before you open the Answer block. After that, do the lab in [03-implementation.md](03-implementation.md).

Write your own answer first. Open the Answer block only after you try. Keep the original numbering.

---

## 1. What you need to know if requests jump from 500 ms to 10 s

Practice: Take your Spring Boot application and list what you would need to know if users suddenly reported that requests were taking 10 seconds instead of 500 milliseconds.

<details>
<summary>Answer</summary>

You need request rate, error rate, and latency percentiles, not only “Pods are Running.” You need which endpoint and which dependency. You need where time is spent: app, database, or external API. You also need whether a deploy happened, whether saturation rose, and one trace for a slow request.

Metrics show what is happening. Logs show the error. Traces show which span ate the time. Monitoring says something is wrong. Observability helps you understand why.

</details>

---

## 2. Average 300 ms, p95 900 ms, p99 8 s — do not call it “300 ms fast”

Practice: Suppose an application reports:

```text
Average latency: 300 ms
p95 latency:     900 ms
p99 latency:     8 s
```

Do not conclude that the application is simply “300 ms fast.” Ask what is causing the long tail. Possible causes include database contention, downstream API calls, connection-pool exhaustion, garbage collection, CPU throttling, network retries, or a small subset of expensive requests.

<details>
<summary>Answer</summary>

Half of requests can look fine while the slow tail is 8 seconds. Users on that tail fail even when the average looks acceptable. Ask what causes the tail: database contention, downstream APIs, connection-pool exhaustion, garbage collection, CPU throttle, retries, or expensive endpoints.

For user-facing systems, distribution matters more than average. Use p95 and p99 on the dashboard and in alerts.

</details>

---

## 3. Introduce an application error and read the logs

Practice: Introduce an application error and inspect the logs. Then ask:

```text
When did it happen?
Which service?
Which request?
Which user/request context?
What exception?
Which downstream dependency?
What happened immediately before it?
```

<details>
<summary>Answer</summary>

Cause a known error. Run `kubectl logs deployment/myapp` or `kubectl logs <pod-name>`. If the container restarted, use `kubectl logs <pod-name> --previous`. Answer: when, which service, which request, which exception, which downstream, and what happened just before.

Use structured logs with `trace_id`. Do not log passwords or tokens. Logs explain what the process believed at that moment. A metric cannot replace a stack trace.

</details>

---

## 4. Follow one slow request through the trace path

Practice: Take one slow request and identify the trace path:

```text
Trace ID
  ↓
Frontend span
  ↓
Backend span
  ↓
Database/downstream span
```

<details>
<summary>Answer</summary>

Take one Trace ID. Read frontend span, backend span, then database or external span. Example: Orders API waits 5 seconds while the external payment span uses most of that time. The Orders log alone only says “we waited.”

“The API is slow” is not a diagnosis. Name the component that consumed the latency. OpenTelemetry can propagate that context across services.

</details>

---

## 5. Connect Request → Trace ID → Logs → Error

Practice: Pick one request and verify whether you can connect:

```text
Request → Trace ID → Logs → Error
```

If you cannot, identify what instrumentation or logging context is missing.

<details>
<summary>Answer</summary>

Start from the alert or a slow request. Copy `trace_id=abc123`. Search logs for the same id. You should land on the exception and the dependency. If you cannot, the app is missing trace context in logs or the tracer is not propagating headers.

Good observability reduces disconnected clues during an incident. Metrics find the window. Traces find the span. Logs explain the error.

</details>

---

## 6. Design three alerts: errors, latency, Pod restarts

Practice: Design three alerts:

1. High application error rate.
2. High latency.
3. Pod crash/restart problem.

For each, write the condition, duration, impact, and first investigation step.

<details>
<summary>Answer</summary>

1. Orders API error rate above 5% for 10 minutes. Impact: failed user requests. First step: check deploy time, then traces and logs for 5xx. 2. p95 latency above SLO for 10 minutes. Impact: slow checkout. First step: open a trace and see which span grew. 3. Pod restart count rising. Impact: possible crash loop. First step: `kubectl logs <pod> --previous` and Events.

Alert on symptoms users feel (errors, latency), not only CPU. CPU belongs on a dashboard. An alert starts investigation. It is not the diagnosis. Keep duration so brief spikes do not page.

</details>

---

## 7. Orders API SLI, SLO, and a latency SLI

Practice: For an Orders API, define:

```text
SLI: successful HTTP requests / total valid HTTP requests
SLO: 99.9% success over a defined window
```

Then ask what latency SLI would also matter.

<details>
<summary>Answer</summary>

SLI: successful HTTP requests divided by valid HTTP requests. SLO: 99.9% success over a defined window, such as 30 days. Add a latency SLI, for example the percentage of requests under 500 ms, with its own SLO.

SLA is the customer promise and may include penalties. Error budget is 100% minus the SLO. Budget burning fast pages a human. Budget healthy lets you ship features.

</details>

---

## 8. Incident scenario — bad deploy, 500s, Pods Running, CPU normal

Incident Drill: Application Failure

Scenario:

```text
10:00 — Deployment completed
10:05 — Error rate increases
10:06 — Users report failed orders
10:07 — Alert fires
```

You observe:

```text
HTTP 500 ↑
p95 latency ↑
Pod restarts normal
CPU normal
Memory normal
Database CPU normal
```

Reason through the evidence.

The normal Pod and infrastructure signals suggest the problem may not be simple resource exhaustion. Compare the deployment timeline with the error timeline. Check traces and logs for the failing request path. Look for a changed API contract, configuration value, database query, dependency behavior, or application exception.

Useful Kubernetes commands:

```bash
kubectl rollout status deployment/orders-api
kubectl rollout history deployment/orders-api
kubectl get pods
kubectl describe pod <pod>
kubectl logs <pod>
kubectl logs <pod> --previous
kubectl get events --sort-by=.lastTimestamp
```

If the application is still serving some traffic, inspect the error distribution rather than assuming every request is failing.

<details>
<summary>Answer</summary>

Timeline: 10:00 deploy, 10:05 errors, 10:06 user reports, 10:07 alert. Infrastructure looks normal, so this is not simple saturation. Compare the deploy clock with the error clock. Inspect traces and logs for a changed contract, query, or exception. Use `kubectl rollout history deployment/orders-api` and `kubectl logs <pod>`.

Mitigate with a safe rollback if data is compatible. Verify error rate returns. Then RCA. Kubernetes health is not application health. Do not restart everything first. Restarts hide symptoms and can destroy evidence.

</details>

---

## 9. Incident record from deploy to recovery

Practice: Write a timeline from:

```text
Deployment → First error → Alert → Investigation → Mitigation → Recovery
```

This is the beginning of an incident record.

<details>
<summary>Answer</summary>

Write the timeline: deploy at 10:00, first error at 10:05, alert at 10:07. Then investigation of logs and traces. Mitigate with `kubectl rollout undo` or Helm rollback. Recovery is when the error rate falls. That record is the start of the incident file.

Keep mitigation separate from root cause. Recovery is the immediate objective. Root cause is the explanation afterward.

</details>

---

## 10. Incident scenario — network: frontend works, orders-api times out to database

Incident Drill: Network Failure

Scenario:

```text
Frontend works
    ↓
Orders API returns timeout
    ↓
Orders API cannot reach database
```

Use the networking troubleshooting model from Day 12 and Day 15:

```text
DNS
 ↓
IP
 ↓
Route
 ↓
Security rule
 ↓
Port
 ↓
Service
 ↓
Application
```

For Kubernetes, include:

```text
Pod
 ↓
Service
 ↓
Endpoints
 ↓
NetworkPolicy
 ↓
Cloud network
 ↓
Database
```

Useful commands:

```bash
kubectl get svc
kubectl get endpoints
kubectl get endpointslices
kubectl get networkpolicy
kubectl exec -it <pod> -- sh
```

From a debugging container, test DNS and connectivity:

```bash
nslookup database.example.internal
nc -vz database.example.internal 5432
```

Do not jump directly to “firewall problem.” The failure could be DNS, routing, security rules, incorrect port, database listener state, credentials, connection limits, or application configuration.

Senior point: Observability tells you **where the failure appears**; networking knowledge lets you determine **which layer is actually failing**.

<details>
<summary>Answer</summary>

Observability shows the failure at the database span. Networking names the layer. Walk DNS → IP → route → security rule → port → Service → application. In Kubernetes add Pod → Service → Endpoints → NetworkPolicy → cloud network → database.

From the Pod run `nslookup database.example.internal` and `nc -vz database.example.internal 5432`. Also run `kubectl get svc`, `kubectl get endpoints`, and `kubectl get networkpolicy`. Do not jump to “firewall.” The cause can be DNS, route, port, listener, credentials, pool limits, or config.

</details>

---

## 11. Incident scenario — resource saturation

Incident Drill: Resource Saturation

Scenario:

```text
Traffic ↑
CPU ↑
p95 latency ↑
HTTP 5xx ↑
Pods at CPU limit
```

This evidence is more consistent with resource saturation than the previous scenario.

Investigate:

```text
Request rate
 ↓
Pod CPU
 ↓
CPU requests/limits
 ↓
HPA behavior
 ↓
Node capacity
 ↓
Application thread pools
 ↓
Database capacity
```

Kubernetes commands:

```bash
kubectl top pods
kubectl top nodes
kubectl get hpa
kubectl describe hpa <hpa-name>
kubectl describe pod <pod>
```

Possible mitigations include scaling replicas, increasing available capacity, reducing expensive work, fixing inefficient code, or addressing downstream bottlenecks. The correct action depends on evidence.

Do not assume “add more Pods” always solves the issue. If all Pods are waiting on the same database, external API, or shared resource, horizontal scaling may increase pressure rather than solve the underlying bottleneck.

**Remember:** Scaling is a capacity action, not automatically a root-cause fix.

<details>
<summary>Answer</summary>

Traffic, CPU, p95, and 5xx all rise, and Pods hit CPU limit. That matches saturation, not a bad query with idle CPU. Check request rate, Pod CPU, requests and limits, HPA, node capacity, thread pools, and database capacity. Use `kubectl top pods`, `kubectl top nodes`, and `kubectl get hpa`.

Mitigations include more replicas, more node capacity, or less expensive work. Adding Pods does not help if every Pod waits on one database. Scaling is a capacity action, not automatically a root-cause fix.

</details>

---

## 12. RCA structure — incompatible query after deploy

Write a Root Cause Analysis for this incident. Use the RCA structure from the lesson.

Example:

```text
Incident:
Orders API returned 500 errors.

Impact:
Users could not complete orders for 12 minutes.

Timeline:
10:00 deployment
10:05 errors begin
10:07 alert
10:10 rollback
10:12 recovery

Root cause:
Application release introduced an incompatible database query.

Contributing factor:
Integration tests did not cover the production schema variation.

Corrective action:
Fix query and redeploy.

Preventive action:
Add schema-compatibility integration testing.
```

Avoid writing:

```text
Root cause: Developer made a mistake.
```

That explains who made the change, not why the system permitted a single mistake to cause the incident.

Senior thinking asks:

```text
Why did the change pass testing?
Why was the risky condition not detected?
Why could the deployment reach production?
Why was recovery possible or difficult?
What control should change?
```

<details>
<summary>Answer</summary>

Incident: Orders API returned 500s. Impact: users could not complete orders for 12 minutes. Timeline: deploy, errors, alert, rollback, recovery. Technical root cause: incompatible database query. Contributing factor: tests missed the production schema. Corrective: fix query and redeploy. Preventive: schema-compatibility tests.

Do not write “developer made a mistake.” Ask why tests passed, why it reached production, and what control must change. RCA explains why the system allowed the failure to reach users. That is a blameless RCA.

</details>

---

## 13. Architecture — observability for Spring Boot on AKS

Design observability for a Spring Boot application running on AKS.

Architecture:

```text
Users
  ↓
Cloudflare / DNS
  ↓
Azure Load Balancer / Ingress
  ↓
AKS
  ↓
Spring Boot
  ↓
Azure Database / PostgreSQL
  ↓
External APIs
```

Your design should answer:

- What metrics are collected?
- What logs are collected?
- How are logs structured?
- How are trace IDs propagated?
- Where are metrics stored?
- Where are logs stored?
- Where are traces stored?
- Which alerts page an engineer?
- Which alerts are informational?
- What is the application's SLI?
- What is its SLO?
- How do you identify a bad deployment?
- How do you identify a network problem?
- How do you identify database saturation?
- How do you trace one slow request?
- How do you correlate an alert with logs and traces?
- How do you retain telemetry?
- How do you control observability cost?
- How do you protect sensitive data in logs?

<details>
<summary>Answer</summary>

Collect golden signals plus Kubernetes CPU, memory, restarts, HPA, database latency, and business counters such as orders created. Structure logs with `trace_id`. Propagate OpenTelemetry context. Store metrics in Azure Monitor or Prometheus, logs in Log Analytics, traces in Application Insights. If the org also runs Datadog, export the same OpenTelemetry signals there. Do not double-instrument.

Page on sustained error rate and SLO burn. Keep CPU informational. Identify a bad deploy by release markers plus error start time. Identify network by timeouts and failed DNS. Identify database saturation by DB latency and pool metrics. Trace one slow request by Trace ID. Drop secrets from logs. Cap retention to control cost.

</details>

---

## 14. One-page operational dashboard

Then create a one-page operational dashboard with:

```text
SERVICE HEALTH
- Request rate
- Error rate
- p50 / p95 / p99 latency

KUBERNETES
- Available replicas
- Restarts
- CPU
- Memory

DEPENDENCIES
- Database latency
- Database errors
- External API errors

BUSINESS
- Orders created
- Orders failed

RELEASE
- Current image version
- Deployment time
- Git commit
```

The objective is not to create the prettiest dashboard. The objective is to make the dashboard useful during a real incident.

<details>
<summary>Answer</summary>

SERVICE HEALTH: request rate, error rate, p50, p95, p99. KUBERNETES: available replicas, restarts, CPU, memory. DEPENDENCIES: database latency and errors, external API errors. BUSINESS: orders created, orders failed. RELEASE: current image, deploy time, Git commit.

The goal is a useful incident view, not the prettiest dashboard. Infrastructure can look healthy while orders created equals zero. Include the business row.

</details>

---

## 15. Production incident simulation

Use the application and Kubernetes environment from previous lessons if available.

First establish a healthy baseline:

```bash
kubectl get pods
kubectl get svc
kubectl get endpoints
kubectl top pods
kubectl top nodes
```

Then introduce one controlled failure, such as:

- Deploy a broken application version.
- Use an incorrect database hostname.
- Break a Service selector.
- Apply an overly restrictive NetworkPolicy.
- Reduce available resources.
- Introduce an application exception.

Do not intentionally break shared or production infrastructure.

Your job is to investigate without immediately looking at the answer.

Record:

```text
1. Detection signal
2. User impact
3. First hypothesis
4. Evidence collected
5. Hypothesis rejected/confirmed
6. Mitigation
7. Recovery verification
8. Root cause
9. Corrective action
10. Preventive action
```

Then produce a short RCA.

A strong exercise ends with you being able to explain the incident in this form:

```text
Users experienced X
because component Y failed
due to condition Z.

We detected it through A,
confirmed it using B,
mitigated it using C,
and changed D to reduce recurrence.
```

<details>
<summary>Answer</summary>

Establish baseline with `kubectl get pods`, `kubectl get svc`, `kubectl get endpoints`, `kubectl top pods`, and `kubectl top nodes`. Introduce one controlled failure: bad image, wrong DB host, broken selector, tight NetworkPolicy, low resources, or an app exception. Do not break shared production.

Record detection, user impact, first hypothesis, evidence, confirm or reject, mitigation, recovery check, root cause, corrective action, and preventive action. Close with: users experienced X because component Y failed due to Z. We detected it through A, confirmed it using B, mitigated it using C, and changed D.

</details>

---

## 16. Recall — Three primary observability signals

What are the three primary observability signals?

What does each answer?

<details>
<summary>Answer</summary>

Metrics, logs, and traces. Metrics: what is happening over time. Logs: what events and errors occurred. Traces: where one request spent its time.

Use all three together during an incident.

</details>

---

## 17. Recall — Why average latency can mislead

Why can average latency be misleading?

<details>
<summary>Answer</summary>

A few very slow requests hide inside a reasonable average. Percentiles such as p95 and p99 expose the slow tail.

User experience follows the tail, not only the mean.

</details>

---

## 18. Recall — Four golden signals

What are the four golden signals?

<details>
<summary>Answer</summary>

Latency, traffic, errors, and saturation. For HTTP: how long, how many, how many failed, how close resources are to limits.

A metric is useful only when someone knows the action that follows an abnormal value.

</details>

---

## 19. Recall — Monitoring versus observability

What is the difference between monitoring and observability?

<details>
<summary>Answer</summary>

Monitoring tells you a known condition is abnormal. Observability gives enough telemetry to investigate internal behavior and understand why.

Install Prometheus and Grafana only if the signals let you detect, isolate, and recover.

</details>

---

## 20. Recall — SLI, SLO, and SLA

What is an SLI?

What is an SLO?

What is an SLA?

<details>
<summary>Answer</summary>

An SLI is a measurement of actual service behavior. An SLO is the target for that measurement. An SLA is a formal commitment, sometimes with consequences.

SLI = what we measure. SLO = what we aim for. SLA = what we promise.

</details>

---

## 21. Recall — RCA or recovery first?

What should happen first during an incident: RCA or recovery?

<details>
<summary>Answer</summary>

Safe recovery and mitigation come first. Root-cause investigation follows after the service is stable.

Separate those jobs or you debug while users stay down.

</details>

---

## 22. Recall — Why not automatically restart everything

Why should you not automatically restart everything?

<details>
<summary>Answer</summary>

A restart can hide symptoms without fixing the cause. It may also destroy logs from the failed container unless you already collected `--previous`.

Restart is a tool, not the default incident action.

</details>

---

## 23. Recall — Why trace correlation matters

Why is trace correlation important?

<details>
<summary>Answer</summary>

It connects one request across services and shows which span caused latency or failure. Metrics show the service. The trace shows the hop.

Without correlation you assemble clues by hand under pressure.

</details>

---

## 24. Recall — What makes a useful alert

What makes a useful alert?

<details>
<summary>Answer</summary>

It is an actionable condition with real impact and a sensible duration. It includes enough context to start: what is wrong, who is affected, how serious, how long, and what to check first.

Alert fatigue starts when alerts fire for conditions that need no action.

</details>

---

## 25. Recall — Senior/Lead incident mindset

What is the Senior/Lead incident mindset?

<details>
<summary>Answer</summary>

Detect → Assess → Stabilize → Investigate → Recover → Learn → Prevent. Mitigate first. Explain later.

Observability is not collecting more data. It is collecting the right evidence to operate production.

</details>

---

## 26. Recall — Why define dashboards and alerts as code?

Why should dashboards and alert rules live in Terraform or Crossplane instead of only in a GUI?

<details>
<summary>Answer</summary>

They become reviewable, versioned, and reversible. A pull request shows who changed the alert. Git can roll it back.

Keep metric-label cardinality low. `user_id` as a label explodes series count and cost. Put IDs in logs and traces. Token usage and model cost are metrics too, next to latency and errors.

</details>
