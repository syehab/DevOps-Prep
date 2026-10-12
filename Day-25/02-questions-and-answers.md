# Day 25 — Questions and answers

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Then answer each item below before you open the Answer block. After that, do the lab in [03-implementation.md](03-implementation.md).

Write your own answer first. Open the Answer block only after you try. Keep the original numbering.

---

## 1. Which system owns source, build, artifact, image, registry, deploy, infra, and secrets

**Practice**

Take a Spring Boot application and write down:

```text
Source:
Azure Repos

Build:
Maven

Artifact:
JAR

Container:
Docker image

Registry:
Azure Container Registry

Deployment:
Azure Container Apps / AKS

Infrastructure:
Terraform

Secrets:
Azure Key Vault
```

The important exercise is identifying which system owns each responsibility.

<details>
<summary>Answer</summary>

Source lives in Azure Repos. Maven builds the JAR. Docker produces the image. ACR stores it. Container Apps or AKS run it. Terraform owns infrastructure. Key Vault owns secrets.

Keep source, artifact, environment, and infrastructure separate. A JAR is not a Git SHA. A deployment target is not Terraform state. Naming the owner of each step is the delivery architecture.

</details>

---

## 2. Feature branch, PR, and required pipeline checks before merge

**Practice**

Create a feature branch, make a harmless application change, push it, create a PR, and observe which pipeline checks are required before merge.

<details>
<summary>Answer</summary>

Run `git checkout -b feature/add-health-check`, commit a harmless change, and `git push origin feature/add-health-check`. Open a PR into protected `main`. Confirm reviewers, build validation, and no direct pushes.

Record `git rev-parse HEAD`. That SHA must travel into the build ID, image tag, digest, and deployment. A tag such as `1.4.2` is friendly. The digest is the real image identity.

</details>

---

## 3. Pipeline stages Build, Security, Publish, Dev, UAT, Production — where approvals sit

**Practice**

Design a pipeline with:

```text
Stage 1: Build
Stage 2: Security
Stage 3: Publish
Stage 4: Dev
Stage 5: UAT
Stage 6: Production
```

Then identify which stages should require approval or automated checks.

<details>
<summary>Answer</summary>

Build, Security, and Publish run automatically on `main` after PR checks. Dev deploys automatically and runs a health check. UAT deploys the same artifact with tests. Production needs environment checks: UAT succeeded, `main` only, and a production-owner approval.

Put production governance on the Azure DevOps Environment, not only in YAML `condition`. If a developer can edit YAML and skip the approval, the control is not real.

</details>

---

## 4. InfraPipelineIdentity vs AppDeploymentIdentity and blast radius

**Practice**

Design two identities:

```text
InfraPipelineIdentity
  → manages infrastructure

AppDeploymentIdentity
  → deploys application
```

Ask yourself what would happen if the AppDeploymentIdentity were compromised. This is the **blast-radius test** for pipeline identity.

<details>
<summary>Answer</summary>

InfraPipelineIdentity applies Terraform or Bicep at the platform resource groups. AppDeploymentIdentity only updates the app on Container Apps or AKS. Use federated service connections, not long-lived client secrets. Scope RBAC to the resource group, not subscription Owner.

If AppDeploymentIdentity is stolen, the attacker can change running apps in that scope, not create subscriptions or rewrite the hub network. That is the blast-radius test. Split build, deploy, and runtime identities.

</details>

---

## 5. Production environment: main, UAT succeeded, owner approval, same artifact

**Practice**

Design a Production environment with:

```text
Approved branch:
main

Required validation:
UAT succeeded

Approval:
Production owner

Deployment:
same artifact tested in UAT
```

Then ask: “Can a developer change YAML and bypass the production control?” If yes, the governance design needs improvement.

<details>
<summary>Answer</summary>

Bind the Prod stage to `environment: production`. Require branch `main`, a successful UAT stage, and a production-owner approval. Deploy the digest already running in UAT.

Ask whether a YAML edit can bypass the check. If yes, move the gate to environment checks and protected service connections. Pipeline logic is not the same as governance.

</details>

---

## 6. Variable groups VG-DEV, VG-UAT, VG-PROD plus Key Vault secrets

**Practice**

Create:

```text
VG-DEV
VG-UAT
VG-PROD
```

Put non-sensitive environment configuration in the groups and keep sensitive values in Key Vault.

<details>
<summary>Answer</summary>

Put `DATABASE_HOST` and feature flags in `VG-DEV`, `VG-UAT`, and `VG-PROD`. Keep passwords and keys in Key Vault. The pipeline identity retrieves secrets at deploy time. The image stays the same.

Never commit `DB_PASSWORD` in YAML or `ENV DB_PASSWORD` in a Dockerfile. Configuration changes per environment. The artifact does not.

</details>

---

## 7. Reusable template for Java build, tests, and artifact publish

**Practice**

Create one reusable template for:

```text
Java build
Unit tests
Artifact publishing
```

Then consume it from two different sample applications.

<details>
<summary>Answer</summary>

Create `templates/build.yml` with parameters such as `javaVersion`. It runs `mvn clean test package` and publishes the artifact. Two app repos include that template from `azure-pipelines.yml`.

Centralize security checks, artifact conventions, and identity patterns. Let teams keep app-specific tests. Copy-paste YAML across 50 repos cannot be patched consistently.

</details>

---

## 8. Map changes to shopsphere-app vs shopsphere-infra

**Practice**

Create two repositories conceptually:

```text
shopsphere-app
shopsphere-infra
```

Map which changes belong to each repository.

<details>
<summary>Answer</summary>

`shopsphere-app`: Java, tests, Dockerfile, Helm or app YAML, application pipeline. `shopsphere-infra`: VNet, ACR, AKS or Container Apps, Key Vault, Terraform modules, infra pipeline.

A Java bugfix must not run `terraform apply`. An AKS node-pool change must not rebuild the JAR. Coordinate only when the app needs a new platform capability first.

</details>

---

## 9. Terraform remote state, then observe drift

**Practice**

Create a small Azure resource with Terraform and configure remote state. Run:

```bash
terraform plan
terraform apply
terraform state list
```

Then make a controlled change outside Terraform and run another plan to observe drift (drift means the real infrastructure no longer matches what the code describes).

<details>
<summary>Answer</summary>

Use an `azurerm` backend on a storage account, with keys such as `prod/platform.tfstate`. Run `terraform init`, `terraform plan`, `terraform apply`, and `terraform state list`. Change a tag in the portal. Run `terraform plan` again and read the drift.

Local state is unsafe in a team. Separate state per environment. State is a control mechanism, not a cache. Protect the storage account.

</details>

---

## 10. Bicep storage account: `what-if` then deploy

**Practice**

Create a Bicep template for a storage account, run `what-if`, review the changes, and deploy it only after understanding the expected result.

<details>
<summary>Answer</summary>

Write a storage account in Bicep. Run `az deployment group what-if` and read creates, deletes, and in-place changes. Deploy with `az deployment group create` only after the result matches intent.

Bicep has no Terraform-style state file. ARM is the control plane. `what-if` is the review artifact, like `terraform plan`.

</details>

---

## 11. Enforce Environment, Owner, and CostCenter tags

**Practice**

Create a rule such as:

```text
Production resources must have:
Environment=Production
Owner=<team>
CostCenter=<value>
```

Then think about where to enforce it: code convention, pipeline validation, Azure Policy, or a combination.

<details>
<summary>Answer</summary>

Use all three layers. Convention and `terraform validate` or a policy check in CI catch mistakes early. Azure Policy Audit then Deny at the Production management group stops non-compliant ARM creates. RBAC still limits who can apply.

One control is not enough. A pipeline skip, a portal click, and a malicious identity are different paths. Policy sits above YAML.

</details>

---

## 12. Build once, push to ACR, promote the same digest

**Practice**

Build one image, push it to ACR, and deploy it to Dev. Then identify the exact digest that you deployed. Use that same image identity for UAT and Production.

<details>
<summary>Answer</summary>

`docker build`, scan, and `docker push` once. Record the digest with `docker inspect` or ACR. Deploy Dev as `<acr>/shopsphere@sha256:<digest>`. Promote that digest to UAT and Production.

Do not rebuild per environment. A mutable tag can move. The digest cannot. Trace Git SHA → build ID → tag → digest → deployment.

</details>

---

## 13. Same Spring Boot image to App Service, Container Apps, and AKS

**Practice**

Take the same Spring Boot image and design three deployment paths:

```text
App Service
Container Apps
AKS
```

Identify what changes in:

```text
Deployment command
Networking
Identity
Scaling
Rollback
Configuration
Operational ownership
```

<details>
<summary>Answer</summary>

App Service: deploy the container to the app; Azure owns the host; slots for rollback. Container Apps: `az containerapp update --image`; revisions and scale rules. AKS: `kubectl set image` or `helm upgrade`; rolling update and probes.

Networking, identity attachment, and operational ownership change. The image and “build once” rule do not. Ask what release mechanism the platform supports.

</details>

---

## 14. ShopSphere production path from PR to running Pods

**Practice**

Take your ShopSphere capstone and design the complete Production deployment path from PR to running Pods/containers. For every arrow, ask:

```text
Who is trusted here?
What identity is used?
What is being verified?
What can fail?
What is the rollback mechanism?
```

<details>
<summary>Answer</summary>

PR on protected `main`: review, unit tests, SAST/SCA. Build identity builds, scans, and pushes the image. Dev then UAT run the digest. Production environment checks plus a deploy identity apply it to AKS. Runtime identity reads Key Vault. Health and smoke tests follow.

For every arrow name who is trusted, which identity, what is verified, what can fail, and how you roll back. `git push` is not a production path.

</details>

---

## 15. Deployment record: SHA, build, digest, approver, result

**Practice**

Design a deployment record containing:

```text
Application
Environment
Git SHA
Build ID
Artifact/Image
Image Digest
Deployment Time
Approver
Deployment Result
```

This is a useful production and interview-level exercise.

<details>
<summary>Answer</summary>

Record application, environment, Git SHA, build ID, image name, digest, deploy time, approver, and result. Expose non-secret `APP_VERSION`, `GIT_COMMIT`, and `BUILD_ID` on an info endpoint.

In an incident you should say digest → build 1842 → SHA `abc123` → PR #417 → 21:42. Do not ask “who deployed recently?” as the first step.

</details>

---

## 16. PR code plus subscription Contributor is not safe

**Practice**

Take a pipeline that has:

```text
PR code
+
Azure subscription Contributor identity
```

Ask whether that is safe. Then redesign it so untrusted validation has minimal permissions and production credentials are available only to the controlled deployment stage.

<details>
<summary>Answer</summary>

Untrusted PR YAML or application code must not receive production credentials. Run PR validation with a low-privilege identity that cannot deploy. Give production Contributor, scoped tightly, only to the production deployment job after merge and checks.

Do not `echo $(DB_PASSWORD)`. Protect pipeline YAML. The pipeline is part of the supply chain. Split untrusted execution from privileged deployment.

</details>

---

## 17. Pipeline succeeded, application returns HTTP 503

**Practice**

Work through this scenario:

```text
Pipeline says deployment succeeded.
Application returns HTTP 503.
```

Do not debug the YAML first.

Use:

```text
Pipeline
→ Azure resource
→ deployment revision
→ health state
→ networking
→ application logs
→ dependency connectivity
```

The pipeline may be completely correct while the application is unhealthy.

<details>
<summary>Answer</summary>

Do not debug YAML first. Check the Azure resource, revision or Deployment, health probes, networking, application logs, and dependencies. Commands: `az resource list`, `kubectl get pods`, `kubectl describe pod`, `kubectl logs`.

The pipeline can be correct while the app is unhealthy. Walk trigger → source → agent → auth → build → artifact → deploy → runtime. Identify the failing layer before you rerun.

</details>

---

## 18. Enterprise Azure DevOps architecture for 50 teams — ten design questions

**Practice**

Draw the architecture on paper and answer these questions:

1. How does an application team deploy without receiving subscription Owner permissions?
2. How is the production artifact proven to be the same artifact tested in UAT?
3. Where are secrets stored?
4. How are Terraform state files separated?
5. How are infrastructure changes reviewed?
6. How can the platform team enforce security standards across 50 teams?
7. What happens if the pipeline identity is compromised?
8. How do you identify exactly which Git commit is running in Production?
9. How do you roll back a bad application release?
10. How do you prevent an application deployment from accidentally changing infrastructure?

<details>
<summary>Answer</summary>

1. Teams deploy through a federated service connection with resource-group RBAC, never subscription Owner. 2. Promote the same image digest from UAT. 3. Secrets live in Key Vault. 4. Separate Terraform state keys per environment and workload. 5. Infra PRs require `fmt`, `validate`, plan/what-if, and approval. 6. Platform templates, required checks, Azure Policy, and ACR rules enforce security. 7. A stolen pipeline identity is limited by scope and cannot be build+deploy+runtime in one. 8. Pod digest → ACR → build ID → Git SHA. 9. Roll back the previous digest or Helm revision if schema allows. 10. App pipelines cannot run Terraform; infra pipelines cannot push app images.

Platform owns templates, identity patterns, modules, and governance. Teams own code, tests, and app config.

</details>

---

## 19. What responsibilities does Azure DevOps cover?

**5-Minute Recall**

1. What responsibilities does Azure DevOps cover?

<details>
<summary>Answer</summary>

Repos, Pipelines, Artifacts, Boards, and deployment environments with checks. It is the delivery platform, not only YAML hosting.

Ask where each responsibility should live: source, artifact, environment, or infrastructure.

</details>

---

## 20. Why should `main` normally be protected?

**5-Minute Recall**

2. Why should `main` normally be protected?

<details>
<summary>Answer</summary>

So production artifacts come only from reviewed, tested commits. Require PRs, reviewers, and pipeline validation. Block direct pushes.

An unprotected `main` is an unsigned path into every environment that deploys from it.

</details>

---

## 21. Difference between source code and an artifact

**5-Minute Recall**

3. What is the difference between source code and an artifact?

<details>
<summary>Answer</summary>

Source is the Git commit. An artifact is the deployable output: JAR, image, or package.

You promote artifacts. You do not rebuild source in Production and hope it matches UAT.

</details>

---

## 22. Why build once and promote?

**5-Minute Recall**

4. Why should an artifact be built once and promoted?

<details>
<summary>Answer</summary>

So Production runs the same bytes that passed UAT. A new Docker build per environment creates uncertainty.

Identity the image by digest and move that digest along Dev → UAT → Prod.

</details>

---

## 23. What is a service connection?

**5-Minute Recall**

5. What is a service connection?

<details>
<summary>Answer</summary>

The Azure DevOps link that lets a pipeline call Azure or another system. It uses an identity, preferably federated.

Authentication (who the pipeline is) stays separate from Azure RBAC (what it may do).

</details>

---

## 24. Why prefer workload identity federation over long-lived secrets?

**5-Minute Recall**

6. Why is workload identity federation preferable to long-lived pipeline secrets?

<details>
<summary>Answer</summary>

Federation issues short-lived tokens. You do not store and rotate a permanent client secret in Azure DevOps.

A leaked secret is standing access. A federated token expires.

</details>

---

## 25. Authentication vs authorization

**5-Minute Recall**

7. What is the difference between authentication and authorization?

<details>
<summary>Answer</summary>

Authentication proves identity. Authorization decides permitted actions.

A federated pipeline can authenticate and still fail RBAC at the resource group.

</details>

---

## 26. Why stronger Production controls than Dev?

**5-Minute Recall**

8. Why should Production have stronger controls than Dev?

<details>
<summary>Answer</summary>

Production blast radius includes customers and data. Use approvals, restricted identities, and the already-tested artifact.

Dev can deploy automatically so teams move fast. Prod must be auditable.

</details>

---

## 27. What problem do YAML templates solve?

**5-Minute Recall**

9. What problem do YAML templates solve?

<details>
<summary>Answer</summary>

They reuse build, security, and deploy steps so 50 teams do not copy 200-line pipelines.

Centralize guardrails. Leave application-specific tests with the team.

</details>

---

## 28. Why separate application and infrastructure pipelines?

**5-Minute Recall**

10. Why separate application and infrastructure pipelines?

<details>
<summary>Answer</summary>

App changes should not carry Terraform risk. Infra changes should not rebuild the JAR.

Do not make every app deploy run a full infrastructure apply.

</details>

---

## 29. Why does Terraform need state?

**5-Minute Recall**

11. Why does Terraform need state?

<details>
<summary>Answer</summary>

State maps configuration to real resources so plan and apply know what already exists.

Without state, Terraform cannot manage infrastructure safely.

</details>

---

## 30. Why remote state in a team environment?

**5-Minute Recall**

12. Why should Terraform state be remote in a team environment?

<details>
<summary>Answer</summary>

So every engineer and pipeline uses one state copy with locking. Local files diverge.

Put state in Azure Storage, split by environment, and restrict who can read it.

</details>

---

## 31. What does `terraform plan` provide?

**5-Minute Recall**

13. What does `terraform plan` provide?

<details>
<summary>Answer</summary>

A preview of creates, changes, and destroys before apply. Save `-out=tfplan` and apply that plan in production.

Plan is the review artifact. Do not apply unreviewed.

</details>

---

## 32. What does Bicep `what-if` provide?

**5-Minute Recall**

14. What does Bicep `what-if` provide?

<details>
<summary>Answer</summary>

The expected ARM changes for a Bicep deployment, analogous to `terraform plan`.

Review `az deployment group what-if` before `az deployment group create`.

</details>

---

## 33. What is the role of ACR?

**5-Minute Recall**

15. What is the role of ACR?

<details>
<summary>Answer</summary>

ACR stores container images that AKS, Container Apps, and App Service pull.

Control who can push and who can pull. Scan before promote.

</details>

---

## 34. Why is an image digest useful?

**5-Minute Recall**

16. Why is an image digest useful?

<details>
<summary>Answer</summary>

A digest identifies exact image bytes. A tag can move.

Production should pin `@sha256:...` so you know what is running.

</details>

---

## 35. Why secrets in Key Vault rather than Dockerfiles?

**5-Minute Recall**

17. Why should secrets live in Key Vault rather than Dockerfiles?

<details>
<summary>Answer</summary>

Images are copied, cached, and often readable. A baked password leaks everywhere that image goes.

Retrieve secrets at runtime with workload identity.

</details>

---

## 36. What is artifact traceability?

**5-Minute Recall**

18. What is artifact traceability?

<details>
<summary>Answer</summary>

The chain from running workload to digest, build, Git SHA, PR, and approver.

It turns “who deployed?” into a record you can read during an incident.

</details>

---

## 37. What happens if a pipeline identity is compromised?

**5-Minute Recall**

19. What happens if a pipeline identity is compromised?

<details>
<summary>Answer</summary>

The attacker can do whatever that identity’s RBAC allows: push images, apply Terraform, or deploy Prod.

Narrow scope, split identities, and federation limit the blast radius. One super-role does not.

</details>

---

## 38. Troubleshoot a pipeline that succeeds but the app returns 503

**5-Minute Recall**

20. How would you troubleshoot a pipeline that succeeds but the application returns 503?

<details>
<summary>Answer</summary>

Inspect the deployed resource, health probes, Pods or revisions, logs, networking, and dependencies. Skip YAML until runtime evidence says the deploy never happened.

Pipeline success means Azure DevOps finished steps. It does not mean users are healthy.

</details>

---

## 39. Build shopsphere-app and shopsphere-infra labs, then inject failures

**Practice: Build a Complete Azure DevOps + IaC Lab**

Use a small Spring Boot application as the workload.

Create:

```text
shopsphere-app
shopsphere-infra
```

For infrastructure, provision:

```text
Resource Group
ACR
Container Apps or AKS
Key Vault
Log/monitoring resources as appropriate
```

Use Terraform for the infrastructure.

Your infrastructure repository should contain something similar to:

```text
shopsphere-infra/
├── main.tf
├── variables.tf
├── outputs.tf
├── providers.tf
├── backend.tf
└── modules/
    ├── acr/
    ├── key-vault/
    └── compute/
```

For the application repository:

```text
shopsphere-app/
├── src/
├── pom.xml
├── Dockerfile
└── azure-pipelines.yml
```

Your infrastructure pipeline should perform:

```text
terraform fmt
terraform validate
terraform plan
approval
terraform apply
```

Your application pipeline should perform:

```text
checkout
→ build
→ test
→ security checks
→ Docker build
→ image scan
→ push to ACR
→ deploy Dev
→ health check
→ deploy UAT
→ approval/checks
→ deploy Production
→ smoke test
```

For Production, use a separate deployment identity with only the required permissions.

Then deliberately introduce failures:

```text
1. Break Terraform configuration
2. Remove an RBAC permission
3. Use the wrong Key Vault secret
4. Deploy an invalid image
5. Deploy the wrong image tag
6. Break application configuration
7. Make the health endpoint fail
8. Change infrastructure manually
```

For every failure, record:

```text
Failure
Layer
Evidence
Root cause
Fix
Prevention
```

This turns the lab into Senior/Lead practice rather than simply a YAML exercise.

<details>
<summary>Answer</summary>

Infra repo: RG, ACR, Container Apps or AKS, Key Vault, remote state. Pipeline: `terraform fmt`, `validate`, `plan`, approval, `apply`. App repo: Maven, tests, scan, Docker, push digest, Dev, UAT, Prod with a separate deploy identity.

Inject the eight failures (bad Terraform, missing RBAC, wrong secret, invalid image, wrong tag, bad config, failing health, manual drift). For each write Failure, Layer, Evidence, Root cause, Fix, Prevention. That is the Senior/Lead lab, not a YAML demo.

</details>
