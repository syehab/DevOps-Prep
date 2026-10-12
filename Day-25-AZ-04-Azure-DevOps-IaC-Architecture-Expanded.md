# Day 25 — Azure Overlay 04: Azure DevOps + IaC Architecture

The goal of this day is to understand how Azure DevOps, Terraform, Bicep, Azure identity, artifacts, and Azure deployment targets fit together into one production delivery system. The important shift is from learning individual Azure DevOps features to designing a **secure, reusable, traceable delivery architecture**.

The core mental model for this day is:

**Source → Validate → Build → Secure → Package → Store → Promote → Deploy → Verify → Observe**

For infrastructure:

**Code → Validate → Plan/What-if → Approve → Apply/Deploy → Verify → Govern**

---

## Part 1 — Azure DevOps as a Delivery Platform

Azure DevOps is not simply a place that stores YAML pipelines. It is a collection of capabilities that support the software delivery lifecycle. Azure Repos provides source control, Azure Pipelines provides CI/CD, Azure Artifacts holds packages, Boards tracks work, and deployment environments/checks control releases. From a Senior/Lead perspective, the important question is not “Which Azure DevOps feature does this?” but “Where should this responsibility live in the delivery architecture?”

A typical enterprise flow is:

```text
Developer
   |
   v
Azure Repos
   |
   v
Pull Request
   |
   +--> Code Review
   +--> Build/Test
   +--> Security Checks
   |
   v
Artifact / Container Image
   |
   v
Dev
   |
   v
UAT
   |
   v
Production
```

The same basic model works whether the application runs on an Azure VM, App Service, Container Apps, or AKS. What changes is the final deployment mechanism.

A useful Senior/Lead distinction is **source, artifact, environment, and infrastructure**. Source answers “what code was changed?” Artifact answers “what exact software is deployable?” Environment answers “where is it running?” Infrastructure answers “what platform is required for it?” Keeping these concepts separate makes releases safer and easier to troubleshoot.

Implementation example — create a basic repository workflow:

```bash
git clone https://dev.azure.com/<organization>/<project>/_git/<repo>

git checkout -b feature/add-health-check

git add .
git commit -m "Add application health check"
git push origin feature/add-health-check
```

A Pull Request should normally be the controlled path into the protected main branch. Branch policies can require reviewers and successful pipeline checks before the change merges.

Practice:

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

---

## Part 2 — Azure Repos and Git Workflow

Azure Repos provides Git repositories for application and infrastructure code. The technology underneath is Git, so the fundamental concepts remain branches, commits, pull requests, tags, merge history, and commit identity. Azure DevOps adds collaboration and governance around that Git workflow.

A production-oriented workflow usually keeps the main branch protected and uses short-lived feature branches. The branch represents the line of development, while the commit SHA identifies the exact version of source code. This distinction becomes important when investigating production incidents because you want to answer exactly which source revision produced the deployed artifact.

A simple workflow is:

```text
feature branch
      |
      v
Pull Request
      |
      v
Build + Test + Security
      |
      v
Code Review
      |
      v
main
```

Implementation example — a simple branch policy concept:

```text
main
 ├── require pull request
 ├── require reviewers
 ├── require build validation
 └── prevent direct pushes
```

You can inspect the exact commit used by a build with:

```bash
git rev-parse HEAD
```

A pipeline can expose that SHA as part of its artifact metadata. For a container image, a useful trace is:

```text
Git SHA
   ↓
Build ID
   ↓
Image tag
   ↓
Image digest
   ↓
Deployment
```

**Remember:** a tag such as `1.4.2` is human-friendly, but the image digest is the stronger identity of the actual image content.

Practice:

Create a feature branch, make a harmless application change, push it, create a PR, and observe which pipeline checks are required before merge.

---

## Part 3 — Azure Pipelines Architecture

Azure Pipelines executes automated delivery workflows. A YAML pipeline describes the workflow as code, usually organized into stages, jobs, and steps. A stage represents a major phase such as Build, Test, Infrastructure, Deploy Dev, Deploy UAT, or Deploy Production. Jobs represent execution units, while steps perform individual commands or tasks.

A typical multi-stage application pipeline looks like:

```text
Build
  |
  +--> Unit Test
  +--> Dependency Scan
  +--> Build Image
  +--> Push Image
          |
          v
       Dev Deploy
          |
       Health Check
          |
          v
       UAT Deploy
          |
      Approval/Checks
          |
          v
       Prod Deploy
          |
      Health Check
```

Implementation example:

```yaml
trigger:
- main

stages:

- stage: Build
  jobs:
  - job: BuildApp
    steps:
    - script: mvn clean test package
      displayName: Build and test

    - task: PublishPipelineArtifact@1
      inputs:
        targetPath: '$(Build.SourcesDirectory)/target'
        artifact: 'application'
```

The important architectural principle is that the pipeline should produce a **known deployable artifact**. Deployment stages should consume that artifact rather than rebuilding the application independently for each environment.

For a containerized application:

```text
Source
  ↓
Maven build
  ↓
Docker build
  ↓
Image scan
  ↓
Push to ACR
  ↓
Deploy same image
```

Avoid a pattern where Dev, UAT, and Production each execute a new Docker build. That creates uncertainty because the artifact deployed to Production may not be byte-for-byte identical to what was tested in UAT.

Practice:

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

---

## Part 4 — Service Connections and Pipeline Identity

A service connection allows an Azure DevOps pipeline to access an external resource such as Azure. The critical security question is: **what identity does the pipeline use?**

Historically, service connections could use long-lived service principal credentials. A stronger modern pattern is workload identity federation, where Azure DevOps obtains short-lived credentials through federated authentication rather than storing a permanent client secret.

Conceptually:

```text
Azure Pipeline
     |
     | federated identity
     v
Microsoft Entra ID
     |
     | temporary access token
     v
Azure Resource Manager
     |
     v
Azure Resource
```

This reduces the need to store and rotate long-lived secrets in Azure DevOps.

Implementation concept:

```text
Azure DevOps service connection
        |
        v
Federated identity credential
        |
        v
Microsoft Entra application/service principal
        |
        v
Azure RBAC role assignment
```

The important distinction is that authentication and authorization are separate. Federation answers “can this pipeline prove who it is?” Azure RBAC answers “what is this identity allowed to do?”

Example role assignment:

```bash
az role assignment create \
  --assignee <PIPELINE-IDENTITY-ID> \
  --role Contributor \
  --scope /subscriptions/<SUBSCRIPTION-ID>/resourceGroups/<RG>
```

In a production design, avoid giving the pipeline broad subscription-level Contributor access unless there is a specific reason. Scope the identity to the resources it genuinely needs.

For an infrastructure pipeline, the identity may need permissions to create or update infrastructure. For an application deployment pipeline, it may only need permission to update the application platform.

Practice:

Design two identities:

```text
InfraPipelineIdentity
  → manages infrastructure

AppDeploymentIdentity
  → deploys application
```

Ask yourself what would happen if the AppDeploymentIdentity were compromised. This is the **blast-radius test** for pipeline identity.

---

## Part 5 — Environments, Approvals and Checks

Azure DevOps Environments provide a logical representation of deployment targets, and you can use them to control and record deployments. They are especially useful for production because they provide a governance boundary around deployment.

A simple model is:

```text
Dev
  ↓
UAT
  ↓
Production
```

The important concept is that an environment is not merely a variable container. It represents a deployment destination and can participate in deployment governance.

Production should typically have stronger controls than Dev:

```text
Dev:
automatic deployment

UAT:
automatic deployment + validation

Production:
approval/checks + deployment + verification
```

Approvals and checks can enforce conditions before a deployment proceeds. Examples include manual approval, branch restrictions, business-hour controls, or integration with external checks.

Implementation example concept:

```yaml
- stage: Production
  dependsOn: UAT
  condition: succeeded()

  jobs:
  - deployment: DeployProduction
    environment: production
    strategy:
      runOnce:
        deploy:
          steps:
          - script: echo "Deploy production"
```

The `environment: production` association allows the deployment to participate in environment-level governance.

A Senior/Lead should also distinguish **pipeline logic from governance**. A YAML condition can control workflow logic. Environment checks can provide centralized controls that developers cannot bypass simply with an application YAML change.

Practice:

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

---

## Part 6 — Variables, Variable Groups and Azure Key Vault

Applications need configuration that changes between environments, such as database endpoints, API URLs, feature flags, and connection settings. The application artifact should normally remain unchanged while the deployment or runtime injects environment-specific configuration.

A useful separation is:

```text
Application code
        +
Environment configuration
        +
Secrets
```

For example:

```text
DEV:
DATABASE_HOST=dev-db

UAT:
DATABASE_HOST=uat-db

PROD:
DATABASE_HOST=prod-db
```

Azure DevOps Variable Groups can centralize reusable configuration. Secrets should preferably come from a dedicated secret-management system such as Azure Key Vault rather than being permanently stored in pipeline YAML.

Conceptually:

```text
Azure Pipeline
     |
     v
Variable Group / Key Vault
     |
     v
Deployment
     |
     v
Application
```

Example variable usage:

```yaml
variables:
- group: app-dev-config

steps:
- script: |
    echo "Deploying $(APP_NAME)"
```

A stronger architecture is:

```text
Azure DevOps
      |
      | managed/federated identity
      v
Azure Key Vault
      |
      | secret retrieval
      v
Deployment
```

Do not put secrets directly into source control:

```yaml
# Bad
DB_PASSWORD: "SuperSecretPassword"
```

Do not bake secrets into a Docker image either:

```dockerfile
# Bad
ENV DB_PASSWORD=SuperSecretPassword
```

The secret should be supplied through an appropriate runtime or deployment mechanism.

Practice:

Create:

```text
VG-DEV
VG-UAT
VG-PROD
```

Put non-sensitive environment configuration in the groups and keep sensitive values in Key Vault.

---

## Part 7 — Pipeline Templates and Reuse

As the number of applications grows, copying the same YAML into every repository creates maintenance problems. If 50 teams each maintain their own 200-line pipeline and a security control needs to change, updating 50 pipelines becomes difficult and inconsistent.

Azure Pipelines supports YAML templates so you can reuse common workflow logic.

A simple structure is:

```text
repo
├── azure-pipelines.yml
└── templates
    ├── build.yml
    ├── security.yml
    └── deploy.yml
```

Example template:

```yaml
# templates/build.yml

parameters:
- name: javaVersion
  type: string
  default: '21'

steps:
- script: |
    echo "Using Java ${{ parameters.javaVersion }}"
    mvn clean test package
```

The main pipeline can consume it:

```yaml
stages:
- stage: Build
  jobs:
  - job: Build
    steps:
    - template: templates/build.yml
      parameters:
        javaVersion: '21'
```

Templates are useful for standardization, but excessive centralization can create a platform bottleneck. A good enterprise design usually centralizes **guardrails and common patterns** while allowing teams reasonable application-specific flexibility.

Senior/Lead thinking:

```text
Centralize:
security checks
artifact conventions
identity patterns
deployment standards

Allow teams to own:
application-specific build/test logic
application-specific deployment configuration
business-specific behavior
```

Practice:

Create one reusable template for:

```text
Java build
Unit tests
Artifact publishing
```

Then consume it from two different sample applications.

---

## Part 8 — Application Pipeline vs Infrastructure Pipeline

Application delivery and infrastructure delivery are related, but do not automatically treat them as the same change.

An application pipeline answers:

> “How do I safely build and deploy a new version of the software?”

An infrastructure pipeline answers:

> “How do I safely create or change the platform on which the software runs?”

A common architecture is:

```text
Application Repository
        |
        v
Application Pipeline
        |
        v
Artifact/Image
        |
        v
Deployment Platform


Infrastructure Repository
        |
        v
Infrastructure Pipeline
        |
        v
Terraform/Bicep
        |
        v
Azure Resources
```

For example, changing Java code may require only the application pipeline:

```text
Java change
 → build
 → test
 → image
 → deploy
```

Changing an AKS node pool may require only infrastructure delivery:

```text
Terraform change
 → validate
 → plan
 → approval
 → apply
```

Sometimes the two are intentionally coordinated. For example, an application release may require a new infrastructure capability first.

A useful Senior/Lead rule is:

**Do not make every application deployment depend on a full infrastructure deployment.**

Otherwise a small application change can acquire unnecessary infrastructure risk.

Practice:

Create two repositories conceptually:

```text
shopsphere-app
shopsphere-infra
```

Map which changes belong to each repository.

---

## Part 9 — Terraform on Azure: Backend, State and Locking

Terraform requires state so it can understand the relationship between configuration and infrastructure. In a team environment, local state is dangerous because different engineers or pipeline runs could operate against different copies of state.

Azure Storage can serve as a remote backend for Terraform state.

Conceptually:

```text
Developer / Pipeline
        |
        v
Terraform
        |
        v
Azure Storage Account
        |
        v
terraform.tfstate
```

A backend configuration might look like:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "stterraformstate123"
    container_name       = "tfstate"
    key                  = "prod/platform.tfstate"
  }
}
```

The state storage itself becomes an important production asset. It should have appropriate access control, protection, backups/versioning where appropriate, and limited administrative access.

A common environment separation is:

```text
tfstate/
├── dev/platform.tfstate
├── uat/platform.tfstate
└── prod/platform.tfstate
```

The exact organization can differ, but the key objective is to prevent unrelated environments from sharing one state file.

Terraform workflow:

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

For production, saving the plan and applying that exact plan helps ensure that the reviewed execution is the one that gets applied.

**Remember:** Terraform state is not simply a cache. It is part of the control mechanism Terraform uses to manage infrastructure safely.

Practice:

Create a small Azure resource with Terraform and configure remote state. Run:

```bash
terraform plan
terraform apply
terraform state list
```

Then make a controlled change outside Terraform and run another plan to observe drift (drift means the real infrastructure no longer matches what the code describes).

---

## Part 10 — Bicep Deployment Architecture

Bicep is Azure's declarative infrastructure language and compiles to ARM templates. Unlike Terraform, Bicep does not maintain a Terraform-style state file. Azure Resource Manager is the control plane responsible for managing the resources.

A simple Bicep architecture is:

```text
parameters
    |
    v
main.bicep
    |
    +--> network.bicep
    +--> storage.bicep
    +--> compute.bicep
    |
    v
Azure Resource Manager
    |
    v
Azure Resources
```

Example:

```bicep
param location string = resourceGroup().location
param storageName string

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}
```

Before deployment, `what-if` is particularly useful because it shows the expected changes to Azure resources.

Example:

```bash
az deployment group what-if \
  --resource-group rg-app-dev \
  --template-file main.bicep \
  --parameters storageName=stappdev123
```

Then deploy:

```bash
az deployment group create \
  --resource-group rg-app-dev \
  --template-file main.bicep \
  --parameters storageName=stappdev123
```

The important comparison is:

```text
Terraform:
configuration + state + provider

Bicep:
configuration + Azure Resource Manager
```

Both can support infrastructure-as-code workflows, but their operational models differ.

Practice:

Create a Bicep template for a storage account, run `what-if`, review the changes, and deploy it only after understanding the expected result.

---

## Part 11 — Infrastructure Validation and Policy Gates

Treat infrastructure code as production code. A Terraform or Bicep change should pass validation and security/governance checks before it reaches production.

A Terraform pipeline might look like:

```text
Pull Request
   |
   +--> terraform fmt -check
   +--> terraform validate
   +--> security scan
   +--> terraform plan
   |
   v
Review
   |
   v
Production approval
   |
   v
terraform apply
```

Example pipeline steps:

```yaml
steps:
- script: terraform init
  displayName: Terraform Init

- script: terraform fmt -check -recursive
  displayName: Terraform Format Check

- script: terraform validate
  displayName: Terraform Validate

- script: terraform plan -out=tfplan
  displayName: Terraform Plan
```

The pipeline can then publish the plan as an artifact for review.

For Bicep, equivalent checks might include:

```bash
az bicep build --file main.bicep
az deployment group what-if \
  --resource-group rg-app-dev \
  --template-file main.bicep
```

Policy should also exist above individual pipelines. Azure Policy can enforce organizational requirements such as allowed regions, required tags, or restricted resource configurations.

This creates multiple layers:

```text
Developer controls
       ↓
Pipeline validation
       ↓
IaC security checks
       ↓
Azure Policy
       ↓
RBAC
       ↓
Azure Resource Manager
```

A Senior/Lead should avoid relying on only one control. A developer mistake, malicious change, and operational error are different failure modes and may require different controls.

Practice:

Create a rule such as:

```text
Production resources must have:
Environment=Production
Owner=<team>
CostCenter=<value>
```

Then think about where to enforce it: code convention, pipeline validation, Azure Policy, or a combination.

---

## Part 12 — Azure Container Registry and Image Promotion

Azure Container Registry stores container images used by Azure services such as AKS and Container Apps. A secure container delivery architecture separates building an image from deploying it.

Typical flow:

```text
Azure Repos
    |
    v
Pipeline
    |
    v
Docker Build
    |
    v
Security Scan
    |
    v
ACR
    |
    v
Deploy
```

Build example:

```bash
docker build -t shopsphere:1.0.0 .
docker tag shopsphere:1.0.0 <acr-name>.azurecr.io/shopsphere:1.0.0
docker push <acr-name>.azurecr.io/shopsphere:1.0.0
```

A more reliable production identity is the image digest:

```bash
docker inspect <acr-name>.azurecr.io/shopsphere:1.0.0
```

The deployment can reference a digest such as:

```text
<acr-name>.azurecr.io/shopsphere@sha256:<digest>
```

This ensures the deployment points to a specific image content rather than depending on a mutable tag.

A useful promotion model is:

```text
Build once
   ↓
Scan
   ↓
Store
   ↓
Deploy Dev
   ↓
Validate
   ↓
Deploy UAT
   ↓
Validate
   ↓
Deploy Production
```

Do not rebuild the image for each environment.

Practice:

Build one image, push it to ACR, and deploy it to Dev. Then identify the exact digest that you deployed. Use that same image identity for UAT and Production.

---

## Part 13 — Deployment Targets: App Service, Container Apps and AKS

Azure DevOps can deploy the same application concept to very different Azure compute platforms. The pipeline design should reflect the deployment model rather than treating every target as equivalent.

For App Service, the pipeline may deploy application packages or supported containerized web applications.

For Container Apps, the pipeline commonly updates a container image and configuration.

For AKS, the pipeline may deploy Kubernetes manifests or Helm charts.

The common pattern is:

```text
Artifact
   |
   +--> App Service
   |
   +--> Container Apps
   |
   +--> AKS
```

But the deployment operation differs.

Container Apps might conceptually use:

```bash
az containerapp update \
  --name myapp \
  --resource-group rg-app-prod \
  --image <acr-name>.azurecr.io/myapp:1.0.0
```

AKS might use:

```bash
kubectl set image deployment/myapp \
  myapp=<acr-name>.azurecr.io/myapp:1.0.0
```

Or Helm:

```bash
helm upgrade --install myapp ./chart \
  --set image.repository=<acr-name>.azurecr.io/myapp \
  --set image.tag=1.0.0
```

The Senior/Lead question is not “Which command do I know?” It is:

> “What deployment model does this platform support, what is the safest release mechanism, and where should configuration and identity be controlled?”

Practice:

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

---

## Part 14 — Secure Production Deployment Architecture

A production pipeline should not simply be:

```text
git push → production
```

A stronger architecture separates build trust from deployment trust.

A practical model is:

```text
Developer
   |
   v
Pull Request
   |
   +--> Review
   +--> Unit Tests
   +--> SAST/SCA
   |
   v
Main
   |
   v
Build
   |
   +--> Container Scan
   +--> Artifact
   |
   v
ACR
   |
   v
Dev
   |
   v
UAT
   |
   +--> Tests
   +--> Approval/Checks
   |
   v
Production
   |
   +--> Health Check
   +--> Smoke Test
   +--> Monitoring
```

SAST and SCA are the scans from Day 19: SAST examines your own source code for coding weaknesses, while SCA examines your third-party dependencies for known vulnerabilities.

Identity should also be separated:

```text
Build identity
   → build/push artifact

Deployment identity
   → modify target environment

Runtime identity
   → access application dependencies
```

This prevents one compromised identity from automatically having access to every layer.

For production, consider:

- Protected main branch
- PR review
- Security checks
- Immutable artifact identity
- Restricted production service connection
- Environment approvals/checks
- Secret retrieval from Key Vault
- Deployment health checks
- Rollback/fix-forward strategy
- Audit trail

Practice:

Take your ShopSphere capstone and design the complete Production deployment path from PR to running Pods/containers. For every arrow, ask:

```text
Who is trusted here?
What identity is used?
What is being verified?
What can fail?
What is the rollback mechanism?
```

---

## Part 15 — Artifact Traceability

One of the strongest indicators of mature DevOps is the ability to trace a production deployment back to source code and build information.

You should be able to answer:

```text
What is running?
        ↓
Which image/artifact?
        ↓
Which build?
        ↓
Which Git commit?
        ↓
Which PR?
        ↓
Who approved it?
```

For a containerized application:

```text
Production Pod
    ↓
Image digest
    ↓
ACR image
    ↓
Build ID
    ↓
Git SHA
    ↓
Pull Request
```

This becomes extremely useful during incidents.

Suppose production suddenly reports errors. Instead of asking:

> “Who deployed something recently?”

you should be able to determine:

```text
Running image digest
→ build 1842
→ Git SHA abc123
→ PR #417
→ deployment at 21:42
```

Implementation example — expose a build identifier in an application:

```text
APP_VERSION=1.4.2
GIT_COMMIT=abc123
BUILD_ID=1842
```

The application can expose non-sensitive build metadata through a health/info endpoint.

Do not expose secrets or sensitive pipeline information through such endpoints.

Practice:

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

---

## Part 16 — Pipeline Security and Supply Chain

The pipeline itself is part of the software supply chain. If an attacker can modify the pipeline, they may be able to alter what gets built or deployed even if the application source looks legitimate.

Important controls include:

```text
Source protection
      ↓
Pipeline YAML protection
      ↓
Dependency security
      ↓
Build agent security
      ↓
Artifact security
      ↓
Registry access control
      ↓
Deployment identity
```

Give pipeline identities only the permissions they require. Do not give build agents permanent access to production. Do not print secrets into logs.

A common dangerous pattern is:

```yaml
- script: |
    echo $(DB_PASSWORD)
```

Even if the platform masks some secret values, deliberately printing secrets is bad practice.

Another risk is allowing untrusted pull-request code to execute with highly privileged credentials. A pipeline that runs arbitrary code from a contributor-controlled branch should not automatically receive production-level credentials.

Senior/Lead thinking requires considering **where untrusted code executes and what identity it receives**.

Practice:

Take a pipeline that has:

```text
PR code
+
Azure subscription Contributor identity
```

Ask whether that is safe. Then redesign it so untrusted validation has minimal permissions and production credentials are available only to the controlled deployment stage.

---

## Part 17 — Troubleshooting Azure DevOps and IaC Pipelines

Pipeline troubleshooting should follow the same layered reasoning used for application and network troubleshooting.

Start with:

```text
Trigger
  ↓
Source
  ↓
Agent
  ↓
Authentication
  ↓
Tooling
  ↓
Build
  ↓
Artifact
  ↓
Deployment
  ↓
Runtime
```

If a pipeline never starts, investigate:

```text
Trigger
→ branch/path filters
→ pipeline permissions
→ YAML syntax
```

If the pipeline starts but cannot access Azure:

```text
Service connection
→ identity
→ federation/token
→ RBAC
→ subscription/resource scope
```

If Terraform fails:

```text
Provider
→ authentication
→ backend/state
→ configuration
→ dependency
→ plan
→ Azure API
```

If deployment succeeds but the application is unavailable:

```text
Deployment result
→ resource state
→ configuration
→ identity
→ networking
→ application logs
→ health probes
```

Useful commands include:

```bash
az account show
az group show --name <rg>
az resource list --resource-group <rg>
terraform state list
terraform plan
kubectl get pods
kubectl describe pod <pod>
kubectl logs <pod>
```

For an Azure DevOps failure, do not immediately rerun the pipeline. First identify the failing layer and determine whether the failure is deterministic or transient.

Practice:

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

---

## Part 18 — Senior/Lead Enterprise Architecture Exercise

Imagine an enterprise with 50 application teams. Each team owns its application code, while a central platform team owns shared delivery standards, security guardrails, and cloud platform patterns.

Design this structure:

```text
Azure DevOps Organization
        |
        +-----------------------+
        |                       |
   Application Repos       Infrastructure Repos
        |                       |
        v                       v
 Application Pipelines     IaC Pipelines
        |                       |
        v                       v
     Artifacts             Terraform/Bicep
        |                       |
        v                       v
     ACR / Artifacts        Azure Resources
        |
        v
 Dev → UAT → Prod
```

Then define centralized standards:

```text
Identity:
federated service connections

Secrets:
Azure Key Vault

Source:
protected main + PR

Security:
SAST/SCA/image scanning

Artifacts:
build once, promote

Infrastructure:
Terraform/Bicep validation + plan/what-if

Production:
environment approvals/checks

Governance:
Azure Policy + RBAC

Observability:
Azure Monitor / application telemetry
```

The architectural challenge is deciding what the platform team should standardize and what application teams should own.

For example:

```text
Platform team:
approved pipeline templates
security gates
service connection patterns
Key Vault patterns
ACR standards
IaC modules
governance

Application team:
application code
unit/integration tests
application-specific pipeline configuration
deployment configuration
runtime behavior
```

There should be a clear ownership boundary rather than a central team becoming responsible for every application detail.

Practice:

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

---

## Part 19 — Azure ↔ AWS Mapping

The underlying DevOps concepts are mostly cloud-independent. Azure and AWS mainly provide different implementations.

| Concept | Azure | AWS |
|---|---|---|
| Source control | Azure Repos | CodeCommit / GitHub / GitLab |
| CI/CD | Azure Pipelines | CodePipeline / CodeBuild / GitHub Actions |
| Identity | Microsoft Entra ID | IAM |
| Pipeline federation | Workload identity federation | OIDC / IAM roles |
| Container registry | Azure Container Registry | Amazon ECR |
| Secrets | Azure Key Vault | Secrets Manager / Parameter Store |
| IaC | Terraform / Bicep | Terraform / CloudFormation / CDK |
| Terraform backend | Azure Storage | S3 + locking mechanism |
| Kubernetes | AKS | EKS |
| App platform | App Service / Container Apps | Elastic Beanstalk / ECS / Fargate |
| Serverless | Azure Functions | Lambda |
| Policy | Azure Policy | AWS Organizations SCP / IAM / Config |
| Monitoring | Azure Monitor | CloudWatch |
| Load balancing | Azure Load Balancer / Application Gateway | ELB family |

The important interview skill is to explain the **underlying capability first** and then map it to the cloud.

For example:

> “I need centralized object storage for Terraform remote state with controlled access and concurrency protection.”

Then:

```text
Azure → Azure Storage backend
AWS   → S3-based backend
```

This is stronger than memorizing service names without understanding the problem being solved.

---

## Part 20 — Practice: Build a Complete Azure DevOps + IaC Lab

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

---

## Part 21 — 5-Minute Recall

Without looking at the notes, explain these in your own words:

1. What responsibilities does Azure DevOps cover?
2. Why should `main` normally be protected?
3. What is the difference between source code and an artifact?
4. Why should an artifact be built once and promoted?
5. What is a service connection?
6. Why is workload identity federation preferable to long-lived pipeline secrets?
7. What is the difference between authentication and authorization?
8. Why should Production have stronger controls than Dev?
9. What problem do YAML templates solve?
10. Why separate application and infrastructure pipelines?
11. Why does Terraform need state?
12. Why should Terraform state be remote in a team environment?
13. What does `terraform plan` provide?
14. What does Bicep `what-if` provide?
15. What is the role of ACR?
16. Why is an image digest useful?
17. Why should secrets live in Key Vault rather than Dockerfiles?
18. What is artifact traceability?
19. What happens if a pipeline identity is compromised?
20. How would you troubleshoot a pipeline that succeeds but the application returns 503?

The most important Senior/Lead answer pattern is:

**Design → Secure → Automate → Verify → Observe → Recover → Govern**

If you can explain why each stage exists and what can go wrong, you are thinking beyond individual Azure DevOps features.

---

## Part 22 — Cleanup

Delete only the resources created specifically for this lab.

For Terraform-managed infrastructure:

```bash
terraform destroy
```

For a Bicep deployment, remove the resources created by the lab according to the deployment scope and ownership model.

For Azure resources created manually:

```bash
az group delete \
  --name <RESOURCE-GROUP> \
  --yes
```

Be careful with shared resources such as:

```text
shared ACR
shared Key Vault
shared Terraform state
shared networking
```

Do not delete shared enterprise resources simply because they were involved in the lab.

After cleanup, verify:

```bash
az group show --name <RESOURCE-GROUP>
az resource list --resource-group <RESOURCE-GROUP>
```

If the resource group was intentionally deleted, confirm that it no longer exists.

**Final mental model for Day 25:**

```text
Source
  ↓
PR + Review
  ↓
Build + Test + Security
  ↓
Artifact / Image
  ↓
ACR / Artifact Store
  ↓
Dev
  ↓
UAT
  ↓
Production Checks
  ↓
Production
  ↓
Health + Observability
```

And for infrastructure:

```text
IaC
  ↓
Validate
  ↓
Plan / What-if
  ↓
Review
  ↓
Approval
  ↓
Apply / Deploy
  ↓
Azure
  ↓
Policy + RBAC + Monitoring
```

The Senior/Lead mindset is to make the entire path **secure, repeatable, traceable, governed, and recoverable**.

## Answers to practice

### 1. Which system owns source, build, artifact, image, registry, deploy, infra, and secrets

<details>
<summary>Answer</summary>

Source lives in Azure Repos. Maven builds the JAR. Docker produces the image. ACR stores it. Container Apps or AKS run it. Terraform owns infrastructure. Key Vault owns secrets.

Keep source, artifact, environment, and infrastructure separate. A JAR is not a Git SHA. A deployment target is not Terraform state. Naming the owner of each step is the delivery architecture.

</details>

### 2. Feature branch, PR, and required pipeline checks before merge

<details>
<summary>Answer</summary>

Run `git checkout -b feature/add-health-check`, commit a harmless change, and `git push origin feature/add-health-check`. Open a PR into protected `main`. Confirm reviewers, build validation, and no direct pushes.

Record `git rev-parse HEAD`. That SHA must travel into the build ID, image tag, digest, and deployment. A tag such as `1.4.2` is friendly. The digest is the real image identity.

</details>

### 3. Pipeline stages Build, Security, Publish, Dev, UAT, Production — where approvals sit

<details>
<summary>Answer</summary>

Build, Security, and Publish run automatically on `main` after PR checks. Dev deploys automatically and runs a health check. UAT deploys the same artifact with tests. Production needs environment checks: UAT succeeded, `main` only, and a production-owner approval.

Put production governance on the Azure DevOps Environment, not only in YAML `condition`. If a developer can edit YAML and skip the approval, the control is not real.

</details>

### 4. InfraPipelineIdentity vs AppDeploymentIdentity and blast radius

<details>
<summary>Answer</summary>

InfraPipelineIdentity applies Terraform or Bicep at the platform resource groups. AppDeploymentIdentity only updates the app on Container Apps or AKS. Use federated service connections, not long-lived client secrets. Scope RBAC to the resource group, not subscription Owner.

If AppDeploymentIdentity is stolen, the attacker can change running apps in that scope, not create subscriptions or rewrite the hub network. That is the blast-radius test. Split build, deploy, and runtime identities.

</details>

### 5. Production environment: main, UAT succeeded, owner approval, same artifact

<details>
<summary>Answer</summary>

Bind the Prod stage to `environment: production`. Require branch `main`, a successful UAT stage, and a production-owner approval. Deploy the digest already running in UAT.

Ask whether a YAML edit can bypass the check. If yes, move the gate to environment checks and protected service connections. Pipeline logic is not the same as governance.

</details>

### 6. Variable groups VG-DEV, VG-UAT, VG-PROD plus Key Vault secrets

<details>
<summary>Answer</summary>

Put `DATABASE_HOST` and feature flags in `VG-DEV`, `VG-UAT`, and `VG-PROD`. Keep passwords and keys in Key Vault. The pipeline identity retrieves secrets at deploy time. The image stays the same.

Never commit `DB_PASSWORD` in YAML or `ENV DB_PASSWORD` in a Dockerfile. Configuration changes per environment. The artifact does not.

</details>

### 7. Reusable template for Java build, tests, and artifact publish

<details>
<summary>Answer</summary>

Create `templates/build.yml` with parameters such as `javaVersion`. It runs `mvn clean test package` and publishes the artifact. Two app repos include that template from `azure-pipelines.yml`.

Centralize security checks, artifact conventions, and identity patterns. Let teams keep app-specific tests. Copy-paste YAML across 50 repos cannot be patched consistently.

</details>

### 8. Map changes to shopsphere-app vs shopsphere-infra

<details>
<summary>Answer</summary>

`shopsphere-app`: Java, tests, Dockerfile, Helm or app YAML, application pipeline. `shopsphere-infra`: VNet, ACR, AKS or Container Apps, Key Vault, Terraform modules, infra pipeline.

A Java bugfix must not run `terraform apply`. An AKS node-pool change must not rebuild the JAR. Coordinate only when the app needs a new platform capability first.

</details>

### 9. Terraform remote state, then observe drift

<details>
<summary>Answer</summary>

Use an `azurerm` backend on a storage account, with keys such as `prod/platform.tfstate`. Run `terraform init`, `terraform plan`, `terraform apply`, and `terraform state list`. Change a tag in the portal. Run `terraform plan` again and read the drift.

Local state is unsafe in a team. Separate state per environment. State is a control mechanism, not a cache. Protect the storage account.

</details>

### 10. Bicep storage account: `what-if` then deploy

<details>
<summary>Answer</summary>

Write a storage account in Bicep. Run `az deployment group what-if` and read creates, deletes, and in-place changes. Deploy with `az deployment group create` only after the result matches intent.

Bicep has no Terraform-style state file. ARM is the control plane. `what-if` is the review artifact, like `terraform plan`.

</details>

### 11. Enforce Environment, Owner, and CostCenter tags

<details>
<summary>Answer</summary>

Use all three layers. Convention and `terraform validate` or a policy check in CI catch mistakes early. Azure Policy Audit then Deny at the Production management group stops non-compliant ARM creates. RBAC still limits who can apply.

One control is not enough. A pipeline skip, a portal click, and a malicious identity are different paths. Policy sits above YAML.

</details>

### 12. Build once, push to ACR, promote the same digest

<details>
<summary>Answer</summary>

`docker build`, scan, and `docker push` once. Record the digest with `docker inspect` or ACR. Deploy Dev as `<acr>/shopsphere@sha256:<digest>`. Promote that digest to UAT and Production.

Do not rebuild per environment. A mutable tag can move. The digest cannot. Trace Git SHA → build ID → tag → digest → deployment.

</details>

### 13. Same Spring Boot image to App Service, Container Apps, and AKS

<details>
<summary>Answer</summary>

App Service: deploy the container to the app; Azure owns the host; slots for rollback. Container Apps: `az containerapp update --image`; revisions and scale rules. AKS: `kubectl set image` or `helm upgrade`; rolling update and probes.

Networking, identity attachment, and operational ownership change. The image and “build once” rule do not. Ask what release mechanism the platform supports.

</details>

### 14. ShopSphere production path from PR to running Pods

<details>
<summary>Answer</summary>

PR on protected `main`: review, unit tests, SAST/SCA. Build identity builds, scans, and pushes the image. Dev then UAT run the digest. Production environment checks plus a deploy identity apply it to AKS. Runtime identity reads Key Vault. Health and smoke tests follow.

For every arrow name who is trusted, which identity, what is verified, what can fail, and how you roll back. `git push` is not a production path.

</details>

### 15. Deployment record: SHA, build, digest, approver, result

<details>
<summary>Answer</summary>

Record application, environment, Git SHA, build ID, image name, digest, deploy time, approver, and result. Expose non-secret `APP_VERSION`, `GIT_COMMIT`, and `BUILD_ID` on an info endpoint.

In an incident you should say digest → build 1842 → SHA `abc123` → PR #417 → 21:42. Do not ask “who deployed recently?” as the first step.

</details>

### 16. PR code plus subscription Contributor is not safe

<details>
<summary>Answer</summary>

Untrusted PR YAML or application code must not receive production credentials. Run PR validation with a low-privilege identity that cannot deploy. Give production Contributor, scoped tightly, only to the production deployment job after merge and checks.

Do not `echo $(DB_PASSWORD)`. Protect pipeline YAML. The pipeline is part of the supply chain. Split untrusted execution from privileged deployment.

</details>

### 17. Pipeline succeeded, application returns HTTP 503

<details>
<summary>Answer</summary>

Do not debug YAML first. Check the Azure resource, revision or Deployment, health probes, networking, application logs, and dependencies. Commands: `az resource list`, `kubectl get pods`, `kubectl describe pod`, `kubectl logs`.

The pipeline can be correct while the app is unhealthy. Walk trigger → source → agent → auth → build → artifact → deploy → runtime. Identify the failing layer before you rerun.

</details>

### 18. Enterprise Azure DevOps architecture for 50 teams — ten design questions

<details>
<summary>Answer</summary>

1. Teams deploy through a federated service connection with resource-group RBAC, never subscription Owner. 2. Promote the same image digest from UAT. 3. Secrets live in Key Vault. 4. Separate Terraform state keys per environment and workload. 5. Infra PRs require `fmt`, `validate`, plan/what-if, and approval. 6. Platform templates, required checks, Azure Policy, and ACR rules enforce security. 7. A stolen pipeline identity is limited by scope and cannot be build+deploy+runtime in one. 8. Pod digest → ACR → build ID → Git SHA. 9. Roll back the previous digest or Helm revision if schema allows. 10. App pipelines cannot run Terraform; infra pipelines cannot push app images.

Platform owns templates, identity patterns, modules, and governance. Teams own code, tests, and app config.

</details>

### 19. What responsibilities does Azure DevOps cover?

<details>
<summary>Answer</summary>

Repos, Pipelines, Artifacts, Boards, and deployment environments with checks. It is the delivery platform, not only YAML hosting.

Ask where each responsibility should live: source, artifact, environment, or infrastructure.

</details>

### 20. Why should `main` normally be protected?

<details>
<summary>Answer</summary>

So production artifacts come only from reviewed, tested commits. Require PRs, reviewers, and pipeline validation. Block direct pushes.

An unprotected `main` is an unsigned path into every environment that deploys from it.

</details>

### 21. Difference between source code and an artifact

<details>
<summary>Answer</summary>

Source is the Git commit. An artifact is the deployable output: JAR, image, or package.

You promote artifacts. You do not rebuild source in Production and hope it matches UAT.

</details>

### 22. Why build once and promote?

<details>
<summary>Answer</summary>

So Production runs the same bytes that passed UAT. A new Docker build per environment creates uncertainty.

Identity the image by digest and move that digest along Dev → UAT → Prod.

</details>

### 23. What is a service connection?

<details>
<summary>Answer</summary>

The Azure DevOps link that lets a pipeline call Azure or another system. It uses an identity, preferably federated.

Authentication (who the pipeline is) stays separate from Azure RBAC (what it may do).

</details>

### 24. Why prefer workload identity federation over long-lived secrets?

<details>
<summary>Answer</summary>

Federation issues short-lived tokens. You do not store and rotate a permanent client secret in Azure DevOps.

A leaked secret is standing access. A federated token expires.

</details>

### 25. Authentication vs authorization

<details>
<summary>Answer</summary>

Authentication proves identity. Authorization decides permitted actions.

A federated pipeline can authenticate and still fail RBAC at the resource group.

</details>

### 26. Why stronger Production controls than Dev?

<details>
<summary>Answer</summary>

Production blast radius includes customers and data. Use approvals, restricted identities, and the already-tested artifact.

Dev can deploy automatically so teams move fast. Prod must be auditable.

</details>

### 27. What problem do YAML templates solve?

<details>
<summary>Answer</summary>

They reuse build, security, and deploy steps so 50 teams do not copy 200-line pipelines.

Centralize guardrails. Leave application-specific tests with the team.

</details>

### 28. Why separate application and infrastructure pipelines?

<details>
<summary>Answer</summary>

App changes should not carry Terraform risk. Infra changes should not rebuild the JAR.

Do not make every app deploy run a full infrastructure apply.

</details>

### 29. Why does Terraform need state?

<details>
<summary>Answer</summary>

State maps configuration to real resources so plan and apply know what already exists.

Without state, Terraform cannot manage infrastructure safely.

</details>

### 30. Why remote state in a team environment?

<details>
<summary>Answer</summary>

So every engineer and pipeline uses one state copy with locking. Local files diverge.

Put state in Azure Storage, split by environment, and restrict who can read it.

</details>

### 31. What does `terraform plan` provide?

<details>
<summary>Answer</summary>

A preview of creates, changes, and destroys before apply. Save `-out=tfplan` and apply that plan in production.

Plan is the review artifact. Do not apply unreviewed.

</details>

### 32. What does Bicep `what-if` provide?

<details>
<summary>Answer</summary>

The expected ARM changes for a Bicep deployment, analogous to `terraform plan`.

Review `az deployment group what-if` before `az deployment group create`.

</details>

### 33. What is the role of ACR?

<details>
<summary>Answer</summary>

ACR stores container images that AKS, Container Apps, and App Service pull.

Control who can push and who can pull. Scan before promote.

</details>

### 34. Why is an image digest useful?

<details>
<summary>Answer</summary>

A digest identifies exact image bytes. A tag can move.

Production should pin `@sha256:...` so you know what is running.

</details>

### 35. Why secrets in Key Vault rather than Dockerfiles?

<details>
<summary>Answer</summary>

Images are copied, cached, and often readable. A baked password leaks everywhere that image goes.

Retrieve secrets at runtime with workload identity.

</details>

### 36. What is artifact traceability?

<details>
<summary>Answer</summary>

The chain from running workload to digest, build, Git SHA, PR, and approver.

It turns “who deployed?” into a record you can read during an incident.

</details>

### 37. What happens if a pipeline identity is compromised?

<details>
<summary>Answer</summary>

The attacker can do whatever that identity’s RBAC allows: push images, apply Terraform, or deploy Prod.

Narrow scope, split identities, and federation limit the blast radius. One super-role does not.

</details>

### 38. Troubleshoot a pipeline that succeeds but the app returns 503

<details>
<summary>Answer</summary>

Inspect the deployed resource, health probes, Pods or revisions, logs, networking, and dependencies. Skip YAML until runtime evidence says the deploy never happened.

Pipeline success means Azure DevOps finished steps. It does not mean users are healthy.

</details>

### 39. Build shopsphere-app and shopsphere-infra labs, then inject failures

<details>
<summary>Answer</summary>

Infra repo: RG, ACR, Container Apps or AKS, Key Vault, remote state. Pipeline: `terraform fmt`, `validate`, `plan`, approval, `apply`. App repo: Maven, tests, scan, Docker, push digest, Dev, UAT, Prod with a separate deploy identity.

Inject the eight failures (bad Terraform, missing RBAC, wrong secret, invalid image, wrong tag, bad config, failing health, manual drift). For each write Failure, Layer, Evidence, Root cause, Fix, Prevention. That is the Senior/Lead lab, not a YAML demo.

</details>
