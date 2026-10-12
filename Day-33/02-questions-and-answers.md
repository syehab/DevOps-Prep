# Day 33 — Questions and answers

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Then answer each item below before you open the Answer block. After that, do the lab in [03-implementation.md](03-implementation.md).

Write your own answer first. Open the Answer block only after you try. Keep the original numbering.

---

## Part 30 — Senior/Lead Interview Recall

Answer these without looking at the lesson.

## 1. Why should the application be built once and promoted?

Why should the application be built once and promoted?

<details>
<summary>Answer</summary>

One Git commit produces one image. Dev, UAT, and Production deploy that same digest. A rebuild can differ even from the same SHA.

You must prove Production runs the bytes that passed UAT. Promotion is the test. Rebuild is the bug.

</details>

---

## 2. Why is an image digest useful?

Why is an image digest useful?

<details>
<summary>Answer</summary>

A tag such as `a81f29c` is convenient. The digest `sha256:...` names the exact image bytes.

Mutable tags can move. Record the digest after the ECR push and deploy that digest.

</details>

---

## 3. Difference between CI and CD

What is the difference between CI and CD?

<details>
<summary>Answer</summary>

CI asks whether this source revision is safe enough to become a release candidate. It compiles, tests, and scans without needing Production.

CD takes that artifact, deploys it, and verifies health. CI must not depend on Production being up.

</details>

---

## 4. What does ECR provide?

What does ECR provide?

<details>
<summary>Answer</summary>

ECR is the artifact boundary between CI and ECS. The build identity pushes. The runtime pulls.

It stores the image that later environments consume. It is not the pipeline and not the deploy identity.

</details>

---

## 5. Why separate build and deployment identities?

Why should build and deployment identities be separated?

<details>
<summary>Answer</summary>

The build role builds, tests, and pushes to ECR. The deploy role updates ECS. Compromise of one must not grant the other.

Do not use one DevOps Administrator for both.

</details>

---

## 6. Why should runtime identity differ from deployment identity?

Why should runtime identity be different from deployment identity?

<details>
<summary>Answer</summary>

Runtime reads named secrets, writes logs, and talks to the database. It must not update ECS, push to ECR, create IAM, or run Terraform.

A stolen task role then cannot rewrite the service or the VPC.

</details>

---

## 7. How should a pipeline authenticate to AWS?

How should a pipeline authenticate to AWS?

<details>
<summary>Answer</summary>

Use federated, short-lived credentials: CI platform → federated auth → AWS role → temporary credentials → AWS API.

Do not store an IAM access key in pipeline variables.

</details>

---

## 8. Why are long-lived access keys undesirable for CI/CD?

Why are long-lived access keys undesirable for CI/CD?

<details>
<summary>Answer</summary>

Keys in variables, logs, and YAML leak and stay valid. Rotation is slow. Blast radius lasts until you disable the key.

Federation vends short-lived tokens scoped to the role.

</details>

---

## 9. How would you design Dev/UAT/Prod promotion?

How would you design Dev/UAT/Prod promotion?

<details>
<summary>Answer</summary>

CI builds once and pushes the digest. Dev deploys it and checks `/health`. UAT takes the same digest. Production needs checks, approval with evidence, deploy, health, then observe.

Do not rebuild between environments.

</details>

---

## 10. What should happen before Production traffic reaches a new version?

What should happen before Production traffic reaches a new version?

<details>
<summary>Answer</summary>

The new version must pass health validation. Process start is not enough.

Traffic moves only after `/health` succeeds and the load balancer marks the target healthy.

</details>

---

## 11. What makes a health check useful?

What makes a health check useful?

<details>
<summary>Answer</summary>

It answers whether the app can serve requests, not whether Java is running. Use `/health` at the application layer.

Do not fail every instance because one optional dependency is down. Design the meaning of healthy on purpose.

</details>

---

## 12. How would you troubleshoot an ECR `AccessDenied`?

How would you troubleshoot an ECR `AccessDenied`?

<details>
<summary>Answer</summary>

Name the identity, the ECR repository, and the API action. Build, test, and compile can still pass.

Restore the minimum push permission. Do not attach Administrator.

</details>

---

## 13. How would you troubleshoot an ECS image-pull failure?

How would you troubleshoot an ECS image-pull failure?

<details>
<summary>Answer</summary>

Walk pipeline → task definition → ECR → pull → startup. Causes include a wrong tag, missing pull permission, bad task definition, or no network to ECR.

Do not say “ECS is broken.” Name the layer.

</details>

---

## 14. Deployment succeeded but users receive 503

How would you investigate a deployment that succeeded but users receive 503?

<details>
<summary>Answer</summary>

The pipeline updated the service. Targets are unhealthy or missing. Check `/health`, target group status, logs, and the digest.

Deployment success must include application verification. A running task is not a healthy app.

</details>

---

## 15. How would you roll back?

How would you roll back?

<details>
<summary>Answer</summary>

Identify current version, previous known-good digest, and deployment revision. Restore that digest.

Verify task healthy → load balancer healthy → HTTP 200 → logs normal. “Rollback command succeeded” is not recovery.

</details>

---

## 16. How does cross-account deployment work?

How does cross-account deployment work?

<details>
<summary>Answer</summary>

Central CI assumes a Dev, UAT, or Prod deploy role. Each account trusts the pipeline identity. Prod is stricter.

The pipeline must not hold permanent administrator in every account.

</details>

---

## 17. Why separate application and infrastructure pipelines?

Why separate application and infrastructure pipelines?

<details>
<summary>Answer</summary>

A Java change must not apply a VPC. A Terraform change must not rebuild the JAR.

App path: Git → build → ECR → deploy. Infra path: `terraform fmt` → `terraform validate` → plan → review → apply.

</details>

---

## 18. How could a pipeline leak a secret?

How could a pipeline leak a secret?

<details>
<summary>Answer</summary>

Git is not the only leak. YAML, variables, build logs, Dockerfiles, image layers, and manifests can copy a secret. `echo $DATABASE_PASSWORD` writes it to logs.

A secret is unsafe anywhere it is copied, logged, or baked into a layer.

</details>

---

## 19. How would you limit blast radius of a compromised pipeline?

How would you limit the blast radius of a compromised pipeline?

<details>
<summary>Answer</summary>

Split build, deploy, and runtime roles. Scope each to one account and the resources it needs. No IAM create, no Terraform state, no other environments.

Minimum permissions, not zero permissions.

</details>

---

## 20. How do you prove which source revision is running in Production?

How do you prove which source revision is running in Production?

<details>
<summary>Answer</summary>

Read the running digest. Map it to Git SHA, build ID, tag, and release record. A branch name such as `main` is not enough.

Keep a release record: commit, digest, Dev/UAT/Prod results.

</details>

---

## Part 17 — Failure Drill: Build Failure

## 21. Failure drill: build failure

Break the build intentionally.

Examples:

```text
Invalid Maven dependency
Failing unit test
Compilation error
```

Then diagnose:

```text
Source
 ↓
Build environment
 ↓
Dependency
 ↓
Compilation
 ↓
Test
```

Do not change the infrastructure.

This is an application build problem.

Record:

```text
Failure
Evidence
Root Cause
Fix
Preventive Control
```

<details>
<summary>Answer</summary>

Break Maven, a unit test, or compile. Walk source → build env → dependency → compile → test. Do not change the VPC.

Record failure, evidence, root cause, fix, and a preventive control such as required tests in CI.

</details>

---

## Part 18 — Failure Drill: ECR Push Failure

## 22. Failure drill: ECR push failure

Remove the required ECR permission from the build identity.

Run the pipeline.

Expected reasoning:

```text
Source → Build → Test
                ↓
              Pass
                ↓
             ECR Push
                ↓
            AccessDenied
```

This tells you the application itself may be completely healthy.

The problem is authorization.

Investigate:

```text
Which identity?
Which ECR repository?
Which API action?
Which policy?
```

Restore the minimum required permission and rerun.

<details>
<summary>Answer</summary>

Remove the build role’s ECR push permission. Source, build, and test pass. Push returns `AccessDenied`.

Restore only that action on that repository. Authorization is not an app bug.

</details>

---

## Part 19 — Failure Drill: ECS Deployment Failure

## 23. Failure drill: ECS deployment failure

Change the deployment configuration so that the task refers to an invalid image.

Observe the deployment.

Trace:

```text
Pipeline
 ↓
Deployment
 ↓
Task Definition
 ↓
ECR
 ↓
Image Pull
 ↓
Container Startup
```

Possible causes include:

```text
Wrong image
Wrong tag
Missing permissions
ECR connectivity
Invalid task definition
Secret access
Resource constraints
```

Do not label the problem “ECS is broken.”

Identify the actual failure layer.

<details>
<summary>Answer</summary>

Point the task at an invalid image. Trace pipeline → task definition → ECR → pull → startup.

Possible layers: wrong image, tag, permissions, ECR connectivity, secrets, or CPU/memory. Name the actual layer.

</details>

---

## Part 20 — Failure Drill: Health Check Failure

## 24. Failure drill: health check failure

Deploy an application version that starts successfully but returns a failure from `/health`.

Observe:

```text
Task:
RUNNING

Application:
UNHEALTHY

Load Balancer:
UNHEALTHY
```

This is a critical production lesson.

A running container is not necessarily a healthy application.

The deployment system should prevent unhealthy capacity from receiving normal production traffic.

Then recover to the previous known-good artifact.

<details>
<summary>Answer</summary>

Deploy a version that runs but fails `/health`. Task shows RUNNING. App and load balancer show UNHEALTHY.

The system must keep that capacity off user traffic. Recover to the previous digest.

</details>

---

## Part 21 — Failure Drill: Rollback

## 25. Failure drill: rollback

Now practice a rollback.

Identify:

```text
Current Version
Previous Known-Good Version
Image Digest
Deployment Revision
```

Then restore the known-good version.

Verify:

```text
Task Healthy
 ↓
Load Balancer Healthy
 ↓
HTTP 200
 ↓
Application Logs Normal
```

Do not stop at “rollback command succeeded.”

Recovery is complete only when the service is verified healthy.

<details>
<summary>Answer</summary>

Record current and previous digest. Restore known-good. Verify health, load balancer, HTTP 200, and logs.

Recovery is users served again, not the rollback API succeeding.

</details>

---

## Part 22 — Failure Drill: Pipeline Identity Compromise

## 26. Failure drill: pipeline identity compromise

Imagine the deployment role is compromised.

Ask:

```text
What can it access?
Can it modify ECS?
Can it access Secrets Manager?
Can it modify IAM?
Can it access Terraform state?
Can it deploy to Production?
Can it access other accounts?
```

Now redesign its permissions.

This is a Lead-level exercise because pipeline security is part of the organization's software supply chain.

The goal is not zero permissions.

The goal is **minimum required permissions and controlled blast radius**.

<details>
<summary>Answer</summary>

Ask what the deploy role can change: ECS, secrets, IAM, Terraform state, Production, other accounts. Then cut it to deploy-only in one environment.

Pipeline security is supply-chain security.

</details>

---

## Part 27 — Lead-Level Pipeline Review

## 27. Lead-level pipeline review

Review the pipeline with these questions:

```text
Can a developer deploy directly to Production?

Can the pipeline deploy without a controlled identity?

Can the build modify Production infrastructure?

Can an image be silently overwritten?

Can an untested artifact reach Production?

Can a secret appear in logs?

Can we identify the exact running commit?

Can we roll back?

Can we determine who deployed?

Can we determine what changed?

Can a compromised build identity affect unrelated environments?
```

Any “yes” should trigger further design discussion.

Do not assume every answer must be “no” in every organization. The important thing is that the risk is deliberate and understood.

<details>
<summary>Answer</summary>

A developer must not deploy Prod from a laptop. Images must not overwrite silently. Untested artifacts must not skip UAT. Secrets must not appear in logs.

Every “yes” to those risks needs a deliberate control, not an accident.

</details>

---

## Part 28 — Hands-On Implementation

## 28. Hands-on pipeline (expected outcome)

Build the complete first version of the ShopSphere application pipeline.

The target is:

```text
Git
 ↓
Build
 ↓
Unit Test
 ↓
Security Checks
 ↓
Docker Build
 ↓
ECR Push
 ↓
Deploy Dev
 ↓
Health Check
 ↓
Promote UAT
 ↓
Health Check
 ↓
Production Approval
 ↓
Production
 ↓
Health Check
```

Record the following for one successful release:

```text
Git SHA:
Build ID:
Image Tag:
Image Digest:
Dev Deployment:
UAT Deployment:
Production Deployment:
```

Then deliberately perform at least three failure drills from this lesson.

Do not just repair them.

Write an incident note for each one.

<details>
<summary>Answer</summary>

Git → build → unit test → security checks → Docker → ECR → Dev `/health` → same digest to UAT → approval → Prod `/health`. Record Git SHA, build ID, tag, digest, and each environment result.

Write incident notes for at least three failure drills.

</details>

---

## Part 29 — Final Architecture Exercise

## 29. Final delivery architecture exercise

Draw the complete ShopSphere delivery architecture from memory.

It should include:

```text
Developer
   ↓
Git
   ↓
CI/CD
   ↓
Build
   ↓
Security
   ↓
ECR
   ↓
Dev
   ↓
UAT
   ↓
Production
```

Add:

```text
IAM
Secrets
Terraform
Network
Database
Load Balancer
Observability
Audit
```

Then annotate the identities:

```text
Developer Identity
Pipeline Identity
Build Identity
Deployment Identity
Runtime Identity
```

Then annotate the artifacts:

```text
Commit
 ↓
Build
 ↓
Image
 ↓
Digest
 ↓
Deployment
```

If you can explain every arrow, you understand the architecture.

<details>
<summary>Answer</summary>

Draw Developer → Git → CI/CD → ECR → Dev → UAT → Prod. Annotate IAM, secrets, Terraform, network, database, load balancer, observability, and audit.

Name five identities: developer, pipeline, build, deploy, runtime. Artifact chain: commit → build → image → digest → deployment.

</details>

---

## 30. Production change control

Define what requires additional control.

For example:

```text
Dev:
Automatic

UAT:
Automatic after Dev validation

Prod:
Controlled promotion
Approval
Health verification
Rollback capability
```

For infrastructure:

```text
Dev:
Automatic or low-friction

UAT:
Review

Prod:
Plan review
Approval
Controlled apply
Verification
```

The exact controls depend on organizational policy.

The engineering principle is:

**The higher the blast radius, the stronger the change controls should be.**

<details>
<summary>Answer</summary>

Dev can be automatic. UAT follows Dev validation. Prod is controlled promotion, approval with evidence, health, and rollback.

Higher blast radius needs stronger controls. Approval is not the only gate.

</details>
