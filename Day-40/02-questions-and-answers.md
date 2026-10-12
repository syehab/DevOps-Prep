# Day 40 — Questions and answers

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Then answer each item below before you open the Answer block. After that, do the lab in [03-implementation.md](03-implementation.md).

Write your own answer first. Open the Answer block only after you try. Keep the original numbering.

---

## Part 27 — Architecture Defense

Now defend your design.

Answer:

## 1. Why AWS?

1. Why AWS?

<details>
<summary>Answer</summary>

The exercise sets cloud = AWS. Use it if the org already runs IAM, VPC, and EKS skills there. Azure can express the same boundaries.

Pick the cloud from skills, compliance, and existing accounts, not from a service wishlist.

</details>

---

## 2. Why separate accounts?

2. Why separate accounts?

<details>
<summary>Answer</summary>

Accounts isolate security, IAM, billing, quotas, and blast radius. Dev must not modify Prod.

Fewer accounts can work. Shared boundaries must still meet security and business rules. That is the trade-off.

</details>

---

## 3. Why EKS?

3. Why EKS?

<details>
<summary>Answer</summary>

Use EKS when you need a Kubernetes platform, standard tooling, or portability. ECS already covered v1 if those needs were absent.

Managed control plane; you still own nodes, workloads, and platform config. Record the capability you accepted.

</details>

---

## 4. Why multi-AZ?

4. Why multi-AZ?

<details>
<summary>Answer</summary>

99.9% availability needs more than one AZ. Place public, app, and data subnets, plus nodes, across AZs.

One AZ is one failure domain. Multi-AZ is not multi-region.

</details>

---

## 5. Why private database?

5. Why private database?

<details>
<summary>Answer</summary>

Orders and payments sit on PostgreSQL. Internet users must not reach 5432. Private subnets, no IGW route, `APP-SG → DB : 5432`.

Public database access fails the security NFR.

</details>

---

## 6. How does traffic reach the application?

6. How does traffic reach the application?

<details>
<summary>Answer</summary>

User → DNS → load balancer / Ingress → Service → ready endpoints → Pod → Spring Boot → private database.

Do not add NAT, endpoints, or extra LBs unless a named path needs them.

</details>

---

## 7. How does the application access AWS services?

7. How does the application access AWS services?

<details>
<summary>Answer</summary>

Workload identity: Service Account → IAM role → AWS API. No long-lived keys in the Pod.

Scope the role to named secrets, logs, and required APIs. Prefer VPC endpoints over general internet when the destination is AWS.

</details>

---

## 8. How are secrets protected?

8. How are secrets protected?

<details>
<summary>Answer</summary>

Secrets Manager or Key Vault, per environment. Not Git, Dockerfiles, images, committed tfvars, or pipeline YAML.

Protect Terraform state too; it can hold secrets. Runtime uses identity, not pasted keys.

</details>

---

## 9. Who can deploy Production?

9. Who can deploy Production?

<details>
<summary>Answer</summary>

The Prod deployment role after UAT evidence and approval. Developers do not apply from a laptop.

Trace who, which digest, which process, and which evidence.

</details>

---

## 10. Who can change infrastructure?

10. Who can change infrastructure?

<details>
<summary>Answer</summary>

The Prod Terraform role in the infra pipeline after `terraform fmt`, `terraform validate`, policy, plan review, and approval.

Not the app runtime. Not standing human admin.

</details>

---

## 11. How is Terraform state protected?

11. How is Terraform state protected?

<details>
<summary>Answer</summary>

Remote S3, encryption, IAM, locking (`use_lockfile`), versioning, and recovery. Split `prod/network`, `prod/eks`, `prod/data`.

Treat state as Production infrastructure.

</details>

---

## 12. How are Terraform changes reviewed?

12. How are Terraform changes reviewed?

<details>
<summary>Answer</summary>

PR → format/validate → policy → plan → review → approval → pipeline apply → verify.

A plan is evidence, not approval. Ask why, blast radius, and reversibility.

</details>

---

## 13. How does the same artifact reach Production?

13. How does the same artifact reach Production?

<details>
<summary>Answer</summary>

Git SHA → build → tests → scan → one image → ECR → Dev → UAT → approval → Prod. Deploy the digest.

A rebuild for Prod breaks the UAT proof.

</details>

---

## 14. How are deployments rolled back?

14. How are deployments rolled back?

<details>
<summary>Answer</summary>

Stop widening traffic. Restore the previous digest if the schema still fits. Verify health, then a real checkout.

App rollback is not a database rollback. Expand-and-contract keeps that door open.

</details>

---

## 15. How are database changes handled?

15. How are database changes handled?

<details>
<summary>Answer</summary>

Expand schema, deploy compatible code, migrate usage, contract later. v2 plus an incompatible column can block v1 rollback.

The database is part of the release, not a side script.

</details>

---

## 16. How does the application scale?

16. How does the application scale?

<details>
<summary>Answer</summary>

HPA changes replicas from metrics. Cluster autoscaling adds nodes when Pods cannot schedule.

Scale the bottleneck. More API Pods on a saturated database worsen connections.

</details>

---

## 17. What happens if a node fails?

17. What happens if a node fails?

<details>
<summary>Answer</summary>

Pods on that node die. Remaining nodes and AZs take the load if you spread replicas and keep a PDB for voluntary work.

Three Pods on one node are not HA.

</details>

---

## 18. What happens if an AZ fails?

18. What happens if an AZ fails?

<details>
<summary>Answer</summary>

Targets in that AZ go away. The load balancer sends traffic to healthy AZs. Database must be Multi-AZ if the NFR says so.

NAT, nodes, and data must exist in more than one AZ.

</details>

---

## 19. What happens if the region fails?

19. What happens if the region fails?

<details>
<summary>Answer</summary>

All AZs in that region fail. DNS or global routing sends users to DR. Recover database to RPO, rebuild EKS from Terraform and Git, deploy the known digest, verify a transaction.

Standby cost follows the 60-minute RTO.

</details>

---

## 20. How do you detect application failure?

20. How do you detect application failure?

<details>
<summary>Answer</summary>

Golden signals plus business metrics: 5xx, latency, checkout success, orders/minute. Logs and traces name the hop.

Cluster green is not checkout healthy.

</details>

---

## 21. How do you detect infrastructure failure?

21. How do you detect infrastructure failure?

<details>
<summary>Answer</summary>

Node, AZ, load-balancer, database, and Terraform drift signals. CloudTrail and plan diffs catch console changes.

Correlate infra events with deploy time before you blame the app.

</details>

---

## 22. How do you recover?

22. How do you recover?

<details>
<summary>Answer</summary>

Detect → triage → contain → investigate → recover → verify a business path → communicate → RCA.

Restore service with the smallest safe change. Prove root cause after users can order.

</details>

---

## 23. What does DR cost?

23. What does DR cost?

<details>
<summary>Answer</summary>

Extra region, replication, transfer, standby EKS, backups, and tests. Tie it to RPO 15 minutes and RTO 60 minutes.

“More reliable” is not a cost argument. The business target is.

</details>

---

## 24. What is the largest remaining blast radius?

24. What is the largest remaining blast radius?

<details>
<summary>Answer</summary>

Often the CI/CD identity, the Prod Terraform role, shared registry trust, or a combined state file.

Name it and add a control. Isolation is never complete.

</details>

---

## 25. What would you simplify if the budget dropped 30%?

25. What would you simplify if the budget were reduced by 30%?

<details>
<summary>Answer</summary>

Shrink idle Dev, unjustified NAT, verbose log retention, and warm DR capacity if the RTO can move. Keep Multi-AZ Prod, private DB, and restore tests.

Cut convenience first, not the NFRs the business still funds.

</details>

---

## 26. Incident drill: 5xx spike — decide

## Part 18 — Final Incident Drill: 5xx Spike

Scenario:

```text
ShopSphere 5xx rate suddenly increases.
```

You have no additional information.

Start from symptoms.

Check:

```text
Traffic
 ↓
Load Balancer
 ↓
Ingress
 ↓
Service
 ↓
Endpoints
 ↓
Pods
 ↓
Application Logs
 ↓
Database
 ↓
External Dependencies
```

Then correlate:

```text
Deployment Timeline
Infrastructure Changes
Configuration Changes
Database Events
```

Do not immediately rollback.

First determine whether the deployment is actually related.

If evidence shows the new release caused the issue, execute the safest rollback or mitigation.

---

<details>
<summary>Answer</summary>

Start at symptoms. Walk traffic → LB → Ingress → Service → endpoints → Pods → logs → database → external APIs. Correlate deploy, infra, config, and DB events.

Do not roll back first. If evidence pins the new release, then roll back or mitigate.

</details>

---

## 27. Incident drill: database failure — decide

## Part 19 — Final Incident Drill: Database Failure

Scenario:

```text
Application:
Healthy Pods

Requests:
Failing

Database:
Unavailable
```

Notice that:

```text
Kubernetes health
≠
Business health
```

Investigate:

```text
DNS
 ↓
Network
 ↓
Security Group
 ↓
Route
 ↓
Database Endpoint
 ↓
Port
 ↓
Database Availability
 ↓
Credentials
 ↓
Connection Pool
```

Then execute the database recovery procedure.

Finally verify a real business transaction.

---

<details>
<summary>Answer</summary>

Pods healthy, requests failing, database unavailable. Kubernetes health ≠ business health.

Walk DNS → network → SG → route → endpoint → port → engine → credentials → pool. Recover the database, then prove a real order.

</details>

---

## 28. Incident drill: Terraform drift — decide

## Part 20 — Final Incident Drill: Terraform Drift

Scenario:

```text
Production security rule changed manually.
```

Terraform detects drift.

Do not blindly apply.

Determine:

```text
Who changed it?
Why?
Was it authorized?
What traffic changed?
What is the security impact?
Should Terraform reflect the change?
Should the infrastructure be restored?
```

Then reconcile.

Finally identify the control that should prevent recurrence.

---

<details>
<summary>Answer</summary>

A Prod SG changed by hand. `terraform plan` shows drift. Do not apply blindly.

Ask who, why, authorization, traffic impact, and security impact. Restore or codify. Then add pipeline-only Prod and least privilege.

</details>

---

## 29. Incident drill: cost spike — decide

## Part 21 — Final Incident Drill: Cost Spike

Scenario:

```text
AWS cost increases sharply.
```

Do not immediately delete resources.

Break the problem down:

```text
Account
 ↓
Service
 ↓
Resource
 ↓
Usage
 ↓
Change
```

Investigate:

```text
Kubernetes scaling
Database capacity
NAT traffic
Data transfer
Logs
Storage
Load balancers
Unexpected resources
```

Then correlate the cost increase with deployment and infrastructure changes.

The objective is to identify the architectural cause, not just the expensive resource.

---

<details>
<summary>Answer</summary>

Do not delete resources. Break account → service → resource → usage → change. Check HPA, DB, NAT, transfer, logs, storage, LBs, unexpected resources.

Correlate with deploys. Find the architecture cause, not only the expensive line.

</details>

---

## 30. Whiteboard: ShopSphere from requirements

## Part 26 — Lead-Level Whiteboard Challenge

You now have 20 minutes to design ShopSphere from scratch.

The interviewer gives you:

```text
A Spring Boot application
A relational database
10,000 daily users
Production business transactions
Dev / UAT / Prod
AWS
99.9% availability target
15-minute RPO
60-minute RTO
Controlled Production releases
Security and audit requirements
```

Your whiteboard should include:

```text
AWS Organization
Accounts
VPC
Subnets
Routing
Security
EKS
Database
IAM
Terraform
CI/CD
ECR
Secrets
Observability
DR
Cost
```

Do not start drawing immediately.

Spend the first few minutes clarifying requirements.

Then build:

```text
Business
 ↓
Requirements
 ↓
Architecture
 ↓
Implementation
 ↓
Operations
 ↓
Failure
 ↓
Recovery
 ↓
Cost
```

---

<details>
<summary>Answer</summary>

Clarify users, criticality (orders/payments), 99.9%, RPO 15, RTO 60, Dev/UAT/Prod, audit, budget. Then: org → accounts → Multi-AZ VPC → EKS → private DB → IAM → Terraform → CI digest promotion → secrets → observability → DR.

Do not start with service names. Business → NFRs → architecture → operations → failure → recovery → cost.

</details>

---

## 31. Architecture trade-offs (examples)

## Part 24 — Architecture Trade-Offs

Now challenge your own design.

For every major decision, write:

```text
Decision
Why
Alternative
Benefit
Cost
Risk
Operational Responsibility
```

Examples:

```text
EKS
Alternative: ECS
Reason:
Kubernetes platform requirement

Separate AWS Accounts
Alternative: Shared account
Reason:
Stronger isolation

Multi-AZ
Alternative: Single AZ
Reason:
Availability

DR Region
Alternative: Rebuild from backup
Reason:
RTO requirement
```

Do not describe alternatives as inherently bad.

Explain why the chosen design satisfies the stated requirements.

---

<details>
<summary>Answer</summary>

EKS vs ECS: Kubernetes platform need vs less cluster ops. Separate accounts vs one account: isolation vs cost. Multi-AZ vs one AZ: availability. DR region vs rebuild: RTO vs spend.

Write decision, why, alternative, benefit, cost, risk, operational load. Alternatives are not “bad.”

</details>

---

## 32. What would you simplify?

## Part 25 — What Would You Simplify?

A Lead engineer should also be able to remove unnecessary complexity.

Look at the architecture and ask:

```text
Do we need this service?
Do we need this network connection?
Do we need this cluster?
Do we need this replica count?
Do we need this telemetry?
Do we need this DR capacity?
Do we need this Terraform state boundary?
Do we need this custom automation?
```

Every component has:

```text
Cost
Failure Modes
Maintenance
Security Surface
Operational Responsibility
```

Good architecture is not maximum technology.

It is appropriate technology.

---

<details>
<summary>Answer</summary>

Drop unused peering, extra clusters, unused replicas, unused telemetry, unused DR capacity, extra state splits, and custom automation nobody runs.

Each box has cost, failure modes, maintenance, and security surface. Appropriate technology, not maximum technology.

</details>

---

## 33. Architecture failure review (prevent / detect / contain / recover / learn)

## Part 28 — Architecture Failure Review

Take your own architecture and deliberately attack it.

Ask:

```text
What if:
```

```text
The CI/CD identity is compromised?

Terraform state is corrupted?

A developer gets excessive Dev permissions?

Dev can access Production secrets?

A Kubernetes node fails?

An AZ fails?

The database becomes unavailable?

A bad image reaches Production?

A deployment creates 5xx errors?

DNS is misconfigured?

The NAT path becomes unavailable?

The central logging system fails?

Cloud cost doubles?

The entire Production region fails?
```

For each scenario, identify:

```text
Prevent
Detect
Contain
Recover
Learn
```

This is the final transformation from technology knowledge to operational engineering.

---

<details>
<summary>Answer</summary>

Stolen CI identity: scoped roles, STS audit, revoke, rotate, tighten. Corrupt state: versioning, stop applies, restore, plan. Dev reading Prod secrets: separate stores. Bad image: digest gates, rollback. Region loss: DR runbook.

For each scenario write those five verbs. That is operational engineering.

</details>

---

## 34. Senior vs Lead thinking

## Part 29 — Senior vs Lead Thinking

A Senior DevOps engineer should be able to:

```text
Build
Deploy
Troubleshoot
Secure
Monitor
Recover
```

A Lead DevOps engineer must also think about:

```text
Standards
Platform Design
Ownership
Governance
Blast Radius
Architecture
Cost
Risk
Consistency
Developer Experience
```

The Lead question is often:

**“How do we make the safe path the easy path for many teams?”**

For example, instead of telling 50 teams:

**“Please configure encryption correctly.”**

provide a platform module and policy that makes encryption the default and prevents unsafe configurations.

That is platform engineering thinking.

---

<details>
<summary>Answer</summary>

Senior: build, deploy, troubleshoot, secure, monitor, recover. Lead also: standards, platform, ownership, governance, blast radius, cost, risk, developer experience.

Make the safe path the easy path: a module plus policy that encrypts by default, rather than asking 50 teams nicely.

</details>

---

## 35. Interview simulation: modernize VMs

## Part 33 — Final Interview Simulation

Conduct a mock interview using this scenario:

> “You are responsible for modernizing a Java application currently running on virtual machines. The company wants Dev, UAT, and Production environments in AWS. Production requires high availability, controlled deployments, centralized observability, strong security, and a defined disaster recovery strategy. The organization also wants reusable infrastructure and standardized delivery across multiple teams.”

You have 30 minutes.

Do not immediately prescribe:

```text
EKS
Terraform
GitOps
Multi-Region
```

Instead ask:

```text
What is the current architecture?
What is the traffic pattern?
What are the availability requirements?
What is the RPO/RTO?
What is the database?
What are the security requirements?
What is the expected scale?
Who owns the platform?
What is the budget?
What operational skills exist?
```

Then design the solution.

A strong Lead-level response should show that technology selection follows requirements.

---

<details>
<summary>Answer</summary>

Ask current architecture, traffic, availability, RPO/RTO, database, security, scale, owners, budget, and skills. Then propose accounts, Terraform modules, digest promotion, runtime (ECS or EKS from need), private DB, observability, and DR that match those answers.

Do not prescribe EKS, GitOps, and multi-region before the requirements.

</details>

---

## 36. 10-minute recall: four perspectives

## Part 31 — Final 10-Minute Recall

Without opening previous lessons, explain this entire system:

```text
Developer
 ↓
Git
 ↓
CI
 ↓
Security
 ↓
Artifact
 ↓
Registry
 ↓
Environment Promotion
 ↓
Production Approval
 ↓
EKS
 ↓
Service
 ↓
Application
 ↓
Database
```

Then explain the infrastructure side:

```text
Organization
 ↓
Accounts
 ↓
VPC
 ↓
Subnets
 ↓
Security
 ↓
EKS
 ↓
Database
```

Then explain the operational side:

```text
Observe
 ↓
Detect
 ↓
Investigate
 ↓
Recover
 ↓
RCA
 ↓
Improve
```

Then explain the governance side:

```text
Identity
Security
Terraform
Policy
Approval
Cost
Ownership
```

If you can connect all four perspectives, you have moved beyond individual-tool knowledge.

---

<details>
<summary>Answer</summary>

Delivery: Git → CI → artifact → registry → promotion → approval → EKS → Service → app → DB. Infra: org → accounts → VPC → subnets → security → EKS → DB. Ops: observe → detect → investigate → recover → RCA → improve. Governance: identity, policy, Terraform, approval, cost, ownership.

Connecting all four is Lead-level, not tool trivia.

</details>

---

## Part 32 — Final Senior/Lead Competency Check

Rate yourself honestly against these capabilities, but do not focus on the number. Focus on evidence.

```text
[ ] I can explain the full production architecture.
[ ] I can design cloud account boundaries.
[ ] I can design VPC/network boundaries.
[ ] I can explain cloud IAM and workload identity.
[ ] I can design Terraform state boundaries.
[ ] I can build a controlled IaC pipeline.
[ ] I can design application CI/CD.
[ ] I can explain artifact promotion.
[ ] I can design Kubernetes workloads.
[ ] I can troubleshoot Kubernetes networking.
[ ] I can design safe deployments.
[ ] I can reason about database compatibility.
[ ] I can design observability.
[ ] I can investigate production incidents.
[ ] I can design backup and DR.
[ ] I can reason about RPO/RTO.
[ ] I can connect reliability decisions to cost.
[ ] I can identify blast radius.
[ ] I can define team ownership.
[ ] I can explain security controls by layer.
[ ] I can defend architecture trade-offs.
[ ] I can simplify an over-engineered design.
[ ] I can create an operational recovery plan.
[ ] I can explain Azure ↔ AWS equivalents.
[ ] I can communicate architecture to engineers and stakeholders.
```

The strongest evidence is not:

**“I know Kubernetes.”**

It is:

**“I can design a production Kubernetes platform, explain why it exists, operate it, troubleshoot it, secure it, recover it, and explain its cost and trade-offs.”**

---

## 37. Final architecture artifact (expected outcome)

## Part 30 — Final Architecture Artifact

Create:

```text
Senior-DevOps-Production-Architecture.md
```

It should contain:

```text
1. Business Requirements
2. Non-Functional Requirements
3. Architecture Diagram
4. Account Structure
5. Network Architecture
6. Identity Model
7. Terraform Architecture
8. CI/CD Architecture
9. Kubernetes Architecture
10. Security Model
11. Observability Model
12. Deployment Strategy
13. DR Strategy
14. Cost Model
15. Ownership Model
16. Failure Scenarios
17. Recovery Procedures
18. Architecture Decisions
19. Trade-Offs
20. Risks / Future Improvements
```

For each major decision, include:

```text
Decision
Reason
Alternative
Trade-Off
```

This becomes your final portfolio/interview artifact.

---

<details>
<summary>Answer</summary>

`Senior-DevOps-Production-Architecture.md` holds NFRs, diagrams, accounts, network, identity, Terraform, CI/CD, Kubernetes, security, observability, deploy, DR, cost, ownership, failures, recovery, ADRs, trade-offs, and risks.

Each major decision: decision, reason, alternative, trade-off. This is the interview portfolio.

</details>

---

## 38. Organization, network, identity (expected design)

## Part 4 — Organization and Account Architecture

Your enterprise boundary should look like:

```text
AWS Organization
│
├── Security
│
├── Infrastructure / Shared Services
│
└── Workloads
    ├── Dev Account
    ├── UAT Account
    └── Prod Account
```

Explain why these boundaries exist.

Your answer should include:

```text
Security
Blast Radius
Access Control
Billing
Governance
Operational Independence
```

Then ask:

**Could ShopSphere operate with fewer accounts?**

Yes.

But the question is whether the resulting shared boundaries satisfy the business and security requirements.

Architecture is a trade-off.

---

## Part 5 — Network Architecture

Design the Production VPC.

For example:

```text
VPC
10.20.0.0/16

AZ-A                     AZ-B

Public / Edge            Public / Edge
Private App              Private App
Private Data             Private Data
```

The application should not require a public database.

The request path should be:

```text
User
 ↓
DNS
 ↓
Load Balancer / Ingress
 ↓
EKS
 ↓
Application
 ↓
Private Database
```

Outbound traffic should follow an intentional design.

Review:

```text
Route Tables
Internet Gateway
NAT
Security Groups
Network ACLs
VPC Endpoints
Private DNS
```

Do not add network components unless you can explain why they exist.

---

## Part 6 — Identity Architecture

Now identify the major identities.

```text
Human Identity
      ↓
AWS / Enterprise Access

Terraform Identity
      ↓
Infrastructure

Deployment Identity
      ↓
Kubernetes Deployment

Runtime Identity
      ↓
AWS Services

Kubernetes Identity
      ↓
Kubernetes API
```

Each identity should have a distinct purpose.

Ask:

```text
Who can modify Production infrastructure?

Who can deploy applications?

Who can read Production secrets?

Who can access Kubernetes?

Who can assume the Terraform role?
```

Then apply:

**Least privilege + separation of duties + environment isolation.**

---

<details>
<summary>Answer</summary>

Org: Security, Shared Services, Workloads (Dev/UAT/Prod). Prod VPC `10.20.0.0/16` with public/app/data in two AZs. Identities: human, Terraform, deploy, runtime, Kubernetes API.

Least privilege, separation of duties, environment isolation. No extra network box without a path.

</details>

---

## 39. Terraform vs Kubernetes ownership

## Part 7 — Terraform Architecture

Terraform should manage the cloud platform.

A reasonable boundary is:

```text
Terraform
 ├── VPC
 ├── EKS
 ├── Node Groups
 ├── IAM
 ├── Security
 ├── Database
 ├── Observability Infrastructure
 └── Supporting Cloud Resources
```

Kubernetes tooling manages workload objects:

```text
Helm / GitOps
 ├── Namespace
 ├── Deployment
 ├── Service
 ├── Ingress
 ├── HPA
 ├── NetworkPolicy
 └── PDB
```

Explain why you do not want multiple systems fighting over the same resource.

---

<details>
<summary>Answer</summary>

Terraform: VPC, EKS, node groups, IAM, security, database, observability infra. Helm/GitOps: Namespace, Deployment, Service, Ingress, HPA, NetworkPolicy, PDB.

Two systems must not fight over one object.

</details>

---

## 40. Security and observability layers

## Part 14 — Security Architecture

Review security in layers.

```text
Organization
 ↓
Account
 ↓
IAM
 ↓
VPC
 ↓
Security Groups / Network Controls
 ↓
Kubernetes RBAC
 ↓
NetworkPolicy
 ↓
Pod / Container
 ↓
Application
```

Then review the supply chain:

```text
Source
 ↓
Dependencies
 ↓
Build
 ↓
Image
 ↓
Registry
 ↓
Deployment
 ↓
Runtime
```

Ask where an attacker could:

```text
Inject code
Steal credentials
Modify artifacts
Gain excessive permissions
Move laterally
Reach private resources
Persist in the environment
```

Then identify the control at each layer.

---

## Part 16 — Observability Architecture

ShopSphere should have:

```text
Metrics
Logs
Traces
```

connected to:

```text
Dashboards
Alerts
Incident Response
RCA
```

At minimum, monitor:

```text
Traffic
Errors
Latency
Saturation
```

Then add business signals:

```text
Orders
Payments
Checkout
Authentication
```

The architecture must let you answer this question quickly:

**Are users failing because the application, Kubernetes, network, database, or an external dependency is unhealthy?**

---

<details>
<summary>Answer</summary>

Security: org → account → IAM → VPC → SG → RBAC → NetworkPolicy → Pod → app, plus the supply chain from source to runtime. Observability: golden signals plus orders, payments, checkout, auth.

Answer quickly: is the user failing because of app, Kubernetes, network, database, or an external API?

</details>

