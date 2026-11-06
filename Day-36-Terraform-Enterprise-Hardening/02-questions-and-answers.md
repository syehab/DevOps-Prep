# Day 36 — Questions and answers

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Then answer each item below before you open the Answer block. After that, do the lab in [03-implementation.md](03-implementation.md).

Write your own answer first. Open the Answer block only after you try. Keep the original numbering.

---

## 1. Why does Terraform need state?

**Interview Recall**

Answer these without looking at the lesson.

1. Why does Terraform need state?

<details>
<summary>Answer</summary>

State maps configuration objects to real cloud resources and remembered values. Without it, Terraform cannot plan a change against what already exists.

Treat state as a control system, not a scratch file.

</details>

---

## 2. Why is local state problematic for teams?

**Interview Recall**

Answer these without looking at the lesson.

2. Why is local state problematic for teams?

<details>
<summary>Answer</summary>

Each laptop can hold a different copy. Two applies then fight. Secrets also sit on disks.

Use remote state so the team shares one source of truth.

</details>

---

## 3. What is state locking?

**Interview Recall**

Answer these without looking at the lesson.

3. What is state locking?

<details>
<summary>Answer</summary>

Locking lets only one Terraform operation modify a given state at a time. Engineer A holds the lock during apply. Engineer B waits or fails.

Current S3 backend locking uses `use_lockfile`. DynamoDB locking is deprecated in current docs.

</details>

---

## 4. What does locking solve?

**Interview Recall**

Answer these without looking at the lesson.

4. What does locking solve?

<details>
<summary>Answer</summary>

It prevents concurrent state writes and the race that corrupts state.

It does not prove the change is safe.

</details>

---

## 5. What does locking not solve?

**Interview Recall**

Answer these without looking at the lesson.

5. What does locking not solve?

<details>
<summary>Answer</summary>

Locking does not review architecture, IAM blast radius, or a dangerous SG rule.

You still need code review, plan review, permissions, approvals, and tests.

</details>

---

## 6. Why should state be protected?

**Interview Recall**

Answer these without looking at the lesson.

6. Why should state be protected?

<details>
<summary>Answer</summary>

State can hold secrets and maps every managed resource. Encrypt it, restrict IAM, audit access, and consider deletion protection.

`sensitive = true` hides values in some output. It does not remove them from state.

</details>

---

## 7. Why enable S3 versioning for Terraform state?

**Interview Recall**

Answer these without looking at the lesson.

7. Why enable S3 versioning for Terraform state?

<details>
<summary>Answer</summary>

Versioning lets you recover a previous state object after delete or corruption.

Without it, empty new state can make Terraform treat live infrastructure as unmanaged.

</details>

---

## 8. Why pin Terraform and provider versions?

**Interview Recall**

Answer these without looking at the lesson.

8. Why pin Terraform and provider versions?

<details>
<summary>Answer</summary>

Laptop “latest” is not a tested platform. Pin `required_version` and provider versions you have run.

The same versions should behave the same in CI and on engineer machines.

</details>

---

## 9. What is `.terraform.lock.hcl`?

**Interview Recall**

Answer these without looking at the lesson.

9. What is `.terraform.lock.hcl`?

<details>
<summary>Answer</summary>

The lock file records selected provider versions so installs stay reproducible.

Commit it. Treat provider upgrades like application dependency upgrades.

</details>

---

## 10. Why version shared modules?

**Interview Recall**

Answer these without looking at the lesson.

10. Why version shared modules?

<details>
<summary>Answer</summary>

A silent latest bump on a network module used by ten teams is a large blast radius.

Publish v1.5, test, then let teams upgrade on purpose.

</details>

---

## 11. How should Terraform state boundaries be chosen?

**Interview Recall**

Answer these without looking at the lesson.

11. How should Terraform state boundaries be chosen?

<details>
<summary>Answer</summary>

Split by ownership, lifecycle, and blast radius: network, data, app platform, observability. Do not put VPC plus IAM plus DNS in one giant file.

Do not create hundreds of tiny states either. Ask: if this apply fails, what can it hit?

</details>

---

## 12. What is drift?

**Interview Recall**

Answer these without looking at the lesson.

12. What is drift?

<details>
<summary>Answer</summary>

Real infrastructure no longer matches configuration and state. Example: Terraform says DB SG is app-only; someone added `0.0.0.0/0`.

`terraform plan` can show the gap. Do not auto-apply.

</details>

---

## 13. How should drift be investigated?

**Interview Recall**

Answer these without looking at the lesson.

13. How should drift be investigated?

<details>
<summary>Answer</summary>

Detect → investigate → owner → intent → restore or codify → prevent. Unauthorized: restore intended state. Legitimate: update Terraform.

Prevention beats repeated repair: least privilege, pipeline-only Prod, audit logs.

</details>

---

## 14. What is Terraform import?

**Interview Recall**

Answer these without looking at the lesson.

14. What is Terraform import?

<details>
<summary>Answer</summary>

Import attaches an existing resource to state. It does not write a perfect config for you.

Import → inspect → write config → `terraform plan` → reconcile until they match.

</details>

---

## 15. Why is `terraform destroy` a governance concern?

**Interview Recall**

Answer these without looking at the lesson.

15. Why is `terraform destroy` a governance concern?

<details>
<summary>Answer</summary>

In a lab, destroy is useful. In Production it can wipe the platform.

Ask who may destroy, under what approval, and with what evidence. Restrict IAM, protect state, pipeline-only apply.

</details>

---

## 16. How does cross-account Terraform work?

**Interview Recall**

Answer these without looking at the lesson.

16. How does cross-account Terraform work?

<details>
<summary>Answer</summary>

Central CI assumes a Dev or Prod Terraform role with `sts:AssumeRole`. Each role has only the permissions that configuration needs.

The pipeline must not be administrator in every account.

</details>

---

## 17. Why separate Terraform, deployment, and runtime identities?

**Interview Recall**

Answer these without looking at the lesson.

17. Why separate Terraform, deployment, and runtime identities?

<details>
<summary>Answer</summary>

Terraform changes infrastructure. Deploy updates the service. Runtime uses secrets and data.

A stolen task role must not modify the VPC. A stolen Terraform role is highly privileged, so its path needs stronger control.

</details>

---

## 18. What should happen before a Production `apply`?

**Interview Recall**

Answer these without looking at the lesson.

18. What should happen before a Production `apply`?

<details>
<summary>Answer</summary>

PR: `terraform fmt`, `terraform validate`, policy, saved plan, review, approval. Apply the reviewed plan from the pipeline.

Do not run `terraform apply -auto-approve` from a laptop against Production.

</details>

---

## 19. How can policy-as-code help?

**Interview Recall**

Answer these without looking at the lesson.

19. How can policy-as-code help?

<details>
<summary>Answer</summary>

Humans cannot inspect every rule. Policy can block public databases, require encryption and tags, limit regions and IAM patterns.

Fail closed on known-unsafe classes. Do not block legitimate work without a reason.

</details>

---

## 20. How would you recover from corrupted Terraform state?

**Interview Recall**

Answer these without looking at the lesson.

20. How would you recover from corrupted Terraform state?

<details>
<summary>Answer</summary>

Stop Terraform operations. Restore the correct S3 object version. Validate, `terraform plan`, then resume.

Do not create empty state over live resources. Write this as a runbook.

</details>

---

## 21. How would you troubleshoot Terraform `AccessDenied`?

**Interview Recall**

Answer these without looking at the lesson.

21. How would you troubleshoot Terraform `AccessDenied`?

<details>
<summary>Answer</summary>

Name identity, API action, and resource. Restore only that permission on the execution role.

Do not attach AdministratorAccess to “make the pipeline green.”

</details>

---

## 22. How would you prevent developers from changing Production infrastructure directly?

**Interview Recall**

Answer these without looking at the lesson.

22. How would you prevent developers from changing Production infrastructure directly?

<details>
<summary>Answer</summary>

No console or laptop apply on Prod. IAM least privilege. Pipeline identity applies. Audit with CloudTrail.

Dev can plan. Prod apply is approved automation.

</details>

---

## 23. How can Terraform help with cost governance?

**Interview Recall**

Answer these without looking at the lesson.

23. How can Terraform help with cost governance?

<details>
<summary>Answer</summary>

Encode approved instance families, tags, env sizing, and ownership. A plan that jumps Dev from 2 small tasks to 20 large ones is a cost signal.

Make expensive changes visible. Do not block real scale.

</details>

---

## 24. What is the blast radius of a shared Terraform state?

**Interview Recall**

Answer these without looking at the lesson.

24. What is the blast radius of a shared Terraform state?

<details>
<summary>Answer</summary>

One state that owns VPC, database, ECS, IAM, monitoring, and DNS can break all of them in one bad apply.

Smaller state files limit that radius. Shared modules without versions spread a different radius across teams.

</details>

---

## 25. What makes a Terraform platform enterprise-ready?

**Interview Recall**

Answer these without looking at the lesson.

25. What makes a Terraform platform enterprise-ready?

<details>
<summary>Answer</summary>

Remote state, locking, versioning, pinned versions, versioned modules, pipeline plan/apply, policy, identity split, drift detection, and a recovery runbook.

Many engineers can change infra without losing control of state, security, or audit.

</details>

---

## 26. Failure drill: concurrent apply

**Failure Drill: Concurrent Terraform Apply**

Run two Terraform operations against the same state.

Observe the locking behavior.

Document:

```text
Operation A:
Acquired lock

Operation B:
Blocked / failed due to lock

Operation A:
Completed

Operation B:
Can retry
```

Then explain:

**What problem does locking solve?**

and:

**What problems does locking not solve?**

<details>
<summary>Answer</summary>

A acquires the lock and applies. B is blocked or fails. After A releases, B retries.

Locking stops concurrent modification. It does not judge whether the plan is wise.

</details>

---

## 27. Failure drill: drift

**Failure Drill: Drift**

Manually change one harmless infrastructure property outside Terraform.

Then run:

```bash
terraform plan
```

Observe the detected difference.

Do not apply immediately.

Record:

```text
Expected Configuration
Actual Infrastructure
Detected Drift
Change Owner
Intent
Resolution
```

Then reconcile.

Finally, identify a control that would reduce the chance of the same manual change happening again.

<details>
<summary>Answer</summary>

Change one harmless property outside Terraform. Run `terraform plan`. Record expected vs actual, owner, intent, and resolution.

Then restore or codify, and name a control that would have blocked the console change.

</details>

---

## 28. Failure drill: module upgrade

**Failure Drill: Module Upgrade**

Create a small module change.

For example:

```text
Module v1.0
 ↓
Module v1.1
```

Run the plan in Dev.

Inspect the impact.

Then promote to UAT.

Only after validation should you consider Production.

Record:

```text
Module Version
Changed Resources
Plan
Test Result
Risk
Production Decision
```

This simulates the lifecycle of shared platform components.

<details>
<summary>Answer</summary>

Bump module v1.0 → v1.1. Plan in Dev, inspect resources, test, promote UAT, then decide on Prod.

Record version, changed resources, plan, risk, and the Prod decision. Shared modules need an upgrade path.

</details>

---

## 29. Failure drill: permission boundary

**Failure Drill: Permission Boundary**

Remove one Terraform permission from the execution role.

Run the pipeline.

Observe:

```text
Terraform
 ↓
AWS API
 ↓
AccessDenied
```

Identify:

```text
Identity
 ↓
API Action
 ↓
Resource
 ↓
Missing Permission
```

Restore only the required permission.

Do not solve the failure by attaching AdministratorAccess.

This is an important Senior/Lead habit:

**Fix authorization failures by understanding the required action, not by broadening permissions blindly.**

<details>
<summary>Answer</summary>

Remove one Terraform permission. Pipeline hits `AccessDenied`. Identify identity → action → resource → missing allow.

Restore only that action. Broadening to Administrator is the wrong habit.

</details>

---

## 30. Remote state layout (expected outcome)

Specify the ShopSphere remote state layout. Separate state objects should exist for meaningful boundaries such as environments or platform components.

For example:

```text
shopsphere/dev/network.tfstate
shopsphere/uat/network.tfstate
shopsphere/prod/network.tfstate
```

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

Do not put every infrastructure component for every environment into one enormous state file simply because it is convenient.

<details>
<summary>Answer</summary>

S3 backend with versioning, tight IAM, encryption, and `use_lockfile`. Separate keys such as `shopsphere/prod/network.tfstate`.

Do not manage the state bucket in the same state that depends on it without a bootstrap plan.

</details>

---

## 31. Hands-on enterprise hardening (expected outcome)

Now refactor the ShopSphere Terraform implementation.

Your target structure should include:

```text
Reusable Modules
Environment Inputs
Remote State
Provider Version Pinning
Lock File
CI/CD Pipeline
Plan Review
IAM Separation
Security Checks
Policy
Documentation
```

Move Production Terraform execution into the controlled pipeline.

Remove unnecessary direct Production access from developer identities.

Document:

```text
Who can plan?
Who can approve?
Who can apply?
Who can access state?
Who owns modules?
Who handles drift?
Who handles state recovery?
```

You are now designing a Terraform operating model rather than just Terraform code.

<details>
<summary>Answer</summary>

Reusable modules, env inputs, remote state, pinned Terraform/providers, committed lock file, CI plan review, IAM split, policy, and docs.

Document who can plan, approve, apply, read state, own modules, handle drift, and recover state. Prod apply lives in the pipeline.

</details>

---

## 32. Architecture review: highest-risk identities and boundaries

Review the complete infrastructure lifecycle:

```text
Engineer
 ↓
Git
 ↓
Pull Request
 ↓
Validation
 ↓
Policy
 ↓
Plan
 ↓
Review
 ↓
Approval
 ↓
Apply
 ↓
Cloud
 ↓
Observe
 ↓
Drift Detection
 ↓
Reconcile
```

Now identify the highest-risk identities and boundaries.

Ask:

```text
What is the most privileged identity?

What is the most sensitive resource?

What is the largest state boundary?

What is the largest blast radius?

What is the easiest way an engineer could accidentally damage Production?

What control prevents it?
```

This is the kind of thinking expected from a Lead DevOps engineer.

<details>
<summary>Answer</summary>

Most privileged: Production Terraform role. Most sensitive: state bucket and database. Largest blast radius: a combined Prod state or an unversioned shared module.

Easiest accident: laptop `terraform apply` or a console SG change. Control: pipeline-only Prod plus least privilege.

</details>

---

## 33. Plan is evidence, not approval

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

<details>
<summary>Answer</summary>

The plan lists intended actions. A deleted `aws_security_group_rule.db_ingress` can be valid Terraform and a bad architecture.

Reviewer asks why, who, what traffic, blast radius, need, and reversibility.

</details>
