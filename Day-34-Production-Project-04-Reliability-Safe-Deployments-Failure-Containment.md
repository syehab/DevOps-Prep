# Day 34 — Production Project 04: Reliability, Safe Deployments & Failure Containment

Day 33 established the ShopSphere delivery pipeline. Day 34 changes the question from **“Can we deploy?”** to **“Can we change Production safely?”**. A reliable deployment is not simply a successful pipeline run: the new version must start correctly, pass meaningful health checks, receive traffic safely, remain observable, and have a recovery path if its behavior is wrong. Today you will connect deployment strategy, application behavior, load balancing, capacity, database compatibility, graceful shutdown, rollback, and incident response into one production model.

---

## Part 1 — Reliability Starts Before Deployment

Reliability is the ability of a system to continue providing its required behavior despite expected failures and changes. Deployment is one of the most common causes of application incidents because it deliberately changes running software, configuration, dependencies, and sometimes database schemas. A reliable release process therefore reduces the amount of change exposed at one time, verifies the new version before broad traffic exposure, and keeps a known-good recovery path. The exact strategy depends on the workload, but the reasoning pattern remains the same.

Think about a release as:

```text
Known Good
    ↓
Introduce Change
    ↓
Validate
    ↓
Expose Traffic
    ↓
Observe
    ↓
Continue
       OR
Recover
```

The key question is:

**How much Production can be affected before we know the release is unhealthy?**

---

## Part 2 — Deployment Is a Traffic Problem

A deployment changes which software version receives user requests.

For a simple service:

```text
Load Balancer
     ↓
 ┌───┴────┐
 ▼        ▼
v1       v1
```

During a deployment, you might move toward:

```text
Load Balancer
     ↓
 ┌───┴────┐
 ▼        ▼
v1       v2
```

Eventually:

```text
Load Balancer
     ↓
 ┌───┴────┐
 ▼        ▼
v2       v2
```

The important question is not just whether v2 started.

It is:

**When should v2 become eligible for user traffic?**

That decision should depend on readiness and health, not merely process startup.

---

## Part 3 — Rolling Deployment

A rolling deployment gradually replaces old capacity with new capacity.

Conceptually:

```text
Start:
v1 v1 v1 v1

Step 1:
v2 v1 v1 v1

Step 2:
v2 v2 v1 v1

Step 3:
v2 v2 v2 v1

Finish:
v2 v2 v2 v2
```

The advantage is that you do not need to run the entire old and new environments simultaneously.

The risk is that old and new versions coexist temporarily. They may behave differently, use different configuration, or expect different database schemas.

Capacity is also important. If you start v2 before stopping v1, you may temporarily need more compute.

A rolling deployment is therefore a combination of:

```text
Replacement Order
+
Capacity
+
Health Checks
+
Traffic Control
+
Rollback Behavior
```

---

## Part 4 — Blue/Green Deployment

Blue/green keeps two versions available.

```text
Blue
v1
 │
 └─────┐
       ▼
    Traffic

Green
v2
```

You validate v2 before moving normal traffic to it.

Conceptually:

```text
Build v2
   ↓
Deploy Green
   ↓
Health / Smoke Tests
   ↓
Traffic Switch
   ↓
Observe
```

The major advantage is a relatively clear separation between the old and new environments.

The trade-off is resource usage and state management. Running two application environments may cost more, and databases or external dependencies can make the switch more complicated.

Blue/green is not automatically “safer.” Its safety depends on how validation, traffic switching, data compatibility, and rollback are designed.

---

## Part 5 — Canary Deployment

Canary deployment exposes a new version to a small portion of traffic before broader rollout.

For example:

```text
100% → v1

        ↓

95% → v1
 5% → v2

        ↓

50% → v1
50% → v2

        ↓

100% → v2
```

The value is controlled blast radius.

If v2 produces errors, only a portion of users may be affected before the rollout is stopped.

Canary deployment becomes powerful when combined with measurable release signals:

```text
Error Rate
Latency
Success Rate
Business Metrics
```

The hard part is deciding **what signal should stop the rollout**.

A canary without meaningful automated observation is simply a complicated partial deployment.

---

## Part 6 — Choose a Strategy Using Requirements

Do not memorize:

```text
Rolling = X
Blue/Green = Y
Canary = Z
```

Instead ask:

```text
How much capacity do we have?
How quickly must rollback happen?
Can two application versions coexist?
Can the database support both versions?
How much traffic control do we have?
How expensive is duplicate capacity?
How risky is the change?
How good are our health signals?
```

For example:

A small internal application with simple stateless behavior may be well served by rolling deployment.

A high-risk customer-facing release may benefit from controlled traffic exposure.

A release requiring a rapid traffic switch may make blue/green attractive.

The strategy is an engineering decision based on failure tolerance and operational capability.

---

## Part 7 — Health Checks Are Release Controls

Health checks decide whether a workload should receive traffic.

A weak health check might only verify:

```text
HTTP process responds
```

A more meaningful check may verify that the application is initialized and capable of serving its intended function.

Think in layers:

```text
Process
 ↓
Container
 ↓
Application
 ↓
Required Dependencies
 ↓
User Request
```

But be careful.

If the health endpoint requires every external dependency to be available, a temporary failure in one dependency can cause every application instance to become unhealthy.

Health checks therefore need deliberate semantics.

Ask:

**What does “healthy enough to receive traffic” actually mean for ShopSphere?**

---

## Part 8 — Graceful Shutdown

During a deployment, old application instances may be terminated.

If they immediately stop accepting and processing work, active requests can fail.

A graceful shutdown attempts to:

```text
Stop New Requests
       ↓
Allow Active Requests to Finish
       ↓
Close Connections
       ↓
Exit
```

This matters for Spring Boot applications behind a load balancer.

The complete deployment interaction can be:

```text
Load Balancer
 ↓
Stop Sending New Traffic
 ↓
Application Draining
 ↓
Active Requests Finish
 ↓
Process Stops
```

Graceful shutdown is therefore part of availability engineering, not simply an application configuration detail.

---

## Part 9 — Connection Draining

Suppose the load balancer is sending traffic to an application instance that is about to be replaced.

If the load balancer immediately removes the instance and the process exits immediately, active requests may be interrupted.

Connection draining gives existing connections time to complete.

Think about:

```text
Traffic Arrival
 ↓
Target Healthy
 ↓
Deployment Starts
 ↓
Target Removed From New Traffic
 ↓
Existing Requests Drain
 ↓
Target Terminates
```

The exact implementation differs between platforms and load balancers.

The architectural principle is:

**Stop new traffic before terminating capacity that may still be serving active requests.**

---

## Part 10 — Capacity During Deployment

Suppose Production normally runs:

```text
4 application tasks
```

A rolling deployment may temporarily require:

```text
4 old
+
2 new
=
6 tasks
```

If the environment has insufficient capacity, the deployment may stall or fail.

This is why deployment strategy and capacity planning are connected.

Ask:

```text
How many old instances?
How many new instances?
Maximum temporary capacity?
Minimum healthy capacity?
Available compute?
```

A production deployment should not unexpectedly consume all available capacity.

---

## Part 11 — Database Compatibility

Database changes are often more difficult to roll back than application binaries.

Suppose v1 expects:

```text
orders.customer_name
```

and v2 changes the schema to:

```text
customer_first_name
customer_last_name
```

If v2 is deployed while v1 is still running, v1 may fail.

A safer approach is often an additive migration:

```text
Step 1
Add new column

Step 2
Deploy code that can use both forms

Step 3
Migrate data

Step 4
Switch fully to new field

Step 5
Remove old field later
```

This is commonly called an expand-and-contract style migration.

The important principle is:

**Application deployment and database migration must be compatible during the transition period.**

---

## Part 12 — Rollback vs Roll Forward

Rollback means returning to a previous known-good version.

Roll forward means fixing the problem and deploying a corrected version.

Rollback is attractive when:

```text
Previous version is known-good
Previous version remains compatible
Recovery is fast
Database changes are compatible
```

Roll forward may be safer when:

```text
Database migration cannot be reversed
Previous version cannot work with the current schema
The defect is configuration-related
The fix is small and well understood
```

Do not make rollback an automatic response.

First ask:

**Is the previous version actually compatible with the current system state?**

---

## Part 13 — Release Failure Scenario

Suppose ShopSphere v2 is deployed.

Five minutes later:

```text
5xx ↑
Latency ↑
CPU normal
Memory normal
Database healthy
```

The pipeline says:

```text
Deployment successful
```

Do not assume the infrastructure is healthy simply because deployment succeeded.

Investigate:

```text
Release timing
 ↓
Affected version
 ↓
Load Balancer
 ↓
Application logs
 ↓
Dependency calls
 ↓
Error patterns
```

Suppose logs show:

```text
PaymentClientException
```

Now investigate the payment dependency.

If only v2 produces the error, the release itself becomes a strong suspect.

The next decision is whether to:

```text
Stop rollout
Rollback
Roll forward
```

Use evidence.

---

## Part 14 — Failure Containment

Failure containment means limiting how much of the system is affected by a problem.

Examples include:

```text
Canary traffic
Separate environments
Availability Zones
Circuit breakers
Timeouts
Rate limits
Bulkheads
Least privilege
Network segmentation
```

These mechanisms solve different problems, but they share one idea:

**Prevent one failure from becoming a larger failure.**

At Lead level, always ask:

**If this component fails, what else can it take down?**

That is the blast-radius question.

---

## Part 15 — Timeouts and Retries

Suppose ShopSphere calls a payment service.

If the payment service becomes slow and your application waits forever, application threads can become exhausted.

A timeout limits how long the application waits.

A retry can help with transient failures, but uncontrolled retries can make an outage worse.

For example:

```text
ShopSphere
   ↓
Payment Service
   ↓
Slow
```

If 1,000 requests each retry five times, the dependency may receive thousands of additional requests.

This is why retries should be bounded and designed with backoff where appropriate.

The Senior/Lead principle is:

**Reliability mechanisms can amplify failures if they are not controlled.**

---

## Part 16 — Circuit Breaker Concept

A circuit breaker prevents repeated calls to a failing dependency.

Conceptually:

```text
Normal
 ↓
Calls Allowed

Repeated Failures
 ↓
Circuit Opens
 ↓
Calls Blocked / Fast Fail

Recovery Evidence
 ↓
Circuit Tests Dependency
 ↓
Normal
```

This protects the application from spending all its resources waiting for a dependency that is already failing.

You do not need to implement a circuit breaker today unless your application uses a suitable library.

The important requirement is that you understand the failure mode it addresses.

---

## Part 17 — Incident Response During Deployment

When a deployment causes an incident, use a structured sequence:

```text
Detect
 ↓
Assess Impact
 ↓
Contain
 ↓
Diagnose
 ↓
Recover
 ↓
Verify
 ↓
Communicate
 ↓
RCA
```

Do not begin by changing five components simultaneously.

For example:

```text
5xx increased
```

First establish:

```text
When did it begin?
Which version changed?
Which endpoints are affected?
How many users?
Is the problem isolated to one AZ?
Is one dependency failing?
```

This separates **incident response** from **root-cause analysis**.

During the incident, restore service first when appropriate.

Then investigate the deeper cause.

---

## Part 18 — Failure Drill: Canary

Deploy v2 to a small percentage of traffic.

Introduce an application defect that increases 5xx responses.

Observe:

```text
v1:
healthy

v2:
5xx elevated
```

The desired response is:

```text
Stop rollout
 ↓
Keep majority on v1
 ↓
Investigate v2
 ↓
Recover
```

Record the release metrics.

Then ask:

**What threshold should automatically stop the rollout?**

Do not invent a universal threshold.

The correct threshold depends on the application's normal error rate, business criticality, traffic volume, and SLOs.

---

## Part 19 — Failure Drill: Rolling Deployment Capacity

Start with a small number of application tasks.

Configure a deployment that temporarily requires additional capacity.

Observe:

```text
Old capacity
+
New capacity
```

Now intentionally restrict available compute capacity.

Observe what the deployment does.

Determine whether:

```text
New tasks cannot start
Deployment stalls
Healthy capacity falls
Traffic becomes constrained
```

Then restore capacity.

This exercise teaches why deployment configuration cannot be separated from infrastructure capacity.

---

## Part 20 — Failure Drill: Database Compatibility

Create a small schema change that demonstrates compatibility concerns.

For example:

```text
v1:
reads column A

v2:
reads column B
```

Now imagine v1 and v2 coexist during a rolling deployment.

Ask:

**Can both versions operate against the same database simultaneously?**

If not, redesign the migration.

The objective is not to create a dangerous Production database migration.

The objective is to understand why:

```text
Application Version
+
Database Version
+
Deployment Strategy
```

must be considered together.

---

## Part 21 — Failure Drill: Rollback

Deploy a deliberately faulty application version.

Allow it to become visible to traffic.

Then execute your rollback procedure.

Record:

```text
Failure detected at:
Version:
Image digest:
Affected environment:
Rollback target:
Rollback action:
Recovery time:
Health after rollback:
```

Then verify the application.

Do not define recovery as:

```text
Rollback command completed
```

Define it as:

```text
Users can successfully use the application again.
```

---

## Part 22 — Release Metrics

Track release-related metrics.

Useful examples include:

```text
Deployment Frequency
Lead Time for Changes
Change Failure Rate
Time to Restore
Rollback Frequency
Deployment Duration
```

For ShopSphere, also inspect:

```text
5xx rate
Latency
Availability
Health-check failures
Task startup time
Database errors
```

These metrics connect delivery engineering with operational reliability.

The purpose is not to create a dashboard full of numbers.

The purpose is to answer:

**Are our changes becoming safer or more dangerous?**

---

## Part 23 — Architecture Decision Exercise

Suppose ShopSphere has:

```text
10,000 requests/minute
99.9% availability target
High-value checkout transactions
Frequent deployments
Stateless application
Relational database
```

Compare three approaches:

```text
Rolling
Blue/Green
Canary
```

Do not choose one because it is universally superior.

Instead document:

```text
Traffic control
Capacity requirement
Rollback speed
Database compatibility
Operational complexity
Cost
Failure blast radius
Observability requirement
```

Then select an approach for the current requirements and document why.

Your answer should follow:

**Requirement → Decision → Reason → Trade-off → Recovery plan**

---

## Part 24 — Production Deployment Runbook

Create:

```text
docs/deployment-runbook.md
```

Include:

### Before Deployment

```text
Confirm artifact
Confirm image digest
Confirm tests
Confirm security checks
Confirm database compatibility
Confirm capacity
Confirm rollback target
```

### During Deployment

```text
Deploy
Monitor health
Monitor errors
Monitor latency
Monitor traffic
```

### After Deployment

```text
Verify application
Verify database behavior
Verify business-critical endpoints
Observe for defined period
```

### If Deployment Fails

```text
Stop rollout
Assess impact
Contain
Rollback or roll forward
Verify
Document
```

The runbook should be executable by another engineer without requiring you to explain every step verbally.

---

## Part 25 — Architecture Review: Where Can This System Fail?

Review ShopSphere from the user backward:

```text
User
 ↓
DNS
 ↓
Load Balancer
 ↓
Application
 ↓
Database
 ↓
External Dependencies
```

Then review the deployment path:

```text
Git
 ↓
CI
 ↓
Registry
 ↓
Deployment
 ↓
Runtime
```

For each layer, identify:

```text
Failure
Detection
Blast Radius
Recovery
```

For example:

```text
Application
Failure:
Bad release

Detection:
5xx / logs / health checks

Blast Radius:
Potentially all traffic

Recovery:
Stop rollout / rollback
```

Do this for at least five components.

---

## Part 26 — Senior/Lead Interview Recall

Answer these without looking back.

1. What makes a deployment reliable?
2. Why is deployment fundamentally a traffic-management problem?
3. Explain rolling deployment.
4. Explain blue/green deployment.
5. Explain canary deployment.
6. What determines which strategy you choose?
7. Why are health checks important?
8. What makes a health check poorly designed?
9. What is graceful shutdown?
10. Why does connection draining matter?
11. Why can deployments temporarily require more capacity?
12. Why do database migrations complicate rollback?
13. Explain expand-and-contract migration.
14. When would roll forward be safer than rollback?
15. How can retries make an outage worse?
16. What problem does a circuit breaker address?
17. What is failure containment?
18. How would you investigate a deployment-related 5xx increase?
19. What metrics would you watch during a release?
20. What evidence would tell you to stop a canary rollout?

---

## Part 27 — Day 34 Completion Criteria

Complete Day 34 when you can demonstrate:

```text
[ ] Rolling deployment understood
[ ] Blue/green understood
[ ] Canary understood
[ ] Deployment strategy selection explained
[ ] Health checks designed
[ ] Graceful shutdown understood
[ ] Connection draining understood
[ ] Deployment capacity considered
[ ] Database compatibility considered
[ ] Rollback vs roll-forward understood
[ ] Timeout/retry failure mode understood
[ ] Circuit breaker concept understood
[ ] Failure containment understood
[ ] Incident response sequence documented
[ ] Canary failure drill completed
[ ] Capacity failure drill completed
[ ] Database compatibility exercise completed
[ ] Rollback drill completed
[ ] Deployment metrics identified
[ ] Deployment runbook written
[ ] Architecture failure review completed
```

The most important completion criterion is:

**You can explain how a new version moves from zero traffic to Production traffic, how you know it is healthy, what can fail during the transition, how you contain the failure, and how you recover.**

---

## Part 28 — What Comes Next

Day 34 made deployments safer.

Day 35 will focus on **observability and production incident response**.

The project will move from:

```text
Deploy Safely
```

to:

```text
Know What Is Happening
```

You will build:

```text
Metrics
Logs
Traces
Dashboards
Alerts
Correlation IDs
SLIs
SLOs
Error Budgets
Incident Investigation
RCA
```

Then you will use the telemetry from ShopSphere to investigate realistic incidents rather than simply looking at whether a server is “up.”

---

## Cleanup

Keep the core ShopSphere environment because it will be reused on Day 35.

Remove only temporary resources created specifically for deployment experiments.

Restore the application to the known-good release.

Record:

```text
Known-Good Git SHA:
Known-Good Image Digest:
Deployment Strategy:
Current Version:
Health Status:
```

Do not leave a deliberately broken release running for the next project day.
