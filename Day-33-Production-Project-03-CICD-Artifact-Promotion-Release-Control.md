# Day 33 — Production Project 03: CI/CD, Artifact Promotion & Release Control

Day 32 established the ShopSphere network and security foundation. Day 33 connects that foundation to the software delivery system. The goal is to build a pipeline that can take a specific source change, verify it, create one deployable artifact, store it, promote that same artifact through Dev and UAT, and then release it to Production through controlled automation. The important Senior/Lead principle is that **a deployment pipeline is a supply chain with trust boundaries**, not just a sequence of shell commands.

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

The infrastructure created on Day 32 is not recreated by the application pipeline.

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

**Is that exact artifact being promoted to Production?**

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

Do not make a health check unnecessarily dependent on every external system if that causes healthy capacity to disappear during a partial dependency failure. Health semantics should be designed deliberately.

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

This can be implemented through pipeline metadata, deployment records, image metadata, or a release manifest.

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

## Part 17 — Failure Drill: Build Failure

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

---

## Part 18 — Failure Drill: ECR Push Failure

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

---

## Part 19 — Failure Drill: ECS Deployment Failure

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

---

## Part 20 — Failure Drill: Health Check Failure

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

---

## Part 21 — Failure Drill: Rollback

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

---

## Part 22 — Failure Drill: Pipeline Identity Compromise

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

## Part 27 — Lead-Level Pipeline Review

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

---

## Part 28 — Hands-On Implementation

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

---

## Part 29 — Final Architecture Exercise

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

---

## Part 30 — Senior/Lead Interview Recall

Answer these without looking at the lesson.

1. Why should the application be built once and promoted?
2. Why is an image digest useful?
3. What is the difference between CI and CD?
4. What does ECR provide?
5. Why should build and deployment identities be separated?
6. Why should runtime identity be different from deployment identity?
7. How should a pipeline authenticate to AWS?
8. Why are long-lived access keys undesirable for CI/CD?
9. How would you design Dev/UAT/Prod promotion?
10. What should happen before Production traffic reaches a new version?
11. What makes a health check useful?
12. How would you troubleshoot an ECR `AccessDenied`?
13. How would you troubleshoot an ECS image-pull failure?
14. How would you investigate a deployment that succeeded but users receive 503?
15. How would you roll back?
16. How does cross-account deployment work?
17. Why separate application and infrastructure pipelines?
18. How could a pipeline leak a secret?
19. How would you limit the blast radius of a compromised pipeline?
20. How do you prove which source revision is running in Production?

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

**You can take one Git commit, follow its artifact through every environment, identify the identity used at each stage, prove what is running in Production, and recover safely when the release is bad.**

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
