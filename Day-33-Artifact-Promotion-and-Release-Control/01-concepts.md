# Day 33 — Production Project 03 CI/CD Artifact Promotion & Release Control

This Day uses three files. Read them in this order.

1. [01-concepts.md](01-concepts.md) — lesson content (this file)
2. [02-questions-and-answers.md](02-questions-and-answers.md) — practice items, each with a model answer
3. [03-implementation.md](03-implementation.md) — hands-on lab

Day 32 established the ShopSphere network and security foundation. Day 33 connects that foundation to the software delivery system. The goal is to build a pipeline that can take a specific source change, verify it, create one deployable artifact, and store it. The pipeline then promotes that same artifact through Dev and UAT and releases it to Production through controlled automation. The important Senior/Lead principle is that **a deployment pipeline is a supply chain with trust boundaries**, not just a sequence of shell commands.

---

## Part 1 — The Delivery System

The target ShopSphere application flow is:

```text
Developer
   ↓
Git
   ↓
CI Pipeline
   ↓
Build + Test + Security
   ↓
Container Image
   ↓
ECR
   ↓
Dev
   ↓
UAT
   ↓
Production Approval
   ↓
Production
   ↓
Health Verification
```

The application pipeline does not recreate the infrastructure from Day 32.

Think of two related systems:

```text
Infrastructure Pipeline
        ↓
Network / IAM / Database / Runtime

Application Pipeline
        ↓
Application Image / Deployment
```

This separation makes ownership and blast radius clearer.

The application pipeline should consume infrastructure; it should not silently redesign the production network every time a developer changes Java code.

---

## Part 2 — Source Control Is the Starting Point

Every deployment should begin with a traceable source revision.

For example:

```text
Git commit:
a81f29c
```

The pipeline should preserve that identifier through the delivery process.

A useful chain is:

```text
Git SHA
   ↓
Pipeline Run
   ↓
Build
   ↓
Image Tag
   ↓
Image Digest
   ↓
Deployment
   ↓
Running Task
```

This allows an incident investigator to answer:

**What source change is running in Production?**

Use immutable source references wherever possible. A branch such as `main` tells you where the code came from, but the commit SHA tells you exactly which revision was built.

---

## Part 3 — Continuous Integration

The CI stage should verify the application before creating a release artifact.

For the Spring Boot backend:

```text
Checkout
 ↓
Dependency Resolution
 ↓
Compile
 ↓
Unit Tests
 ↓
Package
```

Then add security-oriented checks:

```text
Dependency/SCA
 ↓
Secret Detection
 ↓
Static Analysis
 ↓
Container/IaC Checks
```

The exact tools can vary.

The important distinction is:

**CI asks whether this source revision is safe and valid enough to become a release candidate.**

It should not depend on Production being available.

---

## Part 4 — Build Once

After CI succeeds, create the container image once.

For example:

```text
shopsphere-api:a81f29c
```

Then push that image to ECR.

Do not rebuild the application independently for Dev, UAT, and Production.

The desired flow is:

```text
One Git Commit
      ↓
One Build
      ↓
One Image
      ↓
Dev
      ↓
UAT
      ↓
Production
```

The reason is traceability and consistency.

If you rebuild for every environment, the artifact that passed UAT may not be exactly the artifact that reaches Production.

The Senior/Lead question is:

**Can I prove that Production is running the same artifact that passed validation?**

---

## Part 5 — ECR as the Artifact Boundary

ECR becomes the handoff point between CI and the runtime platform.

Conceptually:

```text
CodeBuild / Build Agent
        ↓
      ECR
        ↓
       ECS
```

The build identity needs permission to push images.

The application runtime identity does not need permission to push images.

This is another identity separation:

```text
Image Builder
   ↓
Push to ECR

Application Runtime
   ↓
Pull/use image
```

Keep these responsibilities separate.

Record the image digest after the push.

For example:

```text
Tag:
a81f29c

Digest:
sha256:...
```

The tag is convenient for humans; the digest identifies the exact image content.

---

## Part 6 — Pipeline Identity

Your pipeline needs AWS access.

Do not solve this by putting an IAM access key and secret key directly into pipeline variables.

Instead, design a short-lived/federated authentication path where your CI platform supports it.

The conceptual flow is:

```text
CI Platform
     ↓
Federated Authentication
     ↓
AWS Role
     ↓
Temporary Credentials
     ↓
AWS API
```

The role should have only the permissions required by the pipeline.

For the build stage, that may include:

```text
ECR authentication
ECR image push
CloudWatch log access
Required build resources
```

For deployment:

```text
ECS deployment permissions
Required service/resource access
```

Do not create one “DevOps Administrator” identity and use it for everything.

---

## Part 7 — Separate Build and Deployment Permissions

A useful model is:

```text
Build Role
   ↓
Build / Test / Push Image

Deployment Role
   ↓
Update Runtime

Runtime Role
   ↓
Application Dependencies
```

These are different responsibilities.

For example, the Spring Boot application might need:

```text
Secrets Manager → read specific secret
S3 → read specific bucket
CloudWatch → write application logs
```

It should not need:

```text
ECS → update service
ECR → push image
IAM → create role
Terraform → modify infrastructure
```

Likewise, the deployment identity should not automatically inherit every permission available to the application.

This separation limits blast radius.

---

## Part 8 — Build the First CI Pipeline

Create the pipeline in small steps.

Start with:

```text
Source
 ↓
Build
 ↓
Test
```

Verify that it succeeds.

Then add:

```text
Docker Build
 ↓
ECR Push
```

Verify the image.

Then add:

```text
Deploy Dev
```

Verify the application.

Only after each stage works independently should you combine everything into a production-style flow.

This makes troubleshooting much easier than creating one huge pipeline and trying to diagnose ten interacting failures.

---

## Part 9 — Dev Deployment

The Dev deployment should consume the image produced by CI.

Do not rebuild it.

The flow is:

```text
ECR
 ↓
Image Digest
 ↓
ECS Task Definition
 ↓
ECS Service
 ↓
Load Balancer
 ↓
Application
```

After deployment, perform an automated health check.

At minimum:

```text
HTTP /health
```

The pipeline should fail if the deployment technically completes but the application does not become healthy.

This establishes an important principle:

**Deployment success must include application verification.**

---

## Part 10 — UAT Promotion

After Dev succeeds:

```text
Dev
 ↓
Validation
 ↓
UAT
```

Use the same image digest.

Do not rebuild.

UAT should provide a more production-like validation environment where appropriate.

The pipeline should record:

```text
Artifact
Environment
Deployment Time
Deployment Result
Commit
```

Now you can answer:

**Which artifact was tested in UAT?**

and:

**Does that exact artifact go to Production?**

---

## Part 11 — Production Promotion

Production should add stronger controls.

A simple model is:

```text
UAT Success
    ↓
Automated Checks
    ↓
Production Approval
    ↓
Production Deployment
    ↓
Health Verification
    ↓
Observation
```

Approval should not be the only control.

The approver should have evidence such as:

```text
Commit
Build result
Security checks
Artifact digest
UAT result
Change description
Rollback plan
```

This turns Production approval from a ceremonial button into a meaningful change-control decision.

---

## Part 12 — Deployment Strategy

For the first version of ShopSphere, use a deployment strategy that maintains service availability while the new application becomes healthy.

The exact AWS implementation depends on the runtime and deployment tooling.

The conceptual model is:

```text
Existing Version
       ↓
New Version Starts
       ↓
Health Check
       ↓
Traffic Transition
       ↓
Observe
       ↓
Continue / Roll Back
```

Do not expose all traffic to an unverified version.

The most important question is:

**At what point can the new version receive production traffic?**

The answer should involve health validation rather than simply “when the container starts.”

---

## Part 13 — Health Checks

Use multiple levels of health information.

A process-level check might show:

```text
Java process running
```

That is insufficient.

An application health endpoint should show whether the service is actually capable of serving requests.

For example:

```text
/health
```

A deeper readiness check might validate required dependencies where appropriate.

Think in layers:

```text
Process
 ↓
Container
 ↓
Application
 ↓
Dependencies
 ↓
User Request
```

Do not make a health check unnecessarily dependent on every external system, because healthy capacity can then disappear during a partial dependency failure. Design the health semantics deliberately.

---

## Part 14 — Runtime Configuration

The image should remain environment-neutral.

For example:

```text
Same Image
 ├── Dev
 ├── UAT
 └── Prod
```

Runtime configuration supplies:

```text
DATABASE_HOST
DATABASE_NAME
APPLICATION_ENV
API_ENDPOINTS
```

Secrets should come from the central secret-management system.

The pipeline should not create a different image because Production has different database credentials.

The desired separation is:

```text
Artifact
+
Environment Configuration
+
Secrets
=
Running Application
```

---

## Part 15 — Artifact Traceability

Create a release record.

For example:

```text
Release:
shopsphere-2026.09.18.01

Git:
a81f29c

Image:
shopsphere-api:a81f29c

Digest:
sha256:...

Dev:
Passed

UAT:
Passed

Production:
Deployed
```

Pipeline metadata, deployment records, image metadata, or a release manifest can provide this.

The exact implementation is less important than the capability.

During an incident, you should not need to search through multiple systems manually just to determine which application version is running.

---

## Part 16 — Secrets in CI/CD

Inspect the pipeline for possible secret leakage.

Look for:

```text
Git
Pipeline YAML
Pipeline variables
Build logs
Dockerfile
Docker image layers
Artifacts
Deployment manifests
```

A secret can leak even if it was never committed to Git.

For example:

```bash
echo $DATABASE_PASSWORD
```

can expose it in logs.

Likewise, putting a secret into a Dockerfile can permanently embed it into an image layer.

The security principle is:

**A secret is not safe merely because it is not stored in Git.**

You must consider every place where it can be copied, logged, cached, or persisted.

---

## Part 23 — Multi-Account Promotion

If Dev, UAT, and Production are separate AWS accounts, the pipeline needs controlled cross-account access.

Conceptually:

```text
Central CI/CD
      │
      ├── Assume Dev Role
      │
      ├── Assume UAT Role
      │
      └── Assume Prod Role
```

Each target account has a deployment role with a trust policy that permits the appropriate pipeline identity to assume it.

The Production role should be more restrictive than the Dev role where appropriate.

The central pipeline should not require permanent administrator access to all accounts.

This architecture gives you:

```text
Centralized Delivery
+
Account Isolation
+
Controlled Trust
```

---

## Part 24 — Application Pipeline vs Infrastructure Pipeline

By now, ShopSphere should have two conceptual release paths.

Application:

```text
Git
 ↓
Build
 ↓
Test
 ↓
Security
 ↓
Image
 ↓
ECR
 ↓
Deploy
```

Infrastructure:

```text
Terraform
 ↓
Validate
 ↓
Security / Policy
 ↓
Plan
 ↓
Review
 ↓
Apply
 ↓
Verify
```

An application deployment should not unexpectedly modify a VPC.

An infrastructure deployment should not rebuild the Spring Boot application.

This separation is not absolute in every organization, but it is a strong default because it reduces coupling and blast radius.

---

## Part 25 — Production Change Control

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

---

## Part 26 — Pipeline Observability

A pipeline should itself be observable.

Track:

```text
Pipeline duration
Build failures
Deployment failures
Approval wait time
Deployment frequency
Rollback frequency
Failure rate
```

For individual releases, capture:

```text
Commit
Build
Artifact
Environment
Deployment
Result
```

This allows you to investigate both technical incidents and delivery-process problems.

For example:

**Why are Production deployments frequently failing?**

The answer might be:

- bad health checks
- environment drift
- insufficient capacity
- missing secrets
- incorrect configuration
- weak testing
- unreliable external dependencies

Pipeline metrics can expose these patterns.

---

## Part 31 — Day 33 Completion Criteria

Do not mark Day 33 complete because the pipeline is green once.

Complete the day when you can demonstrate:

```text
[ ] Source revision is traceable
[ ] CI build works
[ ] Unit tests run
[ ] Security checks run
[ ] Docker image is built once
[ ] Image is pushed to ECR
[ ] Image digest is recorded
[ ] Dev deployment works
[ ] Dev health check works
[ ] Same artifact reaches UAT
[ ] UAT health check works
[ ] Production promotion is controlled
[ ] Production health check works
[ ] Pipeline identity is scoped
[ ] Runtime identity is separate
[ ] Secrets are not stored in Git
[ ] Pipeline logs do not expose secrets
[ ] Build failure drill completed
[ ] ECR authorization failure diagnosed
[ ] ECS deployment failure diagnosed
[ ] Health-check failure diagnosed
[ ] Rollback completed
[ ] Cross-account model understood
[ ] Application/IaC pipeline boundary documented
[ ] Release traceability documented
```

The most important completion criterion is:

**You can take one Git commit, follow its artifact through every environment, and identify the identity in use at each stage. You can prove what runs in Production and recover safely when the release is bad.**

---

## Part 32 — What Comes Next

Day 33 established the delivery system.

Day 34 will focus on **production reliability and deployment strategies**.

The project will move from:

```text
Can we deploy?
```

to:

```text
Can we deploy safely under failure?
```

You will work with:

```text
Rolling Deployments
Blue/Green
Canary Concepts
Capacity During Deployment
Health Checks
Graceful Shutdown
Connection Draining
Database Compatibility
Rollback
Rollback vs Roll Forward
Failure Containment
Release Risk
```

The goal is to make ShopSphere not merely deployable, but **safe to change**.

---

## Cleanup

Do not destroy the core ShopSphere application or infrastructure if it will be reused on Day 34.

Remove only temporary failure-drill resources.

Delete unused container images and other resources that can create unnecessary cost.

Before finishing, record the current known-good release:

```text
Git SHA:
Image Digest:
Environment:
Deployment Time:
Health Status:
```

This becomes the baseline for the next day's deployment and reliability exercises.
