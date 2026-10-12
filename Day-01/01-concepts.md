---
title: "L01 — Senior DevOps Mental Model"
description: "Build a simple map of how DevOps pieces fit together."
---

# L01 · Senior DevOps Mental Model

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

# 04 · Mini Exercise · 10–15 min

## Build the map

Start with:

```text
User
 ↓
Application
 ↓
Database
```

Now add what you think is missing.

### A. Network

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
```

### B. Delivery

```text
Developer
 ↓
Git
 ↓
CI/CD
 ↓
Deploy
 ↓
Application
```

### C. Infrastructure

```text
Terraform
 ├── Network
 ├── Compute
 └── Database
```

### D. Operations

Add:

```text
Security
Observability
Reliability
Cost
```

Don't look for a perfect architecture.

**The exercise is simply to place the pieces.**

---

## 05 · One Failure · 5 min

### Scenario

> ❌ Application cannot connect to the database.

Don't immediately change something.

Think:

```text
Application
     ↓
     ?
     ↓
Database
```

Check the path:

```text
DNS?
 ↓
Route?
 ↓
Port?
 ↓
Firewall?
 ↓
Credentials?
 ↓
Database healthy?
```

> **Senior habit:** investigate from evidence instead of guessing.

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

# 09 · Exit Check · 3–5 min

Before moving on, answer these without looking back:

**1.** Where do CI/CD, Terraform, networking, security and monitoring fit into one application?

**2.** What is the difference between knowing a tool and understanding the concept behind it?

**3.** If an application cannot reach its database, what would you investigate?

If you can explain these in your own words, **L01 is complete.**

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

## Answers to practice

### 1. Mini Exercise — Build the map

<details>
<summary>Answer</summary>

Start from User → Application → Database, then place the missing pieces around that path. The network path is User → DNS → Load Balancer → Application → Database. Delivery is Developer → Git → CI/CD → Deploy → Application. Infrastructure is Terraform creating network, compute, and database. Operations wrap the whole system: security, observability, reliability, and cost.

Do not hunt for a perfect architecture. The exercise is to place each piece on one system. CI/CD moves code. Terraform creates the platform. Networking lets users and services reach the application. Security, observability, reliability, and cost sit around the running system.

</details>

### 2. Scenario — Application cannot connect to the database

<details>
<summary>Answer</summary>

Do not change something immediately. The symptom sits on the path Application → ? → Database. Investigate from evidence, not from a guess.

Check the path in order:

1. DNS. Does the application resolve the database name to the right IP?
2. Route. Does a valid path to that IP exist?
3. Port. Can TCP reach the database port?
4. Firewall. Does a security rule allow the application to the database?
5. Credentials. Do the username, password, and database name match?
6. Database health. Is the database process up and able to accept connections?

Senior habit: collect evidence, then form a hypothesis, then test it.

</details>

### 3. Where CI/CD, Terraform, networking, security, and monitoring fit

<details>
<summary>Answer</summary>

Treat them as one system, not as a tool list. Code moves through CI/CD into the runtime. Terraform creates the infrastructure that the application runs on. Networking lets the user reach the application and lets the application reach the database.

Security answers who can access what, across the whole path. Monitoring (observability) tells you whether the running system is healthy. Reliability and cost sit around the same flow: Code → CI/CD → Infrastructure and Runtime → Users.

</details>

### 4. Knowing a tool versus understanding the concept

<details>
<summary>Answer</summary>

Knowing a tool means you can run commands. Understanding the concept means you know why the piece exists, how it works, what can go wrong, how you detect the failure, and how you fix it. Use the sequence: Why? → What? → How? → What can go wrong? → How do I know? → How do I fix it?

The same concept maps to different cloud services. A virtual network is a VNet in Azure and a VPC in AWS. Learn the concept first. Learn the cloud service second.

</details>

### 5. If an application cannot reach its database, what would you investigate?

<details>
<summary>Answer</summary>

Do not restart or rewrite configuration first. Walk the path from the application to the database and find the first failed layer. Check DNS, route, port, firewall, credentials, and then whether the database is healthy.

Collect evidence at each step, then form a hypothesis and test it. The failure may be name resolution, a missing route, a blocked port, a deny rule, a wrong secret, or a down database. Senior habit: investigate from evidence instead of guessing.

</details>
