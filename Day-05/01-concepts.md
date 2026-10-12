---
title: "Day 5 · L05 — Branches, Environments & Deployment Flow"
description: "Understand how code branches, Dev/UAT/Prod environments, application pipelines and infrastructure pipelines work together."
---

# Day 5 · L05 · Branches, Environments & Deployment Flow

> **Goal:** Understand the complete relationship between **Git branches → environments → application pipeline → infrastructure pipeline → deployment**.

| | |
|---|---|
| ⏱️ Time | 70–90 min |
| 🎯 Level | Senior DevOps |
| ☁️ Cost | ₹0 |
| 🧪 Hands-on | Git repository + diagrams |

---

## 01 · Why Do We Have Dev, UAT & Prod? · 7 min

We normally don't send every code change directly to Production. Different environments give us places to **build, test and approve a change before real users receive it**.

A simple setup looks like:

```text
DEV
 ↓
UAT
 ↓
PROD
```

**Dev** is where developers and the team can test changes frequently. **UAT (User Acceptance Testing)** is usually a more controlled environment where the team validates that the application works as expected before release. **Prod (Production)** is the live environment used by real users.

The important point is that these are not simply three folders containing different code. They are usually **separate environments with their own infrastructure, configuration, data and access rules**.

> **Key idea:** An environment is a place where a particular version of the application runs with its own surrounding resources and configuration.

---

## 02 · What Makes Environments Different? · 7 min

The application code can be the same while the environment around it is different. Dev might have a small database and fewer resources, while Production may have multiple application instances, stronger security controls and higher availability.

For example:

```text
                 Same application
                       ↓
          ┌────────────┼────────────┐
         DEV          UAT          PROD
          ↓            ↓             ↓
       small DB     test DB       prod DB
       low scale    medium        high scale
       test data    test data     real data
```

Environment-specific values should normally come from configuration rather than from different copies of the source code. Examples include database connection details, URLs, feature settings and secrets.

> **Senior thinking:** Try to keep **code the same** and let the **environment provide the differences**.

---

## 03 · Branches · 8 min

A **Git branch is a separate line of development**. It lets developers work on changes without immediately changing the main code line.

A common simple model is:

```text
feature branch
      ↓
    main
```

A developer might create:

```text
feature/payment-api
```

make changes, test them and then create a Pull Request to merge those changes into `main`.

Branches are about **managing changes to source code**. Environments are about **where that code runs**. These are related, but they are not the same thing.

> **Important:** `dev`, `uat` and `prod` do not have to mean `dev branch`, `uat branch` and `prod branch`.

---

## 04 · Branch ≠ Environment · 8 min

This is one of the most important ideas in CI/CD.

A branch answers:

> **Which line of code are we working on?**

An environment answers:

> **Where is that code running?**

You can therefore have one `main` branch deployed to several environments.

```text
                 main
                  │
        ┌─────────┼─────────┐
        ↓         ↓         ↓
       DEV       UAT       PROD
```

The same branch does not mean that all three environments must always run the exact same version at the same moment. The pipeline controls which version it promotes into each environment.

For example:

```text
main
 ↓
Commit A → DEV

later

main
 ↓
Commit B → DEV
Commit A → UAT

later

main
 ↓
Commit C → DEV
Commit B → UAT
Commit A → PROD
```

This means Dev can be ahead of UAT, and UAT can be ahead of Production.

> **Key idea:** **One branch can feed many environments.** The environment decides where a particular version runs.

---

## 05 · The Branch → Environment Matrix · 8 min

Instead of thinking:

```text
dev branch → DEV
uat branch → UAT
prod branch → PROD
```

think about a **deployment matrix**:

| Source | DEV | UAT | PROD |
|---|---|---|---|
| Feature branch | Temporary/testing | — | — |
| `main` | ✓ | ✓ | ✓ |

The same `main` branch can therefore move through the environments.

A more detailed example:

| Commit | DEV | UAT | PROD |
|---|---|---|---|
| `A1` | ✓ | ✓ | ✓ |
| `B2` | ✓ | ✓ | — |
| `C3` | ✓ | — | — |

Here `C3` is currently in Dev, `B2` is in UAT, and `A1` is in Production.

This gives us a very useful concept:

> **The branch tells us where the code came from. The commit tells us exactly which version. The environment tells us where that version is running.**

---

## 06 · Two Common Branching Models · 7 min

There is no single required branch model. Two common approaches are worth understanding.

### Model A — Feature branches + main

```text
feature
   ↓
Pull Request
   ↓
 main
   ↓
DEV → UAT → PROD
```

Developers work on feature branches and merge approved changes into `main`. The pipeline then promotes `main` through the environments.

This keeps the model simple and works well with automated testing and frequent releases.

### Model B — Environment branches

Some teams use branches such as:

```text
develop → DEV
release → UAT
main   → PROD
```

Teams merge or promote changes between branches.

This can work, but it creates another problem to manage: **code can become different between branches**. A fix may exist in one branch but not another.

> **Senior thinking:** Don't choose a branching model just because it is familiar. Understand what problem the model is solving and what extra complexity it creates.

---

## 07 · One Application Pipeline Across Environments · 8 min

A pipeline can build the application once and then deploy that same artifact to different environments.

```text
Git
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

Suppose commit `A1B2C3` creates:

```text
myapp:A1B2C3
```

The pipeline can deploy that exact artifact to Dev, then UAT, and later Production.

```text
                myapp:A1B2C3
                     │
          ┌──────────┼──────────┐
          ↓          ↓          ↓
         DEV        UAT        PROD
```

The artifact stays the same. What changes is the environment configuration around it.

This is the practical meaning of:

> **Build once → deploy many times.**

---

## 08 · How Does the Pipeline Know Which Environment? · 6 min

The pipeline can use **stages, approvals, variables and environment settings** to control where the artifact goes.

A simple pipeline might look like:

```text
Build
  ↓
Test
  ↓
Deploy DEV
  ↓
Approval
  ↓
Deploy UAT
  ↓
Approval
  ↓
Deploy PROD
```

The deployment stage knows which environment it is targeting and loads the correct configuration for that environment.

For example:

```text
DEV  → dev database + dev settings
UAT  → uat database + uat settings
PROD → prod database + prod settings
```

You do not need to rebuild the application package just because the target environment changed.

---

## 09 · Application Pipeline vs Infrastructure Pipeline · 9 min

A change usually touches one of two different things.

**Application code** changes the software itself. **Infrastructure code** changes the resources that the software needs, such as networks, VMs, databases, Kubernetes clusters or storage.

That is why teams often have separate pipelines:

```text
Application Repository
        ↓
Application Pipeline
        ↓
Application Artifact
```

and:

```text
Infrastructure Repository
        ↓
Infrastructure Pipeline
        ↓
Cloud Resources
```

For example:

```text
Terraform
  ↓
VNet / VPC
Database
AKS / EKS
Load Balancer
Key Vault / Secrets
```

The application pipeline should not normally recreate the whole cloud infrastructure every time a developer changes one Java file.

> **Key idea:** **Application pipeline changes the application. Infrastructure pipeline changes the platform it runs on.**

---

## 10 · How Do Both Pipelines Work Together? · 9 min

The two pipelines are separate, but they are connected through the environment.

A typical flow is:

```text
              Infrastructure Pipeline
                       ↓
                Create / Update
                       ↓
              DEV / UAT / PROD
                       ↑
                       │
Application Pipeline ──┘
        ↓
   Deploy app
```

Imagine a new application needs a new database.

First, the infrastructure pipeline can create the database:

```text
Terraform
   ↓
Database created
```

Then the application pipeline deploys the application that uses it:

```text
JAR / Image
   ↓
Application deployed
   ↓
Connects to database
```

The order matters when the application depends on infrastructure that does not exist yet.

However, infrastructure does not need to run before every application deployment. If the infrastructure has not changed, there may be nothing for Terraform to change.

> **Senior thinking:** Treat application and infrastructure as **two related delivery flows**, not one giant pipeline by default.

---

## 11 · A Complete Dev → UAT → Prod Flow · 10 min

Put everything together.

### Step 1 — Developer changes code

```text
feature/payment
      ↓
Pull Request
      ↓
main
```

### Step 2 — Application pipeline builds it

```text
main
 ↓
Build
 ↓
Test
 ↓
Artifact
```

### Step 3 — Infrastructure is ready

```text
Terraform
 ↓
DEV infrastructure
```

### Step 4 — Deploy to Dev

```text
Artifact
 ↓
DEV
 ↓
Test
```

### Step 5 — Promote to UAT

```text
Same artifact
 ↓
UAT
 ↓
Acceptance testing
```

### Step 6 — Promote to Production

```text
Same artifact
 ↓
Approval
 ↓
PROD
```

The complete picture is:

```text
                         Git
                          │
                    feature branch
                          │
                    Pull Request
                          │
                         main
                          │
              ┌───────────┴───────────┐
              │                       │
       Application Pipeline    Infrastructure Pipeline
              │                       │
        Build / Test              Terraform
              │                       │
           Artifact             Environment Infra
              │                       │
              └───────────┬───────────┘
                          │
                         DEV
                          ↓
                         UAT
                          ↓
                        PROD
```

This is the mental model you should carry into real projects.

---

## 12 · What If Infrastructure Changes? · 6 min

Suppose the application team changes only Java code.

```text
Code change
 ↓
Application pipeline
 ↓
New artifact
 ↓
Deploy
```

There may be no reason to run an infrastructure change.

Now suppose the team needs a new subnet or database setting.

```text
Terraform change
 ↓
Infrastructure pipeline
 ↓
Infrastructure update
```

After the required infrastructure is ready, the application pipeline can deploy the application.

This separation reduces unnecessary changes and makes it easier to understand **what caused a problem**.

---

## 13 · Mini Exercise · 10–15 min

Draw your own deployment model.

Start with:

```text
feature branch
      ↓
Pull Request
      ↓
main
```

Then add:

```text
DEV → UAT → PROD
```

Now add:

```text
Application Pipeline
Infrastructure Pipeline
```

Finally, answer:

1. Where does the application get built?
2. Where is the artifact stored?
3. Which exact version goes to UAT?
4. Does Production need another build?
5. What happens if only Terraform changes?
6. What happens if only Java code changes?
7. What happens if Production is running `A1B2C3` while Dev is running `D4E5F6`?

---

## 14 · Break & Reason · 6 min

### Scenario

Production is running:

```text
Commit A1B2C3
```

Dev is running:

```text
Commit D4E5F6
```

A developer says:

> “Production is on the main branch, so it should already have the latest code.”

Is that necessarily true?

**No.**

The branch is a moving pointer. The pipeline may have deployed Production from an earlier commit on that branch.

The correct question is:

> **Which exact commit or artifact is running in Production?**

Then trace it:

```text
Production
   ↓
Artifact
   ↓
Build
   ↓
Commit SHA
   ↓
Source code
```

---

## 15 · Azure DevOps Example · 5 min

A simple Azure DevOps setup could look like:

```text
Azure Repos
     ↓
Azure Pipeline
     ↓
Build + Test
     ↓
Artifact
     ↓
DEV
     ↓
UAT
     ↓
PROD
```

A separate Terraform pipeline could manage:

```text
Terraform
   ↓
Plan
   ↓
Approval
   ↓
Apply
   ↓
Azure infrastructure
```

The exact implementation can vary, but the concepts remain the same.

---

## 16 · Cost Check · 1 min

No cloud resources are required.

**AWS:** ₹0  
**Azure:** ₹0

---

## 17 · Cleanup · <1 min

Nothing to clean up.

---

## 18 · Exit Check · 5 min

Answer without looking:

1. What is the difference between a branch and an environment?
2. Can one branch deploy to Dev, UAT and Production?
3. Why can Dev and Production run different commits from the same branch?
4. What is the purpose of the commit SHA in deployment tracking?
5. What does an application pipeline change?
6. What does an infrastructure pipeline change?
7. Does the application need to be rebuilt for every environment?
8. How do application and infrastructure pipelines work together?
9. If only Terraform changes, should you rebuild the Java application?
10. If only Java code changes, does Terraform necessarily need to run?

### Exit criteria

You should be able to draw and explain:

```text
Feature Branch
      ↓
Pull Request
      ↓
     main
      ↓
Application Pipeline
      ↓
Build → Test → Artifact
      ↓
DEV → UAT → PROD
```

alongside:

```text
Infrastructure Code
      ↓
Terraform Pipeline
      ↓
Plan → Approval → Apply
      ↓
DEV / UAT / PROD Infrastructure
```

> **Takeaway:** The clean mental model is **branch = source of change, commit = exact version, artifact = deployable software, environment = where it runs, application pipeline = delivers software, infrastructure pipeline = prepares the platform.**

---

## Next

### Day 6 · L06 — Azure DevOps Pipeline in Practice

We'll turn today's mental model into a real pipeline with:

**Build → Test → Artifact → Dev → Approval → UAT → Approval → Prod**

## Answers to practice

### 1. Where the application gets built

<details>
<summary>Answer</summary>

The application pipeline builds the application after approved changes merge into `main`. A developer works on a feature branch, opens a Pull Request, and merges into `main`. That pipeline then runs Build and Test and produces an artifact.

The infrastructure pipeline does not build the Java application. It prepares the platform with Terraform.

</details>

### 2. Where the artifact is stored

<details>
<summary>Answer</summary>

The application pipeline stores the artifact after Build and Test succeed. Later deploy stages use that stored artifact. They do not compile the source again.

Give the artifact a clear identity, such as `myapp:A1B2C3` from the commit. In the Azure DevOps flow, Azure Pipeline keeps this artifact and deploys it to DEV, then UAT, then PROD.

</details>

### 3. Which exact version goes to UAT

<details>
<summary>Answer</summary>

UAT receives the same artifact the pipeline already built and deployed to Dev. The exact version is that artifact, identified by the commit SHA. It is not “whatever `main` points at now.”

`main` can move ahead while UAT still runs the promoted commit. In the matrix example, UAT can run `B2` while Dev already runs `C3`.

</details>

### 4. Whether Production needs another build

<details>
<summary>Answer</summary>

No. Production does not need another build. The rule is **build once, deploy many times**. The pipeline promotes the same artifact from Dev to UAT to Production.

A second build can create a different output. You then lose proof that Production matches the software you tested.

</details>

### 5. What happens if only Terraform changes

<details>
<summary>Answer</summary>

Run the infrastructure pipeline. That pipeline runs Plan, Approval, and Apply, then updates cloud resources. Do not rebuild the Java application for an infrastructure-only change.

After the required infrastructure is ready, the application pipeline can deploy if the app must use the new resources. If the running app needs no change, you only update infrastructure.

</details>

### 6. What happens if only Java code changes

<details>
<summary>Answer</summary>

Run the application pipeline. It builds a new artifact, tests it, and deploys it. Terraform does not need to run when the platform did not change.

There may be nothing for Terraform to apply. This split makes it easier to see what caused a problem.

</details>

### 7. Production on `A1B2C3` while Dev runs `D4E5F6`

<details>
<summary>Answer</summary>

This is expected. Dev can be ahead of Production. Both versions can come from `main`. The pipeline has promoted `A1B2C3` to Production and a later commit `D4E5F6` to Dev.

Production is not wrong. It runs the last approved artifact, not the version Dev runs now. The branch is the source of change. The commit is the exact version. The environment is where that version runs.

</details>

### 8. Whether Production on `main` already has the latest code

<details>
<summary>Answer</summary>

No. That statement is not necessarily true. A branch is a moving pointer. Production can be on `main` and still run an earlier commit.

The pipeline may have deployed Production from `A1B2C3` while `main` already points at `D4E5F6`. “On the `main` branch” is not the same as “running the latest commit.”

</details>

### 9. Which exact commit or artifact runs in Production

<details>
<summary>Answer</summary>

Ask which exact commit or artifact runs in Production. Trace Production → Artifact → Build → Commit SHA → source code. The commit SHA identifies the version.

The branch name does not. Use that trace when someone claims Production already has the latest code.

</details>

### 10. Difference between a branch and an environment

<details>
<summary>Answer</summary>

A branch answers which line of code you work on. An environment answers where that code runs. They are related, but they are not the same thing.

`dev`, `uat`, and `prod` do not have to mean a `dev` branch, a `uat` branch, and a `prod` branch. Keep code changes in Git. Keep runtime places as environments with their own infrastructure, configuration, data, and access rules.

</details>

### 11. Whether one branch can deploy to Dev, UAT, and Production

<details>
<summary>Answer</summary>

Yes. One branch, often `main`, can deploy to Dev, UAT, and Production. The pipeline controls which commit it promotes into each environment.

The same branch does not mean all three environments run the same version at the same moment. Dev can be ahead of UAT, and UAT can be ahead of Production.

</details>

### 12. Why Dev and Production can run different commits from the same branch

<details>
<summary>Answer</summary>

The pipeline promotes versions at different times. Dev can receive a later commit while Production still runs an earlier approved one. `main` has moved, but Production keeps the last promoted artifact until a newer one is approved.

The branch names the source line. The commit names the exact version in each environment.

</details>

### 13. Purpose of the commit SHA in deployment tracking

<details>
<summary>Answer</summary>

The commit SHA identifies the exact source version. A branch name only names the line of development, and that pointer moves. Use the SHA to trace Production → artifact → build → code.

Then you know exactly what runs. You do not only know which branch it came from.

</details>

### 14. What an application pipeline changes

<details>
<summary>Answer</summary>

An application pipeline changes the application. It builds, tests, and deploys the software artifact, such as a JAR or image. It should not recreate the whole cloud platform when a developer changes one Java file.

</details>

### 15. What an infrastructure pipeline changes

<details>
<summary>Answer</summary>

An infrastructure pipeline changes the platform the application runs on. It uses Terraform to create or update resources such as a VNet, database, AKS cluster, load balancer, or Key Vault.

That is a different delivery flow from the application pipeline. Treat them as two related flows, not one giant pipeline by default.

</details>

### 16. Whether the application needs a rebuild for every environment

<details>
<summary>Answer</summary>

No. Do not rebuild for every environment. Build once, then deploy the same artifact to Dev, UAT, and Production. Each environment supplies its own configuration, such as the database and settings.

The artifact stays the same. You do not rebuild only because the target environment changed.

</details>

### 17. How application and infrastructure pipelines work together

<details>
<summary>Answer</summary>

The two pipelines stay separate, but they meet in the environment. The infrastructure pipeline creates or updates Dev, UAT, or Production. The application pipeline then deploys the app onto that platform.

Order matters when the application depends on infrastructure that does not exist yet. If a new app needs a new database, create the database first, then deploy the app. If infrastructure has not changed, Terraform may have nothing to apply.

</details>

### 18. Whether a Terraform-only change needs a Java rebuild

<details>
<summary>Answer</summary>

No. A Terraform-only change does not need a Java rebuild. Run the infrastructure pipeline and update the platform. Rebuild the application only when application code or its build inputs change.

</details>

### 19. Whether a Java-only change means Terraform must run

<details>
<summary>Answer</summary>

No. Terraform does not necessarily need to run. If infrastructure did not change, there may be nothing for Terraform to apply. Run Terraform when the platform must change.

</details>
