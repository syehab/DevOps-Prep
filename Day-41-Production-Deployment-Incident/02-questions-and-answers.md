# Day 41 — Questions and answers

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Then answer each item below before you open the Answer block. After that, do the lab in [03-implementation.md](03-implementation.md).

Write your own answer first. Open the Answer block only after you try. Keep the original numbering.

---

## 1. What should you do first when Production reports 5xx?

**Interview Recall**

Answer these without looking back.

1. What should you do first when Production reports 5xx?

<details>
<summary>Answer</summary>

Establish scope and severity. Record start time, service, environment, versions, error rate, and which business function fails.

Confirm Production is affected, who is hit, and whether the problem started after the deploy. Do not roll back yet.

</details>

---

## 2. Why shouldn't you immediately rollback?

**Interview Recall**

Answer these without looking back.

2. Why shouldn't you immediately rollback?

<details>
<summary>Answer</summary>

Pipeline SUCCESS and Running Pods do not prove the new release caused the 5xx. A dependency, database, or partial blast radius may be the issue.

Rollback without evidence can hide the cause or break a schema that already moved. Collect timeline and blast radius first.

</details>

---

## 3. What does a successful Kubernetes deployment prove?

**Interview Recall**

Answer these without looking back.

3. What does a successful Kubernetes deployment prove?

<details>
<summary>Answer</summary>

The deploy mechanism finished: rollout applied, Pods scheduled. ShopSphere at 10:05 reported SUCCESS.

It does not prove checkout works.

</details>

---

## 4. What does it not prove?

**Interview Recall**

Answer these without looking back.

4. What does it not prove?

<details>
<summary>Answer</summary>

It does not prove users can place orders, that `/api/orders` is compatible with the database, or that readiness equals business health.

Deployment success ≠ application correctness.

</details>

---

## 5. How do you distinguish infrastructure failure from application failure?

**Interview Recall**

Answer these without looking back.

5. How do you distinguish infrastructure failure from application failure?

<details>
<summary>Answer</summary>

If products return 200 and only `POST /api/orders` returns 500, the platform path likely works. Logs and traces then show SQL or timeout on the order path.

If Ingress, Service, or all endpoints fail, start at the network. Match the layer to the symptom.

</details>

---

## 6. How do you determine blast radius?

**Interview Recall**

Answer these without looking back.

6. How do you determine blast radius?

<details>
<summary>Answer</summary>

Test endpoints, auth vs anonymous, new vs old Pods, request types, and AZs. Example: products 200, orders 500.

Narrow failure means contain the order path, not restart the whole cluster.

</details>

---

## 7. What is the relationship between Pods, readiness, Services, and endpoints?

**Interview Recall**

Answer these without looking back.

7. What is the relationship between Pods, readiness, Services, and endpoints?

<details>
<summary>Answer</summary>

Deployment creates Pods. Readiness decides who may receive traffic. The Service selector fills endpoints. Traffic hits ready endpoints only.

Running but not Ready should stay off the Service. That is traffic control.

</details>

---

## 8. How do logs and traces help narrow the problem?

**Interview Recall**

Answer these without looking back.

8. How do logs and traces help narrow the problem?

<details>
<summary>Answer</summary>

Metrics say 5xx and latency rose. Structured logs give `endpoint=/api/orders` and `error=DatabaseTimeout`. A trace shows API→DB at 5,000 ms vs 25 ms on success.

You stop saying “the app is slow” and name the hop.

</details>

---

## 9. Why can adding application replicas make a database incident worse?

**Interview Recall**

Answer these without looking back.

9. Why can adding application replicas make a database incident worse?

<details>
<summary>Answer</summary>

More Pods open more connections. If the database or pool is saturated, extra replicas increase pressure.

Scale the bottleneck. Do not scale the symptom.

</details>

---

## 10. How do you decide between rollback and fix-forward?

**Interview Recall**

Answer these without looking back.

10. How do you decide between rollback and fix-forward?

<details>
<summary>Answer</summary>

Ask: can v1.8 run on the current schema? Is the failure isolated? Can a fix be tested faster than rollback? What is the fastest safe recovery?

If the schema still fits v1.8, roll back. If the database already changed incompatibly, rollback may be unsafe — fix forward or restore a compatible schema.

</details>

---

## 11. Why can database changes make rollback unsafe?

**Interview Recall**

Answer these without looking back.

11. Why can database changes make rollback unsafe?

<details>
<summary>Answer</summary>

Application rollback and database rollback are different. If v1.9 required `orders.customer_reference` and that change already landed, v1.8 may fail too.

Expand-and-contract keeps both versions viable. Check compatibility before `kubectl rollout undo`.

</details>

---

## 12. How do you verify recovery?

**Interview Recall**

Answer these without looking back.

12. How do you verify recovery?

<details>
<summary>Answer</summary>

Prove the customer path: health, browse, auth, create order, payment, retrieve order. Then watch 5xx down, latency down, checkout up, database errors down.

Recovery is the business function working, not Pods `Running`.

</details>

---

## 13. What should a good incident timeline contain?

**Interview Recall**

Answer these without looking back.

13. What should a good incident timeline contain?

<details>
<summary>Answer</summary>

Factual times only: deploy start 10:00, complete 10:05, 5xx 10:08, checkout reports 10:10, incident 10:15, then later contain, rollback, verified order, mitigated.

Do not write “the database definitely caused everything” until the chain is proven.

</details>

---

## 14. What is the difference between root cause and contributing factors?

**Interview Recall**

Answer these without looking back.

14. What is the difference between root cause and contributing factors?

<details>
<summary>Answer</summary>

Root cause here: v1.9 expected a database structure that Production did not have, so order SQL failed. “Developer forgot the migration” is incomplete.

Contributing: no compatibility test, readiness only checked startup, UAT did not run the order path, so an incompatible release looked healthy.

</details>

---

## 15. How can deployment gates reduce recurrence?

**Interview Recall**

Answer these without looking back.

15. How can deployment gates reduce recurrence?

<details>
<summary>Answer</summary>

Treat app plus database as one release. Add compatibility tests, UAT migration validation, then Production approval, then a business health check.

Detection moves left. Process readiness is not the gate.

</details>

---

## 16. Why isn't `/health` always enough?

**Interview Recall**

Answer these without looking back.

16. Why isn't `/health` always enough?

<details>
<summary>Answer</summary>

`/actuator/health` can pass while `/api/orders` returns 500. That is infrastructure or process health, not business health.

Keep readiness small: can this Pod take traffic? Use a synthetic checkout check as a separate signal. Do not stuff an end-to-end purchase into readiness.

</details>

---

## 17. How can canary deployment help?

**Interview Recall**

Answer these without looking back.

17. How can canary deployment help?

<details>
<summary>Answer</summary>

Send a small share to v1.9, watch error rate, latency, logs, database errors, and checkout success. Stop if those diverge.

A strategy only helps if its signals catch the failures you care about.

</details>

---

## 18. What evidence would convince you that the database is the bottleneck?

**Interview Recall**

Answer these without looking back.

18. What evidence would convince you that the database is the bottleneck?

<details>
<summary>Answer</summary>

DB CPU, memory, connections near max, slow queries, locks, or traces showing API→DB timeouts while other hops are fast. A new version that opens more connections is a clue.

Do not conclude from app 5xx alone. Adding replicas would then make it worse.

</details>

---

## 19. What actions should you avoid during an uncertain incident?

**Interview Recall**

Answer these without looking back.

19. What actions should you avoid during an uncertain incident?

<details>
<summary>Answer</summary>

Do not restart every Pod, scale everything, change SGs or routes, run `terraform apply`, delete the Deployment, tune the database blindly, disable security, or attach AdministratorAccess.

Those destroy evidence or widen blast radius. Stabilize without making it larger.

</details>

---

## 20. How would you explain the incident to a non-technical stakeholder?

**Interview Recall**

Answer these without looking back.

20. How would you explain the incident to a non-technical stakeholder?

<details>
<summary>Answer</summary>

At 10:15 some customers could not place orders after a Production release. We confirmed browse still worked. We rolled back to the last good version after we knew the database still accepted it.

Orders work again. We will add tests so a release cannot ship without the matching database change.

</details>

---

## 21. Decide: first investigation moves (no rollback yet)

A Production deployment has completed, but users are receiving 5xx responses.

The pipeline reports `Production deployment: SUCCESS`. Pods appear to be running. Five minutes later, 5xx rate increases, checkout success decreases, and API latency increases. Customer support reports that some customers cannot place orders.

Do not immediately rollback.

Your first responsibility is to understand the scope and severity of the incident.

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

Decide your first investigation moves. Do not guess. Reduce uncertainty.

<details>
<summary>Answer</summary>

Confirm impact. Build the timeline (10:00 deploy, 10:05 success, 10:08 5xx). Check what changed. Measure blast radius (orders 500, products 200).

Running Pods and pipeline SUCCESS are not health. Do not guess; reduce uncertainty.

</details>

---

## 22. Decide: containment for this incident

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

<details>
<summary>Answer</summary>

Evidence chain: new version → order endpoint → database interaction → app errors. Smallest safe action that restores checkout.

If v1.8 still fits the schema, roll back. Do not change unrelated Terraform, SGs, or cluster size during the incident.

</details>

---

## 23. RCA: why the system allowed the incompatible release

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

<details>
<summary>Answer</summary>

v1.9 added a database dependency. Production migration was not applied. Order SQL failed. Readiness only checked startup, so the rollout looked healthy. Customers failed on orders.

Ask why the platform let that class of release through, not only who forgot a script.

</details>

---

## 24. Five Whys

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

Now you have several improvement opportunities. Write the Five Whys and the improvements that fall out of them.

<details>
<summary>Answer</summary>

Orders failed because v1.9 expected missing structure. v1.9 reached Prod because the pipeline allowed it. Incompatibility was not detected because migration was not validated. Tests were incomplete. The release looked safe because health measured process readiness, not business compatibility.

Several improvements fall out of those whys.

</details>

---

## 25. Corrective and preventive actions

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

<details>
<summary>Answer</summary>

Prioritize: migration validation, expand-and-contract schema, integration tests, production-like UAT, business health on release, ordered migrations, better order-path alerts, runbook update.

Do not write 25 tasks for show. Pick what cuts recurrence or impact.

</details>

---

## 26. Stronger pipeline and health signals (expected outcome)

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

Describe the stronger pipeline and health signals you would put in place.

<details>
<summary>Answer</summary>

Build → test → database compatibility test → UAT → migration validation → app verify → Prod approval → Prod → business health check.

Readiness: safe to receive traffic. Synthetic: representative checkout. Canary: small traffic, observe, then continue.

</details>

---

## 27. Cost of the incident vs prevention

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

<details>
<summary>Answer</summary>

Count lost orders, engineer time, support, possible compensation, reputation. Compare with integration tests, canary, observability, and staging capacity.

The cheapest cluster is not the cheapest system. Same reliability-versus-cost reasoning as Day 39.

</details>

---

## 28. What you should have done first vs random change

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

<details>
<summary>Answer</summary>

Confirm impact → timeline → recent changes → blast radius → workload and traffic path → logs → dependencies → hypothesis → test → contain → verify.

Missing on purpose: random restart, scale, SG change, `terraform apply`. Troubleshooting reduces uncertainty.

</details>

---

## 29. Final incident report (expected content)

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

<details>
<summary>Answer</summary>

`INC-001-ShopSphere-Production-Deployment.md`: summary, impact, timeline, detection, components, evidence, root cause, contributing factors, containment, recovery, verification, corrective/preventive actions, owner, priority, lessons.

Fact: 5xx rose after v1.9. Evidence: database errors in logs. Finding: v1.9 needed structure Prod lacked. Contributing: deploy checks missed the order workflow. Keep facts apart from assumptions.

</details>

---

## 30. Lead-level question: prevent the class of failure

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

<details>
<summary>Answer</summary>

Do not stop at this bug. Make incompatible app-plus-schema releases harder to ship and easier to see: expand-and-contract, integration tests, canary, business telemetry, automated gates.

That improves the platform, not only one incident.

</details>

---

## Production Simulation Scorecard

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
