# Day 4 — Questions and answers

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Then answer each item below before you open the Answer block. After that, do the lab in [03-implementation.md](03-implementation.md).

Write your own answer first. Open the Answer block only after you try. Keep the original numbering.

---

## 1. Mini Exercise Step A — Draw the CI/CD flow

## 09 · Mini Exercise · 10–15 min

Use any small Git repository. It does not need to contain a real application.

### Step A — Draw the flow

Create this on paper or in a diagram:

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
```

<details>
<summary>Answer</summary>

The delivery flow is: Developer → Git → Build → Test → Artifact → Deploy → Verify → Release. A developer commits code and pushes it to Git. The pipeline builds that commit, runs tests, and keeps a versioned artifact. It then deploys that artifact, verifies health, and only then treats the release as successful.

CI/CD is not a tool. It is this delivery process. Azure Pipelines, GitHub Actions, or AWS CodePipeline can run the same flow. Record the commit SHA through build, artifact, and deployment so you can always answer which code runs in Production.

</details>

---

## 2. Mini Exercise Step B — Should we rebuild from UAT to Production?

### Step B — Add environments

Extend it:

```text
Build
 ↓
Dev
 ↓
UAT
 ↓
Production
```

Ask:

> **Should we build the application again when moving from UAT to Production? Why?**

<details>
<summary>Answer</summary>

No. Do not build the application again when you move from UAT to Production. **Build once, keep the artifact, deploy that same artifact.** The artifact is the finished output of the build, such as `myapp.jar` or a container image. Dev, UAT, and Production should receive that same artifact with different environment configuration around it.

A second build can produce a different artifact even from similar source. You then lose confidence that Production runs the software you tested in UAT. Keep configuration, environment variables, and secrets outside the artifact so the same build can run in each environment.

</details>

---

## 3. Mini Exercise Step C — Deploy succeeds but the application cannot connect to the database

### Step C — Add a failure

Imagine the deployment succeeds but the application cannot connect to the database.

Where should you investigate?

```text
Build? → Test? → Deploy? → Runtime? → Database?
```

The goal is to understand **where the pipeline ends and application troubleshooting begins**.

<details>
<summary>Answer</summary>

The pipeline ended at deploy. The platform accepted or started the new version. The failure sits after that, at runtime and the database path, not in build or test. Build and test already passed, so do not rebuild to “fix” a database connection.

Investigate in this order:

1. Runtime configuration. Check environment variables, Java settings, and secrets for the database connection.
2. Application start and logs. Confirm the process started and read the connection error.
3. Network path to the database. Check route, firewall, and whether the app can reach the database port.
4. Database itself. Confirm it accepts connections from the application.

Keep two statements separate: “the new version was deployed” and “the new version is healthy.”

</details>

---

## 4. Scenario — Pipeline is all green, users receive HTTP 500

## 10 · Break & Reason · 5 min

### Scenario

A pipeline says:

```text
Build      ✓
Tests      ✓
Artifact   ✓
Deploy     ✓
```

But users receive HTTP `500` errors.

The pipeline did not necessarily fail.

The deployment step only proved that the platform placed the artifact. The application still needs to start correctly, connect to its dependencies and handle requests.

> **Senior habit:** Always separate **pipeline success** from **application health**.

<details>
<summary>Answer</summary>

Pipeline success is not application health. Build, tests, artifact, and deploy can all pass while users receive HTTP `500`. Deploy only proved that the platform placed the artifact. The application still needs to start correctly, connect to its dependencies, and handle requests.

Verify next: health check, logs, metrics, and a real request or smoke test. Common causes sit in runtime configuration, secrets, database connectivity, or application errors that tests did not cover. Separate **pipeline success** from **application health**, then investigate the running application and its dependencies.

</details>

---

## 5. What is the difference between CI and CD?

## 14 · Exit Check · 3–5 min

Answer without looking:

1. What is the difference between CI and CD?

<details>
<summary>Answer</summary>

**CI (Continuous Integration)** brings code changes together and checks that they build and pass tests. **CD (Continuous Delivery/Deployment)** takes the tested software toward an environment where it can be released. Together they form one flow: Code → Build → Test → Package → Deploy → Verify.

CI/CD is a delivery process, not a product name. The tools can change. The steps stay. Do not deploy software that did not successfully build.

</details>

---

## 6. Why do we build an artifact?

2. Why do we build an artifact?

<details>
<summary>Answer</summary>

The build turns source code into something you can run or deploy, such as a JAR from Java source. An **artifact** is that finished output. It separates building software from running software. After the build produces a known artifact, deploy does not compile the source again.

Give the artifact a clear identifier: build number, commit SHA, package version, or image tag. Then you can trace Production → Artifact → Build → Commit → code change. You normally do not copy source files straight to Production when the application needs a build first.

</details>

---

## 7. Why is “build once, deploy many times” useful?

3. Why is **build once, deploy many times** useful?

<details>
<summary>Answer</summary>

You build one artifact from a commit, then move that same artifact through Dev, UAT, and Production. That gives you confidence that the code tested in UAT is the same software that reaches Production. The artifact stays the same. The environment around it changes: config, secrets, and network settings.

If you rebuild for Production, you may ship something you never tested. Version the artifact (for example `myapp-8f3a91c.jar`) so every environment points to one known build.

</details>

---

## 8. What is the difference between deployment success and application health?

4. What is the difference between deployment success and application health?

<details>
<summary>Answer</summary>

Deployment success means the platform accepted or started the new version. Application health means users can actually use it. The JAR may start and still fail to connect to MySQL. The deploy step can succeed while the application is unhealthy.

Keep these two statements separate: **“The new version was deployed.”** and **“The new version is healthy.”** After deploy, run a health check. Then send a real request or smoke test before you call the release good.

</details>

---

## 9. Why do we verify after deployment?

5. Why do we verify after deployment?

<details>
<summary>Answer</summary>

Verify checks that the new version works in the real environment. A simple check calls a health endpoint. A fuller check uses logs, metrics, or application tests. Deploy does not prove that users can use the application, so verification must follow every deployment.

If the check fails, investigate or roll back. The flow is: Deploy → application starts → health check → real request / smoke test. Healthy continues. Unhealthy triggers investigation or rollback.

</details>

---

## 10. What problem does rollback solve?

6. What problem does rollback solve?

### Exit criteria

You should be able to explain:

```text
Code
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
Rollback if needed
```

<details>
<summary>Answer</summary>

**Rollback** returns to a previously known working version when the new release causes a serious problem. It restores service first. It is not a replacement for finding the root cause. Investigation can continue after users are safe.

Rollback is much easier when you version artifacts and can deploy a previous version again. Record the commit SHA on every deployment so you can identify an earlier known-good version, such as moving back from `8f3a91c` to the last good artifact.

</details>
