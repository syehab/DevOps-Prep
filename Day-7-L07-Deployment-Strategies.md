---
title: "Day 7 · L07 · Deployment Strategies"
description: "Understand how application changes move safely from one version to another."
---

# Day 7 · L07 · Deployment Strategies

> **The goal is not to memorize deployment names.**  
> The goal is to understand how we move a new version into production while controlling risk.

| | |
|---|---|
| ⏱️ Time | 50–65 min |
| 🎯 Level | Senior DevOps |
| ☁️ Cost | ₹0 |
| 🧪 Lab | Local / Azure DevOps |

---

## 01 · What Is a Deployment Strategy · 6 min

A deployment strategy defines **how the new application version replaces the old version**.  
The important questions are: how much traffic goes to the new version, how quickly we move users, and what happens if the new version fails.

For example, replacing every running instance at once is simple, but a problem in the new release can affect everyone immediately. A gradual strategy reduces the amount of change exposed at one time.

### 🧪 Exercise

Take a simple application:

`v1 → v2`

Write down:

1. How many users see v2 immediately?
2. Can v1 remain available?
3. How would you return users to v1?

**Think:** deployment strategy is mainly about **risk and traffic movement**.

---

## 02 · Rolling Deployment · 8 min

In a **rolling deployment**, instances are updated in small groups instead of all at once.  
For example, with 4 application instances, we might update 1 or 2 instances to v2 while the others continue serving v1.

This reduces downtime and avoids changing the entire fleet at once. The trade-off is that **v1 and v2 may run together**, so the application must tolerate this during the deployment.

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
- Why might rollback be harder than simply stopping a new server?

**Senior point:** rolling deployment needs **health checks and rollback control**.

---

## 03 · Blue-Green Deployment · 8 min

In **blue-green deployment**, two environments exist: one runs the current version and the other runs the new version.  
For example, Blue runs v1 while Green is prepared with v2. Traffic stays on Blue until Green is ready.

After validation, traffic is switched to Green. If v2 has a serious problem, traffic can be switched back to Blue, making rollback relatively quick.

```text
             Load Balancer
                  │
            ┌─────┴─────┐
            ↓           ↓
         BLUE          GREEN
          v1             v2
        Current          New

             Switch traffic
                  ↓

         GREEN becomes active
```

The main cost is that you may temporarily need capacity for **both environments**.

### 🧪 Exercise

Create this locally:

```text
Blue  → http://localhost:8081 → "Version 1"
Green → http://localhost:8082 → "Version 2"
```

Use a simple server or container for each version.

Now answer:

1. Which version receives users before the switch?
2. What would you test on Green?
3. If Green fails, where would traffic go?

**Think:** Blue-Green separates **deployment** from **traffic switching**.

---

## 04 · Canary Deployment · 8 min

In a **canary deployment**, only a small percentage of traffic is sent to the new version first.  
For example, 95% can continue using v1 while 5% uses v2. If the new version behaves correctly, traffic can gradually increase.

Canary is useful when you want to observe real production behavior before exposing everyone to the change. It requires good monitoring because the decision to continue should be based on evidence.

```text
Users
  │
  ▼
Traffic Router
  ├── 95% → v1
  └──  5% → v2
```

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
2. What evidence would you check before deciding?
3. What would you do with v2 if the problem is confirmed?

**Senior point:** Canary is not simply "send 5% traffic." It is **controlled exposure + observation + decision**.

---

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

---

## 06 · Rollback vs Roll Forward · 6 min

A **rollback** means returning traffic or deployment state to the previous version.  
A **roll forward** means fixing the problem and deploying a new version instead of returning to the old one.

Rollback sounds simple, but database changes can make it difficult. For example, if v2 changes the database schema in a way that v1 cannot understand, sending traffic back to v1 may not be safe.

### 🧪 Exercise

Consider:

```text
v1 → Database schema A
v2 → Database schema B
```

v2 is deployed and the application fails.

Ask yourself:

- Can v1 safely use schema B?
- Can the database change be reversed?
- Would deploying v3 be safer than rolling back?

**Senior point:** rollback must consider **application code + database + configuration + infrastructure**, not just the application binary.

---

## 07 · Database Changes & Zero-Downtime · 6 min

A deployment can be zero-downtime only when the old and new versions can safely coexist during the change.  
This is why database changes often use a **backward-compatible sequence** instead of changing everything at once.

A common pattern is:

```text
1. Add new database structure
2. Deploy application that can use old + new structure
3. Move traffic / data gradually
4. Remove old structure later
```

This is often called the **expand → migrate → contract** approach.

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

---

## 08 · Deployment Strategy Decision · 5 min

There is no single deployment strategy for every application.  
The choice depends on traffic, infrastructure capacity, rollback requirements, application compatibility, monitoring maturity, and business risk.

Use this simple mental model:

```text
Need simple gradual replacement?
        ↓
     Rolling

Need fast traffic switch + easy rollback?
        ↓
   Blue-Green

Need small production exposure + observation?
        ↓
     Canary
```

### 🧪 Exercise

Choose a strategy for each scenario and explain **why**, not just the name.

**A.** Small internal application with 3 VMs  
**B.** Customer-facing payment API  
**C.** Large application where you want to observe a new release with a small user group

There is no need to memorize a "correct" answer. Explain the factors that influenced your choice.

---

## 09 · Azure DevOps Deployment Flow · 5 min

Azure DevOps can represent deployment strategies through pipeline stages, environments, approvals, deployment jobs, and the capabilities of the target platform.

A simplified pipeline might look like:

```yaml
stages:
- stage: Build
  jobs:
  - job: Build
    steps:
    - script: mvn clean package

- stage: DeployDev
  dependsOn: Build
  jobs:
  - deployment: Dev
    environment: dev
    strategy:
      runOnce:
        deploy:
          steps:
          - script: echo "Deploy to DEV"

- stage: DeployProd
  dependsOn: DeployDev
  jobs:
  - deployment: Prod
    environment: prod
    strategy:
      runOnce:
        deploy:
          steps:
          - script: echo "Deploy existing artifact to PROD"
```

The pipeline controls **when and where** deployment happens. The target platform or deployment design controls **how traffic moves between versions**.

### 🧪 Exercise

Look at the YAML and identify:

- Where is the application built?
- Which stage deploys to Dev?
- Which stage deploys to Prod?
- Why should Prod use the existing artifact instead of rebuilding?

**Key idea:** the pipeline is the delivery mechanism; the deployment strategy is the **release behavior**.

---

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

v2 was deployed using Canary.

Write down the **first three pieces of evidence** you would check before changing anything.

**Senior habit:** deployment success and application success are two different things.

---

## 11 · Azure ↔ AWS · 3 min

The deployment concepts are cloud-independent.

| Concept | Azure example | AWS example |
|---|---|---|
| Rolling | VM Scale Sets / AKS | ASG / ECS / EKS |
| Blue-Green | App Service / deployment design / AKS | CodeDeploy / ECS / EKS |
| Canary | Front Door / App Gateway / AKS patterns | ALB / CodeDeploy / ECS / EKS |
| Pipeline | Azure DevOps | CodePipeline / CodeBuild or other CI/CD |
| Monitoring | Azure Monitor | CloudWatch |

The important thing is to understand **traffic, versions, health checks and rollback** first. The cloud service comes second.

---

## 12 · Cost Check · 1 min

No paid resources are required.

If you run cloud-based Blue-Green or Canary labs, remember that temporarily running multiple application versions can increase compute cost.

---

## 13 · Cleanup · <1 min

If you created local containers or processes:

```bash
docker ps
docker stop <container>
docker rm <container>
```

If you created cloud resources, remove them after the exercise.

---

## 14 · Exit Check · 5 min

Answer without looking:

1. What problem does a deployment strategy solve?
2. How is Rolling different from Blue-Green?
3. Why would you use Canary?
4. Why can rollback become difficult after a database change?
5. What is the difference between rollback and roll forward?
6. Why are health checks important during deployment?
7. Why should the same artifact move from Dev → UAT → Prod?
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

> **Takeaway:** A senior DevOps engineer does not only ask,  
> **"How do I deploy?"**  
> They ask, **"How do I expose this change safely, detect problems quickly, and recover?"**

---

### Next · Day 8 · L08

**Terraform Fundamentals**

You will connect today's deployment thinking with Infrastructure as Code:

`Terraform → Infrastructure → Application → Deployment → Production`
