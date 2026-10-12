# Day 41 — Production Simulation 01: The Production Deployment Incident

Day 40 completed the structured learning track. Day 41 begins the next phase: **production simulation**.

There will be less teaching and more decision-making.

You are now the DevOps engineer responsible for ShopSphere Production. The architecture exists. The pipelines exist. Kubernetes exists. Observability exists. Terraform exists.

Something has gone wrong.

Your job is not to guess the answer.

Your job is to:

```text
Understand the symptom
        ↓
Collect evidence
        ↓
Locate the failing layer
        ↓
Contain the impact
        ↓
Recover safely
        ↓
Verify
        ↓
Find root cause
        ↓
Prevent recurrence
```

Today's incident is intentionally realistic:

**A Production deployment has completed, but users are receiving 5xx responses.**

---

## Part 1 — The Incident

It is 10:15 AM.

ShopSphere's deployment pipeline reports:

```text
Production deployment: SUCCESS
```

The new application version has been deployed to EKS.

Five minutes later, monitoring reports:

```text
HTTP 5xx rate: increasing
Checkout success rate: decreasing
API latency: increasing
```

Customer support reports:

> “Some customers cannot place orders.”

The application Pods appear to be running.

You are the first DevOps engineer investigating.

Do not immediately rollback.

Your first responsibility is to understand the scope and severity of the incident.

---

## Part 2 — Establish Incident Context

Record:

```text
Incident Start:
Affected Service:
Affected Environment:
Deployment Version:
Previous Version:
Current Error Rate:
Affected Business Function:
Customer Impact:
```

Then determine:

```text
Is Production actually affected?
Are all users affected?
Are only orders affected?
Are product searches working?
Did the problem begin immediately after deployment?
```

This establishes the timeline before you start changing anything.

---

## Part 3 — Start With Symptoms

Your first evidence is:

```text
5xx ↑
Latency ↑
Checkout Success ↓
Pods:
Running
```

Do not conclude:

**“The Pods are healthy, therefore Kubernetes is healthy.”**

A running process can still be an unhealthy application.

Likewise:

**“The deployment succeeded, therefore the application is healthy.”**

Deployment success means the deployment mechanism completed its work. It does not prove that the business application works correctly.

---

## Part 4 — Check the Change Timeline

Your first high-value question is:

**What changed immediately before the incident?**

Inspect:

```text
Deployment
Configuration
Secrets
Infrastructure
Database
External Dependencies
```

Build a timeline:

```text
10:00
Production deployment begins

10:05
Deployment completes

10:08
5xx begins increasing

10:10
Checkout failures reported

10:15
Incident declared
```

A temporal relationship is evidence.

It is not yet proof of causation.

---

## Part 5 — Determine the Blast Radius

Check whether the failure affects:

```text
All API endpoints
Only checkout
Only authenticated users
Only new Pods
Only certain requests
Only one AZ
```

For example:

```text
GET /api/products
→ 200

GET /api/products/{id}
→ 200

POST /api/orders
→ 500
```

This is valuable evidence.

It suggests that the entire application may not be broken.

The failure may be concentrated around the order path.

---

## Part 6 — Check Kubernetes Workload Health

Start with:

```bash
kubectl get deployment shopsphere-api
kubectl get pods -o wide
kubectl get rs
kubectl get events --sort-by=.lastTimestamp
```

Look for:

```text
Desired replicas
Available replicas
Ready replicas
Restart count
Pod age
Node placement
Recent events
```

Then inspect an affected Pod:

```bash
kubectl describe pod <pod-name>
```

Do not change anything yet.

You are collecting evidence.

---

## Part 7 — Check Readiness

Now verify whether the Pods receiving traffic are actually ready.

```bash
kubectl get pods
kubectl get endpoints shopsphere-api
```

Compare:

```text
Running Pods
vs
Ready Pods
vs
Service Endpoints
```

The relationship should be:

```text
Deployment
 ↓
Pods
 ↓
Readiness
 ↓
Service Endpoints
 ↓
Traffic
```

If a Pod is running but not ready, it should not normally be part of the ready Service endpoints.

---

## Part 8 — Check the Service Path

Inspect:

```bash
kubectl get svc shopsphere-api
kubectl describe svc shopsphere-api
kubectl get endpoints shopsphere-api
```

Ask:

```text
Does the Service exist?
Does its selector match the Pods?
Does it have endpoints?
Are the endpoints healthy?
```

If the Service has healthy endpoints and requests are reaching the application, move deeper.

Do not continue changing Kubernetes networking if the evidence already shows that traffic is reaching the application.

---

## Part 9 — Check Ingress and Load Balancing

Now inspect the external path.

Conceptually:

```text
User
 ↓
DNS
 ↓
Load Balancer
 ↓
Ingress
 ↓
Service
 ↓
Pod
 ↓
Application
```

Check:

```text
Load Balancer health
Ingress configuration
Backend status
TLS
Routing rules
```

Determine whether:

```text
5xx originates at the edge
```

or:

```text
5xx originates from the application
```

This distinction can dramatically reduce the investigation scope.

---

## Part 10 — Check Application Logs

Now inspect the application.

```bash
kubectl logs <pod-name>
```

If multiple replicas exist, compare several Pods.

Look for:

```text
Exception
Timeout
Connection failure
Authentication failure
Database error
Configuration error
External API failure
```

If the application logs show:

```text
Database connection timeout
```

do not immediately restart Pods.

You have identified a more specific failure signal.

---

## Part 11 — Check Structured Logs

If ShopSphere uses structured logging, search by:

```text
timestamp
request ID
trace ID
endpoint
status code
exception
```

For example:

```text
request_id=abc123
endpoint=/api/orders
status=500
error=DatabaseTimeout
```

Follow the request through:

```text
Ingress
 ↓
Application
 ↓
Database
```

Correlation IDs help connect telemetry from different components.

---

## Part 12 — Check Distributed Tracing

If tracing is enabled, inspect a failed order request.

You may see:

```text
HTTP request
 ↓
Order Service
 ↓
Database query
 ↓
Timeout
```

Compare a successful request with a failed request.

For example:

```text
Successful:
API → DB = 25 ms

Failed:
API → DB = 5,000 ms timeout
```

This is much stronger evidence than simply saying:

**“The application is slow.”**

---

## Part 13 — Check the Database

The order endpoint depends on the database.

Check:

```text
Database availability
CPU
Memory
Connections
Connection saturation
Storage
Latency
Errors
```

Then ask:

```text
Is the database itself unhealthy?

Are connections exhausted?

Did the new application version increase connection usage?

Did a schema change occur?

Is the network path working?
```

Do not scale the application simply because requests are failing.

If the database is saturated, adding application replicas may make the problem worse.

---

## Part 14 — Check the Deployment Difference

Compare the old and new application versions.

You discover:

```text
v1.8
→ orders endpoint uses existing query

v1.9
→ orders endpoint introduces a new query
```

Now inspect:

```text
Database schema
Application migration
Query behavior
Indexes
Connection pool
```

Do not yet conclude that the query caused the incident.

Verify it.

---

## Part 15 — Check Database Compatibility

Suppose the new application expects:

```text
orders.customer_reference
```

but the Production database does not contain the expected column.

The new application may return:

```text
SQL error
 ↓
HTTP 500
```

This produces:

```text
Deployment:
Successful

Pods:
Running

Readiness:
Healthy

Application:
Broken for specific operation
```

This is an important production lesson:

**Infrastructure health does not guarantee application compatibility.**

---

## Part 16 — Incident Containment

At this point you have evidence that:

```text
Production
 ↓
New application version
 ↓
Order endpoint
 ↓
Database interaction
 ↓
Application errors
```

The priority is now customer impact.

Possible containment options include:

```text
Rollback application
Disable affected feature
Reduce traffic
Fix forward
Restore compatible schema
```

Choose the smallest safe action that restores the business function.

Do not make unrelated infrastructure changes during an incident.

---

## Part 17 — Decide: Roll Back or Fix Forward

Ask:

```text
Can the previous application version run safely?

Is the database schema backward compatible?

Is the failure isolated?

Can the fix be safely tested and deployed?

What is the fastest safe recovery?
```

If the previous application version remains compatible with the current database, rollback may be appropriate.

If the database has already changed incompatibly, rollback may not be safe.

This is why Day 34 emphasized:

**Application rollback and database rollback are different problems.**

---

## Part 18 — Execute a Kubernetes Rollback

Assume the database remains compatible with v1.8.

Check history:

```bash
kubectl rollout history deployment/shopsphere-api
```

Review the current rollout:

```bash
kubectl rollout status deployment/shopsphere-api
```

Then perform the controlled rollback:

```bash
kubectl rollout undo deployment/shopsphere-api
```

Monitor:

```bash
kubectl get pods -w
kubectl rollout status deployment/shopsphere-api
```

Do not declare recovery simply because the Pods become `Running`.

---

## Part 19 — Verify Recovery

Verify the actual business path.

Check:

```text
API health
Product browsing
Authentication
Order creation
Payment integration
Order retrieval
```

Then verify telemetry:

```text
5xx ↓
Latency ↓
Checkout success ↑
Database errors ↓
```

Recovery means:

**The customer-facing business function works again.**

Not:

**The deployment command succeeded.**

---

## Part 20 — Incident Communication

During an incident, communication should remain factual.

Example:

```text
10:15
Production checkout failures detected.

10:20
Investigation indicates failures began after application v1.9 deployment.

10:28
Order endpoint identified as affected path.

10:32
Database compatibility issue suspected.

10:35
Rollback initiated.

10:38
Error rate decreasing.

10:42
Checkout transaction verified successfully.

10:45
Incident mitigated.
```

Avoid unsupported statements such as:

```text
“The database definitely caused everything.”
```

until evidence establishes the causal chain.

---

## Part 21 — Root Cause Analysis

After recovery, investigate without the pressure of immediate customer impact.

Suppose the evidence shows:

```text
v1.9 introduced a new database dependency

Production migration was not applied

Order requests generated SQL errors

Readiness probe only checked application startup

Deployment therefore appeared healthy

Customers experienced order failures
```

The root cause is not merely:

**“Developer forgot the migration.”**

That is only part of the causal chain.

Ask why the system allowed the incompatible release to reach Production.

---

## Part 22 — Five Whys

Work through:

```text
Why did orders fail?
→ Application v1.9 expected unavailable database structure.

Why did v1.9 reach Production?
→ Deployment pipeline allowed the release.

Why was incompatibility not detected?
→ Migration compatibility was not validated.

Why was it not validated?
→ Database integration testing was incomplete.

Why was the release considered safe?
→ Deployment health checks measured process readiness rather than business compatibility.
```

Now you have several improvement opportunities.

---

## Part 23 — Corrective Actions

Possible corrective actions include:

```text
Database migration validation
Backward-compatible schema changes
Integration tests
Production-like UAT
Deployment health verification
Release gates
Migration ordering
Observability improvements
Runbook updates
```

Do not create 25 action items simply to make the RCA look thorough.

Prioritize actions that reduce recurrence probability or impact.

---

## Part 24 — Preventing the Same Incident

The pipeline should understand that:

```text
Application
+
Database
```

are part of one release system.

A stronger flow is:

```text
Build
 ↓
Test
 ↓
Database Compatibility Test
 ↓
Deploy to UAT
 ↓
Migration Validation
 ↓
Application Verification
 ↓
Production Approval
 ↓
Production
 ↓
Business Health Check
```

This shifts detection earlier.

---

## Part 25 — Improve Health Checks

The original readiness check may have been:

```text
HTTP /actuator/health
```

That is useful but may not prove that the order workflow works.

Do not turn readiness into a giant end-to-end transaction test.

Instead distinguish:

```text
Infrastructure Health
Application Health
Dependency Health
Business Health
```

For example:

```text
Readiness
→ Can this Pod safely receive normal traffic?

Synthetic Business Check
→ Can a representative customer workflow succeed?
```

Different signals answer different questions.

---

## Part 26 — Improve Deployment Gates

A stronger Production release can verify:

```text
Pod readiness
Error rate
Latency
Application logs
Database errors
Business transaction success
```

Then:

```text
New Version
 ↓
Small Traffic Exposure
 ↓
Observe
 ↓
Continue
```

This connects the incident to the deployment strategy from Day 34.

A deployment strategy is only useful if its health signals can detect the failures you care about.

---

## Part 27 — Cost of the Incident

Estimate the incident impact.

Consider:

```text
Customer impact
Lost orders
Engineering time
Support load
Cloud usage
Potential compensation
Reputation
```

Then compare that with the cost of prevention:

```text
Integration testing
Canary deployment
Better observability
Additional staging capacity
Automation
```

This is the same reliability-versus-cost reasoning from Day 39.

The cheapest infrastructure is not necessarily the cheapest system.

---

## Part 28 — What You Should Have Done First

Review your investigation.

The strongest sequence was:

```text
Confirm impact
 ↓
Establish timeline
 ↓
Check recent changes
 ↓
Determine blast radius
 ↓
Check workload
 ↓
Check traffic path
 ↓
Check application logs
 ↓
Check dependencies
 ↓
Form hypothesis
 ↓
Test hypothesis
 ↓
Contain
 ↓
Verify
```

Notice what is missing:

```text
Random restart
Random scaling
Random security change
Random Terraform apply
```

Production troubleshooting should reduce uncertainty.

---

## Part 29 — What Not to Do

During this incident, avoid:

```text
Restarting every Pod without evidence
Scaling everything
Changing security groups randomly
Changing routes randomly
Running terraform apply
Deleting the deployment
Changing database settings blindly
Disabling security controls
Adding AdministratorAccess
```

These actions can destroy evidence or increase the blast radius.

The first goal is:

**Stabilize without making the incident larger.**

---

## Part 30 — Final Incident Report

Create:

```text
INC-001-ShopSphere-Production-Deployment.md
```

Include:

```text
Incident Summary
Impact
Timeline
Detection
Affected Components
Evidence
Root Cause
Contributing Factors
Containment
Recovery
Verification
Corrective Actions
Preventive Actions
Owner
Priority
Lessons Learned
```

Keep facts separate from assumptions.

For example:

```text
Fact:
5xx increased after v1.9 deployment.

Evidence:
Application logs showed database errors.

Finding:
v1.9 required database structure unavailable in Production.

Contributing factor:
Deployment verification did not validate the affected business workflow.
```

---

## Part 31 — Senior/Lead Interview Recall

Answer these without looking back.

1. What should you do first when Production reports 5xx?
2. Why shouldn't you immediately rollback?
3. What does a successful Kubernetes deployment prove?
4. What does it not prove?
5. How do you distinguish infrastructure failure from application failure?
6. How do you determine blast radius?
7. What is the relationship between Pods, readiness, Services, and endpoints?
8. How do logs and traces help narrow the problem?
9. Why can adding application replicas make a database incident worse?
10. How do you decide between rollback and fix-forward?
11. Why can database changes make rollback unsafe?
12. How do you verify recovery?
13. What should a good incident timeline contain?
14. What is the difference between root cause and contributing factors?
15. How can deployment gates reduce recurrence?
16. Why isn't `/health` always enough?
17. How can canary deployment help?
18. What evidence would convince you that the database is the bottleneck?
19. What actions should you avoid during an uncertain incident?
20. How would you explain the incident to a non-technical stakeholder?

---

## Part 32 — Production Simulation Scorecard

Do not score yourself based on how many commands you remembered.

Evaluate whether you demonstrated:

```text
[ ] Established customer impact
[ ] Built an accurate timeline
[ ] Identified recent changes
[ ] Determined blast radius
[ ] Followed the request path
[ ] Checked Kubernetes health
[ ] Checked Service/endpoints
[ ] Checked application logs
[ ] Checked database/dependencies
[ ] Formed evidence-based hypotheses
[ ] Avoided random changes
[ ] Chose a safe containment action
[ ] Considered database compatibility
[ ] Recovered the service
[ ] Verified business functionality
[ ] Communicated the incident clearly
[ ] Identified root cause
[ ] Identified contributing factors
[ ] Created corrective actions
[ ] Connected prevention to CI/CD
[ ] Connected prevention to observability
[ ] Connected incident impact to cost
```

The important progression is:

**Command-driven troubleshooting → evidence-driven troubleshooting.**

---

## Part 33 — What This Simulation Taught

This incident connects several earlier lessons.

```text
Day 07
Deployment Strategies
        ↓
Rollback / traffic control

Day 15
Kubernetes Troubleshooting
        ↓
Service / endpoints / Pods

Day 20
Observability
        ↓
Metrics / logs / traces

Day 34
Safe Deployments
        ↓
Health / rollback / compatibility

Day 35
Incident Response
        ↓
Timeline / RCA / recovery

Day 39
DR + Cost
        ↓
Business impact / prevention economics
```

The technologies are not separate subjects anymore.

They form one operational system.

---

## Part 34 — The Lead-Level Question

After the incident, do not stop at:

**“How do we prevent this exact bug?”**

Ask:

**“How do we make this class of failure harder to introduce and easier to detect?”**

That may lead to:

```text
Backward-compatible database migrations
+
Integration testing
+
Canary releases
+
Business-level telemetry
+
Automated release gates
```

This is the difference between fixing an incident and improving a platform.

---

## Part 35 — Day 41 Completion Criteria

Complete Day 41 when you can:

```text
[ ] Investigate the incident without immediately guessing
[ ] Establish customer impact
[ ] Build a timeline
[ ] Determine blast radius
[ ] Trace the request path
[ ] Inspect Kubernetes state
[ ] Inspect Service/endpoints
[ ] Inspect application logs
[ ] Use metrics/traces
[ ] Investigate database dependencies
[ ] Correlate deployment with failure
[ ] Form and test hypotheses
[ ] Choose containment
[ ] Decide rollback vs fix-forward
[ ] Consider database compatibility
[ ] Execute recovery
[ ] Verify business functionality
[ ] Communicate incident status
[ ] Write an RCA
[ ] Identify root cause
[ ] Identify contributing factors
[ ] Define corrective actions
[ ] Improve release controls
[ ] Improve observability
[ ] Explain the incident at Senior/Lead interview level
```

The most important completion criterion is:

**When Production is failing, you can move from symptom → evidence → layer → root cause → safe recovery without making the situation worse.**

---

## Part 36 — What Comes Next

Day 41 simulated an application deployment incident.

Day 42 will deliberately remove one of the assumptions that made today's investigation possible:

**The network will fail.**

You will investigate a ShopSphere outage where:

```text
Pods are Running
Application is Healthy
Database is Healthy
```

but customers still cannot reach the application.

You will have to determine whether the failure is:

```text
DNS
Load Balancer
Ingress
Route
Security Group
NetworkPolicy
Service
Endpoint
```

The key lesson will be:

**A healthy application is useless if the network cannot deliver traffic to it.**

---

## Cleanup

Restore ShopSphere to the known-good Production version.

Verify:

```text
Application version
Healthy Pods
Healthy Services
Healthy endpoints
Normal 5xx rate
Normal latency
Healthy database
Healthy business transactions
No temporary debugging changes
No temporary permissions
No disabled security controls
```

Preserve the incident report.

Record:

```text
Incident ID:
Affected Version:
Root Cause:
Recovery Method:
Time to Detect:
Time to Mitigate:
Time to Recover:
Customer Impact:
Corrective Actions:
Preventive Actions:
Known-Good Commit:
```

The final operational habit from Day 41 is:

**Do not troubleshoot Production by changing things until something works. Troubleshoot by reducing uncertainty until the safest change becomes clear.**

## Answers to practice

### 1. What should you do first when Production reports 5xx?

<details>
<summary>Answer</summary>

Establish scope and severity. Record start time, service, environment, versions, error rate, and which business function fails.

Confirm Production is affected, who is hit, and whether the problem started after the deploy. Do not roll back yet.

</details>

### 2. Why shouldn't you immediately rollback?

<details>
<summary>Answer</summary>

Pipeline SUCCESS and Running Pods do not prove the new release caused the 5xx. A dependency, database, or partial blast radius may be the issue.

Rollback without evidence can hide the cause or break a schema that already moved. Collect timeline and blast radius first.

</details>

### 3. What does a successful Kubernetes deployment prove?

<details>
<summary>Answer</summary>

The deploy mechanism finished: rollout applied, Pods scheduled. ShopSphere at 10:05 reported SUCCESS.

It does not prove checkout works.

</details>

### 4. What does it not prove?

<details>
<summary>Answer</summary>

It does not prove users can place orders, that `/api/orders` is compatible with the database, or that readiness equals business health.

Deployment success ≠ application correctness.

</details>

### 5. How do you distinguish infrastructure failure from application failure?

<details>
<summary>Answer</summary>

If products return 200 and only `POST /api/orders` returns 500, the platform path likely works. Logs and traces then show SQL or timeout on the order path.

If Ingress, Service, or all endpoints fail, start at the network. Match the layer to the symptom.

</details>

### 6. How do you determine blast radius?

<details>
<summary>Answer</summary>

Test endpoints, auth vs anonymous, new vs old Pods, request types, and AZs. Example: products 200, orders 500.

Narrow failure means contain the order path, not restart the whole cluster.

</details>

### 7. Relationship between Pods, readiness, Services, and endpoints

<details>
<summary>Answer</summary>

Deployment creates Pods. Readiness decides who may receive traffic. The Service selector fills endpoints. Traffic hits ready endpoints only.

Running but not Ready should stay off the Service. That is traffic control.

</details>

### 8. How do logs and traces help narrow the problem?

<details>
<summary>Answer</summary>

Metrics say 5xx and latency rose. Structured logs give `endpoint=/api/orders` and `error=DatabaseTimeout`. A trace shows API→DB at 5,000 ms vs 25 ms on success.

You stop saying “the app is slow” and name the hop.

</details>

### 9. Why can adding application replicas make a database incident worse?

<details>
<summary>Answer</summary>

More Pods open more connections. If the database or pool is saturated, extra replicas increase pressure.

Scale the bottleneck. Do not scale the symptom.

</details>

### 10. How do you decide between rollback and fix-forward?

<details>
<summary>Answer</summary>

Ask: can v1.8 run on the current schema? Is the failure isolated? Can a fix be tested faster than rollback? What is the fastest safe recovery?

If the schema still fits v1.8, roll back. If the database already changed incompatibly, rollback may be unsafe — fix forward or restore a compatible schema.

</details>

### 11. Why can database changes make rollback unsafe?

<details>
<summary>Answer</summary>

Application rollback and database rollback are different. If v1.9 required `orders.customer_reference` and that change already landed, v1.8 may fail too.

Expand-and-contract keeps both versions viable. Check compatibility before `kubectl rollout undo`.

</details>

### 12. How do you verify recovery?

<details>
<summary>Answer</summary>

Prove the customer path: health, browse, auth, create order, payment, retrieve order. Then watch 5xx down, latency down, checkout up, database errors down.

Recovery is the business function working, not Pods `Running`.

</details>

### 13. What should a good incident timeline contain?

<details>
<summary>Answer</summary>

Factual times only: deploy start 10:00, complete 10:05, 5xx 10:08, checkout reports 10:10, incident 10:15, then later contain, rollback, verified order, mitigated.

Do not write “the database definitely caused everything” until the chain is proven.

</details>

### 14. Difference between root cause and contributing factors

<details>
<summary>Answer</summary>

Root cause here: v1.9 expected a database structure that Production did not have, so order SQL failed. “Developer forgot the migration” is incomplete.

Contributing: no compatibility test, readiness only checked startup, UAT did not run the order path, so an incompatible release looked healthy.

</details>

### 15. How can deployment gates reduce recurrence?

<details>
<summary>Answer</summary>

Treat app plus database as one release. Add compatibility tests, UAT migration validation, then Production approval, then a business health check.

Detection moves left. Process readiness is not the gate.

</details>

### 16. Why isn't `/health` always enough?

<details>
<summary>Answer</summary>

`/actuator/health` can pass while `/api/orders` returns 500. That is infrastructure or process health, not business health.

Keep readiness small: can this Pod take traffic? Use a synthetic checkout check as a separate signal. Do not stuff an end-to-end purchase into readiness.

</details>

### 17. How can canary deployment help?

<details>
<summary>Answer</summary>

Send a small share to v1.9, watch error rate, latency, logs, database errors, and checkout success. Stop if those diverge.

A strategy only helps if its signals catch the failures you care about.

</details>

### 18. What evidence would convince you the database is the bottleneck?

<details>
<summary>Answer</summary>

DB CPU, memory, connections near max, slow queries, locks, or traces showing API→DB timeouts while other hops are fast. A new version that opens more connections is a clue.

Do not conclude from app 5xx alone. Adding replicas would then make it worse.

</details>

### 19. What actions should you avoid during an uncertain incident?

<details>
<summary>Answer</summary>

Do not restart every Pod, scale everything, change SGs or routes, run `terraform apply`, delete the Deployment, tune the database blindly, disable security, or attach AdministratorAccess.

Those destroy evidence or widen blast radius. Stabilize without making it larger.

</details>

### 20. How would you explain the incident to a non-technical stakeholder?

<details>
<summary>Answer</summary>

At 10:15 some customers could not place orders after a Production release. We confirmed browse still worked. We rolled back to the last good version after we knew the database still accepted it.

Orders work again. We will add tests so a release cannot ship without the matching database change.

</details>

### 21. Decide: first investigation moves (no rollback yet)

<details>
<summary>Answer</summary>

Confirm impact. Build the timeline (10:00 deploy, 10:05 success, 10:08 5xx). Check what changed. Measure blast radius (orders 500, products 200).

Running Pods and pipeline SUCCESS are not health. Do not guess; reduce uncertainty.

</details>

### 22. Decide: containment for this incident

<details>
<summary>Answer</summary>

Evidence chain: new version → order endpoint → database interaction → app errors. Smallest safe action that restores checkout.

If v1.8 still fits the schema, roll back. Do not change unrelated Terraform, SGs, or cluster size during the incident.

</details>

### 23. RCA: why the system allowed the incompatible release

<details>
<summary>Answer</summary>

v1.9 added a database dependency. Production migration was not applied. Order SQL failed. Readiness only checked startup, so the rollout looked healthy. Customers failed on orders.

Ask why the platform let that class of release through, not only who forgot a script.

</details>

### 24. Five Whys

<details>
<summary>Answer</summary>

Orders failed because v1.9 expected missing structure. v1.9 reached Prod because the pipeline allowed it. Incompatibility was not detected because migration was not validated. Tests were incomplete. The release looked safe because health measured process readiness, not business compatibility.

Several improvements fall out of those whys.

</details>

### 25. Corrective and preventive actions

<details>
<summary>Answer</summary>

Prioritize: migration validation, expand-and-contract schema, integration tests, production-like UAT, business health on release, ordered migrations, better order-path alerts, runbook update.

Do not write 25 tasks for show. Pick what cuts recurrence or impact.

</details>

### 26. Stronger pipeline and health signals (expected outcome)

<details>
<summary>Answer</summary>

Build → test → database compatibility test → UAT → migration validation → app verify → Prod approval → Prod → business health check.

Readiness: safe to receive traffic. Synthetic: representative checkout. Canary: small traffic, observe, then continue.

</details>

### 27. Cost of the incident vs prevention

<details>
<summary>Answer</summary>

Count lost orders, engineer time, support, possible compensation, reputation. Compare with integration tests, canary, observability, and staging capacity.

The cheapest cluster is not the cheapest system. Same reliability-versus-cost reasoning as Day 39.

</details>

### 28. What you should have done first vs random change

<details>
<summary>Answer</summary>

Confirm impact → timeline → recent changes → blast radius → workload and traffic path → logs → dependencies → hypothesis → test → contain → verify.

Missing on purpose: random restart, scale, SG change, `terraform apply`. Troubleshooting reduces uncertainty.

</details>

### 29. Final incident report (expected content)

<details>
<summary>Answer</summary>

`INC-001-ShopSphere-Production-Deployment.md`: summary, impact, timeline, detection, components, evidence, root cause, contributing factors, containment, recovery, verification, corrective/preventive actions, owner, priority, lessons.

Fact: 5xx rose after v1.9. Evidence: database errors in logs. Finding: v1.9 needed structure Prod lacked. Contributing: deploy checks missed the order workflow. Keep facts apart from assumptions.

</details>

### 30. Lead-level question: prevent the class of failure

<details>
<summary>Answer</summary>

Do not stop at this bug. Make incompatible app-plus-schema releases harder to ship and easier to see: expand-and-contract, integration tests, canary, business telemetry, automated gates.

That improves the platform, not only one incident.

</details>
