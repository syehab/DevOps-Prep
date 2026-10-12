---
title: "Day 4 · L04 — CI/CD Mental Model"
description: "Understand how code moves safely from a developer's machine to production."
---

# Day 4 — CI/CD Mental Model

This Day uses three files. Read them in this order.

1. [01-concepts.md](01-concepts.md) — lesson content (this file)
2. [02-questions-and-answers.md](02-questions-and-answers.md) — practice items, each with a model answer
3. [03-implementation.md](03-implementation.md) — hands-on lab

> **Goal:** Understand what CI/CD does, why each step exists, and how to reason about a failed deployment.

| | |
|---|---|
| ⏱️ Time | 45–60 min |
| 🎯 Level | Senior DevOps |
| ☁️ Cost | ₹0 |
| 🧪 Hands-on | Local Git repository |

---

## 01 · What Is CI/CD? · 7 min

**CI/CD is a way of building, testing and delivering software automatically.** Instead of a developer manually copying code to a server, a pipeline takes the code through a set of controlled steps.

```text
Code
 ↓
Build
 ↓
Test
 ↓
Package
 ↓
Deploy
 ↓
Verify
```

**CI (Continuous Integration)** brings code changes together and checks that they build and pass tests. **CD (Continuous Delivery/Deployment)** takes the tested software toward an environment where it can be released.

The exact tools can change — Azure DevOps, GitHub Actions, Jenkins or GitLab — but the basic flow stays similar.

> **Key idea:** CI/CD is not a tool. It is a **delivery process** that you build with tools.

---

## 02 · Code Commit & Commit SHA · 9 min

A **commit is a saved point in the Git history**. When a developer finishes a change, they create a commit with a message describing what changed. The developer then pushes the commit to the remote repository, where the CI/CD pipeline can pick it up.

```text
Developer changes code
        ↓
      Commit
        ↓
     Git push
        ↓
   Repository
        ↓
    Pipeline
```

Every Git commit gets a unique identifier called a **commit SHA**. It is a long value such as:

```text
8f3a91c2...
```

You can think of the SHA as the **fingerprint of that exact version of the code**. If even a small part of the committed content changes, Git creates a different commit and therefore a different SHA.

You can see the latest commit with:

```bash
git log -1
```

or just its short SHA:

```bash
git rev-parse --short HEAD
```

The SHA is very useful in CI/CD because the pipeline can record exactly which code it built and deployed.

```text
Commit SHA
   ↓
Build
   ↓
Artifact
   ↓
Deployment
```

Suppose Production is running code from commit `8f3a91c`. If a problem appears, you can trace that deployment back to the exact commit and inspect what changed. If you need to roll back, you can also identify an earlier known-good version.

> **Senior habit:** Always be able to answer **“Which commit SHA is running in Production?”** It is much more precise than saying “the latest code.”

### Why not simply use a branch name?

A branch such as `main` is a **moving pointer**. Today it may point to one commit and tomorrow to another.

A commit SHA points to one exact commit.

```text
main
 ↓
8f3a91c   ← today

After another push:

main
 ↓
a72b41e   ← tomorrow
```

For traceability, record the exact commit or artifact version in every deployment.

---

## 03 · Build · 6 min

The **build** step turns source code into something that can be run or deployed. For a Spring Boot application, this could mean compiling the Java code and creating a JAR file.

```text
Java source
   ↓
Compile
   ↓
JAR
```

The build may also download dependencies, run code checks and create other files needed by the application. If the build fails, the pipeline should stop before it deploys anything.

> **Simple rule:** Don't deploy software that did not successfully build.

---

## 04 · Test · 6 min

Tests check whether the application behaves as expected. A pipeline may run unit tests, integration tests or other automated checks before allowing the software to move forward.

```text
Build
 ↓
Tests
 ↓
Pass → Continue
Fail → Stop
```

Tests are not only about finding bugs. They create a **safety check** between a code change and a deployment. The more important the application, the more valuable automated checks become.

A passing test does not prove that production will never fail. It only gives you evidence that the tested conditions behaved as expected.

> **Senior thinking:** Ask **“What risk does this test reduce?”**, not just “Do we have tests?”

---

## 05 · Artifacts · 9 min

An **artifact is the finished output of the build that we are going to deploy**. For a Spring Boot application, the artifact could be a JAR file such as `myapp.jar`. For a containerized application, the artifact is usually a container image.

```text
Source code
    ↓
Build
    ↓
Artifact
    ↓
Deploy
```

The artifact is important because it separates **building software** from **running software**. Once the build has produced a known artifact, the deployment process does not need to compile the source code again.

For example:

```text
Commit 8f3a91c
      ↓
   Build
      ↓
myapp.jar v1.4
      ↓
   Dev → UAT → Production
```

The same artifact can move through each environment. This gives you more confidence that the code tested in UAT is the same software that reaches Production.

An artifact should also have a clear version or identifier. That identifier might be a build number, Git commit SHA, package version or container image tag. The important part is that you can connect the artifact back to the source code that produced it.

For example:

```text
Commit SHA: 8f3a91c
       ↓
Artifact: myapp-8f3a91c.jar
       ↓
Production
```

This makes troubleshooting much easier because you can trace:

**Production → Artifact → Build → Commit → Code change**

### Artifact vs source code

Source code is what developers write. An artifact is what the build produces and the runtime actually receives.

```text
Source code
     ↓
   Build
     ↓
 Artifact
     ↓
 Production
```

You normally do not copy the developer's source files directly to a production server when the application needs to be built first. The pipeline creates the deployable output and then releases that output.

> **Key idea:** **Build once, keep the artifact, deploy that same artifact.**

---

## 06 · Deploy · 9 min

**Deployment means taking a known artifact and putting it into the environment where the application should run.** The target could be a VM, App Service, Kubernetes, Container Apps or another platform.

```text
Artifact
   ↓
Target environment
   ↓
Application starts
   ↓
Users can access it
```

Deployment is more than copying a file. The platform must start the application with the correct **configuration, environment variables, network settings and secrets**. These values normally come from the environment or a secret store, not from the application code itself.

For example, a Spring Boot application may need:

```text
JAR
 ↓
JAVA settings
 ↓
Database connection
 ↓
Secrets
 ↓
Application starts
```

The deployment process can be different depending on the platform. A VM deployment might copy a JAR and restart a systemd service. A Kubernetes deployment might update a container image in a Deployment. An App Service deployment might send the application package to the platform.

The important idea is that **the artifact stays the same while the environment around it can change**.

```text
             Same artifact
                  ↓
        ┌─────────┼─────────┐
       Dev        UAT       Prod
        ↓          ↓          ↓
   different   different   different
   config      config      config
```

This is one reason we keep environment configuration outside the artifact. The same application build can run in different environments without rebuilding it.

### What does a successful deployment mean?

When a deployment command returns success, it usually means the platform accepted or started the new version. It does **not automatically prove that users can successfully use the application**.

For example, the JAR may start but fail to connect to MySQL. The deployment step can therefore be successful while the application is unhealthy.

That is why verification must follow every deployment:

```text
Deploy
  ↓
Application starts
  ↓
Health check
  ↓
Real request / smoke test
```

> **Senior thinking:** Keep these two statements separate: **“The new version was deployed.”** and **“The new version is healthy.”**

---

## 07 · Verify & Rollback · 7 min

After deployment, the pipeline should verify that the new version is working. A simple check might call a health endpoint, while a more complete check may use logs, metrics or application tests.

```text
Deploy
 ↓
Health check
 ↓
Healthy → Continue
Unhealthy → Investigate / Rollback
```

**Rollback** means returning to a previously known working version when the new release causes a serious problem. This is much easier when you version artifacts and can deploy a previous version again.

Rollback is not a replacement for finding the root cause. It restores service first; investigation can then continue safely.

---

## 08 · Pipeline as a Flow · 5 min

Put the whole process together:

```text
Developer
    ↓
Git
    ↓
Build
    ↓
Test
    ↓
Artifact
    ↓
Deploy
    ↓
Verify
    ↓
Release
```

You can add security and quality checks throughout the flow:

```text
        Security
           ↓
Code → Build → Test → Artifact → Deploy → Verify
           ↑
        Quality
```

The pipeline should create a **repeatable path** from code to running software. A good pipeline reduces manual work and makes failures easier to see and investigate.

### Where AI tools fit

Newer senior JDs expect you to use AI assistants inside this exact loop. On the writing side they draft pipeline YAML, scripts and IaC. On the operating side they summarise logs and draft incident timelines. Notice that the loop itself does not change when AI joins it. AI shortens the writing, while the checking stays where it always was: review, tests and an approval gate before production.

> **Remember:** Treat AI output like a fast junior engineer: great first drafts, zero accountability. Review stays human, gates stay in the pipeline.

More on this theme in the [agentic DevOps pattern card](jd-insights/patterns/agentic-devops.md).

---

## 11 · Azure ↔ AWS · 4 min

The tools may have different names, but the CI/CD flow is almost the same.

| Purpose | Azure | AWS |
|---|---|---|
| Source | Azure Repos / GitHub | CodeCommit / GitHub |
| Pipeline | Azure Pipelines | CodePipeline |
| Build | Azure Pipelines | CodeBuild |
| Artifact | Azure Artifacts / Storage | S3 / ECR |
| Deploy | Azure services | CodeDeploy / ECS / EKS |

You do not need to memorize the service names yet. First understand the **delivery flow**. You can then map the cloud-specific tools onto it.

---

## 12 · Cost Check · 1 min

No cloud resources are required.

**AWS:** ₹0  
**Azure:** ₹0

---

## 13 · Cleanup · <1 min

Nothing to clean up if you only used a local repository.

---

## Next

### Day 5 · L05 — Azure DevOps Pipelines

We'll turn today's flow into a real pipeline:

**Repository → Build → Test → Artifact → Approval → Deployment**

> **Takeaway:** CI/CD creates a **repeatable and controlled path from code to production**. The tools are secondary; understanding the flow is the important part.
