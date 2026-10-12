# Day 38 — Questions and answers

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Then answer each item below before you open the Answer block. After that, do the lab in [03-implementation.md](03-implementation.md).

Write your own answer first. Open the Answer block only after you try. Keep the original numbering.

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

---

## 1. Why are Dev, UAT, and Prod separate?

1. Why are Dev, UAT, and Prod separate?

<details>
<summary>Answer</summary>

Dev is fast feedback. UAT is controlled validation. Production serves real users and needs stronger availability, security, and change control.

Same architecture pattern, different capacity and governance. One shared cluster hides blast radius.

</details>

---

## 2. Why are they separate accounts?

2. Why are they separate accounts?

<details>
<summary>Answer</summary>

An account isolates security, permissions, billing, quotas, and blast radius. A Dev mistake must not modify Production.

Developers can be broad in Dev and restricted in Prod. Tags are not that boundary.

</details>

---

## 3. Why are clusters separated?

3. Why are clusters separated?

<details>
<summary>Answer</summary>

A namespace is logical. A cluster shares nodes, API, and admin blast radius. An account is wider still.

Prod in its own namespace is not Prod isolation. Dedicated EKS per account is the ShopSphere default, at higher cost.

</details>

---

## 4. Where does Terraform state live?

4. Where does Terraform state live?

<details>
<summary>Answer</summary>

Separate remote keys: `shopsphere/dev/platform.tfstate`, `uat`, `prod`. Split further by domain if ownership needs it.

A Prod apply must not touch Dev state.

</details>

---

## 5. Who can assume the Production Terraform role?

5. Who can assume the Production Terraform role?

<details>
<summary>Answer</summary>

The infrastructure pipeline identity, through STS, into a narrowly scoped Prod Terraform role.

Not every developer. Not the application runtime. Not a standing laptop admin.

</details>

---

## 6. Who can deploy to Production?

6. Who can deploy to Production?

<details>
<summary>Answer</summary>

The Prod deployment role after UAT evidence and approval. Record who, which digest, which process, and which evidence.

Production is not another automatic stage.

</details>

---

## 7. How does the same image move across environments?

7. How does the same image move across environments?

<details>
<summary>Answer</summary>

Git SHA → build → scan → one image → registry → Dev → UAT → approval → Prod. Pin the digest.

Do not rebuild for Production. Shared or per-account ECR is a security vs operations choice; trust must be explicit.

</details>

---

## 8. How are secrets isolated?

8. How are secrets isolated?

<details>
<summary>Answer</summary>

Same variable names (`DATABASE_URL`), different stores per account. Dev workload reads Dev secrets only.

A compromised Dev identity must not read Prod secrets. Do not copy Prod values into Dev.

</details>

---

## 9. How do networks communicate with shared services?

9. How do networks communicate with shared services?

<details>
<summary>Answer</summary>

Keep Dev, UAT, and Prod VPCs isolated. If logging or DNS is central, use an explicit path such as Transit Gateway to a shared-services VPC.

Do not peer “just in case.” Every link widens trust.

</details>

---

## 10. What happens if the Dev account is compromised?

10. What happens if the Dev account is compromised?

<details>
<summary>Answer</summary>

Blast radius should stay in Dev: its VPC, EKS, secrets, and roles. SCPs, separate IAM, and no Prod secrets in Dev stop the jump.

If Dev can assume Prod or read Prod state, the account boundary failed.

</details>

---

## 11. What happens if the central CI/CD identity is compromised?

11. What happens if the central CI/CD identity is compromised?

<details>
<summary>Answer</summary>

That identity can assume env deploy and Terraform roles. Scope each role tightly, require Prod approval, and audit STS.

One permanent superuser across accounts is the failure mode to avoid.

</details>

---

## 12. What happens if the shared observability platform fails?

12. What happens if the shared observability platform fails?

<details>
<summary>Answer</summary>

Workloads may still serve traffic while you lose metrics, logs, and traces across accounts. Detection and RCA suffer.

Centralize for consistency; keep enough local telemetry that a central outage does not blind Production.

</details>

---

## 13. How do you detect a deployment to the wrong account?

13. How do you detect a deployment to the wrong account?

<details>
<summary>Answer</summary>

Run `aws sts get-caller-identity` before apply. Confirm account ID, principal, and environment against the intended backend and cluster.

Never assume the current identity is the one you meant. Make this a pipeline step.

</details>

---

## 14. How do you prevent cross-environment access?

14. How do you prevent cross-environment access?

<details>
<summary>Answer</summary>

Separate accounts, roles, secrets, state, and VPCs. Add SCP/policy and CI checks. Distinct DNS names (`api.dev` vs `api.shopsphere.example`).

Fix the path that allowed leakage, not only one variable.

</details>

---

## 15. Where is the largest remaining blast radius?

15. Where is the largest remaining blast radius?

<details>
<summary>Answer</summary>

Often the CI/CD identity, a shared registry trust, a shared logging account, or an SCP gap. Shared modules without versions are another.

Name it, then add a control. Isolation is never complete.

</details>

Your answer should describe boundaries and trade-offs rather than simply drawing more boxes.

---

## 16. SCP vs IAM

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

<details>
<summary>Answer</summary>

IAM grants what an identity may do. An SCP sets the maximum allowed in the account. If the SCP denies a region, IAM cannot grant it back.

Use SCPs as org guardrails above team IAM.

</details>

---

## 17. Why shouldn't Dev, UAT, and Prod be namespaces in one cluster?

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

Finally answer:

**Why shouldn't Dev, UAT, and Production simply be namespaces in one Kubernetes cluster?**

Do not answer with “because Production is important.”

Explain the actual security, operational, and blast-radius differences.

<details>
<summary>Answer</summary>

They share the API server, nodes, cluster IAM, and admin roles. A cluster outage or a privileged RBAC mistake hits all three.

Namespaces help org and policy. They do not give account-level security, billing, or blast-radius isolation.

</details>

---

## 18. Failure drill: wrong account — decide

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

Make identity verification part of the pipeline.

<details>
<summary>Answer</summary>

Credentials point at UAT while you meant Dev. Stop. Run `aws sts get-caller-identity`. Check the Terraform provider and backend key.

Do not apply. Identity check is part of the pipeline, not a memory trick.

</details>

---

## 19. Failure drill: cross-account AccessDenied — decide

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

<details>
<summary>Answer</summary>

Walk source identity → `sts:AssumeRole` → trust policy → IAM → resource policy → resource. Name the layer that denied.

Do not add Administrator. Same identity model as Day 18, now across accounts.

</details>

---

## 20. Failure drill: environment leakage — decide

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

<details>
<summary>Answer</summary>

Dev referenced a UAT or Prod secret. Ask how the reference existed, which identity allowed it, which config, which boundary failed.

Then separate accounts, roles, secrets, state, policy, CI validation, and names. Repair the architecture path.

</details>

---

## 21. Failure drill: Terraform state boundary — decide

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

<details>
<summary>Answer</summary>

Dev Terraform should not read Prod state unless a rare, documented reason exists. If needed, record why, owner, change impact, permissions, and blast radius.

Cross-env state dependencies must be deliberate.

</details>

---

## 22. Environment promotion exercise (expected outcome)

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

<details>
<summary>Answer</summary>

Promote one digest Dev → UAT → Prod. Record Git SHA, digest, each deploy, approval, and verification.

Production image must match the UAT artifact. That chain is the proof.

</details>

---

## 23. Terraform multi-account lab (expected outcome)

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

<details>
<summary>Answer</summary>

Common modules (`vpc`, `eks`, `database`, `observability`). Env folders with their own account, state, tfvars, and execution role.

`dev.tfvars` / `uat.tfvars` / `prod.tfvars` change size and HA, not architecture copies.

</details>

---

## 24. Kubernetes multi-environment lab (expected outcome)

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

<details>
<summary>Answer</summary>

Dev/UAT/Prod each have EKS plus their own namespace, Ingress, Service, secrets, workload identity, HPA, NetworkPolicy, and observability.

Manifests stay consistent. Values differ. Same app, independent platforms.

</details>

---

## 25. Ownership model

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

The important point: ownership must be explicit.

If nobody owns a platform component, operational problems eventually become everyone's problem.

<details>
<summary>Answer</summary>

Platform: accounts, EKS, network, Terraform modules. App team: ShopSphere, workload config, app alerts. Security: guardrails and access. FinOps: budgets and cost.

If nobody owns a component, incidents become everyone’s problem.

</details>

---

## 26. Blast radius review: one cluster vs separate accounts

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

<details>
<summary>Answer</summary>

One account/one cluster is cheaper and simpler. Separate accounts, clusters, state, and roles cost more and isolate better.

Choose from the failure you must survive, isolation you need, complexity you can run, and business rules. There is no universal winner.

</details>

---

## 27. Provider aliases

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

<details>
<summary>Answer</summary>

Aliases let one config talk to more than one account, for example `provider "aws" { alias = "shared" }` with `assume_role`.

Do not use them because you can. Ask why resources must be managed together, who owns them, and the blast radius.

</details>

---

## 28. Shared registry vs per-account ECR

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

<details>
<summary>Answer</summary>

Central ECR simplifies promotion. Per-account registries strengthen isolation. Decide from security, promotion, network, ownership, complexity, and compliance.

If images cross accounts, scope the trust. Keep immutable digests.

</details>

---

## 29. Cost ownership

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

<details>
<summary>Answer</summary>

Account plus tags: Application, Environment, Owner, CostCenter, ManagedBy, Criticality. Accounts make attribution easier.

Tags are metadata. Accounts, IAM, networks, and policies are the real controls.

</details>

---

## 30. 5-minute recall: delivery path

Without looking at the lesson, explain this complete path:

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

<details>
<summary>Answer</summary>

Developer → Git → CI/CD → artifact → Dev account → UAT account → Production approval → Prod account → EKS → ShopSphere.

Boundaries exist so each hop has a named identity, state, cluster, and secret store. Verify them before you change anything.

</details>

---

## 31. Azure ↔ AWS mapping (org)

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

<details>
<summary>Answer</summary>

Tenant↔Organization, Management Groups↔OUs, Subscriptions↔Accounts, Entra↔IAM Identity Center, Azure Policy↔SCP/Config, AKS↔EKS, ACR↔ECR, Key Vault↔Secrets Manager.

The questions stay: owner, access, boundary, traffic, deploy, govern, observe, blast radius.

</details>

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

