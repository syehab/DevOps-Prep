# Day 20 — Observability + Production Incident

This Day uses three files. Read them in this order.

1. [01-concepts.md](01-concepts.md) — lesson content (this file)
2. [02-questions-and-answers.md](02-questions-and-answers.md) — practice items, each with a model answer
3. [03-implementation.md](03-implementation.md) — hands-on lab

**Goal:** Learn the three telemetry signals (metrics, logs, traces), define what "healthy" means with numbers (SLIs and SLOs), and run a production incident calmly: mitigate first, explain later.

> **JD note:** This is the core lesson behind every SRE-titled JD. See the [SRE pattern card](jd-insights/patterns/sre-slos-observability.md).

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

Senior DevOps thinking goes beyond “install Prometheus and Grafana.” The real question is whether the telemetry lets you detect an important failure, understand its impact, and isolate the failing component. It should also let you recover safely and prevent the same class of incident from recurring.

**Remember:** Monitoring tells you that something may be wrong; observability helps you understand why.

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

This means about half of requests are at or below 200 ms, 95% are at or below 700 ms, and 99% are at or below 4 seconds. The exact interpretation depends on how the system calculates the metric, but the operational idea is that high percentiles reveal the slower tail of user requests.

**Remember:** For user-facing systems, latency distribution often matters more than average latency.

---

## Part 4 — Logs: Understanding Events

Logs record discrete events and application context. They are useful when you need details that a simple number cannot represent: an exception stack trace, request identifier, authentication failure, configuration error, database timeout, or deployment event. Logs are particularly valuable during troubleshooting because they explain what a process believed was happening at a particular moment.

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

Senior point: In distributed systems, “the API is slow” is not a sufficient diagnosis. You need to identify which component consumed the latency.

---

## Part 6 — Correlation: Connecting Logs, Metrics and Traces

The real value of observability appears when you can connect the telemetry signals. Suppose an alert reports that the `orders-api` error rate increased. Metrics tell you the increase happened. Logs may reveal database timeout exceptions. Traces can show that requests are spending most of their time waiting for the database.

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

> **Remember:** Alert on symptoms users feel (errors, latency), not on causes (CPU). Causes belong on dashboards; symptoms are what page a human.

Better alerting often combines technical symptoms with service-level impact. For example, elevated request failures sustained for a period may be more actionable than a short CPU spike.

**Remember:** An alert is not the diagnosis. It is the signal that starts the investigation.

---

## Part 9 — SLI, SLO and SLA

Senior DevOps engineers should understand the difference between SLI, SLO, and SLA.

An **SLI (Service Level Indicator)** is a measurement of actual service behavior, such as successful request percentage or latency.

An **SLO (Service Level Objective)** is the target for that measurement, such as:

```text
99.9% of valid requests succeed over 30 days.
```

An **SLA (Service Level Agreement)** is a formal agreement with customers or stakeholders. It may include commitments, and consequences if the provider does not meet those commitments.

The relationship is:

```text
SLI = What we measure
SLO = What target we aim for
SLA = What we formally promise
```

A useful Senior-level concept is **error budget**. If the SLO allows a small amount of failure, that allowed failure becomes the error budget. Teams can use it to balance reliability work against feature delivery. The exact policy is an organizational decision.

```text
SLI = what you measure
        ↓
SLO = the target
        ↓
Error budget = 100% minus SLO
        ↓
Budget burning fast? → page a human
Budget healthy?      → ship features
```

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

If evidence strongly connects the incident to the latest release, a rollback may be a reasonable mitigation. It must be safe, and the previous version must remain compatible with the current data state.

Do not automatically restart everything. A restart can temporarily hide symptoms while leaving the underlying problem unresolved.

**Remember:** Recovery is the immediate objective; root cause is the explanation you establish afterward.

---

## Part 11 — Root Cause Analysis

A Root Cause Analysis should explain not only what failed. It should also explain why the system allowed the failure to reach users and why existing controls did not stop or detect it earlier.

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

## Part 12 — Observability for Kubernetes and Cloud Architecture

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

## Part 13 — Cleanup

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

**Final mental model:**

> **Observability is not about collecting more data. It is about collecting the right evidence so an engineer can understand and operate a production system.**

## Next

**Day 21 — Final Senior/Lead Capstone**

The core 20-day curriculum is complete. Day 21 will turn the individual concepts into one end-to-end architecture and troubleshooting exercise covering **cloud architecture, networking, IaC, CI/CD, containers, Kubernetes, identity, security, observability, reliability, cost, and production decision-making**.
