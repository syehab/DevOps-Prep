# Day 1 — Questions and answers

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Then answer each item below before you open the Answer block. After that, do the lab in [03-implementation.md](03-implementation.md).

Write your own answer first. Open the Answer block only after you try. Keep the original numbering.

---

## 1. Mini Exercise — Build the map

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

<details>
<summary>Answer</summary>

Start from User → Application → Database, then place the missing pieces around that path. The network path is User → DNS → Load Balancer → Application → Database. Delivery is Developer → Git → CI/CD → Deploy → Application. Infrastructure is Terraform creating network, compute, and database. Operations wrap the whole system: security, observability, reliability, and cost.

Do not hunt for a perfect architecture. The exercise is to place each piece on one system. CI/CD moves code. Terraform creates the platform. Networking lets users and services reach the application. Security, observability, reliability, and cost sit around the running system.

</details>

---

## 2. Scenario — Application cannot connect to the database

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

---

## 3. Where CI/CD, Terraform, networking, security, and monitoring fit

# 09 · Exit Check · 3–5 min

Before moving on, answer these without looking back:

**1.** Where do CI/CD, Terraform, networking, security and monitoring fit into one application?

<details>
<summary>Answer</summary>

Treat them as one system, not as a tool list. Code moves through CI/CD into the runtime. Terraform creates the infrastructure that the application runs on. Networking lets the user reach the application and lets the application reach the database.

Security answers who can access what, across the whole path. Monitoring (observability) tells you whether the running system is healthy. Reliability and cost sit around the same flow: Code → CI/CD → Infrastructure and Runtime → Users.

</details>

---

## 4. Knowing a tool versus understanding the concept

**2.** What is the difference between knowing a tool and understanding the concept behind it?

<details>
<summary>Answer</summary>

Knowing a tool means you can run commands. Understanding the concept means you know why the piece exists, how it works, what can go wrong, how you detect the failure, and how you fix it. Use the sequence: Why? → What? → How? → What can go wrong? → How do I know? → How do I fix it?

The same concept maps to different cloud services. A virtual network is a VNet in Azure and a VPC in AWS. Learn the concept first. Learn the cloud service second.

</details>

---

## 5. If an application cannot reach its database, what would you investigate?

**3.** If an application cannot reach its database, what would you investigate?

If you can explain these in your own words, **L01 is complete.**

<details>
<summary>Answer</summary>

Do not restart or rewrite configuration first. Walk the path from the application to the database and find the first failed layer. Check DNS, route, port, firewall, credentials, and then whether the database is healthy.

Collect evidence at each step, then form a hypothesis and test it. The failure may be name resolution, a missing route, a blocked port, a deny rule, a wrong secret, or a down database. Senior habit: investigate from evidence instead of guessing.

</details>
