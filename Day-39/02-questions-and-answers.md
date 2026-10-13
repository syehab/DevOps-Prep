# Day 39 — Questions and answers

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Then answer each item below before you open the Answer block. After that, do the lab in [03-implementation.md](03-implementation.md).

Write your own answer first. Open the Answer block only after you try. Keep the original numbering.

---

## Senior/Lead Interview Recall

Answer these without looking at the lesson.

---

## 1. What is RPO?

1. What is RPO?

<details>
<summary>Answer</summary>

Recovery Point Objective is the maximum acceptable data loss measured in time. ShopSphere example: 15 minutes.

If the database fails at 14:00 and the latest recoverable state is 13:50, you lost 10 minutes and still meet a 15-minute RPO.

</details>

---

## 2. What is RTO?

2. What is RTO?

<details>
<summary>Answer</summary>

Recovery Time Objective is the target maximum time to restore service after a qualifying outage. ShopSphere example: 60 minutes.

Restore at 14:40 after a 14:00 failure is 40 minutes and meets a 60-minute RTO. Do not mix RPO and RTO.

</details>

---

## 3. What is the difference between HA and DR?

3. What is the difference between HA and DR?

<details>
<summary>Answer</summary>

High availability keeps the service running through expected failures: Pod, node, AZ. Disaster recovery restores service after a failure that exceeds that design, such as a region loss.

HA is survive. DR is recover.

</details>

---

## 4. Why is multi-AZ not multi-region?

4. Why is multi-AZ not multi-region?

<details>
<summary>Answer</summary>

Three AZs in one region share that region. If the region fails, all three AZs fail.

Multi-region needs a primary plus a DR region. That costs more and adds operations.

</details>

---

## 5. What is the difference between backup and replication?

5. What is the difference between backup and replication?

<details>
<summary>Answer</summary>

Backup makes historical copies you restore later. Replication keeps a second copy near current state.

Replication can copy corruption or a bad delete. It is not a replacement for backups.

</details>

---

## 6. Why must backups be restore-tested?

6. Why must backups be restore-tested?

<details>
<summary>Answer</summary>

An untested backup is an assumption. Restore, validate data, point the app, then run a business transaction.

Measure actual RPO and RTO, not the brochure number.

</details>

---

## 7. How would you recover a Kubernetes platform?

7. How would you recover a Kubernetes platform?

<details>
<summary>Answer</summary>

Rebuild compute from definitions: Terraform creates infra, initialize the platform, Helm/GitOps restores workloads, wire secrets and identity, then start the app.

The cluster is reproducible. Persistent data is not.

</details>

---

## 8. Why should stateless compute be rebuildable?

8. Why should stateless compute be rebuildable?

<details>
<summary>Answer</summary>

Prefer rebuild over irreplaceable servers. Image in ECR, infra in Terraform, Kubernetes in Git, secrets in the secret store.

Protect the database with backup and replication. That is where durable state lives.

</details>

---

## 9. How would you recover Terraform state?

9. How would you recover Terraform state?

<details>
<summary>Answer</summary>

Stop Terraform changes. Restore the correct versioned S3 object. Validate, run `terraform plan`, confirm no surprise diffs, then resume.

Do not apply against empty state over live infrastructure.

</details>

---

## 10. What happens if the primary region is unavailable?

10. What happens if the primary region is unavailable?

<details>
<summary>Answer</summary>

Users must reach a DR region through DNS or global routing. That region needs network, EKS, a database recovery target, image access, secrets, and observability.

Standby level follows RTO and cost. Full active secondary costs more than rebuild-on-demand.

</details>

---

## 11. How does DNS participate in regional failover?

11. How does DNS participate in regional failover?

<details>
<summary>Answer</summary>

Health checks can move `api.shopsphere.example` from primary to DR. TTL, client caches, resolver behavior, and connection reuse delay the real cutover.

Test actual failover time. Do not trust TTL alone.

</details>

---

## 12. What happens to secrets during DR?

12. What happens to secrets during DR?

<details>
<summary>Answer</summary>

DR needs Production secrets through a designed replica or authorized path, not a paste into the DR cluster.

The DR workload identity gets scoped access. The whole DR env must not read every secret.

</details>

---

## 13. Where does the Production container image come from during DR?

13. Where does the Production container image come from during DR?

<details>
<summary>Answer</summary>

From the registry, with replication or alternate access into the DR region. Do not rebuild during the outage.

Record repository, digest, deployment version, and Git SHA.

</details>

---

## 14. How do you preserve artifact traceability during recovery?

14. How do you preserve artifact traceability during recovery?

<details>
<summary>Answer</summary>

Deploy the same digest you ran in primary. Map Git SHA → digest → DR deployment.

A new build during DR breaks the “same artifact” guarantee from Day 33.

</details>

---

## 15. What does active/active mean?

15. What does active/active mean?

<details>
<summary>Answer</summary>

Both regions serve traffic. Failover can be faster and capacity is used.

Cost: data consistency, routing, coordinated deploys, config, observability, and money.

</details>

---

## 16. What does active/passive mean?

16. What does active/passive mean?

<details>
<summary>Answer</summary>

Primary serves traffic. Secondary stands by. Operations are simpler.

Capacity sits idle until disaster. Choose from RTO/RPO, not popularity.

</details>

---

## 17. Why is observability part of DR?

17. Why is observability part of DR?

<details>
<summary>Answer</summary>

If metrics, logs, and alerts live only in the failed region, you go blind when you need evidence.

Keep telemetry independently available. The runbook must say how you know the recovered env is healthy.

</details>

---

## 18. What are ShopSphere's major cloud cost drivers?

18. What are ShopSphere's major cloud cost drivers?

<details>
<summary>Answer</summary>

EKS, worker nodes, load balancers, database, storage, NAT, data transfer, ECR, logs, metrics, traces, backups, and DR infra.

Ask which of those exist because of reliability: Multi-AZ, DR region, replication, central telemetry.

</details>

---

## 19. How can Kubernetes autoscaling affect cost?

19. How can Kubernetes autoscaling affect cost?

<details>
<summary>Answer</summary>

Scale down idle Pods and nodes to save money. Unexpected demand can scale cost up fast.

Set min/max, requests/limits, HPA thresholds, and cluster scale limits. Cost controls sit next to reliability.

</details>

---

## 20. Why can excessive logging become a cost problem?

20. Why can excessive logging become a cost problem?

<details>
<summary>Answer</summary>

Volume, retention, and high-cardinality metrics drive ingest and storage cost.

Collect what you need, keep hot what operators search, archive the rest. Do not keep every debug line forever.

</details>

---

## 21. What is unit economics in cloud?

21. What is unit economics in cloud?

<details>
<summary>Answer</summary>

Cost per business unit: per 1,000 orders, per 1,000 customers, per million API requests.

If the bill rises 20% and orders rise 100%, cost per order fell. Absolute spend is not the whole story.

</details>

---

## 22. How would you optimize cost without reducing required availability?

22. How would you optimize cost without reducing required availability?

<details>
<summary>Answer</summary>

Right-size nodes from usage data, not one graph. Replace unjustified NAT with VPC endpoints. Cut idle Dev. Shorten debug retention.

Do not shrink Prod HA or skip restore tests to hit a budget.

</details>

---

## 23. Why is DR architecture a business decision?

23. Why is DR architecture a business decision?

<details>
<summary>Answer</summary>

RPO, RTO, criticality, and downtime cost come from the business. Engineering then picks backup, replication, and standby.

Do not pick multi-region because it sounds reliable. Map it to the 60-minute RTO if that is the requirement.

</details>

---

## 24. What would you test during a DR exercise?

24. What would you test during a DR exercise?

<details>
<summary>Answer</summary>

Backup restore, database recovery, node and AZ loss, region simulation, DNS failover, app recovery, Terraform rebuild, secret recovery.

Start controlled: restore DB, start app, run an order test, measure actual RPO/RTO, manual steps, and gaps.

</details>

---

## 25. How would you prove that ShopSphere actually meets its RPO and RTO?

25. How would you prove that ShopSphere actually meets its RPO and RTO?

<details>
<summary>Answer</summary>

Run the restore, time it, and compare the recovered data timestamp with the failure time. Record measured RPO and RTO in the runbook.

Documentation is not proof. The last successful test is.

</details>

---

## 26. Recovery tiers

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

<details>
<summary>Answer</summary>

Tier 1: orders, payment, authentication — tightest RPO/RTO and tests. Tier 2: browse and search. Tier 3: analytics and reporting.

Do not spend Tier 1 money on reporting.

</details>

---

## 27. Failure domains and largest survivable domain

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

<details>
<summary>Answer</summary>

Container → Pod → node → AZ → region → account → provider. Kubernetes heals Pods. Other nodes cover a node. Multi-AZ covers an AZ.

Region loss needs DR. Ask: what is the largest domain this design can survive?

</details>

---

## 28. NAT Gateway as a cost example

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

<details>
<summary>Answer</summary>

Private egress through NAT is controlled and billed. If traffic is mostly AWS APIs, VPC endpoints can cut that path.

Do not delete NAT to save money until you know which flows need it.

</details>

---

## 29. Cost optimization exercise (expected outcome)

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

<details>
<summary>Answer</summary>

List at least ten drivers. For each: resource, why it exists, cost driver, optimization, reliability impact, risk, owner.

Example: warm DR EKS exists for regional recovery; shrink standby; risk is longer RTO; owner is platform.

</details>

---

## 30. DR failure drill — decide the chain

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

<details>
<summary>Answer</summary>

Primary region is gone. Answer: how users reach DR, where the database, image, secrets, and Terraform state live, how EKS is recreated, how DNS changes, how you verify health.

“We have backups” is not a chain. Walk every hop.

</details>

---

## 31. Regional recovery runbook (expected outcome)

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

<details>
<summary>Answer</summary>

Declare the incident. Confirm region loss and freeze changes. Pick the recovery point, activate DR, and recover the database. Validate secrets and identity, deploy the known digest, then check network and health.

Shift traffic, run a business transaction, monitor, and communicate. Then restore the primary. Each step needs owner, action, expected result, failure condition, and escalation.

</details>

---

## 32. Design A vs Design B reliability/cost

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

<details>
<summary>Answer</summary>

A: single region, Multi-AZ, backups, rebuild DR — cheaper, slower regional recovery. B: multi-region active/passive with replication and warm standby — faster, costlier, more ops.

Document RPO, RTO, expected failure, cost, complexity, and business impact. Pick from requirements.

</details>

---

## 33. DR + cost architecture review

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

<details>
<summary>Answer</summary>

Draw primary and DR: EKS, database, ECR, secrets, Terraform state, DNS, observability, network, CI/CD.

Annotate each with RPO, RTO, failure domain, recovery method, cost driver, and owner. Every DR box needs a why.

</details>

---

## 34. Capacity reservation versus a savings-plan discount

A GPU-backed release is two weeks away. What is the difference between a savings plan and a capacity reservation, and what do you do before go-live?

<details>
<summary>Answer</summary>

A savings plan or reserved instance buys a discount. A capacity reservation (On-Demand Capacity Reservations, EC2 Capacity Blocks for ML) holds the machines. They are different controls.

Request quota increases before the date. Reserve scarce SKUs in the release plan. Do not discover a quota limit during the incident. Quota is platform capacity, not a billing discount.

</details>

---

## Day 39 Completion Criteria

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
