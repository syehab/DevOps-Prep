---
title: "L01 — Senior DevOps Mental Model"
description: "Build a simple map of how DevOps pieces fit together."
---

# Day 1 — Senior DevOps Mental Model

This Day uses three files. Read them in this order.

1. [01-concepts.md](01-concepts.md) — lesson content (this file)
2. [02-questions-and-answers.md](02-questions-and-answers.md) — practice items, each with a model answer
3. [03-implementation.md](03-implementation.md) — hands-on lab

> **The goal is not to learn more tools.**  
> The goal is to understand how the pieces of a production system fit together.

| ⏱️ Time | 🎯 Level | ☁️ Cost |
|:--|:--|:--|
| **35–45 min** | Senior DevOps | **₹0** |

---

## 01 · The Big Picture · 8 min

A Senior DevOps engineer works across this flow:

```text
Code
  ↓
Build & Test
  ↓
Infrastructure
  ↓
Deploy
  ↓
Run
  ↓
Observe
  ↓
Improve
```

And keeps these concerns around the whole system:

```text
Security · Reliability · Cost
```

### Think of it as one system

```text
             ┌──────────────┐
             │     CODE     │
             └──────┬───────┘
                    ↓
             ┌──────────────┐
             │    CI/CD     │
             └──────┬───────┘
                    ↓
      ┌─────────────┴─────────────┐
      ↓                           ↓
 Infrastructure                Runtime
      │                           │
 Terraform                   App / K8s
      │                           │
      └─────────────┬─────────────┘
                    ↓
             ┌──────────────┐
             │   USERS      │
             └──────────────┘

      Security · Observability · Reliability · Cost
```

---

## 02 · Why Each Piece Exists · 8 min

Take a simple application:

```text
Spring Boot
     ↓
   MySQL
```

| Question | Area |
|:--|:--|
| Where does it run? | **Compute** |
| How does the user reach it? | **Networking** |
| Who creates the infrastructure? | **IaC** |
| How does code reach production? | **CI/CD** |
| Who can access what? | **IAM / Security** |
| How do we know it is healthy? | **Observability** |
| What happens when it fails? | **Reliability** |
| What does it cost? | **FinOps** |

That's the whole idea.

You don't need to master these topics today.  
**You only need to know where they fit.**

---

## 03 · Senior Thinking Pattern · 5 min

For any technology, don't stop at:

> **"What is it?"**

Use this sequence:

```text
WHY?
 ↓
WHAT?
 ↓
HOW?
 ↓
WHAT CAN GO WRONG?
 ↓
HOW DO I KNOW?
 ↓
HOW DO I FIX IT?
```

### Example: Terraform

```text
WHY?
Avoid manual infrastructure

WHAT?
Declarative IaC

HOW?
Terraform → Provider → Cloud API

WHAT CAN GO WRONG?
State · Permissions · Configuration · Drift

HOW DO I KNOW?
Plan · CLI · Logs · Cloud console

HOW DO I FIX IT?
Find the actual cause → Fix → Verify
```

> 💡 **This thinking pattern is more important than memorizing commands.**

---

## 06 · Azure ↔ AWS · 3 min

The concepts are similar even when the services differ.

| Concept | Azure | AWS |
|:--|:--|:--|
| Virtual network | VNet | VPC |
| VM | Azure VM | EC2 |
| Kubernetes | AKS | EKS |
| Identity | Entra ID / RBAC | IAM |
| Secrets | Key Vault | Secrets Manager |
| Monitoring | Azure Monitor | CloudWatch |
| IaC | Terraform / Bicep | Terraform / CloudFormation |

> **Learn the concept first. Learn the cloud service second.**

---

# 07 · Cost Check · 1 min

No resources are provisioned.

**AWS: ₹0 · Azure: ₹0**

---

# 08 · Cleanup · <1 min

Nothing was provisioned.

**No cleanup required.**

---

## → Next

### L02 · Linux & Application Runtime

**⏱️ 45–60 min**

We'll zoom into the running application:

```text
Process
  ↓
Port
  ↓
Network connection
  ↓
Logs
  ↓
Failure
```

> **L01 takeaway:**  
> Don't see DevOps as a list of technologies.  
> **See it as one system.**
