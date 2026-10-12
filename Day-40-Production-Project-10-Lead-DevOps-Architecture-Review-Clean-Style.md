# Day 40 — Production Project 10: Lead DevOps Architecture Review

Day 40 is the final project of the Senior/Lead DevOps crash course.

There is no major new technology today.

Instead, you will bring everything together and operate at the level expected from someone responsible for designing, delivering, securing, and operating a production platform.

The ShopSphere platform now contains:

```text
Business Requirements
        ↓
AWS Organization
        ↓
Accounts / Environments
        ↓
Networking
        ↓
Security / Identity
        ↓
Terraform
        ↓
EKS
        ↓
CI/CD
        ↓
Application
        ↓
Observability
        ↓
Reliability / DR
        ↓
Cost / Governance
```

The objective is not to produce the most complicated architecture.

It is to produce an architecture that is:

**secure, reliable, observable, recoverable, operable, cost-aware, and understandable.**

The central question is:

**Can you defend every important architecture decision and explain what happens when it fails?**

---

## Part 1 — Start With the Business

A Lead DevOps engineer should not begin with:

**“Which AWS service should we use?”**

Begin with:

```text
What does the business need?
Who uses the system?
What must always work?
How much downtime is acceptable?
How much data loss is acceptable?
What security requirements exist?
What is the expected scale?
What is the budget?
```

For ShopSphere, assume the platform supports:

```text
Customer registration
Product browsing
Order creation
Payment processing
Order status
Administrative operations
```

Now classify the functions.

For example:

```text
Critical:
Orders
Payments
Authentication

Important:
Product browsing
Search

Lower criticality:
Analytics
Reporting
```

Architecture follows business criticality.

---

## Part 2 — Define Non-Functional Requirements

Write explicit targets before designing infrastructure.

For example:

```text
Availability:
99.9%

RPO:
15 minutes

RTO:
60 minutes

Deployment:
Zero / minimal customer-visible interruption

Security:
No public database
Least privilege
Centralized audit

Observability:
Metrics + logs + traces

Environments:
Dev / UAT / Prod

Cloud:
AWS
```

These are example requirements for the exercise.

In a real project, the business should validate them.

Every major architecture decision should trace back to one or more requirements.

---

## Part 3 — The Final Architecture

Draw ShopSphere from the outside in.

Start with:

```text
Users
  ↓
DNS
  ↓
Edge / Load Balancing
  ↓
Kubernetes
  ↓
Application
  ↓
Database
```

Then add the platform around it:

```text
Identity
Security
Networking
Terraform
CI/CD
Observability
DR
Cost
Governance
```

Do not begin by drawing every AWS service.

Start with the request and recovery paths.

---

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

## Part 8 — Terraform State Architecture

Production state must be:

```text
Remote
Protected
Locked
Versioned
Access Controlled
Recoverable
```

Separate state according to meaningful ownership and blast-radius boundaries.

For example:

```text
prod/network
prod/eks
prod/data
```

Then explain:

```text
Who can read state?
Who can modify state?
Who can apply?
How is state recovered?
How is drift detected?
```

A Lead engineer should treat state as production infrastructure.

---

## Part 9 — Infrastructure Change Workflow

Your final Terraform change flow should be:

```text
Developer
 ↓
Pull Request
 ↓
Format / Validate
 ↓
Security / Policy
 ↓
Terraform Plan
 ↓
Review
 ↓
Approval
 ↓
Terraform Apply
 ↓
Verification
```

For Production, identify exactly where authorization changes.

Do not allow:

```text
Developer Laptop
      ↓
Production
```

without strong controls.

The objective is not to remove engineers from the process.

It is to make Production changes intentional and traceable.

---

## Part 10 — Application CI/CD Architecture

The final application pipeline should be:

```text
Git
 ↓
Build
 ↓
Unit Tests
 ↓
Security Checks
 ↓
Container Build
 ↓
Image Scan
 ↓
Registry
 ↓
Dev
 ↓
UAT
 ↓
Production Approval
 ↓
Production
 ↓
Health Verification
```

Promote the artifact. Do not rebuild it.

Traceability should look like:

```text
Git SHA
 ↓
Build ID
 ↓
Image Digest
 ↓
Deployment
 ↓
Running Workload
```

If an incident occurs, identify exactly what version is running.

---

## Part 11 — Deployment Architecture

Choose a deployment strategy based on application behavior.

Possible strategies:

```text
Rolling
Blue/Green
Canary
```

For ShopSphere, a controlled rolling or canary strategy may be appropriate depending on the application's traffic and risk requirements.

The important part is not the label.

The important part is:

```text
New Version
 ↓
Health Verification
 ↓
Traffic
 ↓
Observe
 ↓
Continue / Roll Back
```

Also consider:

```text
Graceful Shutdown
Connection Draining
Capacity
Database Compatibility
Startup Time
Rollback
```

---

## Part 12 — Database Compatibility

This is one of the most important architecture challenges.

Suppose version `v2` requires a new database column.

If you deploy:

```text
DB migration
 ↓
v2
```

and then discover v2 is broken, rolling the application back to v1 may fail if v1 cannot handle the changed database schema.

A safer pattern can be:

```text
Expand
 ↓
Deploy compatible application
 ↓
Migrate usage
 ↓
Contract later
```

The database therefore becomes part of deployment architecture.

Never design application rollback without considering database compatibility.

---

## Part 13 — Kubernetes Architecture

The final Production EKS design should consider:

```text
Multiple AZs
Multiple nodes
Pod spreading
Requests / limits
Readiness
Liveness
Startup behavior
HPA
Node autoscaling
PDB
NetworkPolicy
Workload identity
Ingress
Secrets
Observability
```

The objective is not maximum Kubernetes complexity.

Every feature should have a reason.

For example:

```text
Readiness
→ Traffic safety

HPA
→ Workload scaling

PDB
→ Voluntary disruption protection

NetworkPolicy
→ Network isolation

Workload Identity
→ Credential-free cloud access
```

---

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

## Part 15 — Secrets Architecture

The final architecture should separate:

```text
Application Configuration
Secrets
Infrastructure Configuration
```

Do not store production secrets in:

```text
Git
Dockerfile
Container Image
Terraform Variables committed to source
Pipeline YAML
```

Remember that Terraform state can contain sensitive values.

Therefore the security design must include state protection as well as secret-management tooling.

For runtime workloads, use cloud-integrated identity and secret-management mechanisms rather than long-lived credentials wherever possible.

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

## Part 17 — Incident Response

Define the production incident lifecycle:

```text
Detect
 ↓
Triage
 ↓
Contain
 ↓
Investigate
 ↓
Recover
 ↓
Verify
 ↓
Communicate
 ↓
RCA
 ↓
Improve
```

During an incident, do not immediately make large changes.

First establish:

```text
What changed?
What is failing?
When did it start?
Who is affected?
What evidence do we have?
What is the safest containment?
```

The best incident response is evidence-driven.

---

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

## Part 22 — Disaster Recovery Architecture

ShopSphere's DR strategy should map to its RPO and RTO.

Review:

```text
Database
Container Images
Terraform
Kubernetes
Secrets
DNS
Networking
Observability
```

Ask:

```text
If the region disappears, what survives?

If the database disappears, how do we recover?

If EKS disappears, how do we recreate it?

If Terraform state disappears, how do we recover it?

If the Production account is compromised, what remains trustworthy?
```

A DR plan is complete only when you understand the entire recovery chain.

---

## Part 23 — Cost Architecture

Review the final monthly cost model.

Group costs into:

```text
Compute
Database
Networking
Storage
Observability
Security
Backup
DR
Data Transfer
```

Then identify which costs exist because of:

```text
Availability
Security
Performance
Compliance
Convenience
```

This allows engineering discussions to become precise.

For example:

**“We need multi-region because the business requires a 60-minute regional recovery target.”**

is much stronger than:

**“We should have multi-region because it is more reliable.”**

---

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

## Part 27 — Architecture Defense

Now defend your design.

Answer:

1. Why AWS?
2. Why separate accounts?
3. Why EKS?
4. Why multi-AZ?
5. Why private database?
6. How does traffic reach the application?
7. How does the application access AWS services?
8. How are secrets protected?
9. Who can deploy Production?
10. Who can change infrastructure?
11. How is Terraform state protected?
12. How are Terraform changes reviewed?
13. How does the same artifact reach Production?
14. How are deployments rolled back?
15. How are database changes handled?
16. How does the application scale?
17. What happens if a node fails?
18. What happens if an AZ fails?
19. What happens if the region fails?
20. How do you detect application failure?
21. How do you detect infrastructure failure?
22. How do you recover?
23. What does DR cost?
24. What is the largest remaining blast radius?
25. What would you simplify if the budget were reduced by 30%?

---

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

## Part 34 — Final Course Mental Model

You began with individual technologies:

```text
Linux
Networking
CI/CD
Terraform
Docker
Kubernetes
Cloud
IAM
Security
Observability
```

You should now see them as one system:

```text
                    Business
                       ↓
                  Requirements
                       ↓
                Cloud Architecture
                       ↓
          ┌────────────┼────────────┐
          ↓            ↓            ↓
      Security      Networking    Identity
          ↓            ↓            ↓
          └────────────┼────────────┘
                       ↓
                  Infrastructure
                       ↓
                    Runtime
                       ↓
                  Application
                       ↓
                    Delivery
                       ↓
                  Observability
                       ↓
             Incident / Recovery
                       ↓
                 Cost / Governance
                       ↓
                   Improvement
```

The Senior/Lead DevOps mindset is:

**Design → Build → Secure → Deliver → Observe → Operate → Recover → Improve.**

And every decision should answer:

```text
Why?
What?
How?
What can fail?
How will we know?
How will we recover?
What does it cost?
What is the trade-off?
Who owns it?
```

---

## Part 35 — Course Completion Criteria

The course is complete when you can take an unfamiliar production scenario and independently move through:

```text
Requirements
 ↓
Architecture
 ↓
Cloud
 ↓
Network
 ↓
Identity
 ↓
Infrastructure
 ↓
CI/CD
 ↓
Runtime
 ↓
Security
 ↓
Observability
 ↓
Reliability
 ↓
DR
 ↓
Cost
 ↓
Governance
```

You should be able to produce tangible evidence:

```text
[ ] Production architecture diagram
[ ] Terraform repository
[ ] Reusable Terraform modules
[ ] Remote state architecture
[ ] CI/CD pipeline
[ ] Container image
[ ] Kubernetes deployment
[ ] Helm/GitOps configuration
[ ] IAM model
[ ] Security controls
[ ] Observability dashboard
[ ] Incident RCA
[ ] DR runbook
[ ] Cost model
[ ] Architecture Decision Records
[ ] Final architecture document
```

The final standard is not:

**“I completed 40 lessons.”**

It is:

**“I can take ownership of a production DevOps platform and make sound engineering decisions across infrastructure, delivery, security, operations, reliability, and cost.”**

---

## Part 36 — Final Next Step

The structured learning phase is now complete.

The next phase should not be another long theory course.

It should be **deliberate production simulation**.

Take the ShopSphere platform and repeatedly introduce realistic problems:

```text
Bad deployment
Terraform drift
Broken DNS
Wrong route
IAM AccessDenied
Expired certificate
Database saturation
Pod crash loop
Broken readiness probe
Image vulnerability
Secret leakage
Cost spike
AZ failure
Region recovery
```

For every incident, use:

```text
Symptom
 ↓
Evidence
 ↓
Layer
 ↓
Root Cause
 ↓
Safest Fix
 ↓
Verification
 ↓
Prevention
```

That loop is where Senior/Lead-level judgment becomes durable.

---

## Cleanup

Do not destroy the final ShopSphere platform immediately.

Preserve the architecture and artifacts as your reference implementation.

Create a final baseline record:

```text
Project:
ShopSphere

Cloud:
AWS

Environments:
Dev / UAT / Prod

Runtime:
Managed Kubernetes / EKS

Infrastructure:
Terraform

Application:
Spring Boot

Registry:
ECR

Delivery:
CI/CD + controlled promotion

Networking:
Multi-AZ VPC

Identity:
IAM + workload identity

Secrets:
Managed secret store

Observability:
Metrics + Logs + Traces

DR:
Documented RPO/RTO strategy

Cost:
Environment + service visibility

Governance:
Accounts + IAM + policy + approvals

Final Architecture Commit:
<record commit>

Final Review Date:
<record date>
```

Your final architecture is not the endpoint.

It is the baseline from which you continue practicing architecture, troubleshooting, automation, security, and operational judgment.

## Answers to practice

### 1. Why AWS?

<details>
<summary>Answer</summary>

The exercise sets cloud = AWS. Use it if the org already runs IAM, VPC, and EKS skills there. Azure can express the same boundaries.

Pick the cloud from skills, compliance, and existing accounts, not from a service wishlist.

</details>

### 2. Why separate accounts?

<details>
<summary>Answer</summary>

Accounts isolate security, IAM, billing, quotas, and blast radius. Dev must not modify Prod.

Fewer accounts can work. Shared boundaries must still meet security and business rules. That is the trade-off.

</details>

### 3. Why EKS?

<details>
<summary>Answer</summary>

Use EKS when you need a Kubernetes platform, standard tooling, or portability. ECS already covered v1 if those needs were absent.

Managed control plane; you still own nodes, workloads, and platform config. Record the capability you accepted.

</details>

### 4. Why multi-AZ?

<details>
<summary>Answer</summary>

99.9% availability needs more than one AZ. Place public, app, and data subnets, plus nodes, across AZs.

One AZ is one failure domain. Multi-AZ is not multi-region.

</details>

### 5. Why private database?

<details>
<summary>Answer</summary>

Orders and payments sit on PostgreSQL. Internet users must not reach 5432. Private subnets, no IGW route, `APP-SG → DB : 5432`.

Public database access fails the security NFR.

</details>

### 6. How does traffic reach the application?

<details>
<summary>Answer</summary>

User → DNS → load balancer / Ingress → Service → ready endpoints → Pod → Spring Boot → private database.

Do not add NAT, endpoints, or extra LBs unless a named path needs them.

</details>

### 7. How does the application access AWS services?

<details>
<summary>Answer</summary>

Workload identity: Service Account → IAM role → AWS API. No long-lived keys in the Pod.

Scope the role to named secrets, logs, and required APIs. Prefer VPC endpoints over general internet when the destination is AWS.

</details>

### 8. How are secrets protected?

<details>
<summary>Answer</summary>

Secrets Manager or Key Vault, per environment. Not Git, Dockerfiles, images, committed tfvars, or pipeline YAML.

Protect Terraform state too; it can hold secrets. Runtime uses identity, not pasted keys.

</details>

### 9. Who can deploy Production?

<details>
<summary>Answer</summary>

The Prod deployment role after UAT evidence and approval. Developers do not apply from a laptop.

Trace who, which digest, which process, and which evidence.

</details>

### 10. Who can change infrastructure?

<details>
<summary>Answer</summary>

The Prod Terraform role in the infra pipeline after `terraform fmt`, `terraform validate`, policy, plan review, and approval.

Not the app runtime. Not standing human admin.

</details>

### 11. How is Terraform state protected?

<details>
<summary>Answer</summary>

Remote S3, encryption, IAM, locking (`use_lockfile`), versioning, and recovery. Split `prod/network`, `prod/eks`, `prod/data`.

Treat state as Production infrastructure.

</details>

### 12. How are Terraform changes reviewed?

<details>
<summary>Answer</summary>

PR → format/validate → policy → plan → review → approval → pipeline apply → verify.

A plan is evidence, not approval. Ask why, blast radius, and reversibility.

</details>

### 13. How does the same artifact reach Production?

<details>
<summary>Answer</summary>

Git SHA → build → tests → scan → one image → ECR → Dev → UAT → approval → Prod. Deploy the digest.

A rebuild for Prod breaks the UAT proof.

</details>

### 14. How are deployments rolled back?

<details>
<summary>Answer</summary>

Stop widening traffic. Restore the previous digest if the schema still fits. Verify health, then a real checkout.

App rollback is not a database rollback. Expand-and-contract keeps that door open.

</details>

### 15. How are database changes handled?

<details>
<summary>Answer</summary>

Expand schema, deploy compatible code, migrate usage, contract later. v2 plus an incompatible column can block v1 rollback.

The database is part of the release, not a side script.

</details>

### 16. How does the application scale?

<details>
<summary>Answer</summary>

HPA changes replicas from metrics. Cluster autoscaling adds nodes when Pods cannot schedule.

Scale the bottleneck. More API Pods on a saturated database worsen connections.

</details>

### 17. What happens if a node fails?

<details>
<summary>Answer</summary>

Pods on that node die. Remaining nodes and AZs take the load if you spread replicas and keep a PDB for voluntary work.

Three Pods on one node are not HA.

</details>

### 18. What happens if an AZ fails?

<details>
<summary>Answer</summary>

Targets in that AZ go away. The load balancer sends traffic to healthy AZs. Database must be Multi-AZ if the NFR says so.

NAT, nodes, and data must exist in more than one AZ.

</details>

### 19. What happens if the region fails?

<details>
<summary>Answer</summary>

All AZs in that region fail. DNS or global routing sends users to DR. Recover database to RPO, rebuild EKS from Terraform and Git, deploy the known digest, verify a transaction.

Standby cost follows the 60-minute RTO.

</details>

### 20. How do you detect application failure?

<details>
<summary>Answer</summary>

Golden signals plus business metrics: 5xx, latency, checkout success, orders/minute. Logs and traces name the hop.

Cluster green is not checkout healthy.

</details>

### 21. How do you detect infrastructure failure?

<details>
<summary>Answer</summary>

Node, AZ, load-balancer, database, and Terraform drift signals. CloudTrail and plan diffs catch console changes.

Correlate infra events with deploy time before you blame the app.

</details>

### 22. How do you recover?

<details>
<summary>Answer</summary>

Detect → triage → contain → investigate → recover → verify a business path → communicate → RCA.

Restore service with the smallest safe change. Prove root cause after users can order.

</details>

### 23. What does DR cost?

<details>
<summary>Answer</summary>

Extra region, replication, transfer, standby EKS, backups, and tests. Tie it to RPO 15 minutes and RTO 60 minutes.

“More reliable” is not a cost argument. The business target is.

</details>

### 24. What is the largest remaining blast radius?

<details>
<summary>Answer</summary>

Often the CI/CD identity, the Prod Terraform role, shared registry trust, or a combined state file.

Name it and add a control. Isolation is never complete.

</details>

### 25. What would you simplify if the budget dropped 30%?

<details>
<summary>Answer</summary>

Shrink idle Dev, unjustified NAT, verbose log retention, and warm DR capacity if the RTO can move. Keep Multi-AZ Prod, private DB, and restore tests.

Cut convenience first, not the NFRs the business still funds.

</details>

### 26. Incident drill: 5xx spike — decide

<details>
<summary>Answer</summary>

Start at symptoms. Walk traffic → LB → Ingress → Service → endpoints → Pods → logs → database → external APIs. Correlate deploy, infra, config, and DB events.

Do not roll back first. If evidence pins the new release, then roll back or mitigate.

</details>

### 27. Incident drill: database failure — decide

<details>
<summary>Answer</summary>

Pods healthy, requests failing, database unavailable. Kubernetes health ≠ business health.

Walk DNS → network → SG → route → endpoint → port → engine → credentials → pool. Recover the database, then prove a real order.

</details>

### 28. Incident drill: Terraform drift — decide

<details>
<summary>Answer</summary>

A Prod SG changed by hand. `terraform plan` shows drift. Do not apply blindly.

Ask who, why, authorization, traffic impact, and security impact. Restore or codify. Then add pipeline-only Prod and least privilege.

</details>

### 29. Incident drill: cost spike — decide

<details>
<summary>Answer</summary>

Do not delete resources. Break account → service → resource → usage → change. Check HPA, DB, NAT, transfer, logs, storage, LBs, unexpected resources.

Correlate with deploys. Find the architecture cause, not only the expensive line.

</details>

### 30. Whiteboard: ShopSphere from requirements

<details>
<summary>Answer</summary>

Clarify users, criticality (orders/payments), 99.9%, RPO 15, RTO 60, Dev/UAT/Prod, audit, budget. Then: org → accounts → Multi-AZ VPC → EKS → private DB → IAM → Terraform → CI digest promotion → secrets → observability → DR.

Do not start with service names. Business → NFRs → architecture → operations → failure → recovery → cost.

</details>

### 31. Architecture trade-offs (examples)

<details>
<summary>Answer</summary>

EKS vs ECS: Kubernetes platform need vs less cluster ops. Separate accounts vs one account: isolation vs cost. Multi-AZ vs one AZ: availability. DR region vs rebuild: RTO vs spend.

Write decision, why, alternative, benefit, cost, risk, operational load. Alternatives are not “bad.”

</details>

### 32. What would you simplify?

<details>
<summary>Answer</summary>

Drop unused peering, extra clusters, unused replicas, unused telemetry, unused DR capacity, extra state splits, and custom automation nobody runs.

Each box has cost, failure modes, maintenance, and security surface. Appropriate technology, not maximum technology.

</details>

### 33. Architecture failure review (prevent / detect / contain / recover / learn)

<details>
<summary>Answer</summary>

Stolen CI identity: scoped roles, STS audit, revoke, rotate, tighten. Corrupt state: versioning, stop applies, restore, plan. Dev reading Prod secrets: separate stores. Bad image: digest gates, rollback. Region loss: DR runbook.

For each scenario write those five verbs. That is operational engineering.

</details>

### 34. Senior vs Lead thinking

<details>
<summary>Answer</summary>

Senior: build, deploy, troubleshoot, secure, monitor, recover. Lead also: standards, platform, ownership, governance, blast radius, cost, risk, developer experience.

Make the safe path the easy path: a module plus policy that encrypts by default, rather than asking 50 teams nicely.

</details>

### 35. Interview simulation: modernize VMs

<details>
<summary>Answer</summary>

Ask current architecture, traffic, availability, RPO/RTO, database, security, scale, owners, budget, and skills. Then propose accounts, Terraform modules, digest promotion, runtime (ECS or EKS from need), private DB, observability, and DR that match those answers.

Do not prescribe EKS, GitOps, and multi-region before the requirements.

</details>

### 36. 10-minute recall: four perspectives

<details>
<summary>Answer</summary>

Delivery: Git → CI → artifact → registry → promotion → approval → EKS → Service → app → DB. Infra: org → accounts → VPC → subnets → security → EKS → DB. Ops: observe → detect → investigate → recover → RCA → improve. Governance: identity, policy, Terraform, approval, cost, ownership.

Connecting all four is Lead-level, not tool trivia.

</details>

### 37. Final architecture artifact (expected outcome)

<details>
<summary>Answer</summary>

`Senior-DevOps-Production-Architecture.md` holds NFRs, diagrams, accounts, network, identity, Terraform, CI/CD, Kubernetes, security, observability, deploy, DR, cost, ownership, failures, recovery, ADRs, trade-offs, and risks.

Each major decision: decision, reason, alternative, trade-off. This is the interview portfolio.

</details>

### 38. Organization, network, identity (expected design)

<details>
<summary>Answer</summary>

Org: Security, Shared Services, Workloads (Dev/UAT/Prod). Prod VPC `10.20.0.0/16` with public/app/data in two AZs. Identities: human, Terraform, deploy, runtime, Kubernetes API.

Least privilege, separation of duties, environment isolation. No extra network box without a path.

</details>

### 39. Terraform vs Kubernetes ownership

<details>
<summary>Answer</summary>

Terraform: VPC, EKS, node groups, IAM, security, database, observability infra. Helm/GitOps: Namespace, Deployment, Service, Ingress, HPA, NetworkPolicy, PDB.

Two systems must not fight over one object.

</details>

### 40. Security and observability layers

<details>
<summary>Answer</summary>

Security: org → account → IAM → VPC → SG → RBAC → NetworkPolicy → Pod → app, plus the supply chain from source to runtime. Observability: golden signals plus orders, payments, checkout, auth.

Answer quickly: is the user failing because of app, Kubernetes, network, database, or an external API?

</details>
