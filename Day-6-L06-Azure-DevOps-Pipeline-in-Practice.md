---
title: "Day 6 · L06 — Azure DevOps Pipeline in Practice"
description: "Build a simple multi-stage pipeline and understand how code becomes a deployable application."
---

# Day 6 · L06 · Azure DevOps Pipeline in Practice

> **Goal:** Turn the CI/CD ideas from the previous days into a simple Azure DevOps pipeline that builds, tests, creates an artifact and moves it through environments.

| | |
|---|---|
| ⏱️ Time | 60–75 min |
| 🎯 Level | Senior DevOps |
| ☁️ Cost | ₹0* |
| 🧪 Hands-on | Azure DevOps |

> *The lab is designed to use existing/free resources where possible. Azure DevOps usage and hosted-agent availability can depend on your account and organization.*

---

## 01 · What Are We Building? · 6 min

Today we move from the CI/CD diagram to a real pipeline. The pipeline will take code from a repository, build it, test it, create an artifact and then use that artifact for deployment.

```text
Azure Repos
    ↓
Build
    ↓
Test
    ↓
Artifact
    ↓
DEV
    ↓
UAT
    ↓
PROD
```

The important part is not memorizing YAML. First understand **what each stage is doing and why it exists**.

---

## 02 · Pipeline, Stage, Job & Step · 8 min

An Azure DevOps **pipeline is the complete automated process** that takes code through build, testing and deployment. A **stage** is a major part of that process, such as Build, Dev or Production deployment. Stages are useful because they give us clear points where work can be controlled, approved or stopped.

A **job** is a group of work that runs together on an agent. A **step** is one individual action inside a job, such as running `mvn test`, copying a file or publishing an artifact. A single stage can contain one or more jobs, and each job can contain many steps.

```text
Pipeline
  ↓
Stage
  ↓
Job
  ↓
Step
```

Think of the pipeline as the whole journey, stages as the major stops, jobs as groups of work at a stop and steps as the individual actions. You will see these terms often in Azure DevOps, so understanding this basic structure is more useful than memorizing YAML syntax.

> **Key idea:** First understand **what work is happening and in what order**. The YAML is just how we describe that work to Azure DevOps.

A very small example looks like this:

```yaml
stages:
- stage: Build
  jobs:
  - job: BuildApp
    steps:
    - script: mvn clean package
      displayName: Build application
```

Here, `stage` creates the major section, `job` groups the work, and `step` runs the Maven command.

---

## 03 · Trigger · 7 min

A **trigger decides when the pipeline should start**. A team might start CI when code is pushed to a branch, run checks when a Pull Request is opened, or allow a pipeline to be started manually for a controlled release.

A simple trigger might look like:

```yaml
trigger:
- main
```

This means a push to `main` can start the pipeline. In a real project, the team may use different rules for different branches. For example, feature branches might run build and test checks, while a change merged into `main` might start the full delivery pipeline.

The trigger is important because it connects **Git activity to automation**. Without a clear trigger, people may not know why a pipeline ran, why it did not run, or why a deployment started.

> **Senior thinking:** Always know **what event starts the pipeline and which branch or change caused that run**.

For example, this YAML starts the pipeline when code is pushed to `main`:

```yaml
trigger:
- main
```

You can also control Pull Request validation separately:

```yaml
pr:
- main
```

This means a Pull Request targeting `main` can also trigger pipeline checks.

---

## 04 · Build Stage · 9 min

The Build stage gets the source code and turns it into something the application can run. For a Spring Boot application, this normally means compiling the Java code, downloading required dependencies and creating a JAR file.

```text
Git commit
    ↓
Build
    ↓
myapp.jar
```

The build should normally happen in a clean pipeline environment rather than depending on files or settings left on a developer's machine. This makes the result more repeatable and helps the team reproduce the same build when investigating a problem.

For example, a Maven build might run:

```bash
mvn clean package
```

The output could be:

```text
target/myapp.jar
```

The build may also perform checks such as code quality or security scanning. Whether those checks happen inside the Build stage or in separate stages depends on the team's pipeline design.

> **Key idea:** The Build stage turns **source code into a known piece of software that can be tested and eventually deployed**.

A simplified Azure DevOps build job could look like:

```yaml
- stage: Build
  jobs:
  - job: BuildApp
    steps:
    - script: mvn clean package
      displayName: Build Spring Boot application
```

The command creates the JAR, which later steps can publish as the deployment artifact.

---

## 05 · Test Stage · 6 min

After building the application, the pipeline can run automated tests. A failed test should normally stop the pipeline because there is little value in deploying software that has already failed an important check.

For a Java application, this could be:

```bash
mvn test
```

The pipeline should also keep the test result visible so the team can understand what failed. Tests are a safety check, not a guarantee that the application can never fail in Production.

> **Senior thinking:** A pipeline should stop when an important check fails instead of hiding the failure and continuing.

For a Maven application, the test step can be added like this:

```yaml
- script: mvn test
  displayName: Run tests
```

If the command returns a failure, Azure DevOps normally marks the step and job as failed, preventing dependent stages from continuing.

---

## 06 · Publish the Artifact · 9 min

After the build and tests succeed, the pipeline can publish the JAR as an **artifact**. The artifact is the exact output that later deployment stages will use, so it becomes the hand-off point between the Build part of the pipeline and the Release part.

```text
Source
  ↓
Build
  ↓
Test
  ↓
myapp.jar
  ↓
Artifact
```

The artifact can be stored by Azure DevOps or another artifact store. It should have enough version information to identify what it contains. That version might be connected to the Git commit SHA, build number or application version.

For example:

```text
Commit: 8f3a91c
       ↓
Build
       ↓
myapp-8f3a91c.jar
       ↓
DEV → UAT → PROD
```

The deployment stages use this existing artifact instead of compiling the source code again. This gives you a clear path from **the exact code that changed → the build that processed it → the software that reached Production**.

> **Key idea:** **Build once, publish once, deploy the same artifact.**

A simple artifact publishing step can look like:

```yaml
- task: PublishPipelineArtifact@1
  inputs:
    targetPath: '$(Build.SourcesDirectory)/target/myapp.jar'
    artifact: 'myapp'
```

The later deployment stage can download this artifact instead of building the application again.

---

## 07 · Deploy to DEV · 8 min

The Dev deployment takes the artifact and places it into the Dev environment. The application may receive Dev-specific configuration such as the Dev database address, API endpoints, feature settings and secrets, while the application artifact itself remains unchanged.

```text
myapp-8f3a91c.jar
        ↓
       DEV
        ↓
Dev configuration
```

The exact deployment action depends on the platform. On a VM, the pipeline might copy the JAR and restart a systemd service. On Kubernetes, it might update a Deployment with a new container image. On Azure App Service, the pipeline sends the application package to the App Service platform.

After deployment, the pipeline should verify the result. A simple check might confirm that the process started, while a better check calls a health endpoint or performs a small real request.

> **Remember:** A successful deployment means the deployment action worked. It does not automatically mean the application is healthy.

A deployment stage can contain a deployment task followed by a simple health check:

```yaml
- stage: DeployDev
  jobs:
  - job: Deploy
    steps:
    - script: echo "Deploy myapp.jar to DEV"
    - script: curl -f https://dev.example.com/health
      displayName: Verify application
```

The `curl` command gives the pipeline evidence that the application actually responds after deployment.

---

## 08 · Promote to UAT & PROD · 9 min

Once Dev validation is complete, the same artifact can move to UAT. UAT gives the team a more controlled environment where the application can be checked with test data, expected business flows and settings that are closer to Production.

Production can then require an approval before deployment. The approval is a control point where an authorized person confirms that the release has passed the required checks and is allowed to move forward.

```text
Artifact
   ↓
DEV
   ↓
Validation
   ↓
UAT
   ↓
Approval
   ↓
PROD
```

The important part is that there is no second build between UAT and Production. The pipeline promotes the same known artifact, while each environment supplies its own configuration and resources.

This also makes rollback easier. If Production has a problem, you can identify the artifact that was deployed and select an earlier known-good artifact instead of trying to recreate an old build from memory.

> **Key idea:** The pipeline promotes a **known version**, rather than creating a new version at every environment.

A simplified stage structure could look like:

```yaml
- stage: DeployUAT
  dependsOn: DeployDev
  jobs:
  - job: UAT
    steps:
    - script: echo "Deploy existing artifact to UAT"

- stage: DeployProd
  dependsOn: DeployUAT
  jobs:
  - job: Production
    steps:
    - script: echo "Deploy existing artifact to PROD"
```

The real deployment tasks will depend on the target platform, but the idea is the same: later stages consume the artifact created earlier.

---

## 09 · Environment Variables & Secrets · 8 min

The same application can need different settings in different environments. Dev might use one database and UAT another, while Production uses the real database and stricter settings. These values should normally be supplied by the environment instead of being written directly into the source code.

For example, the application can use a variable such as `DATABASE_URL`, while Dev, UAT and Production each provide a different value. The application artifact stays the same; only the environment value changes.

Secrets need extra care because passwords, API keys and tokens should not be stored in Git or written directly into pipeline YAML. A secret store such as Azure Key Vault can keep these values protected and allow the application or pipeline to access them when needed.

> **Senior habit:** Keep **application code, environment configuration and secrets** as separate concerns. This makes the same artifact easier to promote safely.

For example, a pipeline can define a normal environment value without changing the application artifact:

```yaml
variables:
  APP_ENV: 'dev'

steps:
- script: echo "Deploying to $(APP_ENV)"
```

Sensitive values should not be written directly into YAML. They should come from a protected variable or secret store such as Azure Key Vault.

---

## 10 · Azure DevOps Library & Variable Groups · 10 min

When the same pipeline deploys to Dev, UAT and Production, it needs different values for each environment. Azure DevOps provides a **Library** where teams can keep shared pipeline values, and **Variable Groups** let you keep related variables together.

For example, you might create three groups: `VG-DEV`, `VG-UAT` and `VG-PROD`. Each group contains the values needed by that environment, while the application code and artifact stay the same.

```text
Library
 ├── VG-DEV
 ├── VG-UAT
 └── VG-PROD
```

> **Key idea:** Keep the **same pipeline and artifact**, but give each environment its own configuration.

---

## 11 · Different Variables for Different Environments · 8 min

An **environment variable is a value given to an application or pipeline at runtime**. It is useful when the same application needs different settings in different environments.

For example, the application can use the same variable name everywhere while the value changes:

```text
DEV  → DATABASE_URL = dev-db
UAT  → DATABASE_URL = uat-db
PROD → DATABASE_URL = prod-db
```

In Azure DevOps, each deployment stage can load the Variable Group belonging to that environment:

```yaml
- stage: DeployDev
  variables:
  - group: VG-DEV

- stage: DeployUAT
  variables:
  - group: VG-UAT

- stage: DeployProd
  variables:
  - group: VG-PROD
```

The pipeline YAML stays the same. The stage simply loads a different group, so the application receives the correct environment values.

> **Key idea:** **Same application + same pipeline + different environment values.**

---

## 12 · Normal Variables vs Secrets · 6 min

Not every environment value is sensitive. Values such as an environment name or a normal URL can usually be stored as ordinary pipeline variables.

Passwords, API keys, tokens and similar values need protection. They should not be written directly into Git or ordinary YAML; they should come from a protected variable or a secret store such as Azure Key Vault.

For example:

```yaml
variables:
  APP_ENV: 'dev'
  API_URL: 'https://dev-api.example.com'
```

A secret can be kept in a protected Variable Group or retrieved from Key Vault when the pipeline runs.

> **Simple rule:** Keep **normal configuration** and **secret values** separate.

---

## 13 · Azure DevOps Library · 5 min

The **Library** is an Azure DevOps area for storing reusable pipeline information. Variable Groups are one of the main things you manage there.

You can think of it simply as:

```text
Azure DevOps
   ↓
 Library
   ↓
Variable Groups
```

The Library helps prevent teams from repeating the same values across many pipeline YAML files. It is especially useful when several pipelines need shared settings or when each environment has its own set of values.

> **Simple mental model:** **Library = place for reusable pipeline configuration.**

---

## 14 · Azure Artifacts vs Pipeline Artifacts · 6 min

**Azure Artifacts** is a service for storing and sharing software packages such as Maven, npm and NuGet packages. A Java application might download an internal Maven package from Azure Artifacts during its build.

A **Pipeline Artifact** is different: it is normally the output of a pipeline run that later stages need to deploy. For example, your Build stage can create `myapp.jar` and publish it so the Dev, UAT and Production stages can all use that same file.

```text
Pipeline Artifact
Build → myapp.jar → DEV → UAT → PROD

Azure Artifacts
Application → Maven package → Build
```

> **Remember:** **Pipeline Artifact = output of this pipeline. Azure Artifacts = package storage and sharing service.**

---

## 15 · Azure DevOps Pipeline · 6 min

An **Azure DevOps Pipeline** is the automation that connects the whole process. It can get code, build it, test it, publish an artifact, load environment configuration and deploy the application.

The pipeline can therefore use different Variable Groups at different stages without creating three separate pipelines.

```text
                ONE PIPELINE
                     │
          ┌──────────┼──────────┐
          ↓          ↓          ↓
        DEV        UAT        PROD
          │          │          │
       VG-DEV      VG-UAT     VG-PROD
```

The pipeline stays the same, the artifact stays the same, and the configuration changes according to the target environment.

---

## 16 · Putting Environment Configuration Together · 10 min

Suppose your Spring Boot application needs these values:

```text
DATABASE_URL
API_URL
APP_ENV
```

You can create three Variable Groups in the Azure DevOps Library:

```text
VG-DEV
  DATABASE_URL = dev-db
  API_URL      = dev-api
  APP_ENV      = dev

VG-UAT
  DATABASE_URL = uat-db
  API_URL      = uat-api
  APP_ENV      = uat

VG-PROD
  DATABASE_URL = prod-db
  API_URL      = prod-api
  APP_ENV      = prod
```

The same pipeline can then use the correct group for each stage:

```yaml
stages:

- stage: DeployDev
  variables:
  - group: VG-DEV
  jobs:
  - job: Deploy
    steps:
    - script: echo "Deploying to $(APP_ENV)"

- stage: DeployUAT
  variables:
  - group: VG-UAT
  jobs:
  - job: Deploy
    steps:
    - script: echo "Deploying to $(APP_ENV)"

- stage: DeployProd
  variables:
  - group: VG-PROD
  jobs:
  - job: Deploy
    steps:
    - script: echo "Deploying to $(APP_ENV)"
```

Notice what did **not** change: the application code, artifact and pipeline structure remain the same. Only the variables loaded by each environment are different.

This gives you the central pattern:

```text
                 Same artifact
                      ↓
             ┌────────┼────────┐
             ↓        ↓        ↓
            DEV      UAT      PROD
             ↓        ↓        ↓
          VG-DEV   VG-UAT   VG-PROD
```

> **Core mental model:** **One application + one pipeline + one artifact + different environment configuration.**

---

## 17 · What Happens When Something Fails? · 7 min

Imagine the Build stage passes, the artifact is created and Dev deployment succeeds, but the application returns errors in Dev.

The pipeline should stop before automatically promoting the same version to UAT or Production. The team can inspect the logs, fix the problem and create a new commit.

```text
Build ✓
Test ✓
Artifact ✓
DEV deploy ✓
DEV test ✗
       ↓
      STOP
```

This is one of the main reasons for using stages. Each stage creates a controlled point where the software can be checked before moving forward.

---

## 18 · Mini Exercise · 10–15 min

Create a simple Azure DevOps YAML pipeline for a small Java application.

Start with this mental model:

```text
main
 ↓
Build
 ↓
Test
 ↓
Artifact
 ↓
DEV
 ↓
UAT
 ↓
PROD
```

Then identify what each stage needs to do.

**Build:** get the source and create the JAR.

**Test:** run automated tests.

**Artifact:** publish the JAR so later stages can use it.

**DEV:** deploy the artifact and verify the application.

**UAT:** deploy the same artifact and validate it.

**PROD:** deploy the same artifact after the required approval.

The goal is not to create a perfect enterprise pipeline today. The goal is to understand how the pieces connect.

---

## 19 · Break & Reason · 5 min

### Scenario

Your pipeline produced:

```text
Artifact: myapp-8f3a91c.jar
```

Dev is running it successfully.

UAT is also running it successfully.

Before Production, someone suggests:

> “Let's build the application again for Production.”

Ask yourself:

**What problem would rebuilding solve?**

If nothing about the source code needs to change, rebuilding creates another build output instead of promoting the already-tested artifact.

The cleaner flow is:

```text
Build once
   ↓
Test
   ↓
Artifact
   ↓
DEV → UAT → PROD
```

> **Senior thinking:** Keep the software version stable while environment configuration changes around it.

---

## 20 · Azure DevOps Mental Model · 5 min

At this point, you should be able to look at an Azure DevOps pipeline and recognize the major pieces without worrying about every YAML detail.

```text
Repository
    ↓
Trigger
    ↓
Build
    ↓
Test
    ↓
Artifact
    ↓
Deployment stages
    ↓
DEV → UAT → PROD
```

Approvals, security checks, quality checks and automated verification can be added around this basic flow.

The tool is Azure DevOps, but the underlying model is the same one you learned yesterday.

---

## 21 · Cost Check · 1 min

This lesson does not require Azure infrastructure such as VMs, databases or Kubernetes.

If your Azure DevOps organization already has the required pipeline/agent access, the lab can be completed without creating cloud infrastructure.

**Target cloud infrastructure cost:** ₹0

---

## 22 · Cleanup · <1 min

If you created only a pipeline and test repository, there is no cloud infrastructure to delete.

If you created temporary Azure resources for deployment testing, remove them after the exercise.

---

## 23 · Exit Check · 5 min

Answer without looking:

1. What is the difference between a pipeline, stage, job and step?
2. What starts the pipeline?
3. What does the Build stage produce?
4. Why do we publish an artifact?
5. Why should UAT and Production use the same artifact?
6. What is an Azure DevOps Variable Group?
7. What is the Azure DevOps Library?
8. How can one pipeline use different values for Dev, UAT and Prod?
9. Where should secrets come from?
10. What is the difference between a Pipeline Artifact and Azure Artifacts?
11. What should happen if Dev validation fails?
12. Why might Production require approval?
13. What is the difference between deploying an artifact and verifying an application?

### Exit criteria

You should be able to explain:

```text
Commit
  ↓
Pipeline trigger
  ↓
Build
  ↓
Test
  ↓
Artifact
  ↓
DEV
  ↓
UAT
  ↓
Approval
  ↓
PROD
```

and explain **what happens at each step and why it exists**.

> **Takeaway:** A good pipeline creates a controlled path where **one known version of the application is built, tested, packaged and safely promoted through environments**.

---

## Next

### Day 7 · L07 — Deployment Strategies

We'll learn how Production deployments can happen safely using:

**Rolling → Blue/Green → Canary → Rollback**
