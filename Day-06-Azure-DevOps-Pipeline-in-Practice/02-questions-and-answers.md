# Day 6 — Questions and answers

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Then answer each item below before you open the Answer block. After that, do the lab in [03-implementation.md](03-implementation.md).

Write your own answer first. Open the Answer block only after you try. Keep the original numbering.

---

## 1. What each pipeline stage does

# 18 · Mini Exercise · 10–15 min

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

<details>
<summary>Answer</summary>

The pipeline takes code from `main` and moves one known artifact through environments. Each stage has a job:

1. **Build:** Get the source and create the JAR, for example with `mvn clean package`.
2. **Test:** Run automated tests, for example with `mvn test`. Stop the pipeline if an important check fails.
3. **Artifact:** Publish the JAR so later stages can use it. Do not compile again.
4. **DEV:** Deploy that artifact, load Dev configuration, and verify the application.
5. **UAT:** Deploy the same artifact and validate it in a more controlled environment.
6. **PROD:** Deploy the same artifact after the required approval.

The goal is not a perfect enterprise pipeline. The goal is this path: build once, publish once, promote the same artifact.

</details>

---

## 2. Concise YAML sketch of the multi-stage pipeline

Create a simple Azure DevOps YAML pipeline for a small Java application.

<details>
<summary>Answer</summary>

This sketch uses only the Azure DevOps ideas from this Day: `trigger`, stages, jobs, steps, `mvn`, `PublishPipelineArtifact@1`, Variable Groups, `dependsOn`, and a health check.

```yaml
trigger:
- main

pr:
- main

stages:
- stage: Build
  jobs:
  - job: BuildApp
    steps:
    - script: mvn clean package
      displayName: Build Spring Boot application
    - task: PublishPipelineArtifact@1
      inputs:
        targetPath: '$(Build.SourcesDirectory)/target/myapp.jar'
        artifact: 'myapp'

- stage: Test
  dependsOn: Build
  jobs:
  - job: TestApp
    steps:
    - script: mvn test
      displayName: Run tests

- stage: DeployDev
  dependsOn: Test
  variables:
  - group: VG-DEV
  jobs:
  - job: Deploy
    steps:
    - script: echo "Deploy myapp.jar to DEV"
    - script: curl -f https://dev.example.com/health
      displayName: Verify application

- stage: DeployUAT
  dependsOn: DeployDev
  variables:
  - group: VG-UAT
  jobs:
  - job: Deploy
    steps:
    - script: echo "Deploy existing artifact to UAT"

- stage: DeployProd
  dependsOn: DeployUAT
  variables:
  - group: VG-PROD
  jobs:
  - job: Production
    steps:
    - script: echo "Deploy existing artifact to PROD"
```

Later stages consume the artifact created earlier. Each deploy stage loads a different Variable Group. Production still needs an approval before it runs. Keep secrets out of YAML. Take them from a protected variable or Azure Key Vault.

</details>

---

## 3. Whether you should rebuild the application for Production

# 19 · Break & Reason · 5 min

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

<details>
<summary>Answer</summary>

No. Rebuilding does not solve a real problem when the source did not change. Dev and UAT already run `myapp-8f3a91c.jar` successfully. A second build creates another output instead of promoting the already-tested artifact.

Keep the software version stable. Let environment configuration change around it. The clean flow is Build once → Test → Artifact → DEV → UAT → PROD.

</details>

---

# 23 · Exit Check · 5 min

Answer without looking:

## 4. Difference between a pipeline, stage, job, and step

1. What is the difference between a pipeline, stage, job and step?

<details>
<summary>Answer</summary>

A **pipeline** is the complete automated process that takes code through build, testing, and deployment. A **stage** is a major part of that process, such as Build or Production. Stages give you points where work can be controlled, approved, or stopped.

A **job** is a group of work that runs together on an agent. A **step** is one action inside a job, such as `mvn test` or publishing an artifact. Think: pipeline = the journey, stages = the major stops, jobs = groups of work, steps = individual actions.

</details>

---

## 5. What starts the pipeline

2. What starts the pipeline?

<details>
<summary>Answer</summary>

A **trigger** starts the pipeline. A push to `main` can start it with `trigger: - main`. A Pull Request targeting `main` can start checks with `pr: - main`. A team member can also start a pipeline manually for a controlled release.

Always know what event started the run and which branch or change caused it. Without a clear trigger, people cannot explain why a pipeline ran or why it did not.

</details>

---

## 6. What the Build stage produces

3. What does the Build stage produce?

<details>
<summary>Answer</summary>

The Build stage turns source code into a known piece of software. For Spring Boot, it compiles Java, downloads dependencies, and creates a JAR, for example `target/myapp.jar` from `mvn clean package`.

Run the build in a clean pipeline environment, not on leftover files from a developer machine. Later stages test and deploy that output. They do not treat raw source as the thing that goes to Production.

</details>

---

## 7. Why we publish an artifact

4. Why do we publish an artifact?

<details>
<summary>Answer</summary>

The artifact is the exact output that later deployment stages use. Publishing it is the hand-off between Build and Release. Dev, UAT, and Production then download that file instead of compiling the source again.

Give it version information from the Git commit SHA, build number, or application version, such as `myapp-8f3a91c.jar`. That path is: the code that changed → the build that processed it → the software that reached Production.

</details>

---

## 8. Why UAT and Production should use the same artifact

5. Why should UAT and Production use the same artifact?

<details>
<summary>Answer</summary>

UAT and Production should promote a known version, not create a new version at every environment. The same artifact means Production runs the software you already validated. Only configuration and resources change around it.

This also makes rollback easier. If Production has a problem, you can select an earlier known-good artifact. You do not recreate an old build from memory.

</details>

---

## 9. What an Azure DevOps Variable Group is

6. What is an Azure DevOps Variable Group?

<details>
<summary>Answer</summary>

A Variable Group keeps related pipeline variables together. You can create `VG-DEV`, `VG-UAT`, and `VG-PROD`. Each group holds the values that environment needs, such as `DATABASE_URL` and `APP_ENV`.

The application code and artifact stay the same. The stage loads the group for its environment. Keep secrets in a protected group or in Azure Key Vault, not in Git.

</details>

---

## 10. What the Azure DevOps Library is

7. What is the Azure DevOps Library?

<details>
<summary>Answer</summary>

The Library is the Azure DevOps area for reusable pipeline information. Variable Groups are one of the main things you manage there. The path is Azure DevOps → Library → Variable Groups.

The Library stops teams from repeating the same values across many YAML files. Use it when several pipelines need shared settings, or when each environment has its own set of values.

</details>

---

## 11. How one pipeline uses different values for Dev, UAT, and Prod

8. How can one pipeline use different values for Dev, UAT and Prod?

<details>
<summary>Answer</summary>

Keep one pipeline and one artifact. Let each deploy stage load a different Variable Group. `DeployDev` uses `VG-DEV`, `DeployUAT` uses `VG-UAT`, and `DeployProd` uses `VG-PROD`.

The YAML structure stays the same. The stage loads a different group, so the application receives the correct environment values. Same application + same pipeline + different environment values.

</details>

---

## 12. Where secrets should come from

9. Where should secrets come from?

<details>
<summary>Answer</summary>

Secrets should come from a protected variable or a secret store such as Azure Key Vault. Do not store passwords, API keys, or tokens in Git or in pipeline YAML. Anyone with read access could then see them.

Keep application code, environment configuration, and secrets as separate concerns. Ordinary values such as `APP_ENV` can be normal variables. Secret values must stay protected.

</details>

---

## 13. Difference between a Pipeline Artifact and Azure Artifacts

10. What is the difference between a Pipeline Artifact and Azure Artifacts?

<details>
<summary>Answer</summary>

A **Pipeline Artifact** is the output of a pipeline run that later stages deploy. For example, Build creates `myapp.jar` and Dev, UAT, and Production all use that same file.

**Azure Artifacts** is a service for storing and sharing packages such as Maven, npm, and NuGet. A Java build might download an internal Maven package from Azure Artifacts. Pipeline Artifact = output of this pipeline. Azure Artifacts = package storage and sharing service.

</details>

---

## 14. What should happen if Dev validation fails

11. What should happen if Dev validation fails?

<details>
<summary>Answer</summary>

The pipeline should stop. Do not automatically promote the same version to UAT or Production. Build, Test, Artifact, and even Dev deploy can succeed while a Dev test still fails.

Inspect the logs, fix the problem, and create a new commit. Stages exist so you can check the software before it moves forward.

</details>

---

## 15. Why Production might require approval

12. Why might Production require approval?

<details>
<summary>Answer</summary>

An approval is a control point before Production. An authorized person confirms that the release passed the required checks and may move forward. UAT can stay automated after Dev. Production often needs this extra gate.

The approval does not create a new build. After approval, the pipeline still deploys the same known artifact.

</details>

---

## 16. Difference between deploying an artifact and verifying an application

13. What is the difference between deploying an artifact and verifying an application?

<details>
<summary>Answer</summary>

Deploying an artifact means the pipeline placed the software in the environment. Verifying the application means you have evidence it actually works. A deploy task can succeed while the app is unhealthy.

After deploy, run a check such as `curl -f` against a health endpoint. A successful deployment means the deploy action worked. It does not automatically mean the application is healthy.

</details>

---

## 17. Difference between this application pipeline and an IaC plan-review-approve-apply pipeline

14. What is the difference between this application pipeline and an IaC plan-review-approve-apply pipeline?

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

<details>
<summary>Answer</summary>

This Day’s pipeline is the **application** path: Build → Test → Artifact → DEV → UAT → PROD. The thing you promote is a built application, such as a JAR. An **IaC** pipeline uses the same Azure DevOps stages and approvals, but the thing you promote is a reviewed Terraform or Bicep plan.

Keep those two stories separate in interviews. Do not mix “we shipped the same JAR” with “we applied the same module.” Application delivery changes the software. IaC delivery changes the platform.

</details>
