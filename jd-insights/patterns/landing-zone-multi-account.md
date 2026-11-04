# Landing Zones + Multi-Account Thinking

## In one sentence

Lead cloud roles expect you to design the structure around workloads: how subscriptions or accounts are split, how identity and networking are shared, and where the guardrails live.

## What employers ask for

- Design a landing zone: the ready-to-use foundation teams deploy into
- Split environments and teams across subscriptions (Azure) or accounts (AWS)
- Central identity, logging, and networking shared by all workloads
- Policy guardrails: what teams can and cannot create
- Cost and security isolation between workloads
- Azure Landing Zone with hub-spoke networks; workloads like AKS live in spokes
- Interview style: design questions, not commands ("how would you structure...")
- Per-team or per-customer environment factory: one Terraform module stamps compute, data stores, IAM, and VPC. The pipeline applies it. Nobody clicks the console. IAM is least-privilege for that stack. A check after apply proves the pieces exist
- Azure Landing Zones in Bicep: management groups, Azure Policy, and RBAC as the design authority. Test the templates before deploy. Pester runs unit-style tests. PSRule checks the template against Azure Policy-shaped rules. Look-up the cmdlets. The idea is the same as `terraform test` plus a policy scan
- Data residency: keep regulated data in the region the contract names. Policy blocks other regions. A resource group does not keep data in one country
- Audit evidence for ISO 27001 / SOC 2 / HIPAA style reviews: encryption at rest and in transit, a privileged-access review, change records (Git and pipeline), and logs you can show as evidence. The auditor asks "show me", not "we encrypt"
- Regulated stores (health imaging is one example) also need a restore you have run and timed. An untested backup fails the same review. Day-39 measures RTO and RPO

## Mental model

```text
Management / Org root
   │
   ├── Platform (shared)
   │     ├── Identity
   │     ├── Connectivity (hub network)
   │     └── Logging
   │
   └── Workloads (spokes)
         ├── Team A: dev · test · prod
         └── Team B: dev · test · prod

Guardrails (policy) apply from the top down.
New workload = stamp out a spoke, inherit the rules.
```

The same stamp becomes a factory when many teams or customers need it:

```text
Pipeline (no console)
   ↓
Module × team / customer
   ↓
VPC · IAM · compute · data
   ↓
Validate (does it exist? can it reach?)
```

| Concept | Azure | AWS |
|:--|:--|:--|
| Isolation unit | Subscription | Account |
| Grouping | Management groups | Organizations / OUs |
| Guardrails | Azure Policy | SCPs |
| Network pattern | Hub-spoke VNets / Virtual WAN | Transit Gateway / hub VPC |
| Landing zone brand | Azure Landing Zones (CAF) | Control Tower |

Design authority sits above the stamp. Management groups plus Azure Policy decide what teams may create, so a spoke cannot invent a public IP or a region the platform forbids. Azure RBAC answers who may act. Policy answers whether the resource is allowed. Hub-and-spoke peering is the usual network for a small number of spokes (Day-12). Azure Virtual WAN is the other pattern when the mesh of connections would be too many to operate (Day-24). FinOps levers (required tags, budgets, SKU limits) apply from that same top-down scope, so cost control is a guardrail, not a later cleanup.

Azure shops often ship that landing zone as Bicep modules (CAF / Azure Landing Zones). The course lab uses Terraform for the same shape. Before deploy, Bicep pipelines commonly run Pester (does the module behave?) and PSRule (does the template break a policy baseline?). Those names are Look-up. Day-8 already teaches `what-if`. Day-36 already teaches a policy check on the plan. This course's analogue is `terraform test`.

> **Remember:** Management groups plus Policy plus RBAC are the authority. Pester and PSRule are how a Bicep landing zone proves it before apply.

## Data stays in region, evidence stays findable

```text
Policy: allowed regions only
        ↓
Data stores live in those regions (not "the resource group is in EU")
        ↓
Evidence folder the auditor can open
  ├── encryption at rest / in transit
  ├── privileged access review (who still has admin)
  ├── change records (PR, plan, approve, apply)
  └── logs (who did what, retained)
```

A region is a physical place. Data residency means the bytes stay there. Azure Policy or an SCP should fail a store in the wrong region. Day-11 already says a resource group is not a region. This card adds the audit ask: you can show the control and the last review.

ISO 27001, SOC 2, and HIPAA are evidence frameworks. They do not install a product. Encryption, access reviews, change tickets, and logs are the same four piles most reviews request. A regulated store adds one more proof: a restore you have run and timed. Day-18 covers identity. Day-10 and Day-25 cover the change record. Day-20 covers logs. Day-39 covers the restore drill.

> **Remember:** Residency is where the bytes live. Evidence is what you can show. "We encrypt" is not evidence. An untested backup is not evidence either.

**Look-up:** the control IDs a given auditor names. Do not invent an ISO lab.

## Remember

> **A landing zone is a paved parking lot. Workloads park in their own numbered spot; lights, gates, and cameras are already there.**

## Study these days first

1. [Day-11/01-concepts.md](../../Day-11/01-concepts.md) - enterprise structure
2. [Day-12/01-concepts.md](../../Day-12/01-concepts.md) - hub-spoke networking
3. [Day-18/01-concepts.md](../../Day-18/01-concepts.md) - identity and secrets
4. [Day-22/01-concepts.md](../../Day-22/01-concepts.md) - Azure platform view
5. [Day-38/01-concepts.md](../../Day-38/01-concepts.md) - hands-on project
6. [Day-36/01-concepts.md](../../Day-36/01-concepts.md) - the plan, apply, and validate pipeline that stamps the factory
7. [Day-24/01-concepts.md](../../Day-24/01-concepts.md) - hub-and-spoke first, Virtual WAN when the mesh grows
8. [Day-08/01-concepts.md](../../Day-08/01-concepts.md) - Bicep `what-if`; Pester and PSRule are the usual Bicep test names
9. [Day-39/01-concepts.md](../../Day-39/01-concepts.md) - restore drills that an auditor can see

## Common interview question

**Q: A company moves 10 teams to Azure. How do you structure subscriptions?**

Outline:
1. Separate platform (identity, connectivity, logging) from workloads.
2. Per team, per environment subscriptions; prod isolated from non-prod.
3. Management groups carry policy: allowed regions, required tags, no public IPs where forbidden. That pair (management groups plus Azure Policy) is the design authority. RBAC is who may act.
4. New team onboarding is a repeatable IaC stamp, not a bespoke build. After apply, a check proves the VPC, IAM, and data stores exist. Azure shops often stamp this in Bicep. Test with Pester and PSRule (Look-up), or `terraform test` in this course.
5. Name hub-and-spoke for a small estate, Virtual WAN when the mesh would be too many to operate. FinOps levers (tags, budgets, SKU limits) sit on the same policy tree.
6. Mention the trade-off: more subscriptions means more structure to manage, so automate it.

**Q: An auditor asks how you keep customer data in one region and how you prove it.**

Outline:
1. Policy allows only that region. The store is created there. A resource group name is not residency.
2. Evidence: encryption at rest and in transit, last privileged-access review, Git and pipeline change records, retained logs.
3. ISO 27001 / SOC 2 / HIPAA ask for that evidence. They do not install a product. Day-11 is the region lesson.
4. For a regulated store, also show the last restore drill and the measured RTO and RPO (Day-39).

## Honest gap note

Few people have built a full landing zone alone. It is honest to say you worked inside one and extended it, then show you understand the design by walking the diagram above. Design reasoning is what the interview grades.

## Source tags

EPAM Lead Azure Cloud · EPAM Lead Platform · EPAM Senior Azure DevOps (migration) · EPAM Senior Azure Cloud (KZ) · Turkey / Central Asia Platform (per-tenant environment factory) · Turkey banking platform (account vending) · 2026-10-23 market (Azure design authority) · 2026-10-29 market (Bicep landing zones, Pester, PSRule, Policy, RBAC, management groups) · 2026-11-02 market (data residency, ISO 27001 / SOC 2 evidence) · 2026-11-03 market (HIPAA / SOC 2 stores, tested restores)
