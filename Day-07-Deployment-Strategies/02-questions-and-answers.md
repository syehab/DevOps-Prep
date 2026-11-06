# Day 7 — Questions and answers

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Then answer each item below before you open the Answer block. After that, do the lab in [03-implementation.md](03-implementation.md).

Write your own answer first. Open the Answer block only after you try. Keep the original numbering.

---

## 1. How many users see v2 immediately

# 01 · What Is a Deployment Strategy · 6 min

### 🧪 Exercise

Take a simple application:

`v1 → v2`

Write down:

1. How many users see v2 immediately?

**Think:** deployment strategy is mainly about **risk and traffic movement**.

<details>
<summary>Answer</summary>

It depends on the strategy, because a strategy controls traffic movement and risk. If you replace every instance at once, all users see v2 immediately. In a rolling deployment, only users who hit the updated instances see v2 while the rest still see v1.

In blue-green, no users see v2 until you switch traffic, then almost all of them do. In canary, only a small percentage see v2 at first, such as 5%. Choose the strategy by how much of the user base you will expose in one step.

</details>

---

## 2. Whether v1 can remain available

2. Can v1 remain available?

<details>
<summary>Answer</summary>

Yes, if the strategy keeps v1 running while v2 comes in. Rolling keeps some v1 instances until the rollout finishes. Canary keeps most traffic on v1. Blue-green keeps Blue on v1 until you switch, and often after that as a rollback target.

v1 does not remain available if you stop every v1 instance before v2 is ready. That all-at-once replace is simple, but a problem in v2 then affects everyone at once.

</details>

---

## 3. How to return users to v1

3. How would you return users to v1?

<details>
<summary>Answer</summary>

Return users by moving traffic or instances back to v1, using the same strategy you used to go forward. In blue-green, switch the load balancer back to Blue. In canary, send 100% of traffic back to v1 and stop sending users to v2.

In rolling, put v1 back on the instances that already moved to v2. Do not only “stop a new server,” because you may have replaced live instances in place. Also check that v1 can still use the current database and configuration.

</details>

---

## 4. Unhealthy v2 after the first two rolling instances

# 02 · Rolling Deployment · 8 min

### 🧪 Exercise

Imagine 4 instances:

```text
Before:

v1  v1  v1  v1
```

Update two instances:

```text
During:

v2  v2  v1  v1
```

Then complete:

```text
After:

v2  v2  v2  v2
```

Answer:

- What happens if v2 is unhealthy after the first two instances?

**Senior point:** rolling deployment needs **health checks and rollback control**.

<details>
<summary>Answer</summary>

Stop the rollout. Two instances already run unhealthy v2, and two still run v1. Users who hit the v2 instances see errors. Health checks should mark those instances unhealthy.

Restore v1 on the instances that already moved. Do not continue replacing the remaining v1 instances. Rolling deployment needs health checks and rollback control for this exact moment.

</details>

---

## 5. Why rolling rollback is harder than stopping a new server

- Why might rollback be harder than simply stopping a new server?

<details>
<summary>Answer</summary>

You already replaced instances in the live fleet. Rollback means you must put v1 back onto those instances. You cannot only stop a new server, because you converted existing servers in place.

v1 and v2 also run together until the fleet is one version again. Mixed versions make behavior harder to reason about during the rollback. Blue-green is quicker here, because Blue can still hold v1 untouched.

</details>

---

## 6. Local Blue-Green lab

# 03 · Blue-Green Deployment · 8 min

### 🧪 Exercise

Create this locally:

```text
Blue  → http://localhost:8081 → "Version 1"
Green → http://localhost:8082 → "Version 2"
```

Use a simple server or container for each version.

**Think:** Blue-Green separates **deployment** from **traffic switching**.

<details>
<summary>Answer</summary>

Run two versions at the same time. Keep deployment separate from the traffic switch.

1. Start v1 so it listens on `http://localhost:8081` and returns `Version 1`.
2. Start v2 so it listens on `http://localhost:8082` and returns `Version 2`.
3. Treat `8081` as Blue (current) and `8082` as Green (new).
4. Send local “user” requests to Blue first. Confirm the response is Version 1.
5. Test Green on `8082` before you switch. Do not send users there yet.
6. Switch traffic by sending requests to `8082` instead of `8081`.
7. If Green fails, send requests back to `8081`. Blue still runs v1.

Use a simple server, a Spring Boot app, or a container for each version. The ports are the two environments. You are the load balancer.

</details>

---

## 7. Which version receives users before the Blue-Green switch

1. Which version receives users before the switch?

<details>
<summary>Answer</summary>

Blue receives users before the switch. Blue runs v1 on `http://localhost:8081`. Green already has v2 on `8082`, but traffic stays on Blue until you change the destination.

That is the point of blue-green: you can deploy and validate Green without moving users yet. Deployment and traffic switching are separate acts.

</details>

---

## 8. What to test on Green before the switch

2. What would you test on Green?

<details>
<summary>Answer</summary>

Test that Green actually serves v2 and looks healthy before any user traffic moves. Call `http://localhost:8082` and confirm the body is `Version 2`. Check start-up, a health endpoint if you have one, and basic application behavior.

You test Green while Blue still serves users. If Green fails these checks, do not switch. Keep traffic on Blue.

</details>

---

## 9. Where traffic goes if Green fails

3. If Green fails, where would traffic go?

<details>
<summary>Answer</summary>

Send traffic back to Blue. Blue still runs v1, so rollback is a traffic switch, not a rebuild. Users return to `http://localhost:8081` / Version 1.

Keep Blue available until Green has proved itself. The main cost of this model is capacity for both environments at the same time.

</details>

---

## 10. Whether to increase canary v2 traffic immediately

# 04 · Canary Deployment · 8 min

### 🧪 Exercise

Suppose v2 receives 5% of traffic.

Monitor:

- Error rate
- Response time
- CPU / memory
- Application logs

Now imagine v1 has a 1% error rate and v2 has a 7% error rate.

Answer:

1. Would you increase v2 traffic immediately?

**Senior point:** Canary is not simply "send 5% traffic." It is **controlled exposure + observation + decision**.

<details>
<summary>Answer</summary>

No. Do not increase v2 traffic. v1 has a 1% error rate and v2 has a 7% error rate. That gap is evidence of a regression, not a reason to expose more users.

Canary is controlled exposure, observation, and then a decision. A worse error rate says: stop widening the canary. Check evidence next, then reduce or remove v2 traffic if the problem holds.

</details>

---

## 11. Evidence to check before a canary decision

2. What evidence would you check before deciding?

<details>
<summary>Answer</summary>

Compare v2 with v1 on the same window, not v2 in isolation. Check error rate, response time, CPU and memory, and application logs. Confirm that the 7% figure is real, repeatable, and coming from requests that actually hit v2.

Look at sample size and whether one dependency failure explains the gap. Increase traffic only when this evidence says v2 behaves at least as well as v1.

</details>

---

## 12. What to do with v2 if the canary problem is confirmed

3. What would you do with v2 if the problem is confirmed?

<details>
<summary>Answer</summary>

Stop sending users to v2. Route 100% of traffic back to v1. Leave v2 out of the path until you have a fix. Do not promote the canary.

Then decide rollback versus roll forward. If v1 is still safe with the current database and config, keep v1. If you must fix forward, deploy a new version as a new canary. Do not skip observation.

</details>

---

## 13. Recreate rolling, blue-green, and canary locally

## 05 · Recreate the Three Strategies · 10–15 min

Use a simple Spring Boot application, Docker containers, or even two small local HTTP servers.

Create:

```text
v1 → "Hello from Version 1"
v2 → "Hello from Version 2"
```

Then simulate:

### Rolling

Run multiple v1 instances and replace them one by one.

```text
v1 v1 v1 v1
 ↓
v2 v1 v1 v1
 ↓
v2 v2 v1 v1
 ↓
v2 v2 v2 v1
 ↓
v2 v2 v2 v2
```

### Blue-Green

Run both versions at the same time:

```text
Blue  → v1
Green → v2
```

Change the traffic destination from Blue to Green.

### Canary

Keep both versions running:

```text
95% → v1
5%  → v2
```

You can simulate the percentage locally rather than building a real production traffic router.

**The objective is not the tooling. The objective is to see how traffic and application versions change.**

<details>
<summary>Answer</summary>

Use a simple Spring Boot app, Docker containers, or two small local HTTP servers. v1 returns `Hello from Version 1`. v2 returns `Hello from Version 2`. The objective is to see traffic and versions change. Do not build a production router.

**Rolling**

1. Run four v1 instances.
2. Replace one instance with v2. Keep the other three on v1.
3. Repeat one instance at a time until all four run v2.
4. Watch mixed v1 and v2 during the change.

**Blue-green**

1. Run Blue as v1 and Green as v2 at the same time.
2. Send all local traffic to Blue.
3. Validate Green.
4. Change the traffic destination from Blue to Green.

**Canary**

1. Keep v1 and v2 running.
2. Send most requests to v1 (simulate 95%).
3. Send a few requests to v2 (simulate 5%).
4. Watch errors and response time before you increase v2.

When you finish, stop and remove local containers if you used Docker: `docker ps`, then `docker stop` and `docker rm`.

</details>

---

## 14. Rollback versus roll forward

# 06 · Rollback vs Roll Forward · 6 min

### 🧪 Exercise

Consider:

```text
v1 → Database schema A
v2 → Database schema B
```

You deploy v2 and the application fails.

**Senior point:** rollback must consider **application code + database + configuration + infrastructure**, not just the application binary.

<details>
<summary>Answer</summary>

A **rollback** returns traffic or deployment state to the previous version. A **roll forward** fixes the problem and deploys a new version instead of returning to the old one. Rollback sounds simple, but it must consider application code, database, configuration, and infrastructure, not only the binary.

If v2 changed the database to schema B and v1 only understands schema A, sending traffic back to v1 may not be safe. In that case, deploying v3 that works with schema B can be safer than rolling back.

</details>

---

## 15. Whether v1 can safely use schema B

- Can v1 safely use schema B?

<details>
<summary>Answer</summary>

Not necessarily. v1 was built for schema A. If schema B removes or changes fields that v1 still reads or writes, v1 can fail or corrupt data. Rollback of the application is then unsafe even if the v1 artifact still exists.

v1 can use schema B only when the database change is backward compatible. For example, you added columns and kept the old ones. Always ask this before you switch traffic back.

</details>

---

## 16. Whether the database change can be reversed

- Can the database change be reversed?

<details>
<summary>Answer</summary>

Only sometimes. You can reverse a change when the old structure still exists and the data still fits schema A. The reverse script must not destroy needed rows. You cannot safely reverse a change after a destructive rewrite, a dropped column, or a transform you cannot undo.

If the database cannot go back, do not roll the application back to v1. Plan a forward fix that works with schema B.

</details>

---

## 17. Whether deploying v3 is safer than rolling back

- Would deploying v3 be safer than rolling back?

<details>
<summary>Answer</summary>

Yes, when v1 cannot safely use schema B or you cannot reverse the database change. v3 is a roll-forward: a new application version that understands the current schema and fixes the failure.

Choose v3 over rollback when the platform and data have already moved past v1. Choose rollback when v1 can still run on the current database, configuration, and infrastructure.

</details>

---

## 18. Zero-downtime sequence from `full_name` to `first_name` and `last_name`

# 07 · Database Changes & Zero-Downtime · 6 min

### 🧪 Exercise

Suppose v1 uses:

```text
full_name
```

You want v2 to use:

```text
first_name
last_name
```

Design a safe sequence that allows v1 and v2 to run together.

**Think:** if two application versions can run at the same time, their shared dependencies must also support that transition.

<details>
<summary>Answer</summary>

Use expand → migrate → contract so v1 and v2 can run together. Do not replace `full_name` in one step.

1. **Expand.** Add `first_name` and `last_name`. Keep `full_name`.
2. **Deploy a dual-write app.** The new version can read and write old and new columns. v1 can still use `full_name`.
3. **Migrate.** Backfill `first_name` and `last_name` from `full_name`. Move traffic and data gradually.
4. **Contract.** Deploy a version that uses only the new columns. Remove `full_name` later.

Zero-downtime needs the old and new application versions to coexist. Their shared database must support that transition too.

</details>

---

## 19. Strategy for a small internal application on 3 VMs

# 08 · Deployment Strategy Decision · 5 min

### 🧪 Exercise

Choose a strategy for each scenario and explain **why**, not just the name.

**A.** Small internal application with 3 VMs

There is no need to memorize a "correct" answer. Explain the factors that influenced your choice.

<details>
<summary>Answer</summary>

Use **rolling**. You need a simple gradual replacement on a small fleet. Updating one VM at a time avoids taking all three down at once. Health checks still matter, because v1 and v2 will run together during the change.

Blue-green is usually extra cost here: you would need capacity for a second full environment. Canary is extra process: small internal traffic rarely needs percentage-based production observation. Rolling matches the risk and the capacity.

</details>

---

## 20. Strategy for a customer-facing payment API

**B.** Customer-facing payment API

<details>
<summary>Answer</summary>

Use **blue-green** when you need a fast traffic switch and easy rollback. A payment API has high business risk. Mixed v1 and v2 during a long rolling rollout can cause inconsistent payment behavior. Blue keeps v1 ready. You switch to Green only after validation, and you can switch back quickly.

If you also need a small live sample before the full switch, use **canary** with strong monitoring, then finish with a full switch. Do not pick rolling only because it is familiar. Explain capacity, rollback speed, and whether two versions can safely handle payments at the same time.

</details>

---

## 21. Strategy to observe a new release with a small user group

**C.** Large application where you want to observe a new release with a small user group

<details>
<summary>Answer</summary>

Use **canary**. Send a small percentage of production traffic to v2, such as 5%, and keep the rest on v1. Watch error rate, response time, CPU, memory, and logs. Increase v2 traffic only when the evidence is good.

This is controlled exposure plus observation plus a decision. Rolling replaces instances without a deliberate small user group. Blue-green switches everyone at once after the cut.

</details>

---

## 22. Where the Azure DevOps YAML builds the application

# 09 · Azure DevOps Deployment Flow · 5 min

### 🧪 Exercise

Look at the YAML and identify:

- Where is the application built?

**Key idea:** the pipeline is the delivery mechanism; the deployment strategy is the **release behavior**.

<details>
<summary>Answer</summary>

The application is built in the `Build` stage. That stage has job `Build` and a step that runs `mvn clean package`. That command creates the package later environments will deploy.

No later stage in this YAML compiles the application again.

</details>

---

## 23. Which stage deploys to Dev

- Which stage deploys to Dev?

<details>
<summary>Answer</summary>

`DeployDev` deploys to Dev. It `dependsOn: Build`, uses a deployment job against `environment: dev`, and runs `echo "Deploy to DEV"`. The pipeline controls when and where this happens.

The target platform still controls how traffic moves between versions. That is the deployment strategy, not the stage name.

</details>

---

## 24. Which stage deploys to Prod

- Which stage deploys to Prod?

<details>
<summary>Answer</summary>

`DeployProd` deploys to Prod. It `dependsOn: DeployDev`, uses `environment: prod`, and deploys the existing artifact. Production is a later stage, not a second build.

The pipeline is the delivery mechanism. The deployment strategy is the release behavior after that stage starts.

</details>

---

## 25. Why Prod should use the existing artifact instead of rebuilding

- Why should Prod use the existing artifact instead of rebuilding?

<details>
<summary>Answer</summary>

Prod should deploy the artifact that already passed Build and Dev. A rebuild can create a different output from the version you tested. You then lose the chain from commit → build → known artifact → Production.

Build once in the `Build` stage. Promote that same artifact. Environment configuration can change. The software version should not.

</details>

---

## 26. First three evidence checks after a canary failure

## 10 · Failure & Reason · 5 min

Scenario:

> Deployment of v2 completed successfully, but users are reporting errors.

Do not immediately redeploy.

Investigate:

```text
Did deployment succeed?
        ↓
Are instances healthy?
        ↓
Is traffic reaching v2?
        ↓
Are error rates increasing?
        ↓
Are dependencies healthy?
        ↓
Is the problem code, config, database or infrastructure?
        ↓
Rollback or fix forward?
```

### 🧪 Exercise

Imagine:

```text
v1 → 0.8% errors
v2 → 8% errors
```

You deployed v2 using Canary.

Write down the **first three pieces of evidence** you would check before changing anything.

**Senior habit:** deployment success and application success are two different things.

<details>
<summary>Answer</summary>

Do not redeploy immediately. Deployment success and application success are different. v1 at 0.8% errors and v2 at 8% errors is a signal to investigate, not to push more traffic.

Check these three first, before you change anything:

1. Instance health. Confirm v2 instances are up and health checks pass or fail.
2. Traffic path. Confirm the failing requests actually reach v2, not v1 or a dependency in front.
3. Application logs for v2. Read the errors and see whether the cause is code, config, database, or infrastructure.

Then decide rollback or fix forward. Do not skip evidence.

</details>

---

## 27. What problem a deployment strategy solves

## 14 · Exit Check · 5 min

Answer without looking:

1. What problem does a deployment strategy solve?

<details>
<summary>Answer</summary>

A deployment strategy defines how the new application version replaces the old version. It answers how much traffic goes to the new version, how quickly users move, and what happens if the new version fails.

The problem is not “how do I copy files.” The problem is how to expose a change safely, detect trouble quickly, and recover. Replacing every instance at once is simple, but a defect then hits everyone immediately.

</details>

---

## 28. How Rolling differs from Blue-Green

2. How is Rolling different from Blue-Green?

<details>
<summary>Answer</summary>

**Rolling** updates instances in small groups in the same fleet. Some instances run v2 while others still run v1. You save capacity, but mixed versions must be safe, and rollback means putting v1 back onto instances you already changed.

**Blue-green** keeps two environments. Blue serves v1 while you prepare Green with v2, then you switch traffic. Rollback is a switch back to Blue. The cost is capacity for both environments. Rolling changes instances in place. Blue-green separates deploy from the traffic switch.

</details>

---

## 29. Why you would use Canary

3. Why would you use Canary?

<details>
<summary>Answer</summary>

Use canary when you want small production exposure and real observation before everyone gets the change. A typical start is 95% on v1 and 5% on v2. If v2 behaves, you increase traffic. If it does not, you send users back to v1.

Canary needs monitoring. Error rate, response time, resource use, and logs should drive the decision. It is not only “send 5% traffic.”

</details>

---

## 30. Why rollback can be difficult after a database change

4. Why can rollback become difficult after a database change?

<details>
<summary>Answer</summary>

The previous application version may not understand the new schema. If v2 moved the database from schema A to schema B, v1 can break or corrupt data when you send traffic back. Reversing the database may also be unsafe if data already changed.

Rollback must include application code, database, configuration, and infrastructure. The old binary alone is not enough.

</details>

---

## 31. Difference between rollback and roll forward

5. What is the difference between rollback and roll forward?

<details>
<summary>Answer</summary>

**Rollback** returns to the previous version. **Roll forward** deploys a newer fix instead of going back. Use rollback when the old version can still run on the current database and platform. Use roll forward when going back is unsafe, such as after an incompatible schema change.

Both are recovery choices after you observe a failure. Neither replaces finding the cause.

</details>

---

## 32. Why health checks matter during deployment

6. Why are health checks important during deployment?

<details>
<summary>Answer</summary>

Health checks tell you whether the new version is fit to receive traffic. In rolling, they decide if the next instance should update or if you must stop. In blue-green, they tell you whether Green is ready before the switch. In canary, they support the decision to increase traffic.

Without health checks, you can finish a deploy while instances are already unhealthy. Deployment success is not application success.

</details>

---

## 33. Why the same artifact should move from Dev to UAT to Prod

7. Why should the same artifact move from Dev → UAT → Prod?

<details>
<summary>Answer</summary>

The same artifact means each environment runs the software you already built and tested. You promote a known version. You do not create a new version at every stage. Configuration can differ. The binary should not.

If you rebuild for Production, you may ship something UAT never ran. Keep the path Code → Build → Artifact → Deploy → control traffic → observe.

</details>

---

## 34. Evidence to inspect when v2 deploys successfully but errors increase

8. If v2 is deployed successfully but error rates increase, what evidence would you inspect?

### 🎯 Exit Criteria

You should be able to explain this without memorizing definitions:

```text
Code
  ↓
Build
  ↓
Artifact
  ↓
Deploy
  ↓
Control Traffic
  ↓
Observe
  ↓
Continue / Roll Back / Fix Forward
```

<details>
<summary>Answer</summary>

Treat deploy success as only the first fact. Then inspect health and traffic before you redeploy. Walk this evidence: instances healthy, traffic reaching v2, error rates rising, dependencies healthy, then whether the fault is code, config, database, or infrastructure.

Use that picture to choose rollback or fix forward. Users reporting errors after a “successful” v2 deploy means the release behavior failed, even if the pipeline stage passed.

</details>
