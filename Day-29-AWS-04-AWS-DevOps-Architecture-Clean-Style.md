# Day 29 — AWS Overlay 04: AWS DevOps Architecture

The goal of this day is not to memorize AWS developer-tool names. It is to understand how a production AWS delivery platform connects source code, build, security, artifacts, infrastructure, deployment, identity, environments, and operations.

---

## Part 1 — The AWS DevOps Mental Model

A production DevOps platform is a controlled path from a code change to a running workload. The basic flow is **Source → Validate → Build → Test → Secure → Package → Store → Promote → Deploy → Verify → Observe**. AWS provides services for different parts of this flow. CodePipeline coordinates the workflow, CodeBuild runs managed builds and tests, and ECR stores container images. CodeDeploy can run deployments for supported compute targets, and CloudWatch/CloudTrail provide operational visibility and audit evidence. The important Senior/Lead idea is that these services are pieces of an architecture. A good design also defines identity, environment boundaries, approvals, rollback, secrets, artifact traceability, and failure handling. AWS documents CodePipeline as a workflow made from stages and actions, while CodeBuild provides managed build and test execution. [AWS CodePipeline](https://docs.aws.amazon.com/codepipeline/latest/userguide/pipelines.html) and [AWS CodeBuild](https://docs.aws.amazon.com/codebuild/latest/userguide/how-to-create-pipeline.html) are useful references.

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

CodePipeline is the orchestration layer. It defines stages and actions and coordinates source, build, test, approval, and deployment activities. CodeBuild is the managed execution environment for compiling code, running tests, producing artifacts, and running custom build commands. CodeDeploy focuses on application deployment and supports deployment models such as in-place and blue/green for supported targets. In a container platform, you may use CodePipeline + CodeBuild + ECR + ECS/EKS deployment mechanisms rather than assuming CodeDeploy is required for every workload. AWS also provides integrations with external source providers such as GitHub, so the AWS DevOps model does not require your source repository to be hosted inside AWS.

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

AWS CodeCommit deserves one current-status note: AWS announced that CodeCommit returned to general availability for new customers in November 2025 after the 2024 change. It is therefore again a valid AWS-native repository option. In an interview, however, the important architectural point is that CodePipeline can work with multiple source providers; it is not coupled to one Git service.

---

## Part 3 — Build Once, Promote the Same Artifact

A strong CI/CD architecture separates **building software** from **deploying software**. The build stage should compile and test a specific commit, run security checks, and create an immutable release artifact. The pipeline then promotes that artifact through Dev, UAT, and Production; it does not rebuild the application independently in each environment. A rebuild for production creates a subtle traceability problem. The source may be the same while the resulting binary or image differs, because of dependency, compiler, base-image, or build-environment changes.

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

Every pipeline action needs an identity. A common beginner mistake is to think of the pipeline as one identity with broad permissions. A production design separates responsibilities. For example, the pipeline orchestration role should not automatically have unrestricted production access. The build role should have only the permissions to build and publish. The deployment role should have only the permissions to deploy the target workload.

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

For multi-account AWS environments, the pipeline can assume a role in the target account through AWS STS (Security Token Service, the AWS service that issues short-lived credentials when an identity assumes a role). This allows a central delivery platform to deploy into separate Dev, UAT, and Production accounts without giving the central identity permanent administrator permissions everywhere.

The Senior/Lead question is: **If this pipeline identity is compromised, what is the largest thing the attacker can change?**

---

## Part 5 — Secrets and Configuration

Do not keep secrets in Git, Dockerfiles, pipeline YAML, or container images. AWS Secrets Manager serves sensitive secrets such as database credentials, API keys, and application secrets. Systems Manager Parameter Store is useful for configuration parameters and can also hold secure parameters. The application should retrieve what it needs through an appropriate runtime identity rather than receiving a large collection of secrets unnecessarily.

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

For a containerized Spring Boot application, a common AWS flow is **Git → CodePipeline → CodeBuild → ECR → ECS**. CodeBuild builds the Docker image, authenticates to ECR, pushes the image, and produces the metadata required for deployment. ECS then updates the service so the desired task definition points to the new image. AWS provides an example of a CodePipeline-based ECS deployment using CodeBuild and ECR.

The important distinction is between the image and the running service. ECR stores the image. ECS decides how many tasks should run and where. The load balancer controls traffic, and the task role controls what the application can access. A successful image push therefore does not mean a successful deployment. The new task may fail to start, fail its health check, fail to pull the image, fail to obtain secrets, or start successfully but return application errors.

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

CodeDeploy explicitly supports in-place and blue/green deployment types for its EC2/On-Premises platform, and AWS also documents ECS blue/green deployments using CodePipeline and CodeDeploy.

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

The Terraform state should be stored remotely so the team is not sharing local state files. The current Terraform S3 backend supports S3-based state locking with `use_lockfile = true`; DynamoDB-based locking is now deprecated in current Terraform documentation. S3 bucket versioning is strongly recommended for recovery from accidental state deletion or human error.

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

A mature AWS organization often separates Dev, UAT, and Production into different AWS accounts; it does not rely only on naming conventions or resource groups. This gives stronger isolation for permissions, billing, quotas, blast radius, and governance. A central tooling account can host shared CI/CD components while deployment roles exist in workload accounts.

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

A production pipeline needs more than automated commands. It needs controls around who can change the pipeline and who can approve production deployment. It also needs to know which artifact deploys, which infrastructure change applies, and how to stop or reverse the deployment. CodePipeline supports stages and actions, including approval-style workflow controls, while IAM controls who can modify or execute the pipeline.

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

Next, create a simple CodePipeline flow that retrieves the source, invokes CodeBuild, and deploys the application to an ECS service. Keep the first version intentionally simple. Your goal is to understand the complete movement of the artifact rather than creating a complicated enterprise pipeline on the first attempt. AWS provides an end-to-end ECS CodePipeline example using CodeBuild and ECR that can be used as a reference.

Then deliberately break one part of the system. Examples include removing the ECR permission from the CodeBuild role, changing the ECS image reference to an invalid image, removing access to a required secret, or causing the health check to fail. Do not immediately repair it. Identify the failing stage, collect evidence, identify the identity involved, find the permission or runtime problem, and then recover the system.

Finally, add Terraform for the infrastructure and move its state into an S3 backend with state locking. Treat the state bucket as production infrastructure: restrict access, enable versioning, and keep it separate from ordinary application data.

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

Delete the resources created during the lab when they are no longer needed. Pay particular attention to ECS services, load balancers, NAT Gateways, ECR images, CodeBuild projects, CodePipeline resources, CloudWatch log groups, and any temporary networking resources. Some of these generate charges even when the application itself receives no traffic.

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

## Answers to practice

### 1. Which component orchestrates the pipeline?

<details>
<summary>Answer</summary>

CodePipeline orchestrates stages and actions: source, CodeBuild, approval, and deploy. It does not compile the JAR.

Orchestration is a trust boundary. The pipeline role should not be the production administrator.

</details>

### 2. Where does the Docker image get built?

<details>
<summary>Answer</summary>

CodeBuild runs `mvn` tests, `docker build`, and the push. GitHub holds source. CodePipeline only starts that action.

The build happens once. Later stages consume the image. They do not rebuild it.

</details>

### 3. Where is the image stored?

<details>
<summary>Answer</summary>

Amazon ECR stores the image. Record the digest, not only tag `1.8.4`.

A successful push is not a successful ECS deploy. ECS still has to start tasks.

</details>

### 4. Which identity pushes the image?

<details>
<summary>Answer</summary>

The CodeBuild role. It needs ECR push and log write. It must not update the Production ECS service.

If this identity is stolen, the attacker can poison images, not rewrite the hub network.

</details>

### 5. Which identity deploys ECS?

<details>
<summary>Answer</summary>

A deployment role in the target account. It updates the ECS service or task definition. It cannot push unrelated images or read every secret.

Separate orchestrate, build, deploy, and runtime. That is the blast-radius test.

</details>

### 6. Which identity does the application use at runtime?

<details>
<summary>Answer</summary>

The ECS task role. It may `secretsmanager:GetSecretValue` for named secrets and `s3:GetObject` if needed. It must not modify ECS or Terraform.

The app must not inherit pipeline permissions.

</details>

### 7. How does the pipeline reach the Production account?

<details>
<summary>Answer</summary>

The central pipeline assumes a Production deploy role through STS. The trust policy allows only the tooling account or OIDC subject. The role is narrowly scoped.

No standing Production access keys in GitHub or Azure DevOps.

</details>

### 8. Where are database credentials stored?

<details>
<summary>Answer</summary>

AWS Secrets Manager (or secure Parameter Store). The task role retrieves them at runtime. They never live in Git, Dockerfiles, or pipeline YAML.

If deploy succeeds but login fails, trace role → secret permission → secret id → value → network → database, not “reset the password” first.

</details>

### 9. How do you prove which Git commit is running?

<details>
<summary>Answer</summary>

Running task → image digest → ECR → CodeBuild ID → Git SHA. Tags are human labels. Digests are content identity.

If you cannot walk that chain, traceability is missing.

</details>

### 10. How do you prevent a developer from directly modifying Production infrastructure?

<details>
<summary>Answer</summary>

No human Administrator in Prod. Identity Center is read-only or break-glass. Infra changes go through Terraform PRs, plan, approval, and a deploy role.

IAM and account isolation beat a wiki rule.

</details>

### 11. What happens if new ECS tasks start but fail health checks?

<details>
<summary>Answer</summary>

The ALB keeps sending traffic to healthy old tasks if the service deployment is configured to require health. Failed new tasks are replaced or the deploy stalls.

`RUNNING` is not healthy. Inspect target health, service events, and logs.

</details>

### 12. How would you roll back?

<details>
<summary>Answer</summary>

Point the ECS service at the previous Task Definition revision (previous digest). For CodeDeploy blue/green, shift the listener back.

Rollback still needs a compatible RDS schema. Confirm health after the shift.

</details>

### 13. Investigate a deployment that succeeded but the application became unavailable

<details>
<summary>Answer</summary>

Do not debug YAML first. Check ALB target health, ECS events, task logs, secrets, RDS connectivity, and the digest that actually started.

Pipeline success means actions finished. Users healthy is a different question.

</details>

### 14. Where would Terraform state live?

<details>
<summary>Answer</summary>

An S3 backend with versioning, encryption, tight IAM, and `use_lockfile = true`. Separate keys such as `shopsphere/prod/network.tfstate`.

The state bucket is production infrastructure. Developers do not write it from laptops.

</details>

### 15. What happens if two Terraform runs modify the same state at once?

<details>
<summary>Answer</summary>

Without locking, concurrent applies corrupt state. With `use_lockfile = true`, the second run waits or fails until the lock releases.

Never share one state file across Dev and Prod.

</details>

### 16. What problem does CodePipeline solve?

<details>
<summary>Answer</summary>

It orchestrates the release workflow: source, build, test, approval, and deploy stages.

It is not the build VM. CodeBuild executes commands.

</details>

### 17. What does CodeBuild actually execute?

<details>
<summary>Answer</summary>

Managed build and test commands: compile, test, `docker build`, scan, and push.

IAM on the CodeBuild role decides what those commands can touch.

</details>

### 18. Where does ECR fit?

<details>
<summary>Answer</summary>

ECR is the image registry between build and runtime. ECS and EKS pull from it.

Store once. Promote the digest.

</details>

### 19. Difference between an image, an ECS task, and an ECS service

<details>
<summary>Answer</summary>

The image is bytes in ECR. A task is a running copy of a Task Definition. A service keeps the desired task count and attaches the load balancer.

Pushing an image does not start tasks by itself.

</details>

### 20. Why should the application runtime role differ from the deployment role?

<details>
<summary>Answer</summary>

Deploy needs to update ECS. Runtime needs S3 or secrets for the business function. Combining them gives a stolen app credential power to redeploy Production.

Least privilege is separate identities.

</details>

### 21. How does cross-account deployment work?

<details>
<summary>Answer</summary>

Tooling account pipeline assumes a role in Dev, UAT, or Prod via STS. Trust plus IAM plus SCP must all allow.

The central platform is not Production Administrator.

</details>

### 22. Why build once and promote the same artifact?

<details>
<summary>Answer</summary>

A Production rebuild can differ from the UAT binary. Promote the digest that already passed tests.

Traceability requires one artifact identity.

</details>

### 23. Where should secrets live?

<details>
<summary>Answer</summary>

Secrets Manager or secure Parameter Store, retrieved by the task role.

Not Git, Dockerfiles, or YAML.

</details>

### 24. What does Terraform state provide?

<details>
<summary>Answer</summary>

The map from configuration to real resources so plan and apply are safe.

Remote S3 state is required in a team.

</details>

### 25. Why does Terraform need state locking?

<details>
<summary>Answer</summary>

So two applies cannot rewrite the same state together. Use S3 `use_lockfile = true`. DynamoDB locking is deprecated in current Terraform docs.

Locking protects the control mechanism.

</details>

### 26. Difference between Terraform, CloudFormation, and CDK

<details>
<summary>Answer</summary>

Terraform: providers plus Terraform state, multi-cloud. CloudFormation: AWS-native stacks. CDK: code that synthesizes CloudFormation.

Choose from ecosystem, skills, and state model, not from a feature checklist alone.

</details>

### 27. How would you prove exactly what is running in Production?

<details>
<summary>Answer</summary>

Read the running task’s image digest. Map it to ECR, the CodeBuild that pushed it, and the Git SHA. Include the pipeline execution and approver.

That chain is an operational capability.

</details>

### 28. What evidence would you collect after a failed deployment?

<details>
<summary>Answer</summary>

Failed stage and action, identity, CloudWatch/CodeBuild logs, ECS events, target health, CloudTrail API errors, image digest, and secret/network checks.

“ECS deployment failed” is a symptom. Name `AccessDenied`, bad digest, or failing `/health`.

</details>

### 29. What changes when Dev, UAT, and Production are separate AWS accounts?

<details>
<summary>Answer</summary>

IAM, billing, quotas, and blast radius isolate. Pipelines assume per-account roles. State files split. Humans are not Prod admins by default.

Naming conventions in one account are weaker than account boundaries.

</details>

### 30. What problem does CodePipeline solve?

<details>
<summary>Answer</summary>

It coordinates the delivery workflow across stages. CodeBuild still runs the commands. ECR still stores images. ECS still runs tasks.

Say the responsibility first, then the product.

</details>

### 31. Draw ECS Fargate CI/CD for Spring Boot before answering the design questions

<details>
<summary>Answer</summary>

GitHub → CodePipeline → CodeBuild (test, scan, image) → ECR digest → Dev ECS → UAT ECS → approval → Prod ECS Fargate behind an ALB → private RDS. Secrets Manager holds DB credentials. Terraform in a separate pipeline uses S3 state with locking. OIDC or STS assumes account roles.

Draw that path, then answer who is trusted on each arrow. That is Part 14.

</details>

### 32. Hands-on lab: manual ECR, CodeBuild, CodePipeline to ECS, then break and add Terraform

<details>
<summary>Answer</summary>

Push one image by hand so you know the path. Automate build/test/push in CodeBuild. Wire CodePipeline source → build → ECS. Then remove ECR permission, use a bad image, drop a secret, or fail health. Record stage, identity, evidence, and fix.

Add Terraform with an S3 backend, `use_lockfile = true`, versioning, and tight IAM. Treat the state bucket as production. Cleanup ECS, ALB, NAT, images, and IAM when done.

</details>
