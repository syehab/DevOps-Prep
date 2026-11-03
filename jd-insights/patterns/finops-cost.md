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
- AI / LLM workloads: treat tokens per request, cost per request and per tenant, plus latency and error rate of model calls, as first-class metrics. Set a spend budget and alert on it like an error budget
- Cost as routine work, not a quarterly surprise: required tags, right-sizing, a billing export you can query, a monthly review, and a plan for commitments (reservations or savings plans)
- Off-hours as a job, not a slogan: deallocate non-prod VMs, sweep orphaned disks, IPs, NICs, and snapshots, and retry when the run fails. A silent failed cleanup is not a saving

## Mental model

```text
See it        → tags + cost views + billing export
   ↓             (who spends what, on what)
Explain it    → map spend to teams and environments
   ↓
Reduce it     → right-size · deallocate off-hours
   ↓             reserve steady load · sweep orphans (retry)
Keep it down  → monthly review + budgets + policy
                 (require tags, block oversized SKUs,
                  plan the next commitment)
```

Easy wins to name in interviews: deallocate non-prod, sweep orphans with retries, autoscale, reserve steady load, raise scarce quotas before go-live, and export the bill (Azure Cost Management export, AWS Cost and Usage Report) so engineering can query it.

| Concept | Azure | AWS |
|:--|:--|:--|
| Cost views | Cost Management | Cost Explorer |
| Budgets + alerts | Budgets | Budgets |
| Commit discounts | Reservations / Savings Plan | RIs / Savings Plans |
| Tag enforcement | Azure Policy | Tag Policies / SCPs |

## Token spend is a first-class metric

```text
tokens per request
cost per request / per tenant
latency of the model call
error rate of the model call
        ↓
budget + alert  (same shape as an error budget, for spend)
```

When a service calls a model, treat tokens and money as metrics, not as a surprise on the invoice. Track tokens per request, cost per request and per tenant, plus latency and error rate of the model calls.

Set a spend budget. Alert when burn is fast, the same way an error budget pages you when reliability burns. Day-20 already says a surprise token bill is an observability miss. Day-39 is the cost project.

> **Remember:** Token cost needs a budget and an alert, like an error budget for spend.

**Exit check:** Name four first-class metrics for a model call, and say what you do when spend burns the budget.

Cost work has a calendar. Once a month, open the export, check tags, right-size what is idle, and decide the next commitment. Day-39 already teaches attribution and unit cost.

## Off-hours is a job, not a hope

JDs now ask for the automation, not the slogan "schedule off-hours."

```text
Schedule (nights, weekends, non-prod)
        ↓
Deallocate the VMs (stop compute billing)
        ↓
Find orphans (disks, IPs, NICs, snapshots with no owner)
        ↓
Delete or tag for review
        ↓
On failure: retry with backoff, then page
```

Deallocate (Azure) stops the VM and stops compute charges. The disk can still bill. A stop that leaves the VM allocated is not a saving. Orphans are leftover disks, public IPs, NICs, and snapshots after a destroy that did not finish. Write the job so a failed run retries, then alerts. A silent failed cleanup is how last month's savings never happen. Day-23 treats the VM as something you replace. The runner is Look-up (Azure Automation, a Logic App, or a pipeline on a cron).

> **Remember:** A schedule is not FinOps. A job that deallocates, sweeps orphans, and retries is.

**Exit check:** A nightly job failed and nobody was paged. Are the non-prod VMs still billing, and what do you fix first?

## Remember

> **Cost is a feature of the architecture. If you cannot say who spends what, you cannot reduce it. Review the export every month.**

## Study these days first

1. [Day-39/01-concepts.md](../../Day-39/01-concepts.md) - cost engineering project
2. [Day-11/01-concepts.md](../../Day-11/01-concepts.md) - structure enables attribution
3. [Day-17/01-concepts.md](../../Day-17/01-concepts.md) - GPU and other special node pools
4. [Day-22/01-concepts.md](../../Day-22/01-concepts.md) - quota is platform capacity
5. [Day-23/01-concepts.md](../../Day-23/01-concepts.md) - VMs you deallocate and replace
6. [Day-30/01-concepts.md](../../Day-30/01-concepts.md) - cost shows up in design reviews
7. [Day-20/01-concepts.md](../../Day-20/01-concepts.md) - token usage and model cost as metrics

Also note: every hands-on Day lesson ends with a cost check and cleanup section. That habit is FinOps in miniature.

## Common interview question

**Q: The monthly Azure bill doubled. What do you do?**

Outline:
1. Open cost views, break down by subscription, service, and tag.
2. Find the delta: new resource, scaled-up SKU, data egress, forgotten environment.
3. Quick wins first (shut down, delete, downsize), then structural fixes.
4. Prevent repeat: budget alerts, required tags, policy limits on SKUs, and a monthly review of the billing export plus the next commitment.

**Q: An LLM feature just shipped. What do you track, and how do you stop a surprise bill?**

Outline:
1. First-class metrics: tokens per request, cost per request and per tenant, latency, and error rate of the model calls.
2. Set a spend budget. Alert when burn is fast, the same shape as an error budget.
3. Day-20 already treats a surprise token bill as an observability miss, not a finance surprise.

## Honest gap note

You do not need a FinOps certificate for these roles. Showing the loop above, plus one real story of cutting waste, beats tool-name claims.

## Source tags

EPAM Lead Azure Cloud ("cost-effective Azure solutions") · EPAM Lead Platform · EPAM Lead AWS DevOps (cost optimisation and billing) · 2026-10-13 market (GPU capacity reservations, quota lead time) · 2026-10-26 market (AI token cost) · 2026-10-27 market (cost as monthly routine) · 2026-11-03 market (Azure VM deallocate + orphan cleanup with retries)
