# Day 36 — Production Project 06 Terraform Enterprise Hardening

This Day uses three files. Read them in this order.

1. [01-concepts.md](01-concepts.md) — lesson content (this file)
2. [02-questions-and-answers.md](02-questions-and-answers.md) — practice items, each with a model answer
3. [03-implementation.md](03-implementation.md) — hands-on lab

Day 35 gave ShopSphere operational visibility. Day 36 moves deeper into platform engineering: **how do you let many engineers change infrastructure without losing control of state, security, consistency, or auditability?** Terraform is easy to run for one engineer from a laptop. The challenge is to design a workflow that remains safe when multiple teams, environments, accounts, modules, and pipelines are involved. Today you will harden the Terraform architecture you started earlier and deliberately exercise state, drift, permissions, modules, versioning, and controlled changes.

---

## Part 1 — Terraform as a Team System

Terraform is not just an Infrastructure-as-Code command-line tool. In a team environment, it becomes a system for managing desired infrastructure state across people, repositories, cloud accounts, pipelines, modules, and environments. The important pieces are the configuration, provider versions, state, remote backend, locking, identity, plan/apply workflow, module structure, and governance. A technically valid Terraform configuration can still be an unsafe enterprise implementation if anyone can modify Production state or apply arbitrary changes.

The enterprise flow is:

```text
Terraform Code
      ↓
Validation
      ↓
Security / Policy
      ↓
Plan
      ↓
Review
      ↓
Approval
      ↓
Apply
      ↓
Verify
      ↓
Observe / Detect Drift
```

The core principle is:

**Infrastructure changes should be repeatable, reviewable, traceable, and recoverable.**

---

## Part 2 — State Is Part of the Control System

Terraform state records the relationship between your configuration and the infrastructure Terraform manages. It allows Terraform to understand which real resources correspond to which configuration objects and what values Terraform already knows about them. State can contain sensitive information, so protect it like important infrastructure. Do not treat it as an ordinary generated file.

For a team, local state is usually unsuitable because every engineer could have a different copy.

The desired model is:

```text
Engineer / Pipeline
        ↓
Terraform
        ↓
Remote State
        ↓
Cloud Infrastructure
```

For ShopSphere, separate state objects should exist for meaningful boundaries such as environments or platform components.

For example:

```text
shopsphere/dev/network.tfstate
shopsphere/uat/network.tfstate
shopsphere/prod/network.tfstate
```

Do not put every infrastructure component for every environment into one enormous state file simply because it is convenient.

---

## Part 3 — State Isolation and Blast Radius

State boundaries should reflect ownership, lifecycle, and blast radius.

Imagine one state file manages:

```text
VPC
Database
ECS
IAM
Monitoring
DNS
```

A mistake affecting that state can potentially impact many unrelated components.

Instead, you may separate infrastructure into logical states:

```text
network
security
data
application-platform
observability
```

The correct decomposition depends on the organization.

The goal is not to create hundreds of tiny state files.

The goal is to make changes independent where independence improves:

```text
Security
Ownership
Deployment
Recovery
Blast Radius
```

A useful question is:

**If this Terraform operation goes wrong, how much infrastructure can it affect?**

---

## Part 4 — Remote State

For AWS, the ShopSphere Terraform backend can use S3 for remote state.

A current configuration can look like:

```hcl
terraform {
  backend "s3" {
    bucket       = "shopsphere-terraform-state"
    key          = "prod/network.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
  }
}
```

The state bucket should have appropriate security controls, restricted access, versioning, and recovery considerations.

Terraform's current S3 backend documentation recommends S3 bucket versioning for recovery and supports S3-based state locking through `use_lockfile`. DynamoDB-based locking is deprecated in current Terraform documentation.

Do not put the state bucket into the same Terraform state that depends on it without considering the bootstrap problem.

The state backend itself needs a deliberate ownership and bootstrap strategy.

---

## Part 5 — State Locking

Imagine two engineers run:

```text
terraform plan
```

and then both attempt:

```text
terraform apply
```

against the same state.

Without proper coordination, concurrent changes can create race conditions.

State locking helps make sure that only one Terraform operation modifies a given state at a time.

Conceptually:

```text
Engineer A
   ↓
Acquire Lock
   ↓
Apply
   ↓
Release Lock

Engineer B
   ↓
Wait / Fail
```

Locking does not make Terraform changes safe by itself.

It prevents concurrent state operations.

You still need:

```text
Code Review
Plan Review
Permissions
Approvals
Testing
```

Locking solves one class of problem, not the entire governance problem.

---

## Part 6 — Protect the State Backend

Treat the state bucket as a security-sensitive system.

Think about:

```text
Encryption
Versioning
Access Control
Audit Logging
Least Privilege
Recovery
Deletion Protection
```

The pipeline that modifies Production infrastructure should have only the permissions required to read/write the relevant state and manage the resources it owns.

A developer who only needs to run plans should not automatically receive unrestricted state modification permissions.

Also consider whether state contains sensitive resource attributes.

Never assume:

```text
sensitive = true
```

means the value is absent from Terraform state.

It generally means Terraform will avoid displaying the value in certain command output; the underlying state can still contain sensitive data.

---

## Part 7 — Terraform Version Pinning

Terraform configurations should not depend on whatever Terraform version happens to sit on an engineer's laptop.

Pin the Terraform version where appropriate.

For example:

```hcl
terraform {
  required_version = "~> 1.14"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
```

The exact versions should match the versions you have tested.

Also commit:

```text
.terraform.lock.hcl
```

The lock file helps keep provider selections reproducible.

The principle is:

**The same Terraform and provider versions should produce predictable behavior across engineers and CI/CD.**

---

## Part 8 — Provider Governance

Provider versions can introduce behavior changes, new features, deprecations, or breaking changes.

Do not upgrade a provider directly in Production because a newer version exists.

Use a controlled process:

```text
Upgrade
 ↓
Review changelog
 ↓
Test
 ↓
Plan
 ↓
Non-Prod
 ↓
Production
```

A provider upgrade is itself an infrastructure change.

Treat it like application dependency management.

This is one reason infrastructure repositories need the same engineering discipline as application repositories.

---

## Part 9 — Module Governance

Modules reduce duplication, but uncontrolled modules can create a new problem.

Imagine 50 teams each create their own:

```text
VPC module
ECS module
IAM module
Database module
```

Soon you have many slightly different implementations.

A platform team can provide approved reusable modules.

For example:

```text
Platform Modules
 ├── network
 ├── container-service
 ├── database
 ├── iam-role
 └── observability
```

Application teams consume them:

```text
Application Team
       ↓
Approved Module
       ↓
Environment Inputs
       ↓
Infrastructure
```

The module should expose the important decisions without forcing teams to understand every low-level implementation detail.

---

## Part 10 — Module Versioning

Do not silently change a shared module used by Production.

Suppose:

```text
network module v1.4
```

is used by ten teams.

You introduce a breaking change.

If all teams automatically consume the latest version, you have created a large blast radius.

Instead:

```text
v1.4
 ↓
v1.5
 ↓
Test
 ↓
Teams upgrade intentionally
```

Module versions create controlled evolution.

A useful principle is:

**Shared infrastructure code should have an upgrade path, not surprise consumers.**

---

## Part 11 — Repository Architecture

A mature Terraform repository may look like:

```text
terraform-platform/
│
├── modules/
│   ├── network/
│   ├── security/
│   ├── ecs-service/
│   ├── database/
│   └── observability/
│
├── environments/
│   ├── dev/
│   ├── uat/
│   └── prod/
│
├── policies/
│
├── tests/
│
└── pipelines/
```

Another organization might separate repositories by platform domain.

There is no universal folder structure.

The important decisions are:

```text
Ownership
Lifecycle
State Boundary
Deployment Boundary
Module Reuse
Environment Isolation
```

Do not copy a repository structure without understanding these relationships.

---

## Part 12 — Terraform Pipeline

The infrastructure pipeline should validate before applying.

A strong baseline is:

```text
Pull Request
 ↓
terraform fmt
 ↓
terraform validate
 ↓
Security / Policy
 ↓
terraform plan
 ↓
Review
```

Then:

```text
Merge
 ↓
Plan
 ↓
Approval
 ↓
Apply
 ↓
Verification
```

The Production pipeline should use the reviewed plan, or otherwise make sure that the change it applies matches the reviewed source and plan.

Do not casually run:

```bash
terraform apply -auto-approve
```

from an engineer's laptop against Production.

Automation is useful when it increases consistency and control.

---

## Part 13 — Plan Is Evidence, Not Approval

A Terraform plan tells you what Terraform intends to change.

It does not tell you whether the change is appropriate.

For example:

```text
- aws_security_group_rule.db_ingress
```

might be technically valid but architecturally dangerous.

The reviewer must ask:

```text
Why is this changing?
Who requested it?
What traffic does it permit?
What is the blast radius?
Is it required?
Is it reversible?
```

This is why plan review is an engineering activity rather than a checkbox.

---

## Part 14 — Policy as Code

At organizational scale, humans cannot manually review every low-level configuration detail.

Policy can enforce guardrails.

Examples:

```text
No public database
Required encryption
Approved regions
Mandatory tags
Restricted IAM patterns
Approved instance types
Required logging
```

The implementation could use policy frameworks appropriate to the organization's Terraform and cloud platform.

The important architecture is:

```text
Terraform Code
 ↓
Policy Evaluation
 ↓
Pass / Fail
 ↓
Plan / Apply
```

Policy should prevent known classes of unsafe configuration without blocking legitimate engineering unnecessarily.

---

## Part 15 — Drift

Terraform drift occurs when the real infrastructure changes outside the Terraform workflow and no longer matches the configuration/state expectations.

For example:

```text
Terraform:
DB security rule = App only

Manual change:
0.0.0.0/0 added
```

A later plan may reveal the difference.

Do not automatically apply the plan.

Use:

```text
Detect
 ↓
Investigate
 ↓
Identify Owner
 ↓
Determine Intent
 ↓
Reconcile or Codify
 ↓
Prevent Recurrence
```

If the manual change was unauthorized, restore the intended state.

If the change was legitimate, update Terraform so the configuration reflects the new desired state.

---

## Part 16 — Preventing Drift

Drift prevention is more valuable than repeatedly repairing drift.

Controls can include:

```text
Limited console access
Terraform-only production changes
IAM least privilege
Policy
CloudTrail / audit logs
Change review
Automated drift detection
Resource ownership
```

The objective is not to prevent every manual action in every environment.

The objective is to make Production infrastructure changes intentional and traceable.

---

## Part 17 — Import and Existing Infrastructure

Sometimes Terraform needs to manage an existing resource.

For example:

```text
Existing VPC
      ↓
Terraform
```

Importing a resource is not the same as magically generating a perfect configuration.

You need to:

```text
Import
 ↓
Inspect
 ↓
Write Configuration
 ↓
Plan
 ↓
Reconcile
```

The goal is for Terraform configuration and real infrastructure to converge.

Do not import a resource and assume the work is finished.

---

## Part 18 — Terraform Destroy as a Governance Problem

`terraform destroy` is powerful.

In a lab:

```text
terraform destroy
```

may be exactly what you want.

In Production, unrestricted destroy permissions can create catastrophic blast radius.

Consider controls such as:

```text
Separate Production account
Restricted IAM
Protected state
Approval
Policy
Pipeline-only changes
Resource protections where appropriate
```

The question is not:

**“Can Terraform destroy it?”**

The question is:

**“Who should be able to destroy it, under what conditions, and with what evidence?”**

---

## Part 19 — Cross-Account Terraform

ShopSphere uses separate AWS accounts.

A central Terraform pipeline can assume a role in the target account.

Conceptually:

```text
Central CI/CD
      ↓
STS AssumeRole
      ↓
Dev Terraform Role
      ↓
Dev Infrastructure
```

and:

```text
Central CI/CD
      ↓
STS AssumeRole
      ↓
Prod Terraform Role
      ↓
Prod Infrastructure
```

The Production role should have only the permissions required by the Terraform configuration it manages.

Avoid giving the central pipeline unrestricted access to every AWS account.

This is the same identity principle you used in Day 33 for application deployment.

---

## Part 20 — Separate Terraform Identity from Application Identity

ShopSphere now has several identities:

```text
Terraform Identity
     ↓
Infrastructure

Deployment Identity
     ↓
Application Deployment

Runtime Identity
     ↓
Application Dependencies
```

Do not collapse these into one role.

If the application runtime identity is compromised, the attacker should not automatically be able to modify the VPC.

If the Terraform identity is compromised, the blast radius is potentially much larger, so its credentials and execution path need stronger controls.

This is why infrastructure pipelines are highly privileged systems.

---

## Part 21 — Terraform State Recovery

Imagine the state file is accidentally deleted or corrupted.

If the S3 backend has versioning enabled, you may be able to recover a previous object version.

The recovery process should be deliberate:

```text
Detect
 ↓
Stop Terraform Operations
 ↓
Identify Correct State Version
 ↓
Recover
 ↓
Validate
 ↓
Plan
 ↓
Resume
```

Do not simply create a new empty state file.

That can cause Terraform to treat existing infrastructure as unmanaged.

State recovery is therefore an operational runbook, not merely an S3 feature.

---

## Part 26 — Terraform Security Review

Review the entire Terraform system.

Ask:

```text
Who can modify Terraform code?

Who can approve Production?

Who can apply Production?

Who can access state?

Who can modify the state bucket?

Who can assume the Production Terraform role?

Can Terraform create public databases?

Can Terraform create unrestricted security rules?

Are provider versions controlled?

Are modules versioned?

Are plans reviewed?

Is drift detected?
```

Every answer should map to a technical or organizational control.

---

## Part 27 — Cost Governance Through Terraform

Terraform can encode cost-related standards.

Examples:

```text
Approved instance families
Required tags
Environment-specific sizing
Mandatory ownership metadata
Restricted expensive resources
```

You can also detect suspicious changes during plan review.

For example:

```text
Dev:
2 small tasks

Proposed:
20 large tasks
```

The plan itself becomes a cost signal.

Cost governance should not prevent legitimate scaling.

It should make expensive changes visible and controlled.

---

## Part 31 — Day 36 Completion Criteria

Complete Day 36 when you can demonstrate:

```text
[ ] Remote state configured
[ ] State locking configured
[ ] State versioning/recovery understood
[ ] State access restricted
[ ] State boundaries documented
[ ] Terraform version controlled
[ ] Provider versions controlled
[ ] Lock file committed
[ ] Modules structured
[ ] Module versioning understood
[ ] Terraform pipeline created
[ ] Plan review implemented
[ ] Production apply controlled
[ ] Policy concept understood
[ ] Drift drill completed
[ ] Concurrent apply drill completed
[ ] Module upgrade drill completed
[ ] Permission failure drill completed
[ ] Import workflow understood
[ ] Cross-account Terraform understood
[ ] Terraform identity separated from runtime identity
[ ] State recovery procedure documented
[ ] Cost governance considered
[ ] Enterprise Terraform architecture documented
```

The most important completion criterion is:

**You can explain how many teams can safely use Terraform across multiple environments and accounts without losing control of state, permissions, changes, modules, or Production blast radius.**

---

## Part 32 — What Comes Next

Day 36 hardened the infrastructure delivery system.

Day 37 will introduce a major architecture change:

**Move ShopSphere from managed containers to Kubernetes.**

The goal is not to learn Kubernetes commands again. You already learned the Kubernetes mental model earlier.

Now you will experience the operational difference between:

```text
Managed Container Runtime
        ↓
Kubernetes
```

You will work through:

```text
Cluster
Node Pools
Namespaces
Deployments
Services
Ingress
Config
Secrets
Workload Identity
Requests / Limits
Autoscaling
Rolling Updates
Health Checks
Kubernetes Networking
Observability
Failure Recovery
```

The important question will be:

**What operational responsibility did we gain by choosing Kubernetes?**

---

## Cleanup

Keep the core ShopSphere infrastructure and Terraform backend because Day 37 will reuse them.

Remove only temporary resources created for the failure drills.

Restore the Terraform configuration and infrastructure to the known-good state.

Record:

```text
Terraform Version:
AWS Provider Version:
State Backend:
State Key:
Module Versions:
Production Apply Method:
Terraform Execution Role:
Known-Good Commit:
```

Do not leave a deliberately modified IAM permission, route, security rule, or module version active.

