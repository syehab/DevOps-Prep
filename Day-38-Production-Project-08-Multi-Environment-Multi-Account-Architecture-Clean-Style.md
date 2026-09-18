# Day 38 — Production Project 08: Multi-Environment & Multi-Account Architecture

Day 37 moved ShopSphere onto managed Kubernetes. The next challenge is bigger than Kubernetes itself: **how do you structure the organization when Dev, UAT, and Production must be isolated, governed, deployed, and operated without creating unnecessary duplication?**

A single environment can hide architectural problems. Once multiple environments and AWS accounts exist, questions about blast radius, ownership, Terraform state, identities, networking, Kubernetes clusters, CI/CD, secrets, logging, and cost become tightly connected.

The goal today is to design ShopSphere as a platform that can grow from one application into an enterprise environment.

The central question is:

**Where should the boundaries exist, and why?**

---

## Part 1 — Why Multiple Environments Need Boundaries

Dev, UAT, and Production serve different purposes.

Dev is optimized for rapid engineering feedback.

UAT is used for controlled validation and business acceptance.

Production serves real users and therefore requires stronger availability, security, change control, and operational discipline.

You could technically place all three environments in one AWS account and one Kubernetes cluster. But that creates shared failure and security boundaries.

For ShopSphere, begin with:

```text
AWS Organization
      ↓
Dev Account
UAT Account
Prod Account
```

Then each account can contain its own infrastructure and workload boundaries.

The principle is:

**Use an account boundary when you need meaningful isolation of security, billing, access, governance, or blast radius.**

---

## Part 2 — Account as an Isolation Boundary

An AWS account is more than a billing container.

It provides an important administrative and security boundary.

For ShopSphere:

```text
Dev Account
 └── Dev Infrastructure

UAT Account
 └── UAT Infrastructure

Prod Account
 └── Production Infrastructure
```

A mistake in Dev should not automatically have permission to modify Production.

A developer may receive broad permissions in Dev while Production access remains restricted.

This gives you:

```text
Security Isolation
Permission Isolation
Blast-Radius Isolation
Cost Visibility
Governance Isolation
```

This is one reason mature organizations commonly use multiple AWS accounts.

---

## Part 3 — Organization and Organizational Units

The account structure can sit underneath AWS Organizations.

For example:

```text
AWS Organization
│
├── Security OU
│   ├── Log Archive
│   └── Security Tooling
│
├── Infrastructure OU
│   └── Shared Platform
│
└── Workloads OU
    ├── Dev
    ├── UAT
    └── Prod
```

The exact structure depends on organizational requirements.

Do not create OUs simply because the hierarchy looks clean.

An OU should help apply governance, security controls, or administrative policies to a meaningful group of accounts.

---

## Part 4 — SCP vs IAM

A common interview mistake is treating AWS Organizations SCPs as normal permission policies.

They are different.

IAM policies grant permissions to identities.

Service Control Policies establish the maximum permissions available within affected accounts.

Conceptually:

```text
SCP
 ↓
Maximum allowed boundary

IAM
 ↓
Permissions actually granted
```

If the SCP blocks an action, an IAM policy cannot simply grant it back.

For example, an organization might restrict Production to approved AWS Regions.

That creates a governance guardrail above individual IAM permissions.

---

## Part 5 — Environment Isolation

There are several possible designs:

```text
Option A:
One Account
One Cluster
Dev + UAT + Prod

Option B:
One Account
Separate Clusters

Option C:
Separate Accounts
Separate Clusters
```

The choice should be based on:

```text
Security
Blast Radius
Cost
Operational Complexity
Compliance
Team Ownership
Availability Requirements
```

For a production-oriented ShopSphere design, use:

```text
Dev Account
 └── Dev EKS

UAT Account
 └── UAT EKS

Prod Account
 └── Prod EKS
```

This creates strong isolation at both the account and cluster levels.

It also increases infrastructure and operational cost.

That trade-off is deliberate.

---

## Part 6 — Cluster Boundaries

A Kubernetes namespace can separate applications logically.

A cluster provides a stronger infrastructure and operational boundary.

An AWS account is an even broader boundary.

Therefore:

```text
Namespace
   ↓
Cluster
   ↓
AWS Account
```

These boundaries solve different problems.

Do not assume that:

**“Prod is in its own namespace, therefore Prod is isolated.”**

It is isolated logically in some respects, but it still shares cluster-level infrastructure and administrative blast radius.

For a critical Production workload, a dedicated cluster can provide a stronger boundary.

---

## Part 7 — Environment Design

Design ShopSphere like this:

```text
Dev
 ├── AWS Account
 ├── VPC
 ├── EKS
 ├── ECR access
 ├── Database
 └── Observability

UAT
 ├── AWS Account
 ├── VPC
 ├── EKS
 ├── ECR access
 ├── Database
 └── Observability

Prod
 ├── AWS Account
 ├── VPC
 ├── EKS
 ├── ECR
 ├── Database
 └── Observability
```

The architecture is intentionally similar.

The values differ.

For example:

```text
Dev:
smaller nodes
lower database capacity
less redundancy

Prod:
multiple AZs
larger capacity
stronger availability
stricter access
```

The architecture should be standardized while capacity and governance adapt to the environment.

---

## Part 8 — One Architecture, Different Values

Do not create three completely different Terraform implementations.

Instead:

```text
Common Module
      ↓
Environment Inputs
      ↓
Dev / UAT / Prod
```

For example:

```hcl
module "eks" {
  source = "../../modules/eks"

  cluster_name = var.cluster_name
  node_size    = var.node_size
  min_nodes    = var.min_nodes
  max_nodes    = var.max_nodes
}
```

Then:

```text
dev.tfvars
uat.tfvars
prod.tfvars
```

provide environment-specific values.

This gives you:

**Standardization without forcing identical capacity.**

---

## Part 9 — Terraform State Boundaries

Each environment should have its own Terraform state.

Do not allow Dev and Production to share a state file.

A possible structure is:

```text
shopsphere/dev/platform.tfstate
shopsphere/uat/platform.tfstate
shopsphere/prod/platform.tfstate
```

You can also split state further by platform domain.

For example:

```text
prod/network.tfstate
prod/eks.tfstate
prod/data.tfstate
```

The right boundary depends on ownership and blast radius.

The important rule is:

**A Production operation should not require manipulating unrelated Dev infrastructure state.**

---

## Part 10 — Account-Aware Terraform

Terraform now needs to know which AWS account it is targeting.

The provider configuration can use role assumption.

Conceptually:

```text
CI/CD
 ↓
AWS STS
 ↓
Dev Terraform Role
 ↓
Dev Account
```

and separately:

```text
CI/CD
 ↓
AWS STS
 ↓
Prod Terraform Role
 ↓
Prod Account
```

The pipeline identity should not automatically become an administrator of every account.

Each target account should have a narrowly scoped Terraform execution role.

---

## Part 11 — Provider Aliases

Sometimes Terraform needs to interact with more than one AWS account in the same configuration.

Provider aliases allow you to distinguish providers.

For example:

```hcl
provider "aws" {
  region = var.region
}

provider "aws" {
  alias  = "shared"
  region = var.region

  assume_role {
    role_arn = var.shared_account_role_arn
  }
}
```

A module can then receive the appropriate provider.

This is useful for controlled cross-account resources.

However, do not use cross-account Terraform simply because it is technically possible.

Ask:

```text
Why must these resources be managed together?
Who owns them?
What is the blast radius?
```

---

## Part 12 — Shared Services

Some enterprise services are intentionally centralized.

Examples include:

```text
Central Logging
Security Tooling
DNS
Artifact Management
Network Connectivity
Identity
Monitoring
```

But centralization creates dependencies.

For example:

```text
Prod
 ↓
Central Logging Account
```

If the central service becomes unavailable, visibility may be affected across many workloads.

Therefore:

**Centralize where consistency and governance benefit; decentralize where availability and isolation matter more.**

---

## Part 13 — ECR and Image Promotion

ShopSphere should continue to build the application once.

The image should then be promoted across environments.

Conceptually:

```text
Git SHA
 ↓
Build
 ↓
Security Scan
 ↓
Container Image
 ↓
Registry
 ↓
Dev
 ↓
UAT
 ↓
Prod
```

Do not rebuild the application separately for Production.

Otherwise you lose the guarantee that the artifact tested in UAT is the artifact running in Production.

Use immutable image references where possible, ideally content-addressed digests.

---

## Part 14 — Shared Registry vs Per-Account Registry

There are multiple valid approaches.

For example:

```text
Central ECR
 ├── ShopSphere image
 └── shared platform images
```

or:

```text
Dev ECR
UAT ECR
Prod ECR
```

A central registry simplifies artifact management.

Separate registries can strengthen account isolation.

The decision depends on:

```text
Security
Promotion Model
Network Access
Ownership
Operational Complexity
Compliance
```

If using cross-account image access, make the trust relationship explicit and narrowly scoped.

---

## Part 15 — CI/CD Promotion Across Accounts

The application pipeline now crosses account boundaries.

A simplified flow is:

```text
Source
 ↓
Build
 ↓
Test
 ↓
Security
 ↓
Image
 ↓
Dev Account
 ↓
UAT Account
 ↓
Production Approval
 ↓
Prod Account
```

The deployment identity changes at each boundary.

For example:

```text
Pipeline
 ↓
Assume Dev Deployment Role

Pipeline
 ↓
Assume UAT Deployment Role

Pipeline
 ↓
Assume Prod Deployment Role
```

This is safer than one permanent superuser credential.

---

## Part 16 — Production Approval Boundary

Production should not be just another automatic stage.

The pipeline should create a clear control point:

```text
UAT Validation
      ↓
Evidence
      ↓
Production Approval
      ↓
Production Deployment
      ↓
Verification
```

Approval can include:

```text
Change reference
Artifact version
Test results
Security results
Deployment plan
Rollback plan
Owner
```

The objective is traceability.

A Production deployment should answer:

**Who changed what, using which artifact, through which process, and what evidence supported the change?**

---

## Part 17 — Configuration and Secrets Across Accounts

Do not copy Production secrets into Dev simply because the application expects the same variable names.

Keep secrets isolated:

```text
Dev Secrets
UAT Secrets
Prod Secrets
```

The application can use the same logical configuration interface:

```text
DATABASE_URL
PAYMENT_API_KEY
JWT_SECRET
```

but each environment receives different values.

The identity accessing the secret should also be environment-specific.

For example:

```text
Dev workload
 ↓
Dev secret

Prod workload
 ↓
Prod secret
```

A compromised Dev workload should not automatically be able to read Production secrets.

---

## Part 18 — Networking Between Environments

Avoid unnecessary network connectivity between Dev and Production.

A clean model is:

```text
Dev VPC       UAT VPC       Prod VPC
   |             |             |
 isolated      isolated      isolated
```

If shared services are required, establish explicit connectivity.

For example:

```text
Prod VPC
   ↓
Transit Gateway
   ↓
Shared Services VPC
```

Do not connect networks merely because “they may need to communicate someday.”

Every network connection expands the trust and failure boundary.

---

## Part 19 — Cross-Account Access

Suppose a Production support engineer needs read-only access.

They should not receive:

```text
AdministratorAccess
```

just because they occasionally troubleshoot.

Instead:

```text
Engineer
 ↓
Identity Provider
 ↓
Prod ReadOnly Role
 ↓
Production Account
```

For temporary elevated access:

```text
Engineer
 ↓
Approved elevation
 ↓
Privileged role
 ↓
Time-bounded access
```

The exact implementation depends on the organization's identity system.

The principle is:

**Access should be scoped to the environment and task.**

---

## Part 20 — DNS and Environment Separation

Environment names should make accidental access difficult.

For example:

```text
api.dev.shopsphere.example
api.uat.shopsphere.example
api.shopsphere.example
```

Production should not be confused with Dev simply because the application names are identical.

DNS, certificates, load balancers, and secrets should all respect the environment boundary.

This is a small design decision with large operational value.

---

## Part 21 — Observability Across Accounts

Multi-account architecture creates a visibility problem.

An engineer should be able to understand Production without manually opening ten unrelated consoles.

A central observability architecture may aggregate:

```text
Metrics
Logs
Traces
Audit Events
Security Findings
```

But retain clear ownership and access boundaries.

For example:

```text
Prod Workload
 ↓
Prod Telemetry
 ↓
Central Observability
```

while sensitive Production data remains accessible only to authorized roles.

Central visibility should not mean unrestricted access.

---

## Part 22 — Cost Ownership

Separate accounts make cost attribution easier.

You can associate:

```text
AWS Account
 ↓
Environment
 ↓
Application
 ↓
Team
 ↓
Cost
```

Use tags and account structure together.

Useful metadata includes:

```text
Application
Environment
Owner
CostCenter
ManagedBy
Criticality
```

Do not rely on tags alone for security boundaries.

Tags are useful metadata; accounts, IAM, networks, and policies provide stronger control boundaries.

---

## Part 23 — Failure Drill: Wrong Account

Create a harmless Terraform configuration mistake where the intended environment is Dev but the credentials point to UAT.

Before applying, verify:

```bash
aws sts get-caller-identity
```

Confirm:

```text
Account ID
Principal
Environment
```

Then verify Terraform's provider configuration.

The lesson is simple:

**Never assume the current cloud identity is the account you intended to modify.**

Identity verification should be part of the pipeline.

---

## Part 24 — Failure Drill: Cross-Account Access Denied

Attempt a legitimate cross-account operation without the required trust relationship.

You may see:

```text
AccessDenied
```

Reason through:

```text
Source Identity
 ↓
STS AssumeRole
 ↓
Trust Policy
 ↓
IAM Permissions
 ↓
Target Resource Policy
 ↓
Resource
```

Do not immediately add broad permissions.

Determine which layer rejected the request.

This is the same troubleshooting model from Day 18, now applied across account boundaries.

---

## Part 25 — Failure Drill: Environment Leakage

Create a non-production scenario where Dev accidentally references a UAT or Production secret/resource.

Identify:

```text
How was the reference possible?
Which identity allowed it?
Which configuration caused it?
Which boundary failed?
```

Then prevent recurrence using appropriate controls:

```text
Separate accounts
Separate roles
Separate secrets
Separate state
Policy
CI/CD validation
Naming conventions
```

The objective is not simply fixing one variable.

It is fixing the architectural path that allowed the leakage.

---

## Part 26 — Failure Drill: Terraform State Boundary

Attempt to make a Dev Terraform change that references Production infrastructure state.

Ask whether that dependency is actually necessary.

If not, remove it.

If it is necessary, document:

```text
Why?
Who owns the dependency?
What happens if Production changes?
What happens if Dev changes?
What permissions are required?
What is the blast radius?
```

Cross-environment Terraform dependencies should be rare and deliberate.

---

## Part 27 — Environment Promotion Exercise

Take the current ShopSphere image.

Promote the exact same image through:

```text
Dev
 ↓
UAT
 ↓
Prod
```

Record:

```text
Git SHA
Image Digest
Dev Deployment
UAT Deployment
Production Approval
Prod Deployment
Verification
```

Then verify that the running Production image corresponds to the artifact tested earlier.

This creates end-to-end traceability:

```text
Git SHA
 ↓
Image Digest
 ↓
Environment Deployments
 ↓
Production
```

---

## Part 28 — Terraform Multi-Account Lab

Refactor the Terraform project so that:

```text
Dev
UAT
Prod
```

each have:

```text
Separate account
Separate state
Separate variables
Separate Terraform execution role
```

Reuse common modules.

For example:

```text
modules/
 ├── vpc/
 ├── eks/
 ├── database/
 └── observability/

environments/
 ├── dev/
 ├── uat/
 └── prod/
```

The module code should remain common.

The environment configuration should express differences.

---

## Part 29 — Kubernetes Multi-Environment Lab

Deploy the ShopSphere application into each environment.

Use:

```text
Dev EKS
UAT EKS
Prod EKS
```

Each environment should have its own:

```text
Namespace
Ingress
Service
Secrets
Workload Identity
HPA
NetworkPolicy
Observability
```

The manifests should remain largely consistent while environment-specific values differ.

You are now operating the same application architecture across multiple independent platforms.

---

## Part 30 — Ownership Model

Document ownership explicitly.

For example:

```text
Platform Team
→ AWS accounts
→ EKS platform
→ networking
→ Terraform modules

Application Team
→ ShopSphere application
→ Kubernetes workload configuration
→ application alerts

Security Team
→ guardrails
→ security monitoring
→ access governance

FinOps / Platform
→ cost visibility
→ budgets
→ optimization
```

These responsibilities may belong to different teams in a real organization.

The important point is that ownership must be explicit.

If nobody owns a platform component, operational problems eventually become everyone's problem.

---

## Part 31 — Blast Radius Review

Now compare these designs:

```text
One Account
One Cluster
All Environments
```

versus:

```text
Separate Accounts
Separate Clusters
Separate State
Separate Roles
```

The second design creates more infrastructure and operational overhead.

But it also creates stronger boundaries.

Do not conclude that one architecture is universally correct.

Instead ask:

```text
What failure are we protecting against?
What isolation do we require?
What complexity can we operate?
What does the business require?
```

This is the architecture mindset expected from a Lead DevOps engineer.

---

## Part 32 — Senior/Lead Architecture Challenge

Design the complete ShopSphere enterprise structure.

Your whiteboard should contain:

```text
AWS Organization
   ↓
OUs
   ↓
Accounts
   ↓
VPCs
   ↓
EKS
   ↓
Namespaces
   ↓
Applications
```

Around it, add:

```text
IAM
SCP
Terraform
CI/CD
ECR
Secrets
Observability
DNS
Networking
Security
Cost
Governance
```

Then explain:

1. Why are Dev, UAT, and Prod separate?
2. Why are they separate accounts?
3. Why are clusters separated?
4. Where does Terraform state live?
5. Who can assume the Production Terraform role?
6. Who can deploy to Production?
7. How does the same image move across environments?
8. How are secrets isolated?
9. How do networks communicate with shared services?
10. What happens if the Dev account is compromised?
11. What happens if the central CI/CD identity is compromised?
12. What happens if the shared observability platform fails?
13. How do you detect a deployment to the wrong account?
14. How do you prevent cross-environment access?
15. Where is the largest remaining blast radius?

Your answer should describe boundaries and trade-offs rather than simply drawing more boxes.

---

## Part 33 — Azure ↔ AWS Mapping

The underlying architecture is transferable.

```text
Azure                                  AWS
----------------------------------------------------------------
Tenant                                 AWS Organization
Management Groups                      OUs
Subscriptions                          Accounts
Resource Groups                        Logical resource grouping
Entra ID                               IAM / Identity Center
Azure Policy                           SCP / AWS Config / policy tooling
VNet                                   VPC
AKS                                    EKS
ACR                                    ECR
Key Vault                              Secrets Manager
Azure Monitor                          CloudWatch / observability stack
ExpressRoute                           Direct Connect
VNet Peering                           VPC Peering
Virtual WAN                            Transit Gateway / broader network architecture
```

The exact services differ, but the architectural questions remain:

```text
Who owns it?
Who can access it?
Where is the boundary?
How does traffic flow?
How is it deployed?
How is it governed?
How is it observed?
What is the blast radius?
```

---

## Part 34 — 5-Minute Recall

Without looking at the lesson, explain:

```text
AWS Organization
OU
AWS Account
SCP
IAM
Environment boundary
Cluster boundary
Namespace boundary
Terraform state boundary
Cross-account role assumption
Provider alias
Shared services
ECR promotion
Environment-specific secrets
Cross-account networking
Central observability
Cost allocation
Blast radius
```

Then explain this complete path:

```text
Developer
 ↓
Git
 ↓
CI/CD
 ↓
Artifact
 ↓
Dev Account
 ↓
UAT Account
 ↓
Production Approval
 ↓
Prod Account
 ↓
EKS
 ↓
ShopSphere
```

Finally answer:

**Why shouldn't Dev, UAT, and Production simply be namespaces in one Kubernetes cluster?**

Do not answer with “because Production is important.”

Explain the actual security, operational, and blast-radius differences.

---

## Part 35 — Day 38 Completion Criteria

Complete Day 38 when you can demonstrate:

```text
[ ] AWS Organization structure designed
[ ] OU purpose understood
[ ] Account as isolation boundary understood
[ ] SCP vs IAM understood
[ ] Dev/UAT/Prod account model designed
[ ] Cluster boundaries documented
[ ] Namespace boundaries understood
[ ] Common Terraform modules implemented
[ ] Environment-specific values separated
[ ] Separate state per environment
[ ] Cross-account Terraform understood
[ ] Terraform execution roles separated
[ ] Provider aliases understood
[ ] Shared services architecture considered
[ ] ECR promotion model implemented
[ ] Same image promoted across environments
[ ] Environment-specific secrets implemented
[ ] Cross-environment network access restricted
[ ] Cross-account IAM troubleshooting completed
[ ] Wrong-account drill completed
[ ] Environment leakage drill completed
[ ] State-boundary drill completed
[ ] Central observability model documented
[ ] Cost ownership model documented
[ ] Team ownership model documented
[ ] Multi-account Terraform lab completed
[ ] Multi-cluster Kubernetes deployment completed
[ ] Production approval boundary documented
[ ] Blast-radius analysis completed
[ ] Enterprise architecture diagram completed
```

The most important completion criterion is:

**You can design environment, account, cluster, network, identity, state, CI/CD, and ownership boundaries and explain why each boundary exists.**

---

## Part 36 — What Comes Next

ShopSphere now has:

```text
Production Infrastructure
        ↓
Secure Networking
        ↓
Controlled CI/CD
        ↓
Safe Deployments
        ↓
Observability
        ↓
Hardened Terraform
        ↓
Kubernetes
        ↓
Multi-Environment / Multi-Account Architecture
```

Day 39 moves into two areas that become critical at this scale:

**Disaster Recovery + Cost Engineering**

You will deliberately break the architecture conceptually and ask:

```text
What happens if an AZ fails?
What happens if a region fails?
What happens if the database is lost?
What happens if Terraform state is unavailable?
What happens if an entire AWS account is compromised?
What availability target are we actually designing for?
What recovery time can the business tolerate?
What does that resilience cost?
```

The objective will be to connect **reliability engineering with financial engineering** rather than treating DR and cloud cost as separate topics.

---

## Cleanup

Keep the Dev, UAT, and Production architecture because Day 39 builds on it.

Remove only temporary failure-drill resources.

Verify:

```text
Correct AWS account
Correct Terraform backend
Correct Terraform role
Correct EKS cluster
Correct Kubernetes namespace
Correct image
Correct secrets
Correct network rules
Correct IAM trust
No temporary cross-environment access
No temporary elevated permissions
```

For every environment, record:

```text
AWS Account:
Region:
VPC:
EKS Cluster:
Terraform State:
Terraform Role:
Deployment Role:
ECR Source:
Secret Store:
Observability Destination:
Owner:
Cost Center:
Known-Good Commit:
```

The most important operational habit from today is simple:

**Before changing infrastructure, know exactly which account, environment, identity, state, and cluster you are changing.**
