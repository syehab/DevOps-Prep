# Day 25 — Azure Overlay 04: Azure DevOps + IaC Architecture

The goal of this day is to understand how Azure DevOps, Terraform, Bicep, Azure identity, artifacts, and Azure deployment targets fit together into one production delivery system. The important shift is from learning individual Azure DevOps features to designing a **secure, reusable, traceable delivery architecture**.

The core mental model for this day is:

**Source → Validate → Build → Secure → Package → Store → Promote → Deploy → Verify → Observe**

For infrastructure:

**Code → Validate → Plan/What-if → Approve → Apply/Deploy → Verify → Govern**

---

## Part 1 — Azure DevOps as a Delivery Platform

Azure DevOps is not simply a place where YAML pipelines are stored. It is a collection of capabilities that can support the software delivery lifecycle: Azure Repos for source control, Azure Pipelines for CI/CD, Azure Artifacts for packages, Boards for work tracking, and deployment environments/checks for controlled releases. From a Senior/Lead perspective, the important question is not “Which Azure DevOps feature does this?” but “Where should this responsibility live in the delivery architecture?”

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

The same basic model works whether the application is deployed to an Azure VM, App Service, Container Apps, or AKS. What changes is the final deployment mechanism.

A useful Senior/Lead distinction is **source, artifact, environment, and infrastructure**. Source answers “what code was changed?” Artifact answers “what exact software is deployable?” Environment answers “where is it running?” Infrastructure answers “what platform is required for it?” Keeping these concepts separate makes releases safer and easier to troubleshoot.

Implementation example — create a basic repository workflow:

```bash
git clone https://dev.azure.com/<organization>/<project>/_git/<repo>

git checkout -b feature/add-health-check

git add .
git commit -m "Add application health check"
git push origin feature/add-health-check
```

A Pull Request should normally be the controlled path into the protected main branch. Branch policies can require reviewers and successful pipeline checks before the change is merged.

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

Azure DevOps Environments provide a logical representation of deployment targets and can be used to control and record deployments. They are especially useful for production because they provide a governance boundary around deployment.

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

A Senior/Lead should also distinguish **pipeline logic from governance**. A YAML condition can control workflow logic, while environment checks can provide centralized controls that developers should not be able to bypass simply by changing application YAML.

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

Applications need configuration that changes between environments, such as database endpoints, API URLs, feature flags, and connection settings. The application artifact should normally remain unchanged while environment-specific configuration is injected during deployment or runtime.

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

Azure Pipelines supports YAML templates so common workflow logic can be reused.

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

Application delivery and infrastructure delivery are related but should not automatically be treated as the same change.

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

Azure Storage can be used as a remote backend for Terraform state.

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

Then make a controlled change outside Terraform and run another plan to observe drift.

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

Infrastructure code should be treated as production code. A Terraform or Bicep change should pass validation and security/governance checks before it reaches production.

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

The image should not be rebuilt for each environment.

Practice:

Build one image, push it to ACR, deploy it to Dev, then identify the exact digest that was deployed. Use that same image identity for UAT and Production.

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

Pipeline identities should have only the permissions they require. Build agents should not automatically have permanent access to production. Secrets should not be printed into logs.

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
