# Landing Zones + Multi-Account Thinking

## In one sentence

Lead cloud roles expect you to design the structure around workloads: how subscriptions or accounts are split, how identity and networking are shared, and where the guardrails live.

## What employers ask for

- Design a landing zone: the ready-to-use foundation teams deploy into
- Split environments and teams across subscriptions (Azure) or accounts (AWS)
- Central identity, logging, and networking shared by all workloads
- Policy guardrails: what teams can and cannot create
- Cost and security isolation between workloads
- Interview style: design questions, not commands ("how would you structure...")

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

| Concept | Azure | AWS |
|:--|:--|:--|
| Isolation unit | Subscription | Account |
| Grouping | Management groups | Organizations / OUs |
| Guardrails | Azure Policy | SCPs |
| Network pattern | Hub-spoke VNets | Transit Gateway / hub VPC |
| Landing zone brand | Azure Landing Zones (CAF) | Control Tower |

## Remember

> **A landing zone is a paved parking lot. Workloads park in their own numbered spot; lights, gates, and cameras are already there.**

## Study these days first

1. [Day-11-L11-Cloud-Architecture-Enterprise-Structure.md](../../Day-11-L11-Cloud-Architecture-Enterprise-Structure.md) - enterprise structure
2. [Day-12-L12-Cloud-Networking-Azure-AWS.md](../../Day-12-L12-Cloud-Networking-Azure-AWS.md) - hub-spoke networking
3. [Day-18-L18-Identity-Secrets-Cloud-Security-v2.md](../../Day-18-L18-Identity-Secrets-Cloud-Security-v2.md) - identity and secrets
4. [Day-22-AZ-01-Azure-Platform-Architecture.md](../../Day-22-AZ-01-Azure-Platform-Architecture.md) - Azure platform view
5. [Day-38-Production-Project-08-Multi-Environment-Multi-Account-Architecture-Clean-Style.md](../../Day-38-Production-Project-08-Multi-Environment-Multi-Account-Architecture-Clean-Style.md) - hands-on project

## Common interview question

**Q: A company moves 10 teams to Azure. How do you structure subscriptions?**

Outline:
1. Separate platform (identity, connectivity, logging) from workloads.
2. Per team, per environment subscriptions; prod isolated from non-prod.
3. Management groups carry policy: allowed regions, required tags, no public IPs where forbidden.
4. New team onboarding is a repeatable IaC stamp, not a bespoke build.
5. Mention the trade-off: more subscriptions means more structure to manage, so automate it.

## Honest gap note

Few people have built a full landing zone alone. It is honest to say you worked inside one and extended it, then show you understand the design by walking the diagram above. Design reasoning is what the interview grades.

## Source tags

EPAM Lead Azure Cloud · EPAM Lead Platform · EPAM Senior Azure DevOps (migration)
