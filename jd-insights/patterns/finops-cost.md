# FinOps + Cost Awareness

## In one sentence

Lead cloud JDs (Azure and AWS) add "cost-effective" next to "secure and scalable", meaning you should treat cost as a design input and be able to find and fix waste.

## What employers ask for

- Design with cost in mind, not as an afterthought
- Visibility: tags, budgets, and alerts so spend is attributable
- Right-sizing: match compute and storage to real usage
- Environment hygiene: non-prod does not run like prod
- Explain cost trade-offs to non-engineers
- Scarce compute: GPU capacity is often not on the shelf. A capacity reservation (AWS On-Demand Capacity Reservations, EC2 Capacity Blocks for ML) holds the machines. A savings plan only buys a discount. Those are different controls
- Service quotas: request increases before the release, not during it. Quota is platform capacity. Capacity planning is part of the release plan

## Mental model

```text
See it        → tags + cost views
   ↓             (who spends what, on what)
Explain it    → map spend to teams and environments
   ↓
Reduce it     → right-size · schedule off-hours
   ↓             reserve steady load · delete orphans
Keep it down  → budgets + alerts + policy
                 (require tags, block oversized SKUs)
```

Easy wins to name in interviews:

- Dev and test shut down at night and weekends
- Orphaned disks, IPs, and old snapshots deleted
- Steady workloads on reservations or savings plans
- Autoscale instead of sized-for-peak
- Scarce SKUs (GPUs): reserve capacity and raise quotas before go-live, not during the incident

| Concept | Azure | AWS |
|:--|:--|:--|
| Cost views | Cost Management | Cost Explorer |
| Budgets + alerts | Budgets | Budgets |
| Commit discounts | Reservations / Savings Plan | RIs / Savings Plans |
| Tag enforcement | Azure Policy | Tag Policies / SCPs |

## Remember

> **Cost is a feature of the architecture. If you cannot say who spends what, you cannot reduce it.**

## Study these days first

1. [Day-39/01-concepts.md](../../Day-39/01-concepts.md) - cost engineering project
2. [Day-11/01-concepts.md](../../Day-11/01-concepts.md) - structure enables attribution
3. [Day-17/01-concepts.md](../../Day-17/01-concepts.md) - GPU and other special node pools
4. [Day-22/01-concepts.md](../../Day-22/01-concepts.md) - quota is platform capacity
5. [Day-30/01-concepts.md](../../Day-30/01-concepts.md) - cost shows up in design reviews

Also note: every hands-on Day lesson ends with a cost check and cleanup section. That habit is FinOps in miniature.

## Common interview question

**Q: The monthly Azure bill doubled. What do you do?**

Outline:
1. Open cost views, break down by subscription, service, and tag.
2. Find the delta: new resource, scaled-up SKU, data egress, forgotten environment.
3. Quick wins first (shut down, delete, downsize), then structural fixes.
4. Prevent repeat: budget alerts, required tags, policy limits on SKUs.

## Honest gap note

You do not need a FinOps certificate for these roles. Showing the loop above, plus one real story of cutting waste, beats tool-name claims.

## Source tags

EPAM Lead Azure Cloud ("cost-effective Azure solutions") · EPAM Lead Platform · EPAM Lead AWS DevOps (cost optimisation and billing) · 2026-10-13 market (GPU capacity reservations, quota lead time)
