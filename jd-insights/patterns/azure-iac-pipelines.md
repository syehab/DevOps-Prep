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
8. [Day-36/01-concepts.md](../../Day-36/01-concepts.md) - policy evaluation before plan (Checkov is in the Day-25 and Day-36 labs)

Interview-ready deep dives: [Day-08 v2](../../Day-08-IaC-Terraform-Bicep-Interview-Ready-Clean-v2.md), [Day-09 v2](../../Day-09-IaC-Modules-Environments-Interview-Ready-Clean-v2.md), [Day-10 v2](../../Day-10-Terraform-State-Enterprise-Interview-Ready-Clean-v2.md).

## Common interview question

**Q: How do you promote the same infrastructure from dev to prod safely?**

Outline:
1. One module, separate state and variable files per environment.
2. Pipeline runs plan, a policy check (OPA, Conftest, or Checkov) fails unsafe defaults, a human reviews the diff, then apply.
3. Prod gets extra gates: approvals, locked state, no manual portal changes.
4. Drift is detected by re-running plan, not by guessing.

## Honest gap note

JDs sometimes name OpenTofu or Ansible. If you use Terraform daily, say so, and say you are happy to work in OpenTofu-compatible workflows (the language is the same). Do not claim daily Ansible depth you do not have; explain configuration as code concepts instead.

## Source tags

EPAM Azure Lead (TR, KZ) · EPAM Senior Azure DevOps · EPAM Senior Azure DevOps (KZ, migration) · EPAM Senior Azure Engineer (KZ) · EPAM Lead Azure Cloud · EPAM Senior Azure Cloud (KZ) · EPAM Lead DevOps (KZ) · 2026-10-27 market (policy-as-code on IaC)
