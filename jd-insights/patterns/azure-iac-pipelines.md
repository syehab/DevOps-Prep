# Azure + IaC + Pipelines (the most common ask)

## In one sentence

Most Azure senior roles want one person who can describe infrastructure as code (Terraform or Bicep) and ship it safely through Azure DevOps pipelines.

## What employers ask for

- Terraform and Bicep together, many JDs name both (sometimes OpenTofu)
- Reusable IaC modules across dev, test, and prod environments
- Azure DevOps pipelines: build, plan, approve, apply
- Remote state, locking, and drift control
- Secure defaults: identity, Key Vault, private networking baked into modules
- Policy-as-code on the plan: OPA, Conftest, or Checkov fail a public IP, a missing tag, or an open store before a human approves apply. Look-up the tool the JD names
- Migration work: move many existing on-prem apps (one JD counts 20+ Java and .NET systems) onto Azure; re-platforming means the same app on a new runtime, not a rewrite
- Multi-cloud migration: on-prem to cloud and cloud to cloud. Terraform is the common layer. The names change (AKS, EKS, GKE). The plan-review-approve-apply loop does not
- Azure serverless operations: deploy Functions and Logic Apps with Bicep, watch them with Application Insights and Azure Monitor, and give them a managed identity so they do not store secrets
- Hybrid CI/CD: Azure DevOps self-hosted agents on-prem when the build must see a private network, plus Environments and approvals for production. Terraform Cloud workspaces add remote state, run triggers, and policy checks. A plain remote backend only stores state and the lock. The pipeline still runs plan and apply

## Mental model

```text
Engineer writes module code
        ↓
Pull request + review
        ↓
Pipeline: terraform plan
        ↓
Policy check (OPA / Conftest / Checkov)
        ↓
Human approves the plan
        ↓
Pipeline: terraform apply
        ↓
Same module → dev → test → prod
        (only variables change)
```

The JD words differ (platform engineering, cloud automation, IaC engine). The loop above is what they all mean.

The policy check is a test on the plan. The same review that catches a bad variable also catches a public bucket. OPA, Conftest, and Checkov are Look-up names. Pick the one the JD uses and keep the gate in the pipeline. Day-36 already draws this evaluation step. The Day-25 and Day-36 labs run Checkov.

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

## On-prem agents and Terraform Cloud

```text
On-prem agent  →  sees the private network  →  talks to Azure
Azure DevOps Environment  →  human approval  →  apply

Plain remote backend     →  state + lock (you still run plan/apply)
Terraform Cloud workspace →  state + lock + runs + triggers + policy
```

A hosted agent lives in Microsoft's pool. A self-hosted agent is a machine you run, often on-prem, so the job can reach a private Git server, an internal artifact store, or a network that has no public inbound path. Day-19 already treats that agent as a security boundary: patch it, isolate jobs, and do not leave production credentials on the box. Day-06 already puts the production approval on an Environment.

Terraform Cloud (or HCP Terraform) is a hosted run service. A workspace is one state boundary, like one backend key. It also runs plan and apply, can start a downstream workspace after a successful apply (a run trigger), and can fail a plan that breaks a policy. A plain Azure Storage or S3 backend only keeps state and the lock. You still need a pipeline for the run, the policy check, and the approval. Day-10 teaches that backend. Pick Terraform Cloud when you want the run and the policy in the same product. Pick a plain backend when your Azure DevOps pipeline already owns those steps.

> **Remember:** The agent is where the job runs. The backend is where state lives. Terraform Cloud is a backend plus a run service. Do not mix those three sentences.

**Look-up:** agent pool registration and Terraform Cloud run-trigger UI. Do not invent a Terraform Cloud lab.

## Terraform is the common layer

```text
On-prem  ──Terraform──►  Cloud A
Cloud A  ──Terraform──►  Cloud B
```

JDs now ask for both moves: datacentre to cloud, and one cloud to another. Keep the same modules and the same plan-review-approve-apply loop. Change the provider and the names (AKS to EKS or GKE, VNet to VPC). Day-37 already teaches waves and a rollback boundary. Day-17 is the name map. Do not rewrite the application only to change the cloud.

> **Remember:** Terraform is the common language. The loop stays. Only the provider names change.

## Remember

> **Employers are not buying Terraform syntax. They are buying a safe change process: plan, policy check, review, approve, apply, repeat in every environment.**

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
11. [Day-36/01-concepts.md](../../Day-36/01-concepts.md) - policy evaluation before plan (Checkov is in the Day-25 and Day-36 labs)
12. [Day-19/01-concepts.md](../../Day-19/01-concepts.md) - self-hosted agents as a security boundary

Interview-ready deep dives: [Day-08 v2](../../Day-08-IaC-Terraform-Bicep-Interview-Ready-Clean-v2.md), [Day-09 v2](../../Day-09-IaC-Modules-Environments-Interview-Ready-Clean-v2.md), [Day-10 v2](../../Day-10-Terraform-State-Enterprise-Interview-Ready-Clean-v2.md).

## Common interview question

**Q: How do you promote the same infrastructure from dev to prod safely?**

Outline:
1. One module, separate state and variable files per environment.
2. Pipeline runs plan, a policy check (OPA, Conftest, or Checkov) fails unsafe defaults, a human reviews the diff, then apply.
3. Prod gets extra gates: approvals, locked state, no manual portal changes.
4. Drift is detected by re-running plan, not by guessing.

**Q: How do you operate an Azure Function in production?**

Outline:
1. Describe it in Bicep. Pipeline runs what-if, a human approves, then deploy.
2. Attach a managed identity. Grant it the narrow Azure RBAC it needs. No secrets in app settings if Key Vault can hold them.
3. Send traces to Application Insights. Alert from Azure Monitor on failures and latency users feel.
4. Honest: Logic Apps is the same IaC and identity story. Say if you have not built a Logic App. Do not invent connectors.

**Q: Why put an Azure DevOps agent on-prem, and what does Terraform Cloud add over a storage backend?**

Outline:
1. The on-prem agent reaches a private network the hosted pool cannot see. Treat it as a security boundary (Day-19).
2. Production still uses an Environment approval (Day-06).
3. A plain backend stores state and the lock. Terraform Cloud also runs the plan, can trigger another workspace, and can fail a policy.
4. Honest: say if you have only used a storage backend. Transfer Day-10. Do not invent run-trigger syntax.

**Q: How do you move the same stack from one cloud to another?**

Outline:
1. Terraform stays the common layer. Keep the module shape: network, identity, cluster, data.
2. Change the provider and the names. Do not rewrite the app to change the cloud.
3. Move in waves with a rollback boundary (Day-37). Map names with Day-17.

## Honest gap note

JDs sometimes name OpenTofu or Ansible. If you use Terraform daily, say so, and say you are happy to work in OpenTofu-compatible workflows (the language is the same). Do not claim daily Ansible depth you do not have; explain configuration as code concepts instead.

Logic Apps has no Day lesson. Transfer Functions, Bicep, managed identity, and Azure Monitor. Name the gap if the interviewer asks for Logic Apps depth.

## Source tags

EPAM Azure Lead (TR, KZ) · EPAM Senior Azure DevOps · EPAM Senior Azure DevOps (KZ, migration) · EPAM Senior Azure Engineer (KZ) · EPAM Lead Azure Cloud · EPAM Senior Azure Cloud (KZ) · EPAM Lead DevOps (KZ) · 2026-10-27 market (policy-as-code on IaC) · 2026-10-28 market (Functions / Logic Apps with Bicep, App Insights, managed identity) · 2026-11-02 market (on-prem ADO agents, Terraform Cloud vs remote backend) · 2026-11-04 market (on-prem and cloud-to-cloud migration, Terraform as the common layer)
