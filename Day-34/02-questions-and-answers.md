# Day 34 — Questions and answers

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Then answer each item below before you open the Answer block. After that, do the lab in [03-implementation.md](03-implementation.md).

Write your own answer first. Open the Answer block only after you try. Keep the original numbering.

---

## 1. What makes a deployment reliable?

**Interview Recall**

Answer these without looking back.

1. What makes a deployment reliable?

<details>
<summary>Answer</summary>

A reliable release limits how much Production changes at once. It validates the new version before broad traffic and keeps a known-good recovery path.

Pipeline green is not enough. Users must still get the required behavior.

</details>

---

## 2. Why is deployment a traffic-management problem?

**Interview Recall**

2. Why is deployment fundamentally a traffic-management problem?

<details>
<summary>Answer</summary>

A deploy changes which version receives requests. The question is when v2 becomes eligible for user traffic.

That decision uses readiness and health, not process start.

</details>

---

## 3. Explain rolling deployment

**Interview Recall**

3. Explain rolling deployment.

<details>
<summary>Answer</summary>

Rolling replaces old capacity in steps: `v1 v1 v1 v1` → mix → `v2 v2 v2 v2`. You do not run two full environments.

Risk: versions coexist, schema must fit both, and extra compute may be needed while old and new overlap.

</details>

---

## 4. Explain blue/green deployment

**Interview Recall**

4. Explain blue/green deployment.

<details>
<summary>Answer</summary>

Blue serves v1. Green starts v2, passes health and smoke tests, then traffic switches. Rollback can switch back if the schema still fits.

Trade-off is duplicate capacity and harder shared state. Blue/green is not automatically safer.

</details>

---

## 5. Explain canary deployment

**Interview Recall**

5. Explain canary deployment.

<details>
<summary>Answer</summary>

Canary sends a small share of traffic to v2, then widens if signals stay good. Blast radius stays limited if v2 errors.

Without error rate, latency, and business metrics, a canary is only a partial deploy.

</details>

---

## 6. What determines which strategy you choose?

**Interview Recall**

6. What determines which strategy you choose?

<details>
<summary>Answer</summary>

Ask capacity, rollback speed, whether two versions can coexist, database compatibility, traffic control, cost, change risk, and health-signal quality.

A small internal API may roll. High-risk checkout may canary. Need a fast switch → consider blue/green.

</details>

---

## 7. Why are health checks important?

**Interview Recall**

7. Why are health checks important?

<details>
<summary>Answer</summary>

They decide whether a workload receives traffic. Weak checks only prove a process answers HTTP.

ShopSphere `/health` should mean “healthy enough to serve,” with deliberate dependency rules.

</details>

---

## 8. What makes a health check poorly designed?

**Interview Recall**

8. What makes a health check poorly designed?

<details>
<summary>Answer</summary>

Too weak: Java is up while checkout is dead. Too strict: one optional dependency fails and every instance leaves the load balancer.

Write the meaning of healthy on purpose.

</details>

---

## 9. What is graceful shutdown?

**Interview Recall**

9. What is graceful shutdown?

<details>
<summary>Answer</summary>

Stop new requests, finish in-flight work, close connections, then exit. The load balancer must stop sending first.

This is availability engineering, not a Spring Boot footnote.

</details>

---

## 10. Why does connection draining matter?

**Interview Recall**

10. Why does connection draining matter?

<details>
<summary>Answer</summary>

If the load balancer drops a target and the process dies at once, active requests fail.

Stop new traffic, drain existing connections, then terminate. Stop new work before you stop capacity.

</details>

---

## 11. Why can deployments temporarily require more capacity?

**Interview Recall**

11. Why can deployments temporarily require more capacity?

<details>
<summary>Answer</summary>

Rolling may run old plus new tasks together. Four v1 plus two v2 needs six tasks.

If compute is short, the deploy stalls or healthy capacity falls. Strategy and capacity planning are one design.

</details>

---

## 12. Why do database migrations complicate rollback?

**Interview Recall**

12. Why do database migrations complicate rollback?

<details>
<summary>Answer</summary>

Binaries roll back easily. Schema often does not. If v2 renamed columns, v1 may not run on the new schema.

Ask whether the previous version still fits current data before you roll back.

</details>

---

## 13. Explain expand-and-contract migration

**Interview Recall**

13. Explain expand-and-contract migration.

<details>
<summary>Answer</summary>

Add the new column. Deploy code that understands both forms. Migrate data. Switch fully. Remove the old field later.

App version, database version, and deploy strategy must stay compatible during the overlap.

</details>

---

## 14. When would roll forward be safer than rollback?

**Interview Recall**

14. When would roll forward be safer than rollback?

<details>
<summary>Answer</summary>

When the schema cannot reverse, v1 cannot run on current data, the defect is a small known config fix, or rollback would break more.

Rollback is not automatic. Check compatibility first.

</details>

---

## 15. How can retries make an outage worse?

**Interview Recall**

15. How can retries make an outage worse?

<details>
<summary>Answer</summary>

If payment is slow and 1,000 requests each retry five times, the dependency gets thousands of extra calls.

Bound retries and use backoff. Reliability controls can amplify failure.

</details>

---

## 16. What problem does a circuit breaker address?

**Interview Recall**

16. What problem does a circuit breaker address?

<details>
<summary>Answer</summary>

Repeated calls to a failing dependency waste threads. After enough failures the circuit opens and calls fail fast.

After recovery evidence, it tests the dependency and closes again.

</details>

---

## 17. What is failure containment?

**Interview Recall**

17. What is failure containment?

<details>
<summary>Answer</summary>

Limit how much a problem can take down. Canary share, AZ isolation, timeouts, circuit breakers, bulkheads, least privilege, and network segments all do this.

Ask: if this component fails, what else dies?

</details>

---

## 18. How would you investigate a deployment-related 5xx increase?

**Interview Recall**

18. How would you investigate a deployment-related 5xx increase?

<details>
<summary>Answer</summary>

Pipeline success is not health. Check release time, version, load balancer, logs, dependency calls, and error types.

If only v2 logs `PaymentClientException`, stop the rollout, then roll back or roll forward from evidence.

</details>

---

## 19. What metrics would you watch during a release?

**Interview Recall**

19. What metrics would you watch during a release?

<details>
<summary>Answer</summary>

5xx rate, latency, availability, health-check failures, task startup time, and database errors. Also DORA: deploy frequency, lead time, change failure rate, time to restore.

Ask whether changes are getting safer.

</details>

---

## 20. What evidence would tell you to stop a canary rollout?

**Interview Recall**

20. What evidence would tell you to stop a canary rollout?

<details>
<summary>Answer</summary>

v2 error rate, latency, or checkout success diverges from v1 beyond the threshold you set from SLOs and normal noise.

There is no universal number. Stop widening traffic, keep majority on v1, then recover.

</details>

---

## 21. DORA: which metrics are speed vs stability, and why they move together

**Exit Check**

Answered without looking back.

1. Which two DORA metrics measure speed, which two measure stability, and why do they tend to improve together?

<details>
<summary>Answer</summary>

Speed: Deployment Frequency and Lead Time for Changes. Stability: Change Failure Rate and Time to Restore.

Small batches plus automated verification make releases faster and failures rarer. Healthy teams do not buy speed by dropping stability.

</details>

---

## 22. High change failure rate and slow restore — first two practices

**Exit Check**

2. A team's Change Failure Rate is high and its Time to Restore is measured in hours. What two delivery practices from this Day would you introduce first, and why?

<details>
<summary>Answer</summary>

Add automated pipeline tests so bad artifacts fail before Production. Switch to small, frequent releases so a bad change is easy to find and roll back.

Those two habits cut failure rate and restore time together.

</details>

---

## 23. Failure drill: canary

**Failure Drill: Canary**

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

<details>
<summary>Answer</summary>

Send a small share to a defective v2. v1 stays healthy. v2 5xx rises. Stop rollout, keep majority on v1, investigate, recover.

Set the auto-stop threshold from normal error rate, criticality, volume, and SLOs.

</details>

---

## 24. Failure drill: rolling capacity

**Failure Drill: Rolling Deployment Capacity**

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

<details>
<summary>Answer</summary>

Start few tasks. Configure a deploy that needs extra capacity, then restrict compute. New tasks may not start, the deploy may stall, or healthy capacity may fall.

Restore capacity. Deployment config and infrastructure capacity are one problem.

</details>

---

## 25. Failure drill: database compatibility

**Failure Drill: Database Compatibility**

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

<details>
<summary>Answer</summary>

v1 reads column A. v2 reads column B. During a rolling mix both hit the same database. If both cannot run, redesign with expand-and-contract.

Do not run a dangerous Prod migration. Learn the three-way coupling: app, schema, strategy.

</details>

---

## 26. Failure drill: rollback

**Failure Drill: Rollback**

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

<details>
<summary>Answer</summary>

Deploy a faulty version into traffic. Record detect time, digest, environment, rollback target, action, recovery time, and health after.

Recovery means users can use the app again, not that the rollback command completed.

</details>

---

## 27. Architecture decision: rolling vs blue/green vs canary

**Architecture Decision Exercise**

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

<details>
<summary>Answer</summary>

ShopSphere: 10,000 req/min, 99.9% availability, high-value checkout, frequent deploys, stateless app, relational DB.

Canary fits high-value traffic if you have error/latency/business signals and compatible schema. Rolling is simpler and cheaper but mixes versions. Blue/green switches fast but costs duplicate capacity. Write requirement → decision → reason → trade-off → recovery.

</details>

---

## 28. Production deployment runbook (expected outcome)

**Production Deployment Runbook**

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

<details>
<summary>Answer</summary>

`docs/deployment-runbook.md`: confirm digest, tests, schema, capacity, and rollback target. During: deploy and watch health, errors, latency, traffic. After: verify app, DB, and checkout for a defined period.

On failure: stop rollout, contain, roll back or forward, verify, document. Another engineer must be able to run it.

</details>

---

## 29. Architecture review: where can this system fail?

**Architecture Review: Where Can This System Fail?**

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

<details>
<summary>Answer</summary>

Walk user → DNS → load balancer → app → database → external deps, then Git → CI → registry → deploy → runtime. For each: failure, detection, blast radius, recovery.

Example: bad release → 5xx/logs/health → potentially all traffic → stop rollout or rollback. Do at least five components.

</details>

---

## 30. Incident response during deployment

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

Explain that sequence. Say what you would do first, and what you would leave for RCA.

<details>
<summary>Answer</summary>

Detect → assess impact → contain → diagnose → recover → verify → communicate → RCA. Do not change five things at once.

Ask when it started, which version, which endpoints, how many users, AZ vs dependency. Restore service first. Prove root cause after.

</details>
