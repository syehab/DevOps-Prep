# Day 5 — Questions and answers

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Then answer each item below before you open the Answer block. After that, do the lab in [03-implementation.md](03-implementation.md).

Write your own answer first. Open the Answer block only after you try. Keep the original numbering.

---

# 13 · Mini Exercise · 10–15 min

## Draw your own deployment model

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

## 1. Where does the application get built?

1. Where does the application get built?

<details>
<summary>Answer</summary>

The application pipeline builds the application after approved changes merge into `main`. A developer works on a feature branch, opens a Pull Request, and merges into `main`. That pipeline then runs Build and Test and produces an artifact.

The infrastructure pipeline does not build the Java application. It prepares the platform with Terraform.

</details>

---

## 2. Where is the artifact stored?

2. Where is the artifact stored?

<details>
<summary>Answer</summary>

The application pipeline stores the artifact after Build and Test succeed. Later deploy stages use that stored artifact. They do not compile the source again.

Give the artifact a clear identity, such as `myapp:A1B2C3` from the commit. In the Azure DevOps flow, Azure Pipeline keeps this artifact and deploys it to DEV, then UAT, then PROD.

</details>

---

## 3. Which exact version goes to UAT?

3. Which exact version goes to UAT?

<details>
<summary>Answer</summary>

UAT receives the same artifact the pipeline already built and deployed to Dev. The exact version is that artifact, identified by the commit SHA. It is not “whatever `main` points at now.”

`main` can move ahead while UAT still runs the promoted commit. In the matrix example, UAT can run `B2` while Dev already runs `C3`.

</details>

---

## 4. Does Production need another build?

4. Does Production need another build?

<details>
<summary>Answer</summary>

No. Production does not need another build. The rule is **build once, deploy many times**. The pipeline promotes the same artifact from Dev to UAT to Production.

A second build can create a different output. You then lose proof that Production matches the software you tested.

</details>

---

## 5. What happens if only Terraform changes?

5. What happens if only Terraform changes?

<details>
<summary>Answer</summary>

Run the infrastructure pipeline. That pipeline runs Plan, Approval, and Apply, then updates cloud resources. Do not rebuild the Java application for an infrastructure-only change.

After the required infrastructure is ready, the application pipeline can deploy if the app must use the new resources. If the running app needs no change, you only update infrastructure.

</details>

---

## 6. What happens if only Java code changes?

6. What happens if only Java code changes?

<details>
<summary>Answer</summary>

Run the application pipeline. It builds a new artifact, tests it, and deploys it. Terraform does not need to run when the platform did not change.

There may be nothing for Terraform to apply. This split makes it easier to see what caused a problem.

</details>

---

## 7. What happens if Production is running `A1B2C3` while Dev is running `D4E5F6`?

7. What happens if Production is running `A1B2C3` while Dev is running `D4E5F6`?

<details>
<summary>Answer</summary>

This is expected. Dev can be ahead of Production. Both versions can come from `main`. The pipeline has promoted `A1B2C3` to Production and a later commit `D4E5F6` to Dev.

Production is not wrong. It runs the last approved artifact, not the version Dev runs now. The branch is the source of change. The commit is the exact version. The environment is where that version runs.

</details>

---

# 14 · Break & Reason · 6 min

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

## 8. Whether Production on `main` already has the latest code

Is that necessarily true?

<details>
<summary>Answer</summary>

No. That statement is not necessarily true. A branch is a moving pointer. Production can be on `main` and still run an earlier commit.

The pipeline may have deployed Production from `A1B2C3` while `main` already points at `D4E5F6`. “On the `main` branch” is not the same as “running the latest commit.”

</details>

---

## 9. Which exact commit or artifact runs in Production

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

<details>
<summary>Answer</summary>

Ask which exact commit or artifact runs in Production. Trace Production → Artifact → Build → Commit SHA → source code. The commit SHA identifies the version.

The branch name does not. Use that trace when someone claims Production already has the latest code.

</details>

---

# 18 · Exit Check · 5 min

Answer without looking:

## 10. Difference between a branch and an environment

1. What is the difference between a branch and an environment?

<details>
<summary>Answer</summary>

A branch answers which line of code you work on. An environment answers where that code runs. They are related, but they are not the same thing.

`dev`, `uat`, and `prod` do not have to mean a `dev` branch, a `uat` branch, and a `prod` branch. Keep code changes in Git. Keep runtime places as environments with their own infrastructure, configuration, data, and access rules.

</details>

---

## 11. Whether one branch can deploy to Dev, UAT, and Production

2. Can one branch deploy to Dev, UAT and Production?

<details>
<summary>Answer</summary>

Yes. One branch, often `main`, can deploy to Dev, UAT, and Production. The pipeline controls which commit it promotes into each environment.

The same branch does not mean all three environments run the same version at the same moment. Dev can be ahead of UAT, and UAT can be ahead of Production.

</details>

---

## 12. Why Dev and Production can run different commits from the same branch

3. Why can Dev and Production run different commits from the same branch?

<details>
<summary>Answer</summary>

The pipeline promotes versions at different times. Dev can receive a later commit while Production still runs an earlier approved one. `main` has moved, but Production keeps the last promoted artifact until a newer one is approved.

The branch names the source line. The commit names the exact version in each environment.

</details>

---

## 13. Purpose of the commit SHA in deployment tracking

4. What is the purpose of the commit SHA in deployment tracking?

<details>
<summary>Answer</summary>

The commit SHA identifies the exact source version. A branch name only names the line of development, and that pointer moves. Use the SHA to trace Production → artifact → build → code.

Then you know exactly what runs. You do not only know which branch it came from.

</details>

---

## 14. What an application pipeline changes

5. What does an application pipeline change?

<details>
<summary>Answer</summary>

An application pipeline changes the application. It builds, tests, and deploys the software artifact, such as a JAR or image. It should not recreate the whole cloud platform when a developer changes one Java file.

</details>

---

## 15. What an infrastructure pipeline changes

6. What does an infrastructure pipeline change?

<details>
<summary>Answer</summary>

An infrastructure pipeline changes the platform the application runs on. It uses Terraform to create or update resources such as a VNet, database, AKS cluster, load balancer, or Key Vault.

That is a different delivery flow from the application pipeline. Treat them as two related flows, not one giant pipeline by default.

</details>

---

## 16. Whether the application needs a rebuild for every environment

7. Does the application need to be rebuilt for every environment?

<details>
<summary>Answer</summary>

No. Do not rebuild for every environment. Build once, then deploy the same artifact to Dev, UAT, and Production. Each environment supplies its own configuration, such as the database and settings.

The artifact stays the same. You do not rebuild only because the target environment changed.

</details>

---

## 17. How application and infrastructure pipelines work together

8. How do application and infrastructure pipelines work together?

<details>
<summary>Answer</summary>

The two pipelines stay separate, but they meet in the environment. The infrastructure pipeline creates or updates Dev, UAT, or Production. The application pipeline then deploys the app onto that platform.

Order matters when the application depends on infrastructure that does not exist yet. If a new app needs a new database, create the database first, then deploy the app. If infrastructure has not changed, Terraform may have nothing to apply.

</details>

---

## 18. Whether a Terraform-only change needs a Java rebuild

9. If only Terraform changes, should you rebuild the Java application?

<details>
<summary>Answer</summary>

No. A Terraform-only change does not need a Java rebuild. Run the infrastructure pipeline and update the platform. Rebuild the application only when application code or its build inputs change.

</details>

---

## 19. Whether a Java-only change means Terraform must run

10. If only Java code changes, does Terraform necessarily need to run?

<details>
<summary>Answer</summary>

No. Terraform does not necessarily need to run. If infrastructure did not change, there may be nothing for Terraform to apply. Run Terraform when the platform must change.

</details>

---

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
