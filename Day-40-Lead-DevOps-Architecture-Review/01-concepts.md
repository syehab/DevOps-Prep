# Day 40 — Production Project 10 Lead DevOps Architecture Review

This Day uses three files. Read them in this order.

1. [01-concepts.md](01-concepts.md) — lesson content (this file)
2. [02-questions-and-answers.md](02-questions-and-answers.md) — practice items, each with a model answer
3. [03-implementation.md](03-implementation.md) — hands-on lab

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
