# Azure + IaC + Pipelines (the most common ask)

## In one sentence

Most Azure senior roles want one person who can describe infrastructure as code (Terraform or Bicep) and ship it safely through Azure DevOps pipelines.

## What employers ask for

- Terraform and Bicep together, many JDs name both (sometimes OpenTofu)
- Reusable IaC modules across dev, test, and prod environments
- Azure DevOps pipelines: build, plan, approve, apply
- Remote state, locking, and drift control
- Secure defaults: identity, Key Vault, private networking baked into modules
- Migration work: move many existing on-prem apps (one JD counts 20+ Java and .NET systems) onto Azure; re-platforming means the same app on a new runtime, not a rewrite
- Azure serverless operations: deploy Functions and Logic Apps with Bicep, watch them with Application Insights and Azure Monitor, and give them a managed identity so they do not store secrets

## Mental model

```text
Engineer writes module code
        ↓
Pull request + review
        ↓
Pipeline: terraform plan
        ↓
Human approves the plan
        ↓
Pipeline: terraform apply
        ↓
Same module → dev → test → prod
        (only variables change)
```

The JD words differ (platform engineering, cloud automation, IaC engine). The loop above is what they all mean.

| Concept | Azure | AWS |
|:--|:--|:--|
| Native IaC | Bicep | CloudFormation |
| Cross-cloud IaC | Terraform | Terraform |
| Pipeline service | Azure DevOps Pipelines | CodePipeline / GitHub Actions |
| State backend | Azure Storage + lock | S3 + DynamoDB lock |

## Serverless on Azure still needs IaC

```text
Bicep describes Function / Logic App
        ↓
Pipeline: what-if → approve → deploy
        ↓
Managed identity calls Key Vault / Storage / APIs
        ↓
Application Insights + Azure Monitor show failures and latency
```

Functions and Logic Apps are event-driven compute. Azure runs the servers. You still describe the resources in Bicep (or Terraform). You ship them through the same plan-review-approve-apply loop. You watch them with native Azure tools. Application Insights traces requests. Azure Monitor holds metrics, logs, and alerts.

A managed identity is the identity Azure assigns to the Function or Logic App. The app then calls Key Vault or Storage without a password in config. Day-23 teaches Functions as event-driven compute, not a small always-on app. Day-08 and Day-09 teach Bicep. Day-18 teaches managed identity. Day-20 teaches Application Insights and Azure Monitor. Logic Apps is not a Day lesson. Treat it as a workflow that runs when an event arrives. Deploy it as Azure resources, with the same IaC, identity, and monitoring rules.

> **Remember:** Serverless does not mean no operations. You still deploy with Bicep, watch with Azure Monitor, and use a managed identity.

**Look-up:** Logic Apps connectors, Function hosting plans, and Application Insights sampling. Do not invent a Logic Apps lab.

## Remember

> **Employers are not buying Terraform syntax. They are buying a safe change process: plan, review, approve, apply, repeat in every environment.**

## Study these days first

1. [Day-08/01-concepts.md](../../Day-08/01-concepts.md) - why IaC exists
2. [Day-09/01-concepts.md](../../Day-09/01-concepts.md) - modules and environments
3. [Day-10/01-concepts.md](../../Day-10/01-concepts.md) - state and team workflow
4. [Day-06/01-concepts.md](../../Day-06/01-concepts.md) - the pipeline itself
5. [Day-22/01-concepts.md](../../Day-22/01-concepts.md) - the Azure platform picture
6. [Day-25/01-concepts.md](../../Day-25/01-concepts.md) - putting it together
7. [Day-37/01-concepts.md](../../Day-37/01-concepts.md) - incremental migration with a rollback boundary (Parts 26 and 36)
8. [Day-23/01-concepts.md](../../Day-23/01-concepts.md) - Functions as event-driven compute
9. [Day-18/01-concepts.md](../../Day-18/01-concepts.md) - managed identity
10. [Day-20/01-concepts.md](../../Day-20/01-concepts.md) - Application Insights and Azure Monitor

Interview-ready deep dives: [Day-08 v2](../../Day-08-IaC-Terraform-Bicep-Interview-Ready-Clean-v2.md), [Day-09 v2](../../Day-09-IaC-Modules-Environments-Interview-Ready-Clean-v2.md), [Day-10 v2](../../Day-10-Terraform-State-Enterprise-Interview-Ready-Clean-v2.md).

## Common interview question

**Q: How do you promote the same infrastructure from dev to prod safely?**

Outline:
1. One module, separate state and variable files per environment.
2. Pipeline runs plan, a human reviews the diff, then apply.
3. Prod gets extra gates: approvals, locked state, no manual portal changes.
4. Drift is detected by re-running plan, not by guessing.

**Q: How do you operate an Azure Function in production?**

Outline:
1. Describe it in Bicep. Pipeline runs what-if, a human approves, then deploy.
2. Attach a managed identity. Grant it the narrow Azure RBAC it needs. No secrets in app settings if Key Vault can hold them.
3. Send traces to Application Insights. Alert from Azure Monitor on failures and latency users feel.
4. Honest: Logic Apps is the same IaC and identity story. Say if you have not built a Logic App. Do not invent connectors.

## Honest gap note

JDs sometimes name OpenTofu or Ansible. If you use Terraform daily, say so, and say you are happy to work in OpenTofu-compatible workflows (the language is the same). Do not claim daily Ansible depth you do not have; explain configuration as code concepts instead.

Logic Apps has no Day lesson. Transfer Functions, Bicep, managed identity, and Azure Monitor. Name the gap if the interviewer asks for Logic Apps depth.

## Source tags

EPAM Azure Lead (TR, KZ) · EPAM Senior Azure DevOps · EPAM Senior Azure DevOps (KZ, migration) · EPAM Senior Azure Engineer (KZ) · EPAM Lead Azure Cloud · EPAM Senior Azure Cloud (KZ) · EPAM Lead DevOps (KZ) · 2026-10-28 market (Functions / Logic Apps with Bicep, App Insights, managed identity)
