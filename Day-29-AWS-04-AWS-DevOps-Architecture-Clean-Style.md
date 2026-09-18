# Day 29 — AWS Overlay 04: AWS DevOps Architecture

The goal of this day is not to memorize AWS developer-tool names. It is to understand how a production AWS delivery platform connects source code, build, security, artifacts, infrastructure, deployment, identity, environments, and operations.

---

## Part 1 — The AWS DevOps Mental Model

A production DevOps platform is a controlled path from a code change to a running workload. The basic flow is **Source → Validate → Build → Test → Secure → Package → Store → Promote → Deploy → Verify → Observe**. AWS provides services that can implement different parts of this flow: CodePipeline coordinates the workflow, CodeBuild performs managed builds and tests, ECR stores container images, CodeDeploy can perform deployments for supported compute targets, and CloudWatch/CloudTrail provide operational visibility and audit evidence. The important Senior/Lead idea is that these services are pieces of an architecture; a good design also defines identity, environment boundaries, approvals, rollback, secrets, artifact traceability, and failure handling. AWS documents CodePipeline as a workflow made from stages and actions, while CodeBuild provides managed build and test execution. [AWS CodePipeline](https://docs.aws.amazon.com/codepipeline/latest/userguide/pipelines.html) and [AWS CodeBuild](https://docs.aws.amazon.com/codebuild/latest/userguide/how-to-create-pipeline.html) are useful references.

A simple enterprise flow looks like:

```text
Developer
   ↓
Git repository
   ↓
Pipeline
   ↓
Build + Test + Security
   ↓
Artifact / Container Image
   ↓
Registry / Artifact Store
   ↓
Dev → UAT → Production
   ↓
Deployment
   ↓
Health Checks
   ↓
Monitoring + Audit
```

The senior question is not “Which AWS service do I use?” It is “What trust boundary, artifact, identity, approval, deployment mechanism, and recovery path should exist at each step?”

---

## Part 2 — AWS CI/CD Services

CodePipeline is the orchestration layer. It defines stages and actions and coordinates source, build, test, approval, and deployment activities. CodeBuild is the managed execution environment for compiling code, running tests, producing artifacts, and running custom build commands. CodeDeploy focuses on application deployment and supports deployment models such as in-place and blue/green for supported targets. In a container platform, you may use CodePipeline + CodeBuild + ECR + ECS/EKS deployment mechanisms rather than assuming CodeDeploy is required for every workload. AWS also provides integrations with external source providers such as GitHub, so the AWS DevOps model does not require your source repository to be hosted inside AWS. citeturn0search4turn0search6turn0search3

A useful mapping from the Azure DevOps model you already know is:

| DevOps responsibility | Azure-oriented example | AWS-oriented example |
|---|---|---|
| Source | Azure Repos | GitHub / CodeCommit |
| Pipeline orchestration | Azure Pipelines | CodePipeline |
| Build/test | Pipeline agent | CodeBuild |
| Container registry | ACR | ECR |
| Artifact storage | Pipeline/Artifacts | S3 / artifact stores |
| Deployment | Azure Pipelines | CodeDeploy / ECS / EKS deployment |
| Secrets | Key Vault | Secrets Manager / Parameter Store |
| Identity | Managed Identity / service connection | IAM Role / STS |
| Monitoring | Azure Monitor | CloudWatch |
| Audit | Activity Log | CloudTrail |
| IaC | Terraform / Bicep | Terraform / CloudFormation / CDK |

Do not memorize this as a list of equivalent products. The more useful mental model is **orchestration, execution, storage, deployment, identity, secrets, and observability**.

AWS CodeCommit deserves one current-status note: AWS announced that CodeCommit returned to general availability for new customers in November 2025 after the 2024 change, so it is again a valid AWS-native repository option. In an interview, however, the important architectural point is that CodePipeline can work with multiple source providers rather than being coupled to one Git service. citeturn0search7turn0search17

---

## Part 3 — Build Once, Promote the Same Artifact

A strong CI/CD architecture separates **building software** from **deploying software**. The build stage should compile and test a specific commit, run security checks, and create an immutable release artifact. That artifact is then promoted through Dev, UAT, and Production rather than rebuilding the application independently in each environment. Rebuilding for production creates a subtle traceability problem because the source may be the same while the resulting binary or image can differ because of dependency, compiler, base-image, or build-environment changes.

For a Spring Boot container application, the traceability chain should look like:

```text
Git commit SHA
   ↓
Build ID
   ↓
Container image
   ↓
ECR image digest
   ↓
Deployment revision
   ↓
Running ECS/EKS workload
```

The important operational question is: **Can I prove exactly which source commit is running in production?**

An image tag such as `1.8.4` is useful for humans, but a digest is the stronger content identity because it identifies the exact image contents. Your process should also prevent accidental overwriting of release references where appropriate.

---

## Part 4 — IAM Is Part of the Pipeline Architecture

Every pipeline action needs an identity. A common beginner mistake is to think of the pipeline as one identity with broad permissions. A production design separates responsibilities. For example, the pipeline orchestration role should not automatically have unrestricted production access, the build role should have only the permissions required to build and publish, and the deployment role should have only the permissions required to deploy the target workload.

A simplified model is:

```text
CodePipeline role
        ↓
   orchestrates
        ↓
CodeBuild role → ECR / logs / required build resources
        ↓
Deployment role → ECS / EKS / Lambda / supported target
        ↓
Runtime role → application resources
```

Notice the distinction between **pipeline identity** and **application runtime identity**. The application should not inherit the permissions needed by the deployment system. If the Spring Boot application only needs to read objects from one S3 bucket, its runtime role should not also be able to modify ECS services or production infrastructure.

For multi-account AWS environments, the pipeline can assume a role in the target account through AWS STS. This allows a central delivery platform to deploy into separate Dev, UAT, and Production accounts without giving the central identity permanent administrator permissions everywhere.

The Senior/Lead question is: **If this pipeline identity is compromised, what is the largest thing the attacker can change?**

---

## Part 5 — Secrets and Configuration

Secrets should not live in Git, Dockerfiles, pipeline YAML, or container images. AWS Secrets Manager is designed for sensitive secrets such as database credentials, API keys, and application secrets, while Systems Manager Parameter Store is useful for configuration parameters and can also hold secure parameters. The application should retrieve what it needs through an appropriate runtime identity rather than receiving a large collection of secrets unnecessarily.

Think about configuration in three layers:

```text
Code
  ↓
Environment configuration
  ↓
Secrets
```

For example, the Spring Boot application can remain identical across environments while the database endpoint, feature configuration, and credentials change according to the environment.

A useful failure scenario is: **the deployment succeeds, but the application cannot authenticate to the database.** Do not immediately change the password. Trace the chain: runtime role → secret permission → secret identifier → secret value/version → network connectivity → database authentication → application configuration.

---

## Part 6 — Container Delivery with ECR + ECS

For a containerized Spring Boot application, a common AWS flow is **Git → CodePipeline → CodeBuild → ECR → ECS**. CodeBuild builds the Docker image, authenticates to ECR, pushes the image, and produces the metadata required for deployment. ECS then updates the service so the desired task definition points to the new image. AWS provides an example of a CodePipeline-based ECS deployment using CodeBuild and ECR. citeturn0search9

The important distinction is between the image and the running service. ECR stores the image; ECS decides how many tasks should run and where they should run; the load balancer controls traffic; the task role controls what the application can access. A successful image push therefore does not mean a successful deployment. The new task may fail to start, fail its health check, fail to pull the image, fail to obtain secrets, or start successfully but return application errors.

A practical troubleshooting chain is:

```text
Pipeline
  ↓
Build
  ↓
ECR image
  ↓
Task definition
  ↓
ECS task
  ↓
Container startup
  ↓
Health check
  ↓
Load balancer
  ↓
Application
```

---

## Part 7 — Deployment Strategies in AWS

Deployment strategy determines how new software reaches users and how quickly you can recover when the release is bad. Rolling deployment replaces or updates capacity progressively, while blue/green runs old and new environments alongside each other and shifts traffic after validation. Canary-style approaches expose the new version to a controlled portion of traffic before broader rollout. The exact mechanics depend on the compute platform and deployment service, so first identify the runtime before choosing the deployment mechanism.

CodeDeploy explicitly supports in-place and blue/green deployment types for its EC2/On-Premises platform, and AWS also documents ECS blue/green deployments using CodePipeline and CodeDeploy. citeturn0search16turn0search15

The Senior/Lead question is not “Which strategy is best?” It is:

**What is the safest traffic transition for this workload, and how will I detect failure before increasing blast radius?**

Consider database compatibility as part of the deployment strategy. A perfectly implemented blue/green application deployment can still fail if the new application expects a database schema that the old application cannot tolerate.

---

## Part 8 — Terraform in AWS CI/CD

Terraform should be treated as another software delivery system rather than as a collection of commands run manually from a laptop. A production flow is typically:

```text
Terraform code
   ↓
fmt / validate
   ↓
security / policy checks
   ↓
terraform plan
   ↓
review / approval
   ↓
terraform apply
   ↓
verification
```

The Terraform state should be stored remotely so the team is not sharing local state files. The current Terraform S3 backend supports S3-based state locking with `use_lockfile = true`; DynamoDB-based locking is now deprecated in current Terraform documentation. S3 bucket versioning is strongly recommended for recovery from accidental state deletion or human error. citeturn0search0

A current backend example is:

```hcl
terraform {
  backend "s3" {
    bucket       = "company-terraform-state"
    key          = "shopsphere/prod/network.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
  }
}
```

The state bucket is highly sensitive because Terraform state can contain resource attributes and sensitive values. Therefore, protect it with tightly scoped IAM, encryption, versioning, logging, and environment separation. Production state should not be casually writable by every developer or every pipeline.

For a multi-account architecture, the pipeline can authenticate to a central tooling account and then assume a narrowly scoped Terraform role in the target account.

---

## Part 9 — Terraform vs CloudFormation vs CDK

Terraform, CloudFormation, and AWS CDK solve the same broad problem—provisioning infrastructure—but they use different models. Terraform is multi-cloud and maintains its own state model; CloudFormation is AWS-native and uses CloudFormation stacks as the management boundary; CDK lets you define infrastructure using programming languages and synthesizes it into CloudFormation templates. The decision is therefore partly about ecosystem, team skills, portability, governance, state management, and existing platform standards rather than simply which tool has more features.

For your learning path, Terraform remains particularly important because the underlying IaC concepts transfer across Azure and AWS. Learn CloudFormation and CDK enough to recognize their architecture and explain when an AWS-native organization might choose them.

The interview-level distinction to remember is:

```text
Terraform → provider + Terraform state
CloudFormation → AWS-native stack management
CDK → code → CloudFormation
```

---

## Part 10 — Multi-Account CI/CD Architecture

In a mature AWS organization, Dev, UAT, and Production are often separated into different AWS accounts rather than relying only on naming conventions or resource groups. This gives stronger isolation for permissions, billing, quotas, blast radius, and governance. A central tooling account can host shared CI/CD components while deployment roles exist in workload accounts.

A simplified architecture is:

```text
                 Tooling Account
                      │
               CI/CD Platform
                      │
          ┌───────────┼───────────┐
          ↓           ↓           ↓
       Dev Role    UAT Role    Prod Role
          ↓           ↓           ↓
      Dev Account  UAT Account  Prod Account
```

The key security boundary is the role assumption. The central pipeline does not need unrestricted access to all target accounts. Each target role should have only the permissions required for its workload and deployment scope.

This also creates a useful separation of duties: the team that manages the delivery platform does not automatically become an administrator of every production resource.

---

## Part 11 — Pipeline Governance and Production Controls

A production pipeline needs more than automated commands. It needs controls around who can change the pipeline, who can approve production deployment, what artifact is being deployed, what infrastructure change is being applied, and how the deployment can be stopped or reversed. CodePipeline supports stages and actions, including approval-style workflow controls, while IAM controls who can modify or execute the pipeline. citeturn0search4

A useful production release sequence is:

```text
Commit
 ↓
Build + Test
 ↓
Security validation
 ↓
Create artifact
 ↓
Deploy Dev
 ↓
Automated verification
 ↓
Promote UAT
 ↓
Approval / policy checks
 ↓
Promote Production
 ↓
Health verification
 ↓
Observe
```

Do not confuse an approval with a security control by itself. An approval only helps if the approver has meaningful evidence: test results, security results, change details, artifact identity, deployment risk, and rollback information.

---

## Part 12 — Observability and Audit

CI/CD itself must be observable. You should be able to answer: **Which commit triggered this pipeline? Which build produced the artifact? Who approved production? Which role performed the deployment? Which version is running? Did the application become unhealthy after the release?**

CloudWatch is used for operational monitoring and logs, while CloudTrail provides an audit trail of AWS API activity. Together with pipeline history, ECR metadata, deployment records, and application logs, they help reconstruct what happened during an incident.

Imagine a production incident begins two minutes after deployment. A Senior/Lead engineer should be able to move backward through evidence:

```text
Application error
   ↓
Deployment timestamp
   ↓
Running artifact/image
   ↓
Pipeline execution
   ↓
Build
   ↓
Commit
   ↓
Change
```

This is why traceability is an operational capability, not just a compliance requirement.

---

## Part 13 — Pipeline Failure Troubleshooting

When a pipeline fails, start by identifying the exact stage and action that failed. If the source stage fails, investigate repository access, credentials, webhook/event configuration, and source revision. If the build fails, inspect the CodeBuild logs, dependency access, build image, environment variables, and IAM permissions. If deployment fails, inspect the target service, deployment role, image access, networking, health checks, secrets, and runtime logs.

A useful troubleshooting sequence is:

```text
Which stage failed?
        ↓
Which action failed?
        ↓
What identity executed it?
        ↓
What resource was it trying to access?
        ↓
Was authorization allowed?
        ↓
Was the network path available?
        ↓
Did the target resource accept the change?
        ↓
Is the application actually healthy?
```

For example, “ECS deployment failed” is not a root cause. The real cause might be `AccessDenied`, an image pull failure, an invalid task definition, missing secrets, a failing health check, insufficient capacity, or an application startup exception.

---

## Part 14 — Senior/Lead Architecture Exercise

Design a production CI/CD platform for a Spring Boot application running on ECS Fargate.

The organization has separate AWS accounts for Dev, UAT, and Production. Developers use GitHub. Infrastructure is managed using Terraform. Container images are stored in ECR. Production deployments require approval. The application needs a private RDS database and secrets must never be stored in Git.

Draw the architecture yourself before reading the expected flow:

```text
GitHub
  ↓
CI/CD
  ↓
Build + Test + Security
  ↓
ECR
  ↓
Dev Account
  ↓
UAT Account
  ↓
Production Account
  ↓
ECS Fargate
  ↓
ALB
  ↓
Spring Boot
  ↓
RDS
```

Now answer these questions in your own words:

1. Which component orchestrates the pipeline?
2. Where does the Docker image get built?
3. Where is the image stored?
4. Which identity pushes the image?
5. Which identity deploys ECS?
6. Which identity does the application use at runtime?
7. How does the pipeline reach the Production account?
8. Where are database credentials stored?
9. How do you prove which Git commit is running?
10. How do you prevent a developer from directly modifying Production infrastructure?
11. What happens if the new ECS tasks start but fail their health checks?
12. How would you roll back?
13. How would you investigate a deployment that succeeded but the application became unavailable?
14. Where would Terraform state live?
15. What happens if two Terraform runs try to modify the same state simultaneously?

If you can answer these without memorizing service definitions, you are thinking at the right level.

---

## Part 15 — Hands-On Practice

Create a small AWS DevOps lab using a simple Spring Boot or equivalent application.

Start with a Git repository containing the application and a Dockerfile. Create an ECR repository and push an image manually first so you understand the image path before automating it. Then create a CodeBuild project that builds the application, runs tests, builds the Docker image, and publishes it to ECR.

Next, create a simple CodePipeline flow that retrieves the source, invokes CodeBuild, and deploys the application to an ECS service. Keep the first version intentionally simple. Your goal is to understand the complete movement of the artifact rather than creating a complicated enterprise pipeline on the first attempt. AWS provides an end-to-end ECS CodePipeline example using CodeBuild and ECR that can be used as a reference. citeturn0search9

Then deliberately break one part of the system. Examples include removing the ECR permission from the CodeBuild role, changing the ECS image reference to an invalid image, removing access to a required secret, or causing the health check to fail. Do not immediately repair it. Identify the failing stage, collect evidence, identify the identity involved, find the permission or runtime problem, and then recover the system.

Finally, add Terraform for the infrastructure and move its state into an S3 backend with state locking. Treat the state bucket as production infrastructure: restrict access, enable versioning, and keep it separate from ordinary application data. citeturn0search0

---

## Part 16 — AWS ↔ Azure DevOps Mapping

You should now be able to translate the architecture rather than memorize two unrelated cloud platforms.

A typical Azure architecture might be **GitHub/Azure Repos → Azure Pipelines → build/test → ACR → Container Apps/AKS → Key Vault → Azure Monitor**. The AWS version could be **GitHub/CodeCommit → CodePipeline → CodeBuild → ECR → ECS/EKS → Secrets Manager/Parameter Store → CloudWatch**. Terraform can sit above both because the infrastructure concepts—identity, network, compute, storage, state, environments, modules, policy, and deployment—remain broadly transferable.

The important interview skill is to explain the underlying responsibility first and the product second.

For example, instead of saying “CodeBuild is AWS's Azure Pipelines equivalent,” say: **“CodeBuild provides managed build execution; CodePipeline provides release orchestration. In Azure DevOps, those responsibilities are commonly provided through Azure Pipelines.”**

That answer demonstrates architecture understanding rather than product memorization.

---

## Part 17 — 5-Minute Recall

Without looking back, explain these ideas:

- What problem does CodePipeline solve?
- What does CodeBuild actually execute?
- Where does ECR fit?
- What is the difference between an image, an ECS task, and an ECS service?
- Why should the application runtime role be different from the deployment role?
- How does cross-account deployment work?
- Why build once and promote the same artifact?
- Where should secrets live?
- What does Terraform state provide?
- Why does Terraform need state locking?
- What is the difference between Terraform, CloudFormation, and CDK?
- How would you prove exactly what is running in Production?
- What evidence would you collect after a failed deployment?
- What changes when Dev, UAT, and Production are separate AWS accounts?

The final mental model is:

**Source creates a version → CI verifies it → Build produces an artifact → Registry stores it → IAM controls who can move it → Pipeline promotes it → Deployment changes runtime → Health checks validate it → Observability proves what happened → Terraform manages infrastructure → Governance limits the blast radius.**

---

## Part 18 — Cleanup

Delete the resources created during the lab when they are no longer needed. Pay particular attention to ECS services, load balancers, NAT Gateways, ECR images, CodeBuild projects, CodePipeline resources, CloudWatch log groups, and any temporary networking resources because some of these can generate charges even when the application itself is not receiving traffic.

If Terraform created the infrastructure, prefer Terraform-managed cleanup so the state remains consistent with the actual environment. For manually created resources, verify deletion in the AWS console or CLI rather than assuming that deleting the top-level application removed every dependent resource.

Before finishing, confirm:

```text
Lab resources deleted
ECR images removed
ECS service removed
Load balancer removed
NAT Gateway removed if created
CloudWatch logs reviewed/deleted where appropriate
Temporary IAM roles/policies removed
Terraform state preserved if intentionally retained
```

