---
title: "Day 7 · L07 · Deployment Strategies"
description: "Understand how application changes move safely from one version to another."
---

# Day 7 — Deployment Strategies

This Day uses three files. Read them in this order.

1. [01-concepts.md](01-concepts.md) — lesson content (this file)
2. [02-questions-and-answers.md](02-questions-and-answers.md) — practice items, each with a model answer
3. [03-implementation.md](03-implementation.md) — hands-on lab

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

---

## 02 · Rolling Deployment · 8 min

In a **rolling deployment**, you update instances in small groups instead of all at once.  
For example, with 4 application instances, we might update 1 or 2 instances to v2 while the others continue serving v1.

This reduces downtime and avoids changing the entire fleet at once. The trade-off is that **v1 and v2 may run together**, so the application must tolerate this during the deployment.

**Senior point:** rolling deployment needs **health checks and rollback control**.

---

## 03 · Blue-Green Deployment · 8 min

In **blue-green deployment**, two environments exist: one runs the current version and the other runs the new version.  
For example, Blue runs v1 while you prepare Green with v2. Traffic stays on Blue until Green is ready.

After validation, you switch traffic to Green. If v2 has a serious problem, you can switch traffic back to Blue, which makes rollback relatively quick.

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

**Think:** Blue-Green separates **deployment** from **traffic switching**.

---

## 04 · Canary Deployment · 8 min

In a **canary deployment**, you send only a small percentage of traffic to the new version first.  
For example, 95% can continue using v1 while 5% uses v2. If the new version behaves correctly, traffic can gradually increase.

Canary is useful when you want to observe real production behavior before exposing everyone to the change. It needs good monitoring, because evidence should drive the decision to continue.

```text
Users
  │
  ▼
Traffic Router
  ├── 95% → v1
  └──  5% → v2
```

**Senior point:** Canary is not simply "send 5% traffic." It is **controlled exposure + observation + decision**.

---

## 06 · Rollback vs Roll Forward · 6 min

A **rollback** means returning traffic or deployment state to the previous version.  
A **roll forward** means fixing the problem and deploying a new version instead of returning to the old one.

Rollback sounds simple, but database changes can make it difficult. For example, if v2 changes the database schema in a way that v1 cannot understand, sending traffic back to v1 may not be safe.

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

**Key idea:** the pipeline is the delivery mechanism; the deployment strategy is the **release behavior**.

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

### Next · Day 8 · L08

**Terraform Fundamentals**

You will connect today's deployment thinking with Infrastructure as Code:

`Terraform → Infrastructure → Application → Deployment → Production`

> **Takeaway:** A senior DevOps engineer does not only ask,  
> **"How do I deploy?"**  
> They ask, **"How do I expose this change safely, detect problems quickly, and recover?"**
