# Application Environments: Accelerate, Then Hand Over

## In one sentence

Some Azure platform roles sit beside the app team, turn the app into an environment spec, stand up Dev, UAT, and Prod, land the first pipeline deploy, then hand over so the team self-serves.

## What employers ask for

- Sit with application owners, not only with the platform team
- Translate the app (runtime, data, identity, inbound path) into an environment spec
- Provision Dev, UAT, and Prod on Azure with Terraform and Azure DevOps
- Enable the first pipeline deploy, so the app actually lands
- Hand over: the team runs the next change without a ticket
- Interview: walk the whole path and show how you coach. Raw IaC syntax is not enough

## Mental model

```text
App owners  →  what does this app need?
        ↓
Environment spec (compute, data, identity, network, secrets)
        ↓
Terraform module × Dev / UAT / Prod
        ↓
Azure DevOps: plan → approve → apply
        ↓
First pipeline deploy succeeds
        ↓
Hand over: who applies, who approves, who is paged
        ↓
Team self-serves. You leave.
```

The [Azure IaC card](azure-iac-pipelines.md) is the plan-review-approve-apply loop. The [GitOps card](gitops-platform.md) is the paved road as a product. This card is the engagement: you land the first team on that road, then you get out of the way.

Day-05 already maps branches to Dev, UAT, and Prod. Day-09 already says one module, different values. Day-06 is the first application pipeline. Day-21 starts from the app, not from a service list. The interview puts those four together in one walkthrough, with the owners in the room.

Work a small example. A .NET API needs a private store, a managed identity, and inbound HTTPS. You write that spec with the owners. You stamp three environments from one module. You watch the first pipeline put the API in Dev. You sit with the team while they promote to UAT. Then they own Prod. You do not stay as their ticket queue.

> **Remember:** The job ends when the team can ship the next change without you. A finished module with no first deploy is not done.

**Understand:** Coaching is part of the delivery. The interview will ask you to walk Dev to Prod with the app team beside you.

**Look-up:** the app runtime the owners name. Do not invent a new Azure product.

**Exit check:** Name the steps from the sit-down to hand-over. Then say what is still missing if only Terraform apply succeeded.

## Remember

> **Employers are not buying a Terraform repo. They are buying Dev, UAT, and Prod that the app team can run after you leave.**

## Study these days first

1. [Day-05/01-concepts.md](../../Day-05/01-concepts.md) - why Dev, UAT, and Prod exist
2. [Day-09/01-concepts.md](../../Day-09/01-concepts.md) - one module, different values per environment
3. [Day-06/01-concepts.md](../../Day-06/01-concepts.md) - the first application pipeline
4. [Day-08/01-concepts.md](../../Day-08/01-concepts.md) - why IaC exists
5. [Day-10/01-concepts.md](../../Day-10/01-concepts.md) - separate state per environment
6. [Day-22/01-concepts.md](../../Day-22/01-concepts.md) - the Azure platform picture
7. [Day-16/01-concepts.md](../../Day-16/01-concepts.md) - the paved road the team inherits
8. [Day-21/01-concepts.md](../../Day-21/01-concepts.md) - start from the app, then choose Azure

## Common interview question

**Q: A product team needs Dev, UAT, and Prod on Azure. How do you land them, then leave?**

Outline:
1. Sit with the owners. Write the spec: runtime, data, identity, inbound path, secrets.
2. One Terraform module. Separate state per environment. Azure DevOps runs plan, a human approves, then apply.
3. First pipeline deploy into Dev. Walk UAT with them. Prod gets extra gates.
4. Hand over: who applies, who approves, who is paged, where the runbook lives.
5. Honest: say if you have not coached a team through the first deploy. Transfer Day-09 and Day-06. Do not only recite resource types.

## Honest gap note

The course labs stamp environments. They do not grade a coaching session. Transfer Day-21 (start from the app) and Day-06 (the first pipeline). Do not claim a consulting engagement you have not run.

## Source tags

2026-11-06 market (application-environment acceleration, Azure Terraform + Azure DevOps, first-pipeline handover)
