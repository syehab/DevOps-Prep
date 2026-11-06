# Day 29 — Questions and answers

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Then answer each item below before you open the Answer block. After that, do the lab in [03-implementation.md](03-implementation.md).

Write your own answer first. Open the Answer block only after you try. Keep the original numbering.

---

## 1. Which component orchestrates the pipeline?

**Senior/Lead Architecture Exercise**

Design a production CI/CD platform for a Spring Boot application running on ECS Fargate.

The organization has separate AWS accounts for Dev, UAT, and Production. Developers use GitHub. Infrastructure is managed using Terraform. Container images are stored in ECR. Production deployments require approval. The application needs a private RDS database and secrets must never be stored in Git.

Answer this question in your own words.

Which component orchestrates the pipeline?

<details>
<summary>Answer</summary>

CodePipeline orchestrates stages and actions: source, CodeBuild, approval, and deploy. It does not compile the JAR.

Orchestration is a trust boundary. The pipeline role should not be the production administrator.

</details>

---

## 2. Where does the Docker image get built?

**Senior/Lead Architecture Exercise**

Continue the ECS Fargate Spring Boot CI/CD design from item 1.

Where does the Docker image get built?

<details>
<summary>Answer</summary>

CodeBuild runs `mvn` tests, `docker build`, and the push. GitHub holds source. CodePipeline only starts that action.

The build happens once. Later stages consume the image. They do not rebuild it.

</details>

---

## 3. Where is the image stored?

**Senior/Lead Architecture Exercise**

Continue the ECS Fargate Spring Boot CI/CD design from item 1.

Where is the image stored?

<details>
<summary>Answer</summary>

Amazon ECR stores the image. Record the digest, not only tag `1.8.4`.

A successful push is not a successful ECS deploy. ECS still has to start tasks.

</details>

---

## 4. Which identity pushes the image?

**Senior/Lead Architecture Exercise**

Continue the ECS Fargate Spring Boot CI/CD design from item 1.

Which identity pushes the image?

<details>
<summary>Answer</summary>

The CodeBuild role. It needs ECR push and log write. It must not update the Production ECS service.

If this identity is stolen, the attacker can poison images, not rewrite the hub network.

</details>

---

## 5. Which identity deploys ECS?

**Senior/Lead Architecture Exercise**

Continue the ECS Fargate Spring Boot CI/CD design from item 1.

Which identity deploys ECS?

<details>
<summary>Answer</summary>

A deployment role in the target account. It updates the ECS service or task definition. It cannot push unrelated images or read every secret.

Separate orchestrate, build, deploy, and runtime. That is the blast-radius test.

</details>

---

## 6. Which identity does the application use at runtime?

**Senior/Lead Architecture Exercise**

Continue the ECS Fargate Spring Boot CI/CD design from item 1.

Which identity does the application use at runtime?

<details>
<summary>Answer</summary>

The ECS task role. It may `secretsmanager:GetSecretValue` for named secrets and `s3:GetObject` if needed. It must not modify ECS or Terraform.

The app must not inherit pipeline permissions.

</details>

---

## 7. How does the pipeline reach the Production account?

**Senior/Lead Architecture Exercise**

Continue the ECS Fargate Spring Boot CI/CD design from item 1.

How does the pipeline reach the Production account?

<details>
<summary>Answer</summary>

The central pipeline assumes a Production deploy role through STS. The trust policy allows only the tooling account or OIDC subject. The role is narrowly scoped.

No standing Production access keys in GitHub or Azure DevOps.

</details>

---

## 8. Where are database credentials stored?

**Senior/Lead Architecture Exercise**

Continue the ECS Fargate Spring Boot CI/CD design from item 1.

Where are database credentials stored?

<details>
<summary>Answer</summary>

AWS Secrets Manager (or secure Parameter Store). The task role retrieves them at runtime. They never live in Git, Dockerfiles, or pipeline YAML.

If deploy succeeds but login fails, trace role → secret permission → secret id → value → network → database, not “reset the password” first.

</details>

---

## 9. How do you prove which Git commit is running?

**Senior/Lead Architecture Exercise**

Continue the ECS Fargate Spring Boot CI/CD design from item 1.

How do you prove which Git commit is running?

<details>
<summary>Answer</summary>

Running task → image digest → ECR → CodeBuild ID → Git SHA. Tags are human labels. Digests are content identity.

If you cannot walk that chain, traceability is missing.

</details>

---

## 10. How do you prevent a developer from directly modifying Production infrastructure?

**Senior/Lead Architecture Exercise**

Continue the ECS Fargate Spring Boot CI/CD design from item 1.

How do you prevent a developer from directly modifying Production infrastructure?

<details>
<summary>Answer</summary>

No human Administrator in Prod. Identity Center is read-only or break-glass. Infra changes go through Terraform PRs, plan, approval, and a deploy role.

IAM and account isolation beat a wiki rule.

</details>

---

## 11. What happens if new ECS tasks start but fail health checks?

**Senior/Lead Architecture Exercise**

Continue the ECS Fargate Spring Boot CI/CD design from item 1.

What happens if the new ECS tasks start but fail their health checks?

<details>
<summary>Answer</summary>

The ALB keeps sending traffic to healthy old tasks if the service deployment is configured to require health. Failed new tasks are replaced or the deploy stalls.

`RUNNING` is not healthy. Inspect target health, service events, and logs.

</details>

---

## 12. How would you roll back?

**Senior/Lead Architecture Exercise**

Continue the ECS Fargate Spring Boot CI/CD design from item 1.

How would you roll back?

<details>
<summary>Answer</summary>

Point the ECS service at the previous Task Definition revision (previous digest). For CodeDeploy blue/green, shift the listener back.

Rollback still needs a compatible RDS schema. Confirm health after the shift.

</details>

---

## 13. Investigate a deployment that succeeded but the application became unavailable

**Senior/Lead Architecture Exercise**

Continue the ECS Fargate Spring Boot CI/CD design from item 1.

How would you investigate a deployment that succeeded but the application became unavailable?

<details>
<summary>Answer</summary>

Do not debug YAML first. Check ALB target health, ECS events, task logs, secrets, RDS connectivity, and the digest that actually started.

Pipeline success means actions finished. Users healthy is a different question.

</details>

---

## 14. Where would Terraform state live?

**Senior/Lead Architecture Exercise**

Continue the ECS Fargate Spring Boot CI/CD design from item 1.

Where would Terraform state live?

<details>
<summary>Answer</summary>

An S3 backend with versioning, encryption, tight IAM, and `use_lockfile = true`. Separate keys such as `shopsphere/prod/network.tfstate`.

The state bucket is production infrastructure. Developers do not write it from laptops.

</details>

---

## 15. What happens if two Terraform runs modify the same state at once?

**Senior/Lead Architecture Exercise**

Continue the ECS Fargate Spring Boot CI/CD design from item 1.

What happens if two Terraform runs try to modify the same state simultaneously?

<details>
<summary>Answer</summary>

Without locking, concurrent applies corrupt state. With `use_lockfile = true`, the second run waits or fails until the lock releases.

Never share one state file across Dev and Prod.

</details>

---

## 16. What problem does CodePipeline solve?

**5-Minute Recall**

1. What problem does CodePipeline solve?

<details>
<summary>Answer</summary>

It orchestrates the release workflow: source, build, test, approval, and deploy stages.

It is not the build VM. CodeBuild executes commands.

</details>

---

## 17. What does CodeBuild actually execute?

**5-Minute Recall**

2. What does CodeBuild actually execute?

<details>
<summary>Answer</summary>

Managed build and test commands: compile, test, `docker build`, scan, and push.

IAM on the CodeBuild role decides what those commands can touch.

</details>

---

## 18. Where does ECR fit?

**5-Minute Recall**

3. Where does ECR fit?

<details>
<summary>Answer</summary>

ECR is the image registry between build and runtime. ECS and EKS pull from it.

Store once. Promote the digest.

</details>

---

## 19. Difference between an image, an ECS task, and an ECS service

**5-Minute Recall**

4. What is the difference between an image, an ECS task, and an ECS service?

<details>
<summary>Answer</summary>

The image is bytes in ECR. A task is a running copy of a Task Definition. A service keeps the desired task count and attaches the load balancer.

Pushing an image does not start tasks by itself.

</details>

---

## 20. Why should the application runtime role differ from the deployment role?

**5-Minute Recall**

5. Why should the application runtime role be different from the deployment role?

<details>
<summary>Answer</summary>

Deploy needs to update ECS. Runtime needs S3 or secrets for the business function. Combining them gives a stolen app credential power to redeploy Production.

Least privilege is separate identities.

</details>

---

## 21. How does cross-account deployment work?

**5-Minute Recall**

6. How does cross-account deployment work?

<details>
<summary>Answer</summary>

Tooling account pipeline assumes a role in Dev, UAT, or Prod via STS. Trust plus IAM plus SCP must all allow.

The central platform is not Production Administrator.

</details>

---

## 22. Why build once and promote the same artifact?

**5-Minute Recall**

7. Why build once and promote the same artifact?

<details>
<summary>Answer</summary>

A Production rebuild can differ from the UAT binary. Promote the digest that already passed tests.

Traceability requires one artifact identity.

</details>

---

## 23. Where should secrets live?

**5-Minute Recall**

8. Where should secrets live?

<details>
<summary>Answer</summary>

Secrets Manager or secure Parameter Store, retrieved by the task role.

Not Git, Dockerfiles, or YAML.

</details>

---

## 24. What does Terraform state provide?

**5-Minute Recall**

9. What does Terraform state provide?

<details>
<summary>Answer</summary>

The map from configuration to real resources so plan and apply are safe.

Remote S3 state is required in a team.

</details>

---

## 25. Why does Terraform need state locking?

**5-Minute Recall**

10. Why does Terraform need state locking?

<details>
<summary>Answer</summary>

So two applies cannot rewrite the same state together. Use S3 `use_lockfile = true`. DynamoDB locking is deprecated in current Terraform docs.

Locking protects the control mechanism.

</details>

---

## 26. Difference between Terraform, CloudFormation, and CDK

**5-Minute Recall**

11. What is the difference between Terraform, CloudFormation, and CDK?

<details>
<summary>Answer</summary>

Terraform: providers plus Terraform state, multi-cloud. CloudFormation: AWS-native stacks. CDK: code that synthesizes CloudFormation.

Choose from ecosystem, skills, and state model, not from a feature checklist alone.

</details>

---

## 27. How would you prove exactly what is running in Production?

**5-Minute Recall**

12. How would you prove exactly what is running in Production?

<details>
<summary>Answer</summary>

Read the running task’s image digest. Map it to ECR, the CodeBuild that pushed it, and the Git SHA. Include the pipeline execution and approver.

That chain is an operational capability.

</details>

---

## 28. What evidence would you collect after a failed deployment?

**5-Minute Recall**

13. What evidence would you collect after a failed deployment?

<details>
<summary>Answer</summary>

Failed stage and action, identity, CloudWatch/CodeBuild logs, ECS events, target health, CloudTrail API errors, image digest, and secret/network checks.

“ECS deployment failed” is a symptom. Name `AccessDenied`, bad digest, or failing `/health`.

</details>

---

## 29. What changes when Dev, UAT, and Production are separate AWS accounts?

**5-Minute Recall**

14. What changes when Dev, UAT, and Production are separate AWS accounts?

<details>
<summary>Answer</summary>

IAM, billing, quotas, and blast radius isolate. Pipelines assume per-account roles. State files split. Humans are not Prod admins by default.

Naming conventions in one account are weaker than account boundaries.

</details>

---

## 30. What problem does CodePipeline solve?

**Practice**

The important interview skill is to explain the underlying responsibility first and the product second.

For example, instead of saying “CodeBuild is AWS's Azure Pipelines equivalent,” say: **“CodeBuild provides managed build execution; CodePipeline provides release orchestration. In Azure DevOps, those responsibilities are commonly provided through Azure Pipelines.”**

What problem does CodePipeline solve? Answer by naming the responsibility first, then the product.

<details>
<summary>Answer</summary>

It coordinates the delivery workflow across stages. CodeBuild still runs the commands. ECR still stores images. ECS still runs tasks.

Say the responsibility first, then the product.

</details>

---

## 31. Draw ECS Fargate CI/CD for Spring Boot before answering the design questions

**Senior/Lead Architecture Exercise**

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

Design a production CI/CD platform for a Spring Boot application running on ECS Fargate. The organization has separate AWS accounts for Dev, UAT, and Production. Developers use GitHub. Infrastructure is managed using Terraform. Container images are stored in ECR. Production deployments require approval. The application needs a private RDS database and secrets must never be stored in Git.

<details>
<summary>Answer</summary>

GitHub → CodePipeline → CodeBuild (test, scan, image) → ECR digest → Dev ECS → UAT ECS → approval → Prod ECS Fargate behind an ALB → private RDS. Secrets Manager holds DB credentials. Terraform in a separate pipeline uses S3 state with locking. OIDC or STS assumes account roles.

Draw that path, then answer who is trusted on each arrow. That is Part 14.

</details>

---

## 32. Hands-on lab: manual ECR, CodeBuild, CodePipeline to ECS, then break and add Terraform

**Hands-On Practice**

Create a small AWS DevOps lab using a simple Spring Boot or equivalent application.

Start with a Git repository containing the application and a Dockerfile. Create an ECR repository and push an image manually first so you understand the image path before automating it. Then create a CodeBuild project that builds the application, runs tests, builds the Docker image, and publishes it to ECR.

Next, create a simple CodePipeline flow that retrieves the source, invokes CodeBuild, and deploys the application to an ECS service. Keep the first version intentionally simple. Your goal is to understand the complete movement of the artifact rather than creating a complicated enterprise pipeline on the first attempt. AWS provides an end-to-end ECS CodePipeline example using CodeBuild and ECR that can be used as a reference.

Then deliberately break one part of the system. Examples include removing the ECR permission from the CodeBuild role, changing the ECS image reference to an invalid image, removing access to a required secret, or causing the health check to fail. Do not immediately repair it. Identify the failing stage, collect evidence, identify the identity involved, find the permission or runtime problem, and then recover the system.

Finally, add Terraform for the infrastructure and move its state into an S3 backend with state locking. Treat the state bucket as production infrastructure: restrict access, enable versioning, and keep it separate from ordinary application data.

<details>
<summary>Answer</summary>

Push one image by hand so you know the path. Automate build/test/push in CodeBuild. Wire CodePipeline source → build → ECS. Then remove ECR permission, use a bad image, drop a secret, or fail health. Record stage, identity, evidence, and fix.

Add Terraform with an S3 backend, `use_lockfile = true`, versioning, and tight IAM. Treat the state bucket as production. Cleanup ECS, ALB, NAT, images, and IAM when done.

</details>
