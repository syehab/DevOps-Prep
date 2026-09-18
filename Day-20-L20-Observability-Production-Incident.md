# Day 20 — Observability + Production Incident

## Part 1 — Why Observability Exists

A production system is not healthy simply because the application process is running or Kubernetes reports that Pods are `Running`. A system can be technically “up” while users experience slow requests, failed payments, database timeouts, incorrect responses, or intermittent errors. Observability gives the operations team enough evidence to understand what the system is doing internally by looking at externally visible signals. The three core signals are **metrics, logs, and traces**, while alerting, dashboards, and incident processes turn those signals into operational action.

A useful mental model is:

```text
Application
    ↓
Telemetry
    ├── Metrics → What is happening?
    ├── Logs    → What happened?
    └── Traces  → Where did the request go?
    ↓
Dashboards + Alerts
    ↓
Incident Detection
    ↓
Investigation
    ↓
Recovery
    ↓
RCA + Improvement
```

Senior DevOps thinking goes beyond “install Prometheus and Grafana.” The real question is whether the telemetry allows you to detect an important failure, understand its impact, isolate the failing component, recover safely, and prevent the same class of incident from recurring.

**Remember:** Monitoring tells you that something may be wrong; observability helps you understand why.

Practice: Take your Spring Boot application and list what you would need to know if users suddenly reported that requests were taking 10 seconds instead of 500 milliseconds.

---

## Part 2 — Metrics: Measuring System Behavior

Metrics are numerical measurements collected over time. Examples include request rate, error rate, latency, CPU usage, memory usage, active connections, queue depth, and database connection-pool usage. Metrics are efficient for dashboards and alerting because you can aggregate large amounts of activity into time-series data without storing every individual event.

For an HTTP application, four particularly useful measurements are:

```text
Traffic   → How many requests?
Errors    → How many failed?
Latency   → How long do requests take?
Saturation → How close are resources to their limits?
```

This is often called the **four golden signals** approach: latency, traffic, errors, and saturation.

A Prometheus-style metric might look conceptually like:

```text
http_requests_total{method="GET",status="200"} 15234
```

Another might represent latency observations:

```text
http_request_duration_seconds
```

Implementation practice: expose application metrics from Spring Boot using Actuator and Micrometer, then make them available to your monitoring system.

Typical endpoint:

```text
/actuator/health
/actuator/prometheus
```

The exact endpoints and configuration depend on the application setup.

For infrastructure, Kubernetes, nodes, databases, and cloud services, collect metrics appropriate to the component rather than collecting everything indiscriminately.

Senior point: A metric is useful only when someone knows what it means and what action should follow an abnormal value.

---

## Part 3 — Percentiles and Why Average Latency Can Mislead

Average latency is useful but can hide serious user experience problems. Imagine 1,000 requests where most finish quickly but a small number take several seconds. The average may still look acceptable while a subset of users experiences severe delays. Percentiles help describe the distribution.

For example:

```text
p50 = 200 ms
p95 = 700 ms
p99 = 4 s
```

This means approximately half of requests are at or below 200 ms, 95% are at or below 700 ms, and 99% are at or below 4 seconds. The exact interpretation depends on how the metric is calculated, but the operational idea is that high percentiles reveal the slower tail of user requests.

Practice: Suppose an application reports:

```text
Average latency: 300 ms
p95 latency:     900 ms
p99 latency:     8 s
```

Do not conclude that the application is simply “300 ms fast.” Ask what is causing the long tail. Possible causes include database contention, downstream API calls, connection-pool exhaustion, garbage collection, CPU throttling, network retries, or a small subset of expensive requests.

**Remember:** For user-facing systems, latency distribution often matters more than average latency.

---

## Part 4 — Logs: Understanding Events

Logs record discrete events and application context. They are useful when you need details that cannot be represented by a simple number: an exception stack trace, request identifier, authentication failure, configuration error, database timeout, or deployment event. Logs are particularly valuable during troubleshooting because they explain what a process believed was happening at a particular moment.

A useful structured log might contain:

```json
{
  "timestamp": "2026-09-18T10:20:30Z",
  "level": "ERROR",
  "service": "orders-api",
  "trace_id": "abc123",
  "message": "Database connection timeout"
}
```

Structured logs are easier for log platforms to search and aggregate than arbitrary text.

For Kubernetes:

```bash
kubectl logs deployment/myapp
kubectl logs <pod-name>
kubectl logs <pod-name> --previous
```

`--previous` is particularly useful when a container has restarted and the current container no longer contains the logs from the failed instance.

For a Spring Boot service, avoid logging passwords, access tokens, private keys, or other sensitive information. Logging too much can create both cost and security problems.

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

---

## Part 5 — Trace: Following One Request Across Services

A distributed request may travel through many components:

```text
User
 ↓
Load Balancer
 ↓
Frontend
 ↓
Orders API
 ↓
Payment API
 ↓
Database
 ↓
External payment provider
```

A log from only the Orders API may show that it spent 5 seconds waiting, but not immediately reveal which downstream operation caused the delay. Distributed tracing attaches a trace context to the request and records spans representing individual operations. This allows you to follow one request across service boundaries.

Conceptually:

```text
Trace: 7f91

Frontend       0–50 ms
Orders API    50–5000 ms
Payment API  100–4800 ms
Database     200–400 ms
External API 500–4700 ms
```

The exact numbers are illustrative. The important point is that the trace shows where the request spent its time.

OpenTelemetry is a common vendor-neutral framework for collecting telemetry. It can generate or propagate traces, metrics, and logs and export them to compatible observability backends.

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

Senior point: In distributed systems, “the API is slow” is not a sufficient diagnosis. You need to identify which component consumed the latency.

---

## Part 6 — Correlation: Connecting Logs, Metrics and Traces

The real value of observability appears when telemetry signals can be connected. Suppose an alert reports that the `orders-api` error rate increased. Metrics tell you the increase happened. Logs may reveal database timeout exceptions. Traces can show that requests are spending most of their time waiting for the database.

A useful investigation chain is:

```text
Alert
  ↓
Metric
  ↓
Time window
  ↓
Affected service
  ↓
Trace
  ↓
Relevant log
  ↓
Root cause
```

Correlation IDs or trace IDs are extremely useful. If a trace contains:

```text
trace_id=abc123
```

and the corresponding application log also contains:

```text
trace_id=abc123
```

you can move from the distributed request view to the detailed event view.

Practice: Pick one request and verify whether you can connect:

```text
Request → Trace ID → Logs → Error
```

If you cannot, identify what instrumentation or logging context is missing.

**Remember:** Good observability reduces the number of disconnected clues an engineer has to manually assemble during an incident.

---

## Part 7 — Dashboards: Turning Telemetry Into a System View

A dashboard should help an engineer answer an operational question quickly. A useful application dashboard might contain:

```text
Request rate
Error rate
p50 / p95 / p99 latency
CPU
Memory
Pod count
Pod restarts
Database connections
Database latency
Dependency errors
```

Do not build dashboards by displaying every metric available. Too many panels create visual noise and slow down incident response. A good dashboard follows the system's architecture and shows the signals needed to determine whether users are affected and which layer may be responsible.

For Kubernetes, a practical first dashboard can answer:

```text
Are Pods healthy?
Are requests reaching the service?
Are errors increasing?
Is latency increasing?
Are Pods restarting?
Are resources saturated?
Are nodes healthy?
```

For Azure, common monitoring components include Azure Monitor, Log Analytics, Application Insights, and Managed Prometheus/Grafana capabilities depending on the architecture.

For AWS, common components include CloudWatch and AWS integrations with managed observability tooling.

Azure ↔ AWS mapping:

```text
Azure Monitor / Application Insights  ↔ CloudWatch / X-Ray
Log Analytics                         ↔ CloudWatch Logs
Managed Prometheus / Grafana          ↔ Managed Prometheus / Grafana
```

The exact service combination depends on the workload.

---

## Part 8 — Alerting: Detecting Problems Without Creating Noise

An alert should represent a condition that requires human or automated action. If an alert fires constantly for conditions that do not require action, engineers begin ignoring alerts. This is alert fatigue, and it reduces the value of the monitoring system.

A useful alert answers:

```text
What is wrong?
Who is affected?
How serious is it?
How long has it been happening?
What should the responder investigate?
```

Example:

```text
ALERT: Orders API error rate > 5%
Duration: 10 minutes
Service: orders-api
Environment: production
Impact: elevated failed requests
```

Compare this with:

```text
ALERT: CPU = 81%
```

The second may be less useful by itself because high CPU does not necessarily mean users are affected.

Better alerting often combines technical symptoms with service-level impact. For example, elevated request failures sustained for a period may be more actionable than a short CPU spike.

Practice: Design three alerts:

1. High application error rate.
2. High latency.
3. Pod crash/restart problem.

For each, write the condition, duration, impact, and first investigation step.

**Remember:** An alert is not the diagnosis. It is the signal that starts the investigation.

---

## Part 9 — SLI, SLO and SLA

Senior DevOps engineers should understand the difference between SLI, SLO, and SLA.

An **SLI (Service Level Indicator)** is a measurement of actual service behavior, such as successful request percentage or latency.

An **SLO (Service Level Objective)** is the target for that measurement, such as:

```text
99.9% of valid requests succeed over 30 days.
```

An **SLA (Service Level Agreement)** is a formal agreement with customers or stakeholders that may include commitments and consequences if those commitments are not met.

The relationship is:

```text
SLI = What we measure
SLO = What target we aim for
SLA = What we formally promise
```

Practice: For an Orders API, define:

```text
SLI: successful HTTP requests / total valid HTTP requests
SLO: 99.9% success over a defined window
```

Then ask what latency SLI would also matter.

A useful Senior-level concept is **error budget**. If the SLO allows a small amount of failure, that allowed failure becomes the error budget. Teams can use it to balance reliability work against feature delivery. The exact policy is an organizational decision.

---

## Part 10 — Production Incident: A Structured Response

When production breaks, the first objective is to restore a safe service, not to immediately prove the root cause. Incident response should separate **mitigation** from **root-cause investigation**.

A useful sequence is:

```text
Detect
  ↓
Assess impact
  ↓
Stabilize
  ↓
Mitigate
  ↓
Verify recovery
  ↓
Investigate root cause
  ↓
Document
  ↓
Prevent recurrence
```

Suppose the Orders API begins returning HTTP 500 responses after a deployment.

First determine:

```text
When did the errors start?
What percentage of requests fail?
Which endpoints?
Which users/regions?
Did a deployment happen immediately before?
Are dependencies healthy?
Are Pods healthy?
Is the database healthy?
```

If evidence strongly connects the incident to the latest release, a rollback may be a reasonable mitigation if the rollback is safe and the previous version remains compatible with the current data state.

Do not automatically restart everything. A restart can temporarily hide symptoms while leaving the underlying problem unresolved.

**Remember:** Recovery is the immediate objective; root cause is the explanation you establish afterward.

---

## Part 11 — Incident Drill: Application Failure

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

Practice: Write a timeline from:

```text
Deployment → First error → Alert → Investigation → Mitigation → Recovery
```

This is the beginning of an incident record.

---

## Part 12 — Incident Drill: Network Failure

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

---

## Part 13 — Incident Drill: Resource Saturation

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

---

## Part 14 — Root Cause Analysis

A Root Cause Analysis should explain not only what failed but why the system allowed the failure to reach users and why existing controls did not stop or detect it earlier.

A useful RCA structure is:

```text
Incident
Impact
Timeline
Detection
Immediate mitigation
Technical root cause
Contributing factors
Why controls did not prevent it
Corrective actions
Preventive actions
```

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

---

## Part 15 — Observability for Kubernetes and Cloud Architecture

A production Kubernetes platform has multiple layers that need telemetry:

```text
User
 ↓
DNS
 ↓
Load Balancer / Ingress
 ↓
Service
 ↓
Pods
 ↓
Application
 ↓
Database / External Services
```

Telemetry should exist at the appropriate layers.

At the edge:

```text
Request count
HTTP status
Latency
TLS failures
```

At Kubernetes:

```text
Pod health
Restarts
CPU
Memory
Scheduling
Node health
HPA
```

At the application:

```text
Request rate
Errors
Latency
Business events
Exceptions
```

At dependencies:

```text
Database latency
Connections
Errors
Capacity
External API latency/errors
```

At the business level, consider metrics such as:

```text
Orders created
Orders failed
Payments succeeded
Payments failed
```

This matters because infrastructure can look healthy while the business function is broken.

For example:

```text
CPU = normal
Memory = normal
Pods = healthy
HTTP 200 = normal

BUT

Orders created = 0
```

That should trigger investigation because technical health does not necessarily equal business health.

---

## Part 16 — Senior/Lead Architecture Exercise

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

---

## Part 17 — Practice: Run a Complete Production Incident Simulation

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

---

## Part 18 — 5-Minute Recall

What are the three primary observability signals?

**Metrics, logs, and traces.**

What does each answer?

**Metrics:** What is happening over time?

**Logs:** What events and errors occurred?

**Traces:** Where did an individual request spend its time?

Why can average latency be misleading?

Because a small number of very slow requests can be hidden by a reasonable average. Percentiles such as p95 and p99 expose the slow tail.

What are the four golden signals?

**Latency, traffic, errors, and saturation.**

What is the difference between monitoring and observability?

Monitoring commonly tells you that a known condition is abnormal; observability provides enough telemetry to investigate internal system behavior and understand why.

What is an SLI?

A measurement of actual service behavior.

What is an SLO?

A target for an SLI.

What is an SLA?

A formal service commitment or agreement.

What should happen first during an incident: RCA or recovery?

**Safe recovery/mitigation comes first.** Root-cause investigation follows once the service is stabilized.

Why should you not automatically restart everything?

Because restarting can hide symptoms without fixing the cause and may destroy useful evidence.

Why is trace correlation important?

It connects a single request across distributed services and helps identify where latency or failure originated.

What makes a useful alert?

It represents an actionable condition with meaningful impact, appropriate duration, and enough context to begin investigation.

What is the Senior/Lead incident mindset?

**Detect → Assess → Stabilize → Investigate → Recover → Learn → Prevent.**

**Final mental model:**

> **Observability is not about collecting more data. It is about collecting the right evidence so an engineer can understand and operate a production system.**

---

## Part 19 — Cleanup

Remove temporary lab resources:

```bash
kubectl delete deployment myapp --ignore-not-found
kubectl delete service myapp --ignore-not-found
kubectl delete configmap myapp-config --ignore-not-found
kubectl delete secret db-secret --ignore-not-found
```

Remove temporary monitoring resources, dashboards, test alerts, and test cloud resources according to your lab setup.

For any managed monitoring service, check whether you created billable resources, log ingestion, retained telemetry, dashboards, or storage.

Do not delete shared monitoring infrastructure or production resources without confirming ownership.

---

## Next

**Day 21 — Final Senior/Lead Capstone**

The core 20-day curriculum is complete. Day 21 will turn the individual concepts into one end-to-end architecture and troubleshooting exercise covering **cloud architecture, networking, IaC, CI/CD, containers, Kubernetes, identity, security, observability, reliability, cost, and production decision-making**.
