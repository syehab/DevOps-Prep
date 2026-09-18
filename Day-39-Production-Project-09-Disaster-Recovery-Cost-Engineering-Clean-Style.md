# Day 39 — Production Project 09: Disaster Recovery & Cost Engineering

ShopSphere now has production infrastructure, Kubernetes, controlled CI/CD, observability, hardened Terraform, and separate AWS accounts. The next question is not simply whether the system is reliable.

It is:

**How much failure can the business tolerate, how quickly must we recover, and what are we willing to spend to achieve that?**

Disaster Recovery (DR) and cost engineering are connected. A highly resilient architecture usually requires additional capacity, replicas, backups, networking, storage, monitoring, and operational effort. A very cheap architecture may recover slowly or lose more data.

Today you will design the recovery strategy for ShopSphere and then connect every resilience decision to its financial impact.

---

## Part 1 — Reliability Before Disaster Recovery

Disaster Recovery is not the same thing as high availability.

High Availability tries to keep the service operating when expected infrastructure failures occur.

Disaster Recovery focuses on restoring service after a major failure that exceeds the normal availability design.

Think:

```text
High Availability
→ Survive common failures

Disaster Recovery
→ Recover from major failures
```

For ShopSphere:

```text
Pod failure
→ Kubernetes self-healing

Node failure
→ Other nodes / rescheduling

AZ failure
→ Multi-AZ architecture

Region failure
→ Disaster Recovery strategy
```

Each failure requires a different design.

---

## Part 2 — Business Requirements Come First

Do not start DR planning by choosing a backup service.

Start with the business.

Ask:

```text
How much data can we lose?
How long can the service be unavailable?
Which functions are critical?
What is the financial impact of downtime?
```

For ShopSphere, suppose the business defines:

```text
RPO: 15 minutes
RTO: 60 minutes
```

RPO means:

**Recovery Point Objective — the maximum acceptable amount of data loss measured in time.**

RTO means:

**Recovery Time Objective — the target maximum time to restore the service after a qualifying outage.**

These are business requirements that influence technical architecture.

---

## Part 3 — RPO and RTO

Imagine the database fails at:

```text
14:00
```

The latest recoverable database state is:

```text
13:50
```

Potential data loss:

```text
10 minutes
```

That satisfies an RPO of 15 minutes.

Now suppose the service is restored at:

```text
14:40
```

Recovery time:

```text
40 minutes
```

That satisfies an RTO of 60 minutes.

RPO answers:

**“How much recent data can we afford to lose?”**

RTO answers:

**“How quickly must we restore service?”**

Never confuse the two.

---

## Part 4 — Recovery Tiers

Not every ShopSphere component deserves the same recovery investment.

For example:

```text
Tier 1
Order processing
Payment integration
Customer authentication

Tier 2
Product browsing
Search

Tier 3
Analytics
Administrative reporting
```

Criticality should influence:

```text
RPO
RTO
Backup frequency
Replication
Recovery automation
Testing frequency
```

Do not spend the same amount to protect a non-critical reporting system as you spend protecting order processing.

---

## Part 5 — Failure Domains

ShopSphere now has several failure domains:

```text
Container
Pod
Node
AZ
Region
AWS Account
Cloud Provider
```

The larger the failure domain, the more significant the recovery architecture becomes.

For example:

```text
Pod failure
→ Kubernetes replaces Pod

Node failure
→ Scheduler places workload elsewhere

AZ failure
→ Other AZs continue

Region failure
→ DR region required
```

A Lead DevOps engineer should always ask:

**What is the largest failure domain this architecture can survive?**

---

## Part 6 — Multi-AZ Is Not Multi-Region

Running ShopSphere across multiple Availability Zones provides resilience against an AZ-level failure.

It does not automatically protect against a regional failure.

For example:

```text
Region A
 ├── AZ-A
 ├── AZ-B
 └── AZ-C
```

If the entire region becomes unavailable, all three AZs are affected.

Multi-region architecture requires:

```text
Primary Region
       +
DR Region
```

This usually introduces significant additional cost and operational complexity.

---

## Part 7 — Backup vs Replication

Backup and replication solve different problems.

Backup creates recoverable historical copies.

Replication maintains another copy, often closer to current state.

For example:

```text
Backup:
Database
 ↓
Snapshot
 ↓
Recover later
```

Replication:

```text
Primary Database
 ↓
Continuous / near-continuous replication
 ↓
Secondary Database
```

Replication can reduce recovery time and data loss, but it can also replicate corruption or accidental deletion depending on the design.

Therefore:

**Replication is not a replacement for backups.**

---

## Part 8 — Database Recovery

The ShopSphere database is one of the most important DR components.

Consider:

```text
Automated Backups
Point-in-Time Recovery
Snapshots
Cross-Region Copies
Replication
Restore Testing
```

A backup that has never been restored is only an assumption.

The recovery process should be tested.

A useful flow is:

```text
Database Failure
 ↓
Identify Recovery Point
 ↓
Restore / Promote
 ↓
Validate Data
 ↓
Update Application Connectivity
 ↓
Verify Business Operations
```

---

## Part 9 — Kubernetes Recovery

Kubernetes workloads should be treated differently from persistent data.

Most Kubernetes application objects can be recreated from:

```text
Git
Helm
GitOps
Terraform
Container Registry
Secret Management
```

The cluster itself should therefore be reproducible.

Think:

```text
Cluster lost
 ↓
Terraform creates infrastructure
 ↓
Kubernetes platform initialized
 ↓
GitOps / Helm restores workloads
 ↓
Secrets / identities configured
 ↓
Application starts
```

This is a powerful reason to keep Kubernetes configuration declarative.

---

## Part 10 — Back Up Data, Rebuild Compute

A useful DR principle is:

**Prefer rebuilding stateless compute from known definitions rather than treating servers as irreplaceable assets.**

For ShopSphere:

```text
Application image
→ ECR

Infrastructure
→ Terraform

Kubernetes configuration
→ Git / Helm / GitOps

Secrets
→ Secret Manager / Key Vault equivalent

Database
→ Backup / replication
```

This reduces dependence on manually maintained servers.

The persistent state deserves stronger recovery planning.

---

## Part 11 — Terraform State Recovery

Terraform state is itself an important recovery dependency.

Suppose the Production infrastructure is healthy but Terraform state is accidentally deleted.

The application may continue running.

But infrastructure management is now impaired.

If the backend uses versioned storage, state recovery may be possible.

The runbook should be:

```text
Stop Terraform Changes
 ↓
Identify Correct State Version
 ↓
Recover State
 ↓
Validate
 ↓
terraform plan
 ↓
Confirm No Unexpected Changes
 ↓
Resume Operations
```

Never casually run Terraform against an empty state after losing the original state.

---

## Part 12 — Region-Level Disaster

Imagine the primary AWS Region is unavailable.

The DR architecture may look like:

```text
Users
  ↓
DNS / Traffic Management
  ↓
Primary Region
```

and:

```text
                 ┌── Primary Region
Users → Routing ─┤
                 └── DR Region
```

The DR region may contain:

```text
Networking
EKS
Database recovery target
Container registry access
Secrets
Observability
```

The exact level of standby capacity depends on RTO and cost requirements.

A fully active secondary region is generally more expensive than a partially provisioned or rebuild-on-demand strategy.

---

## Part 13 — Active/Active vs Active/Passive

Two common models are:

```text
Active/Active

Region A → Traffic
Region B → Traffic
```

and:

```text
Active/Passive

Region A → Traffic
Region B → Standby
```

Active/active can provide faster regional failover and better resource utilization.

It also introduces more complexity:

```text
Data consistency
Traffic routing
Deployment coordination
Configuration
Observability
Cost
```

Active/passive can simplify operations but may leave capacity underutilized while waiting for a disaster.

There is no universal answer.

The architecture must satisfy the business RTO/RPO.

---

## Part 14 — DNS During Disaster Recovery

If traffic must move between regions, DNS or another global traffic-management mechanism may participate.

For example:

```text
api.shopsphere.example
        ↓
Global Traffic Management
        ↓
Primary Region
```

During a regional failure:

```text
Primary unhealthy
        ↓
Routing changes
        ↓
DR Region
```

DNS TTL alone does not guarantee instant failover.

Client caching, resolver behavior, health-check intervals, and application connection behavior all affect actual recovery time.

Test the real behavior.

---

## Part 15 — Secrets in DR

A DR environment needs access to the correct Production secrets.

Do not solve this by manually copying secrets into the DR cluster.

Instead design the secret architecture so that:

```text
Primary Region
        +
DR Region
        ↓
Authorized access
        ↓
Production secret source / replicated secret strategy
```

The DR workload identity should have appropriate access.

Avoid giving the entire DR environment unrestricted access to every secret.

---

## Part 16 — Container Images in DR

If the Production region becomes unavailable, the DR environment still needs the application image.

Consider:

```text
ECR
 ↓
Replication / alternate access
 ↓
DR Region
```

The recovery plan should not depend on an engineer rebuilding the application during an outage.

Record:

```text
Image Repository
Image Digest
Deployment Version
Git SHA
```

This preserves the same artifact traceability model from Day 33.

---

## Part 17 — Observability During DR

Monitoring must survive the failure domain you are monitoring.

If all monitoring infrastructure exists only in the failed region, visibility can disappear precisely when you need it most.

Consider centralized or independently available:

```text
Logs
Metrics
Traces
Audit Events
Alerts
Incident Communication
```

The DR runbook should answer:

**How do we know whether the recovered environment is actually healthy?**

---

## Part 18 — DR Testing

A DR strategy that exists only in documentation is not proven.

Testing can include:

```text
Backup Restore
Database Recovery
Node Failure
AZ Failure
Region Simulation
DNS Failover
Application Recovery
Terraform Rebuild
Secret Recovery
```

Start with controlled tests.

For example:

```text
Restore database backup
 ↓
Start application against restored database
 ↓
Run order test
 ↓
Measure recovery time
```

Record actual:

```text
RPO
RTO
Manual Steps
Automation Gaps
Failure Points
```

---

## Part 19 — Recovery Runbook

Create a practical ShopSphere regional recovery runbook.

It should contain:

```text
1. Declare incident
2. Confirm regional failure
3. Freeze normal changes
4. Determine recovery point
5. Activate DR environment
6. Recover database
7. Validate secrets and identity
8. Deploy application
9. Verify networking
10. Verify health
11. Shift traffic
12. Validate business transactions
13. Monitor
14. Communicate recovery
15. Begin primary-region restoration
```

The runbook should identify:

```text
Owner
Command / Action
Expected Result
Failure Condition
Escalation
```

---

## Part 20 — DR Failure Drill

Simulate a regional disaster conceptually or in a controlled lab.

Start with:

```text
Primary Region
```

Assume it is unavailable.

Then work through:

```text
How do users reach DR?
Where is the database?
Where is the image?
Where are the secrets?
Where is Terraform state?
How is EKS recreated?
How is DNS changed?
How is application health verified?
```

Do not accept answers such as:

**“We have backups.”**

Explain the entire recovery chain.

---

## Part 21 — Cost Engineering

Now connect the architecture to money.

Cloud cost is not simply:

```text
Number of resources × price
```

It is the result of:

```text
Architecture
Usage
Capacity
Region
Data Transfer
Storage
Requests
Licensing
Redundancy
Operational Choices
```

A Lead DevOps engineer should be able to explain what architectural decisions drive the bill.

---

## Part 22 — Cost Drivers in ShopSphere

Review:

```text
EKS
Worker nodes
Load balancers
Database
Storage
NAT Gateway
Data transfer
ECR
Logs
Metrics
Traces
Backups
DR infrastructure
```

Then ask:

**Which of these costs exist because of reliability requirements?**

For example:

```text
Multiple AZs
→ Additional infrastructure

DR Region
→ Additional infrastructure

Cross-region replication
→ Replication + storage + transfer

Central observability
→ Telemetry storage + ingestion
```

This connects cost directly to architecture.

---

## Part 23 — NAT Gateway as a Cost Example

NAT Gateway is a useful architecture-cost relationship.

A private application subnet may use:

```text
Private Subnet
 ↓
NAT Gateway
 ↓
Internet Gateway
 ↓
Internet
```

This provides controlled outbound connectivity but introduces charges.

If workloads frequently access AWS services, VPC endpoints may reduce certain traffic paths and improve architecture depending on the service and usage pattern.

Do not remove NAT simply to reduce cost.

First understand what traffic depends on it.

---

## Part 24 — Right-Sizing

ShopSphere's Kubernetes nodes should match actual workload requirements.

Suppose:

```text
Current:
Large nodes
Low utilization
```

Potential optimization:

```text
Smaller nodes
Better utilization
```

But excessive downsizing can cause:

```text
CPU pressure
Memory pressure
Pod evictions
Scaling instability
Performance degradation
```

Right-sizing therefore requires:

```text
Usage Data
Capacity Requirements
Availability Requirements
Scaling Behavior
```

Do not optimize from a single day's utilization graph.

---

## Part 25 — Autoscaling and Cost

Autoscaling can reduce unnecessary idle capacity.

For example:

```text
Low traffic
 ↓
Fewer Pods / Nodes

High traffic
 ↓
More Pods / Nodes
```

But autoscaling can also increase cost rapidly if a workload generates unexpected demand.

Set appropriate:

```text
Minimum Capacity
Maximum Capacity
Resource Requests
Resource Limits
HPA Thresholds
Cluster Scaling Limits
```

Cost controls should work alongside reliability controls.

---

## Part 26 — Observability Cost

Logs, metrics, and traces are valuable but not free.

High-cardinality metrics and verbose logs can generate substantial telemetry volume.

Ask:

```text
What do we collect?
Why do we collect it?
How long do we retain it?
Who needs it?
What must be searchable immediately?
What can be archived?
```

Use retention appropriate to operational and compliance requirements.

Do not solve observability by collecting everything forever.

---

## Part 27 — Cost Allocation

ShopSphere should be able to answer:

```text
How much does Dev cost?
How much does UAT cost?
How much does Production cost?
How much does DR cost?
How much does the platform cost?
```

Then go one level deeper:

```text
Application
Team
Environment
Service
Cost Center
```

Use account boundaries, tags, billing data, and resource metadata together.

Cost visibility should support engineering decisions rather than simply producing monthly reports.

---

## Part 28 — Unit Economics

Introduce a useful Lead-level concept:

**Cost per business unit.**

For ShopSphere, examples could be:

```text
Cost per 1,000 orders
Cost per 1,000 active customers
Cost per million API requests
```

Suppose cloud cost rises 20% but order volume rises 100%.

Absolute cost increased.

But cost per order decreased.

This gives a more useful view of infrastructure efficiency.

---

## Part 29 — Reliability vs Cost Trade-Off

Consider two designs.

Design A:

```text
Single Region
Multi-AZ
Automated Backups
Rebuild DR
```

Design B:

```text
Multi-Region
Active/Passive
Continuous Replication
Warm Standby
```

Design B may provide faster recovery.

It also requires more infrastructure and operational complexity.

The architecture decision should therefore document:

```text
RPO
RTO
Expected Failure
Cost
Operational Complexity
Business Impact
```

Do not choose DR architecture by technology popularity.

Choose it from business requirements.

---

## Part 30 — Cost Optimization Exercise

Review the ShopSphere architecture and identify at least ten cost drivers.

For each, record:

```text
Resource
Why It Exists
Cost Driver
Optimization
Reliability Impact
Risk
Owner
```

Example:

```text
DR EKS capacity
Why:
Regional recovery

Optimization:
Reduce standby capacity

Risk:
Longer recovery

Owner:
Platform
```

This forces you to understand the relationship between cost and reliability rather than treating optimization as deleting resources.

---

## Part 31 — DR + Cost Architecture Review

Now draw the full architecture.

Include:

```text
Primary Region
DR Region
EKS
Database
ECR
Secrets
Terraform State
DNS
Observability
Networking
CI/CD
```

Then annotate each component with:

```text
RPO
RTO
Failure Domain
Recovery Method
Cost Driver
Owner
```

You should be able to explain why every DR component exists.

---

## Part 32 — Senior/Lead Interview Recall

Answer these without looking at the lesson.

1. What is RPO?
2. What is RTO?
3. What is the difference between HA and DR?
4. Why is multi-AZ not multi-region?
5. What is the difference between backup and replication?
6. Why must backups be restore-tested?
7. How would you recover a Kubernetes platform?
8. Why should stateless compute be rebuildable?
9. How would you recover Terraform state?
10. What happens if the primary region is unavailable?
11. How does DNS participate in regional failover?
12. What happens to secrets during DR?
13. Where does the Production container image come from during DR?
14. How do you preserve artifact traceability during recovery?
15. What does active/active mean?
16. What does active/passive mean?
17. Why is observability part of DR?
18. What are ShopSphere's major cloud cost drivers?
19. How can Kubernetes autoscaling affect cost?
20. Why can excessive logging become a cost problem?
21. What is unit economics in cloud?
22. How would you optimize cost without reducing required availability?
23. Why is DR architecture a business decision?
24. What would you test during a DR exercise?
25. How would you prove that ShopSphere actually meets its RPO and RTO?

---

## Part 33 — Day 39 Completion Criteria

Complete Day 39 when you can demonstrate:

```text
[ ] RPO understood
[ ] RTO understood
[ ] HA vs DR understood
[ ] Failure domains identified
[ ] Multi-AZ vs multi-region understood
[ ] ShopSphere recovery tiers defined
[ ] Database backup strategy defined
[ ] Database recovery tested
[ ] Backup vs replication understood
[ ] Kubernetes rebuild strategy defined
[ ] Terraform state recovery strategy defined
[ ] DR region architecture designed
[ ] DNS failover considered
[ ] Secrets recovery designed
[ ] Container image availability in DR verified
[ ] Observability during DR designed
[ ] DR runbook created
[ ] DR exercise completed
[ ] Actual recovery time measured
[ ] Actual recovery point measured
[ ] Major ShopSphere cost drivers identified
[ ] Kubernetes cost reviewed
[ ] NAT/network cost reviewed
[ ] Observability cost reviewed
[ ] Backup/DR cost reviewed
[ ] Cost allocation model created
[ ] Unit economics considered
[ ] Cost optimization exercise completed
[ ] Reliability/cost trade-offs documented
[ ] DR architecture diagram completed
```

The most important completion criterion is:

**You can explain exactly how ShopSphere recovers from a major failure, how much data/service interruption the business experiences, how you would prove that recovery works, and what that resilience costs.**

---

## Part 34 — What Comes Next

ShopSphere now has almost the complete Senior/Lead DevOps architecture:

```text
Foundation
 ↓
Networking
 ↓
Security
 ↓
CI/CD
 ↓
Reliability
 ↓
Observability
 ↓
Terraform Governance
 ↓
Kubernetes
 ↓
Multi-Account Architecture
 ↓
Disaster Recovery
 ↓
Cost Engineering
```

Day 40 is the final architecture review.

There will be no new major technology to memorize.

Instead, you will be given a production scenario and asked to think like the person responsible for the entire platform.

You will need to defend:

```text
Architecture
Networking
Identity
Terraform
Kubernetes
CI/CD
Security
Reliability
Observability
DR
Cost
Governance
```

The final transition is:

**From learning individual technologies → to making and defending system-level engineering decisions.**

---

## Cleanup

Keep the ShopSphere primary and DR architecture because Day 40 uses the complete system.

Remove only temporary DR-test resources and restore any deliberately modified components.

Verify:

```text
Primary environment healthy
DR environment known state
Database restored / verified
DNS restored
Secrets correct
IAM correct
Terraform state healthy
Kubernetes workloads healthy
Observability healthy
Temporary resources removed
Temporary permissions removed
```

Record the final DR baseline:

```text
Primary Region:
DR Region:
RPO:
RTO:
Database Recovery Method:
Application Recovery Method:
DNS Failover Method:
Secret Recovery Method:
Terraform State Recovery Method:
Container Image Source:
Observability:
Estimated DR Cost:
Known-Good Commit:
Last DR Test:
Measured Recovery Time:
Measured Recovery Point:
```

The key operational lesson from today is:

**Reliability is a business requirement expressed through engineering, and every reliability decision has a cost.**
