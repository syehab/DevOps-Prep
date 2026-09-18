# Day 35 — Production Project 05: Observability & Production Incident Response

Day 34 made ShopSphere safer to change. Day 35 focuses on the next production question: **How do we know what the system is doing, and how do we investigate when something goes wrong?** A production system is not observable simply because logs exist or a dashboard shows CPU. Good observability connects system behavior to user impact and gives engineers enough evidence to move from symptom → affected component → root cause → recovery. Today you will build that capability and use it during realistic incidents.

---

## Part 1 — The Observability Mental Model

Observability is the ability to understand the internal state and behavior of a system from the evidence it produces. The three primary telemetry signals are **metrics, logs, and traces**. Metrics tell you that something is changing, logs provide detailed events and context, and traces show how an individual request moves across services and dependencies. These signals become useful when they are connected to deployment information, infrastructure state, business impact, and a clear incident process.

Think of the production loop as:

```text
System
 ↓
Telemetry
 ↓
Detection
 ↓
Investigation
 ↓
Diagnosis
 ↓
Recovery
 ↓
Verification
 ↓
RCA
 ↓
Improvement
```

The objective is not to collect everything.

The objective is to collect the evidence you need to answer:

**What is happening?**

**Who is affected?**

**Where is the failure?**

**Why is it happening?**

**What changed?**

**How do we recover safely?**

---

## Part 2 — Metrics, Logs and Traces

Metrics are numerical measurements collected over time. Examples include request rate, error rate, latency, CPU utilization, memory usage, database connections, and queue depth. Logs are timestamped events that provide detailed information about what the application or infrastructure did. Traces follow a request through multiple components and make distributed behavior easier to understand.

A simple distinction is:

```text
Metrics → What is happening?
Logs    → What happened?
Traces  → Where did this request go?
```

They complement one another.

For example:

```text
Metric:
5xx rate increased

        ↓

Log:
Database connection timeout

        ↓

Trace:
Checkout request spent 4 seconds waiting on DB
```

The three signals together are much more useful than any one of them alone.

---

## Part 3 — Start With User Impact

Do not begin every incident by opening CPU graphs.

Start with the user or business symptom.

For ShopSphere:

```text
Customers cannot place orders
```

Then translate that into technical signals:

```text
Order API
 ↓
5xx errors
 ↓
Latency
 ↓
Database calls
 ↓
Payment dependency
```

This prevents a common operational mistake: optimizing or repairing a component that is healthy while the real failure exists elsewhere.

A useful incident question is:

**Which user action is failing?**

Examples:

```text
Login
Browse Products
Place Order
View Order
Payment
```

Then trace only the relevant system path.

---

## Part 4 — The Four Golden Signals

A practical starting point for service observability is:

```text
Latency
Traffic
Errors
Saturation
```

Latency tells you how long requests take. Traffic tells you how much demand the service is receiving. Errors tell you whether requests are failing. Saturation indicates whether a resource is approaching a meaningful limit.

For ShopSphere:

```text
Traffic:
Requests/minute

Latency:
p50 / p95 / p99

Errors:
HTTP 5xx / failed requests

Saturation:
CPU / memory / DB connections / thread pools
```

Do not rely only on averages.

A service can have an acceptable average latency while a significant portion of users experience very slow requests.

---

## Part 5 — Percentiles

Suppose ShopSphere reports:

```text
Average latency: 200 ms
```

That sounds reasonable.

But imagine:

```text
p50: 120 ms
p95: 600 ms
p99: 4 seconds
```

A small but important group of users is experiencing very slow requests.

Percentiles help describe the distribution rather than hiding slow requests inside an average.

For production APIs, pay particular attention to:

```text
p50
p95
p99
```

The correct target depends on the application and its SLOs.

Do not copy a universal latency threshold.

---

## Part 6 — Structured Logging

Application logs should be structured so that systems can search and correlate them.

Instead of:

```text
Order failed
```

prefer a structured event containing fields such as:

```text
timestamp
level
service
environment
request_id
trace_id
user/order identifier where appropriate
operation
error_type
message
```

For example:

```json
{
  "level": "ERROR",
  "service": "shopsphere-api",
  "environment": "prod",
  "operation": "createOrder",
  "trace_id": "abc123",
  "error_type": "DatabaseTimeout"
}
```

Do not put passwords, tokens, private keys, or unnecessary personal information into logs.

A log that helps diagnose an outage but exposes credentials is a security incident.

---

## Part 7 — Correlation IDs

Suppose a customer places an order.

The request passes through:

```text
Frontend
 ↓
Load Balancer
 ↓
ShopSphere API
 ↓
Database
 ↓
Payment Service
```

Without correlation, finding the events belonging to one request can be difficult.

A correlation or request ID allows you to connect related events.

Conceptually:

```text
Request ID: 7f91

Frontend
   ↓
API log
   ↓
Database call
   ↓
Payment call
   ↓
API response
```

Distributed tracing provides a richer version of this concept by representing the request as spans across components.

The important operational principle is:

**One user request should be traceable across the system wherever practical.**

---

## Part 8 — Distributed Tracing

A trace represents one request's journey.

For ShopSphere:

```text
Trace
 └── API Request
      ├── DB Query
      ├── Payment API
      └── Inventory API
```

Suppose the total request takes 3 seconds.

The trace might show:

```text
API:
3.0 sec

Database:
150 ms

Payment:
2.7 sec

Inventory:
80 ms
```

Now you know where to investigate.

Without tracing, you might incorrectly spend time investigating the database because the endpoint is slow.

OpenTelemetry is a common framework for instrumenting applications and producing telemetry that can be exported to compatible observability backends.

You do not need to build a complete distributed tracing platform today.

Understand the model first.

---

## Part 9 — Application Health vs Infrastructure Health

Infrastructure can be healthy while the application is broken.

For example:

```text
EC2/ECS:
Running

CPU:
Normal

Memory:
Normal

Network:
Normal

Application:
500 errors
```

Likewise:

```text
Application:
Healthy

Database:
Unavailable
```

Therefore monitor at multiple layers:

```text
Infrastructure
 ↓
Runtime
 ↓
Application
 ↓
Dependencies
 ↓
Business Operation
```

A Production dashboard should not consist only of CPU and memory.

---

## Part 10 — Business Observability

Technical metrics are not always enough.

Suppose:

```text
HTTP 200:
99.9%
```

That sounds excellent.

But if:

```text
Orders successfully created:
70%
```

the business system is not healthy.

For ShopSphere, useful business signals may include:

```text
Orders created/minute
Payment success rate
Checkout completion rate
Cart failures
Login success rate
```

This helps connect infrastructure and application behavior to business outcomes.

The Lead-level question is:

**What does “healthy” mean for the business, not just the server?**

---

## Part 11 — SLI, SLO and SLA

An **SLI** is a measurement of a service characteristic.

Example:

```text
Successful checkout requests / total checkout requests
```

An **SLO** is the target you set for that measurement.

Example:

```text
99.9% successful requests
```

An **SLA** is a formal service commitment, often involving consequences if agreed targets are not met.

Keep the distinction clear:

```text
SLI → Measurement
SLO → Target
SLA → Commitment
```

Do not treat these as interchangeable terms.

---

## Part 12 — Error Budgets

If an SLO is:

```text
99.9% availability
```

then some failure is within the allowed error budget.

The error budget creates a connection between reliability and release velocity.

If the service is consuming its error budget rapidly, the organization may choose to reduce release risk and prioritize reliability work.

The important concept is:

**Reliability is not completely separate from delivery speed.**

Teams need a way to balance both.

Do not turn error budgets into a mathematical exercise without understanding the operational decision they support.

---

## Part 13 — Alerting

A dashboard tells you what is happening when you look at it.

An alert tells you when a condition requires attention.

Good alerts should be:

```text
Actionable
Relevant
Understandable
Linked to impact
```

Poor alerts include:

```text
CPU > 70%
```

when that condition has no relationship to actual user impact.

A more useful alert might be:

```text
Checkout error rate exceeds the defined service threshold
```

or:

```text
No successful orders detected for a sustained period
```

The exact thresholds depend on normal traffic and service requirements.

Avoid alert fatigue.

If engineers ignore alerts because most are noise, the monitoring system has failed operationally.

---

## Part 14 — Dashboard Design

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

---

## Part 15 — Incident Timeline

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

---

## Part 16 — Incident Severity

Not every alert is an incident.

A useful distinction is:

```text
Alert
 ↓
Potential Problem
 ↓
Confirmed Incident
```

Severity should reflect impact.

Consider:

```text
How many users?
Which functionality?
How long?
Revenue impact?
Security impact?
Data integrity?
Availability?
Workaround?
```

Avoid defining severity only from technical metrics.

A small CPU spike may be irrelevant.

A 2% checkout failure may be commercially significant.

---

## Part 17 — Incident Response Process

Use a consistent process:

```text
Detect
 ↓
Assess
 ↓
Declare
 ↓
Contain
 ↓
Investigate
 ↓
Recover
 ↓
Verify
 ↓
Communicate
 ↓
RCA
 ↓
Improve
```

During an active incident, prioritize restoring service and limiting impact.

Do not spend 45 minutes trying to prove the perfect root cause while customers remain unable to place orders.

Root-cause analysis can continue after service restoration when appropriate.

---

## Part 18 — Incident Drill: High 5xx Rate

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

---

## Part 19 — Incident Drill: Latency Increase

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

---

## Part 20 — Incident Drill: No Orders

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

---

## Part 21 — Incident Drill: Deployment Correlation

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

---

## Part 22 — Incident Drill: Database Saturation

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

---

## Part 23 — RCA: Root Cause Analysis

After recovery, write an RCA.

Use:

```text
Incident:
Checkout failures

Impact:
X% of checkout requests failed

Start:
10:05

End:
10:20

Detection:
5xx alert

Root Cause:
Payment dependency timeout caused request failures

Contributing Factors:
Insufficient timeout handling
Weak dependency alerting

Recovery:
Disabled affected flow / rolled back / restored dependency path

Corrective Actions:
Improve timeout policy
Improve dependency monitoring
Add failure-mode testing
```

Do not turn the RCA into a blame document.

Focus on:

```text
System conditions
Technical causes
Process gaps
Detection gaps
Recovery gaps
Preventive actions
```

---

## Part 24 — Five Whys

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

---

## Part 25 — Corrective vs Preventive Actions

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

---

## Part 26 — Observability Security

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

---

## Part 27 — Cost of Observability

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

---

## Part 28 — Hands-On Practice

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

---

## Part 29 — Production Incident Lab

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

---

## Part 30 — Incident Command Exercise

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

---

## Part 31 — Senior/Lead Observability Review

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

---

## Part 32 — Day 35 Completion Criteria

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

---

## Part 33 — What Comes Next

Day 35 gives ShopSphere operational visibility.

Day 36 will move into **Terraform Enterprise Hardening and Infrastructure Governance**.

The project will shift from:

```text
Can we build infrastructure?
```

to:

```text
Can many engineers safely change infrastructure at scale?
```

You will work with:

```text
Terraform Repository Design
Remote State
State Isolation
Locking
Module Governance
Provider Versions
Version Pinning
CI/CD
Plan Review
Policy
Drift
Import
Secrets
Least Privilege
Cross-Account Deployment
Recovery
```

The goal is to make the infrastructure delivery process suitable for a larger engineering organization.

---

## Cleanup

Keep the core ShopSphere infrastructure and observability configuration for Day 36.

Remove only temporary incident-test resources and data.

Restore the application to the known-good version.

Record:

```text
Known-Good Git SHA:
Known-Good Image Digest:
Current Deployment:
Dashboard:
Alerts:
Open Incidents:
```

If you intentionally retain logs and telemetry for later exercises, document their retention and expected cost.

Do not leave intentionally broken alerts, health checks, or application versions active.
