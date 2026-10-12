# Day 16 — Helm + GitOps Mental Model

**Goal:** Understand why Helm exists, how Helm charts package Kubernetes applications, and how GitOps changes the way teams manage Kubernetes deployments.

**Core idea:** A real application quickly needs many YAML files, different values per environment, and a safe way to upgrade and roll back. Helm solves the packaging half of that problem: one chart, many values files, so the design is written once and only the environment values change. GitOps solves the deployment half: Git holds the desired state, and a controller continuously corrects the cluster toward it. Without this, a pipeline pushes changes and the cluster slowly drifts away from what anyone wrote down.

> **JD note:** GitOps plus paved roads is the core ask in Platform and Lead roles. See the [GitOps pattern card](jd-insights/patterns/gitops-platform.md).

## Part 1 — Why Helm Exists

1. By Day 14 and Day 15, you have seen that deploying even a simple application can require several Kubernetes objects: a Deployment, Service, ConfigMap, Secret references, probes, resources and possibly an Ingress or NetworkPolicy. If you manage several applications and multiple environments, copying these YAML files quickly becomes difficult to maintain. Helm exists primarily to package Kubernetes application resources and make their configuration reusable. Think of Helm as a **package manager and templating system for Kubernetes applications**.

2. Without Helm, you might have:

```text
myapp/
├── deployment.yaml
├── service.yaml
├── configmap.yaml
├── ingress.yaml
└── networkpolicy.yaml
```

Then Dev, UAT and Prod might each need slightly different values. Copying the entire YAML set three times creates duplication:

```text
dev/
  deployment.yaml
uat/
  deployment.yaml
prod/
  deployment.yaml
```

The application design is mostly identical, but values such as replica count, image tag, resource limits and hostnames differ. Helm allows you to keep one reusable application template and supply environment-specific values.

3. The important distinction is between **template structure** and **configuration values**. The template describes what Kubernetes resources should exist and how they are constructed. Values provide things that change between environments, such as:

```text
image.repository
image.tag
replicaCount
service.port
resources
ingress.host
```

This is similar to the Terraform/Bicep approach you learned earlier: keep the reusable design separate from environment-specific configuration.

4. Helm does not replace Kubernetes. Kubernetes still creates and manages the actual Pods, Services and other resources. Helm is a tool used to package, render, install and upgrade those Kubernetes resources. Therefore, when troubleshooting a Helm deployment, remember that there are two layers: **Helm packaging/release management** and **the Kubernetes resources Helm created**.

**Practice:** Take the Spring Boot application from Day 14 and list all the Kubernetes objects it currently needs. Ask yourself which values would probably change between Dev, UAT and Prod.

---

## Part 2 — Anatomy of a Helm Chart

1. A Helm chart is a directory containing the templates and metadata required to package a Kubernetes application. A typical chart looks like:

```text
myapp/
├── Chart.yaml
├── values.yaml
└── templates/
    ├── deployment.yaml
    ├── service.yaml
    ├── ingress.yaml
    └── _helpers.tpl
```

`Chart.yaml` describes the chart, `values.yaml` contains default configuration, and the `templates` directory contains Kubernetes manifests with Helm template expressions.

2. `Chart.yaml` contains chart metadata such as its name and version:

```yaml
apiVersion: v2
name: myapp
description: Spring Boot application
type: application
version: 0.1.0
appVersion: "1.0.0"
```

The important distinction is that `version` is the **chart version**, while `appVersion` describes the application version represented by the chart. They are related but are not the same thing. A chart can change because its Kubernetes configuration changes even when the application binary does not.

3. `values.yaml` provides default values:

```yaml
replicaCount: 2

image:
  repository: myregistry/myapp
  tag: "1.0.0"

service:
  port: 80
  targetPort: 8080

resources:
  requests:
    cpu: 250m
    memory: 512Mi
  limits:
    cpu: "1"
    memory: 1Gi
```

The purpose is to avoid hard-coding every environment-specific value directly into the Kubernetes template.

4. A template can consume those values:

```yaml
spec:
  replicas: {{ .Values.replicaCount }}

containers:
  - name: myapp
    image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
```

When Helm processes the chart, it replaces these expressions with actual values and produces normal Kubernetes YAML. The Kubernetes API server does not understand `{{ .Values.replicaCount }}`; Helm processes it before Kubernetes receives the final manifest.

5. This gives you a useful flow:

```text
Chart
  +
values
  ↓
Helm renders templates
  ↓
Kubernetes manifests
  ↓
Kubernetes API
  ↓
Deployment / Service / Pods
```

This is the most important Helm mental model for today.

**Practice:** Create a chart skeleton:

```bash
helm create myapp
```

Inspect:

```bash
cd myapp
ls
find . -maxdepth 2 -type f
```

Do not deploy it yet. First identify `Chart.yaml`, `values.yaml` and the files under `templates/`.

---

## Part 3 — Helm Templating and Values

1. Helm's templating system allows one Kubernetes manifest to be reused with different values. For example, instead of writing:

```yaml
replicas: 3
```

you can write:

```yaml
replicas: {{ .Values.replicaCount }}
```

and define the value in `values.yaml`. This becomes powerful when you deploy the same chart to multiple environments with different configuration.

2. You can override values at deployment time using another values file:

```text
values.yaml
values-dev.yaml
values-uat.yaml
values-prod.yaml
```

For example:

```yaml
# values-dev.yaml
replicaCount: 1

image:
  tag: "1.2.3"
```

and:

```yaml
# values-prod.yaml
replicaCount: 4

image:
  tag: "1.2.3"
```

The chart remains the same while the environment configuration changes.

3. You can render the chart without deploying it:

```bash
helm template myapp ./myapp
```

This is one of the most useful Helm commands because it lets you inspect the Kubernetes manifests Helm will generate. You can also specify values:

```bash
helm template myapp ./myapp \
  -f ./myapp/values-prod.yaml
```

This separates **template problems** from **cluster problems**. If the rendered YAML is wrong, you can investigate the problem before Kubernetes is involved.

4. You can also inspect a specific rendered resource:

```bash
helm template myapp ./myapp \
  -f ./myapp/values-prod.yaml \
  --debug
```

Then ask:

```text
Did the image become the expected image?
Did replicas become the expected number?
Did the Service target the correct port?
Did the environment-specific hostname appear?
Did the resource requests/limits render correctly?
```

This is much better than blindly installing and then trying to discover what Helm generated.

5. Helm supports multiple ways of supplying values, but a clean environment strategy should avoid making the deployment command itself an enormous collection of overrides. For example, this is easy to understand:

```bash
helm upgrade --install myapp ./myapp \
  -f values-prod.yaml
```

while a command containing dozens of `--set` values can become difficult to audit and reproduce. Use values files for meaningful environment configuration and reserve `--set` for small, intentional overrides.

**Practice:** Create:

```text
values-dev.yaml
values-prod.yaml
```

Make Dev use one replica and Prod use three replicas. Render both:

```bash
helm template myapp ./myapp -f values-dev.yaml
helm template myapp ./myapp -f values-prod.yaml
```

Compare the resulting Deployment manifests.

---

## Part 4 — Helm Install, Upgrade and Rollback

1. Helm groups the Kubernetes resources belonging to an application into a **release**. A release represents an installed instance of a chart in a Kubernetes cluster. For example, the same chart could create one release in Dev and another in Prod. Helm maintains release information so that you can inspect, upgrade and roll back that deployment.

2. Install a chart with:

```bash
helm install myapp ./myapp
```

Then inspect:

```bash
helm list
helm status myapp
kubectl get all
```

The important mental model is:

```text
Helm Chart
   ↓
Helm Release
   ↓
Kubernetes Resources
   ↓
Pods / Services / etc.
```

3. When the application changes, you generally upgrade the existing release rather than installing another release with a different name:

```bash
helm upgrade myapp ./myapp \
  -f values-prod.yaml
```

A useful production pattern is to change the image tag through values:

```yaml
image:
  repository: myregistry/myapp
  tag: "1.1.0"
```

Then upgrade the release. Kubernetes performs the actual Deployment rollout according to the Deployment specification.

4. You can inspect release history:

```bash
helm history myapp
```

If an upgrade causes a problem, Helm can roll the release back:

```bash
helm rollback myapp <REVISION>
```

Then verify:

```bash
helm status myapp
kubectl rollout status deployment/myapp
kubectl get pods
```

The important distinction is that Helm rollback is not a magical recovery mechanism for every failure. It changes the managed release configuration back toward an earlier revision, but application state such as database migrations may not automatically be reversible. This is the same deployment principle from Day 7: **application rollback and database rollback are separate problems**.

5. Helm also has:

```bash
helm uninstall myapp
```

This removes the Helm release and the resources managed by it, subject to how the chart and resources were designed. Before uninstalling a production release, understand what data resources, persistent volumes or externally managed objects are involved.

**Practice:** Install the chart, change the image tag or replica count, upgrade it, and inspect the history. Then deliberately introduce a bad application image and observe the resulting failure. Roll back and verify recovery.

---

## Part 5 — Helm Dependencies, Secrets and Configuration

1. Real applications often depend on other components. A Helm chart can declare dependencies on other charts, which allows an application package to describe related components. However, use dependencies deliberately. To package an entire database, message broker and application into one chart may be convenient for a lab. In production it can create an undesirable operational boundary, because those components have different ownership, scaling and lifecycle requirements.

2. Helm values are appropriate for configuration, but they should not become a place to casually store production secrets in Git. A value such as:

```yaml
database:
  host: db.internal
  username: appuser
```

may be acceptable as non-secret configuration, while:

```yaml
database:
  password: SuperSecretPassword
```

should not be committed to a normal Git repository.

3. A better production model is to let Kubernetes receive secrets from an appropriate secret-management mechanism. Depending on the platform, this might involve Azure Key Vault, AWS Secrets Manager, external-secrets tooling, CSI integrations or another approved secret-management architecture. The Helm chart should describe how the application consumes the secret rather than making the secret itself part of the source-controlled chart.

4. Configuration and secrets should therefore follow the same principle you learned in CI/CD and IaC:

```text
Application image
       +
Non-secret configuration
       +
Secret references
       ↓
Environment-specific deployment
```

The image should remain the same across environments whenever possible. Environment-specific values and secret resolution should happen at deployment/runtime rather than requiring a separate application image for every environment.

5. Be careful with Helm's `--set` when dealing with sensitive values. Even if a secret eventually becomes a Kubernetes Secret, credentials that pass through shell history, CI logs or pipeline command output create another exposure path. A secure design considers not only where the secret ends up but also how it travels through the deployment process.

**Practice:** Modify your chart so the database host is configurable through values, but the database password is represented only as a Secret reference. Do not put a real password into the repository.

---

## Part 6 — From Helm to GitOps

1. Helm answers the question **“How do I package and deploy Kubernetes applications?”** GitOps adds the question **“What should be running in the cluster, and where is that desired state defined?”** In a GitOps model, Git becomes the authoritative source for the desired configuration. A controller running in or around the cluster continuously compares the desired state with the actual cluster state. When they differ, the controller attempts to reconcile the cluster toward the desired state.

2. The traditional CI/CD model you learned earlier might look like:

```text
Developer
   ↓
Git
   ↓
CI/CD Pipeline
   ↓
Build Image
   ↓
Push Registry
   ↓
kubectl / Helm
   ↓
Kubernetes
```

The pipeline actively performs the deployment.

3. A GitOps model commonly looks like:

```text
Developer
   ↓
Git
   ↓
CI builds application image
   ↓
Image Registry

Git
   ↓
Desired Kubernetes configuration
   ↓
GitOps Controller
   ↓
Kubernetes
```

The CI pipeline may build and publish the image, while a GitOps controller handles deployment by observing the desired state stored in Git.

> **Remember:** Two loops. The CI loop builds things (code → image). The CD loop applies things (Git state → cluster). GitOps means nobody pushes to the cluster: the cluster pulls from Git, so every change has a diff, an author, and an undo.

The platform idea uses those same two loops and offers them as a product. A **paved road** (also called a golden path) is a ready path for a new service: a repo template, a pipeline, a deploy path, and monitoring defaults. Product teams ship on that path without opening a ticket for each step. Day 33 teaches the artifact-promotion half of the path. Day 25 Part 18 shows how a platform team owns the path and an application team consumes it.

> **Remember:** A paved road is a template plus a pipeline plus a deploy path plus monitoring, so a new service ships without a ticket for each step.

4. The controller continuously performs reconciliation:

```text
Desired state in Git
        ↓
GitOps Controller
        ↓
Actual cluster state
        ↓
Difference?
   ↙          ↘
 Yes           No
 ↓              ↓
Reconcile      Nothing
```

This is closely related to the Kubernetes controller model from Day 14. Kubernetes already uses reconciliation internally; GitOps extends the idea so that Git-defined desired state becomes part of the deployment control loop.

5. This changes the operational model. If someone manually changes a Deployment in the cluster, the cluster may temporarily differ from Git. Depending on the GitOps controller's configuration, the controller can detect that difference and restore the Git-defined state. This is why GitOps can improve auditability and consistency, but it also means engineers must understand that **manual `kubectl` changes may be temporary or actively reverted**.

**Practice:** Draw both architectures:

```text
Traditional:
Git → Pipeline → Helm → Kubernetes
```

and:

```text
GitOps:
Git → GitOps Controller → Kubernetes
```

Then identify who owns the deployment action in each model.

---

## Part 7 — GitOps and the CI/CD Pipeline

1. GitOps does not mean that CI/CD disappears. A common architecture separates **CI** from **CD**. CI builds, tests, scans and publishes the application image. CD is handled by the GitOps controller, which continuously reconciles the desired deployment state. This separation creates a useful boundary: the CI system produces an immutable artifact, while the deployment system determines where and how that artifact should run.

2. A typical flow is:

```text
Developer commits code
        ↓
CI Pipeline
        ↓
Build + Test + Security Scan
        ↓
Container Image
        ↓
Registry
        ↓
Update deployment configuration in Git
        ↓
GitOps Controller
        ↓
Kubernetes
```

For example, CI might produce:

```text
myapp:1.4.0
```

and update the environment configuration:

```yaml
image:
  repository: registry.example.com/myapp
  tag: "1.4.0"
```

The GitOps controller notices the Git change and reconciles Kubernetes.

3. An important security benefit is that the GitOps controller can operate with controlled access to the cluster. Developers and CI systems then do not need unrestricted direct write access to production Kubernetes APIs. The exact permissions depend on the architecture, but the general principle is **reduce the number of systems that need direct production-cluster mutation privileges**.

4. GitOps also creates a strong audit trail because Git commits and pull requests represent the deployment configuration changes. Instead of asking “Who changed the production Deployment manually?” you can often trace the desired-state change through Git history. This does not eliminate all operational investigation, because cluster-level changes and infrastructure changes can still happen outside Git. It does provide a strong source of evidence.

5. GitOps introduces its own failure modes. A deployment can fail because the image does not exist, the Helm template renders invalid Kubernetes YAML, the controller cannot access the cluster or repository, the Kubernetes resources are invalid, or the application itself is unhealthy. Therefore, “Git commit merged” does not mean “production is healthy.” You still need the observability and rollout verification concepts from Day 7 and Day 15.

**Practice:** Design a simple pipeline for the Spring Boot application:

```text
Source
  ↓
Build/Test
  ↓
Docker Image
  ↓
Registry
  ↓
Update Helm values
  ↓
Git
  ↓
GitOps Controller
  ↓
AKS/EKS
```

For every arrow, identify what system is responsible and what artifact is being passed forward.

---

## Part 8 — GitOps Reconciliation and Drift

1. One of the most important GitOps concepts is reconciliation. Suppose Git says the application should have three replicas:

```yaml
replicaCount: 3
```

but someone manually changes the Deployment to one replica:

```bash
kubectl scale deployment myapp --replicas=1
```

Now the cluster and Git disagree. This is configuration drift. A GitOps controller detects the difference and, depending on its configuration, can reconcile the cluster back toward the desired state stored in Git.

2. This gives GitOps a powerful operational property:

```text
Git = desired state
Cluster = actual state
Controller = reconciliation mechanism
```

The controller does not simply “run the pipeline again.” It continuously observes the state and attempts to converge actual state toward desired state.

3. Drift can also be intentional during an incident. An engineer may temporarily scale a workload or change a configuration to stabilize production. In a GitOps environment, that emergency change should be treated carefully because the controller may revert it. The long-term correction should normally be represented in Git if the changed state is supposed to become the new desired state.

4. This is closely related to the Terraform drift concept from Day 10. Terraform compares configuration, state and infrastructure; GitOps compares desired Kubernetes configuration with actual cluster state. The mechanisms are different, but the underlying engineering principle is similar: **detect divergence, understand why it happened, and reconcile deliberately.**

5. GitOps does not eliminate drift everywhere. It primarily manages the resources and fields under its control. External infrastructure such as a VNet, VPC, managed database or cloud load balancer may still require separate IaC and governance mechanisms. This is why a mature platform commonly combines:

```text
Terraform / Bicep
        ↓
Cloud infrastructure

GitOps
        ↓
Kubernetes workloads
```

rather than trying to force one tool to own everything.

**Practice:** Deploy your application through Helm, then manually scale the Deployment:

```bash
kubectl scale deployment myapp --replicas=1
```

Observe the change:

```bash
kubectl get deployment myapp
```

Then restore the desired configuration through Helm. In a real GitOps lab, repeat this with an actual GitOps controller and observe automatic reconciliation.

---

## Part 9 — Helm vs GitOps: Understand the Boundary

1. Helm and GitOps are not competing replacements. Helm is primarily a packaging and templating/release-management tool for Kubernetes. GitOps is an operating model in which a controller continuously reconciles cluster state from a declarative source such as Git. A GitOps controller can use Helm charts as part of that process. Therefore, the architecture can be **Git → Helm chart/values → GitOps controller → Kubernetes**.

2. Think about the responsibilities separately:

```text
Helm
- Package Kubernetes resources
- Template configuration
- Manage releases
- Support upgrades and rollbacks

GitOps
- Define desired state in Git
- Continuously reconcile state
- Provide Git-based auditability
- Detect and correct drift
```

The exact capabilities vary by implementation, but this separation gives you the correct conceptual foundation.

3. A common mistake is saying “Helm is GitOps.” Helm by itself does not continuously watch Git and reconcile a cluster. Running `helm upgrade` from a pipeline is still a traditional push-style deployment. GitOps requires a reconciliation mechanism that continuously observes the desired state and actual state.

4. Another common mistake is saying “GitOps means everything must be stored in Git.” Secrets require special treatment, generated data should not necessarily be committed, and external systems may remain authoritative for certain values. The more accurate principle is that **the desired declarative configuration for the resources under GitOps management is version-controlled and reconciled from an authoritative source**.

5. Senior/Lead engineers should also recognize the organizational boundary. Application teams may own Helm charts and application configuration, a platform team may own the GitOps controller and cluster platform, and an infrastructure team may own Terraform/Bicep for cloud resources. Clear ownership prevents multiple systems from fighting over the same resource.

**Practice:** For each item below, decide which layer you would normally use:

```text
Azure VNet
AWS VPC
AKS/EKS cluster
Kubernetes Deployment
Kubernetes Service
Application image
Environment-specific replica count
Cloud database
Kubernetes Secret reference
```

Then explain why you assigned it to Terraform/Bicep, CI, Helm/GitOps or another system.

---

## Part 10 — Senior/Lead Troubleshooting Drill

1. Helm and GitOps add deployment layers, so troubleshooting must account for them. If a Helm deployment fails, first check that the chart rendered correctly and that Kubernetes accepted the resources. Then check that the Pods started, that Services have endpoints, and that the application is healthy. If GitOps is involved, add another question: **Did the controller actually observe and reconcile the desired state?** This extends the troubleshooting approach from Day 15 rather than replacing it.

2. Consider this incident:

```text
Developer merged:
image tag = 1.5.0

GitOps reports:
Synced

Users report:
Application unavailable
```

Do not conclude that GitOps failed simply because users cannot access the application. Investigate:

```text
Git commit
   ↓
GitOps controller observed change?
   ↓
Helm rendered expected manifest?
   ↓
Kubernetes accepted resources?
   ↓
Deployment rollout succeeded?
   ↓
Pods Ready?
   ↓
Service endpoints present?
   ↓
Ingress / Load Balancer working?
   ↓
Application responding?
```

3. Useful commands include:

```bash
helm list
helm status myapp
helm history myapp
helm get values myapp
helm get manifest myapp
helm template myapp ./myapp -f values-prod.yaml

kubectl get deployment
kubectl rollout status deployment/myapp
kubectl get pods -o wide
kubectl get svc
kubectl get endpoints
kubectl describe pod <pod>
kubectl logs <pod>
```

For a GitOps controller, also inspect its application/reconciliation status and controller logs using the tooling provided by your chosen implementation.

4. A particularly useful debugging technique is to separate **desired-state problems** from **runtime problems**. If `helm template` generates the wrong image tag, you have a configuration/template problem. If the manifest is correct but the Pod is `ImagePullBackOff`, investigate the registry/image access. If the Pod is Ready but users receive connection failures, move toward Service, Ingress and external networking. This prevents you from debugging the wrong layer.

5. The Senior/Lead interview question behind this lesson is often: **“Your GitOps deployment says Synced/Healthy, but users still cannot access the application. What do you check?”** A strong answer follows the actual traffic and deployment paths rather than assuming that synchronization equals application availability.

**Practice — Full Deployment Investigation:**

Create a failure matrix:

```text
Failure
↓
Evidence
↓
Layer
↓
Command
↓
Recovery
```

Use at least these scenarios:

```text
1. Wrong Helm image tag
2. Wrong Service targetPort
3. Pod fails readiness
4. Service has no endpoints
5. Ingress points to wrong Service
6. Git change is not reconciled
7. Manual cluster change conflicts with Git desired state
```

The goal is to recognize the difference between **template failure, deployment failure, Kubernetes networking failure and application failure**.

---

## Part 11 — 5-Minute Recall

Without looking at the notes, explain these in your own words:

1. Why does Helm exist when Kubernetes already accepts YAML manifests?

2. What are `Chart.yaml`, `values.yaml` and `templates/` responsible for?

3. What is the difference between a Helm chart and a Helm release?

4. What is the difference between `version` and `appVersion` in a chart?

5. How does Helm turn a template into a Kubernetes manifest?

6. Why would you use `values-dev.yaml` and `values-prod.yaml`?

7. What does `helm template` help you troubleshoot?

8. What happens conceptually during `helm upgrade`?

9. What is Helm rollback actually rolling back?

10. Why should production secrets not simply be stored in `values.yaml`?

11. What problem does GitOps solve that Helm alone does not?

12. What does reconciliation mean in GitOps?

13. What happens when someone manually changes a GitOps-managed Deployment?

14. How is GitOps conceptually similar to Terraform's desired-state model?

15. Does GitOps replace CI?

16. What is the difference between push-style CD and pull/reconciliation-based GitOps?

17. Can Helm and GitOps be used together? How?

18. If GitOps says the application is synced but users cannot access it, what would you investigate?

19. Where would Terraform/Bicep normally fit relative to GitOps?

20. Why is “deployment succeeded” still different from “application is healthy”?

21. What is a paved road, and which two loops does it offer as a product?

**Core mental model:**

> **Helm packages and templates Kubernetes applications. GitOps makes declarative configuration in Git the desired state and uses continuous reconciliation to keep the cluster aligned with it.**

**Deployment model to remember:**

```text
Code
 ↓
CI
 ↓
Container Image
 ↓
Registry
 ↓
Git desired state
 ↓
GitOps Controller
 ↓
Helm / Kubernetes manifests
 ↓
Kubernetes
 ↓
Pods / Services / Ingress
 ↓
Users
```

**Senior/Lead question to remember:**

> **Where is the desired state? Who changes it? Who reconciles it? Who owns the cluster? What happens when actual state differs from desired state?**

---

## Part 12 — Cleanup

If you installed the Helm release during the lab:

```bash
helm uninstall myapp
```

Verify:

```bash
helm list
kubectl get all
```

If you created the chart only for the lab, you can remove the local directory after confirming you do not need it:

```bash
rm -rf myapp
```

On Windows PowerShell:

```powershell
Remove-Item -Recurse -Force .\myapp
```

Do not delete a shared chart repository or production GitOps configuration as part of cleanup.

The operational habit remains:

**Create → Render → Inspect → Deploy → Break → Diagnose → Recover → Destroy → Verify**

**Next: Day 17 — AKS + EKS: Managed Kubernetes Architecture**

## Answers to practice

### 1. List Kubernetes objects and values that change across environments

<details>
<summary>Answer</summary>

The Day 14 Spring Boot application needs a Deployment, a Service, a ConfigMap, Secret references, probes, resource requests, and often an Ingress or NetworkPolicy. List those objects once. Do not copy the whole YAML set for Dev, UAT, and Prod.

Values that usually change are `image.tag`, `replicaCount`, resource requests and limits, Ingress host, and environment names. The template structure stays. Only environment values change. Helm exists to keep that split.

</details>

### 2. Create a chart skeleton and identify the three core files

<details>
<summary>Answer</summary>

Run `helm create myapp`. Then run `ls` and `find . -maxdepth 2 -type f` inside `myapp`. Do not deploy yet.

`Chart.yaml` holds chart metadata, including `version` and `appVersion`. `values.yaml` holds default configuration. Files under `templates/` are Kubernetes manifests with Helm expressions. Kubernetes never sees `{{ .Values.replicaCount }}` until Helm renders it.

</details>

### 3. Render Dev with one replica and Prod with three

<details>
<summary>Answer</summary>

Create `values-dev.yaml` with `replicaCount: 1`. Create `values-prod.yaml` with `replicaCount: 3`. Render with `helm template myapp ./myapp -f values-dev.yaml` and `helm template myapp ./myapp -f values-prod.yaml`.

Compare the Deployment manifests. Dev should show one replica. Prod should show three. The chart stays the same. If the rendered YAML is wrong, fix the template before Kubernetes is involved.

</details>

### 4. Install, upgrade, introduce a bad image, then roll back

<details>
<summary>Answer</summary>

Install with `helm install myapp ./myapp`. Inspect with `helm list`, `helm status myapp`, and `kubectl get all`. Change the image tag or replica count. Upgrade with `helm upgrade myapp ./myapp -f values-prod.yaml`. Inspect history with `helm history myapp`.

Point the values at a bad image. Observe the Deployment fail, often `ImagePullBackOff`. Roll back with `helm rollback myapp <REVISION>`. Verify with `helm status myapp`, `kubectl rollout status deployment/myapp`, and `kubectl get pods`. Helm rollback restores an earlier release revision. It does not reverse database migrations.

</details>

### 5. Make the database host a value and the password a Secret reference

<details>
<summary>Answer</summary>

Put `database.host` in values, for example `db.internal`. In the Deployment template, inject the host from `.Values`. Inject the password only from a Secret, using `secretKeyRef` or a volume mount.

Do not put a real password in `values.yaml` or Git. The chart describes how the application consumes the secret. Azure Key Vault or AWS Secrets Manager can supply the value later. `--set` of a password also leaks through shell history and CI logs.

</details>

### 6. Traditional pipeline versus GitOps: who owns the deploy action

<details>
<summary>Answer</summary>

Traditional: Git → pipeline → Helm → Kubernetes. The pipeline owns the deploy action. It pushes with `helm upgrade` or `kubectl`. After the job ends, the cluster can drift.

GitOps: Git holds desired Kubernetes configuration. A GitOps controller pulls and reconciles. CI still builds and publishes the image. CD is the controller, not a push job. Manual `kubectl` changes may be reverted.

</details>

### 7. Spring Boot pipeline: system and artifact on every arrow

<details>
<summary>Answer</summary>

Source is the Git commit. Build/Test is CI and produces compiled artifacts plus test results. Docker Image is the build job and produces an image. Registry stores that image. Update Helm values is CI or a release job writing `image.tag` into Git.

Git holds desired state. The GitOps controller reads Git and applies Helm or manifests. AKS or EKS runs the Pods. A merge does not prove production is healthy. You still need rollout checks from Day 15.

</details>

### 8. Scale by hand, then restore desired state through Helm

<details>
<summary>Answer</summary>

Deploy with Helm. Then run `kubectl scale deployment myapp --replicas=1`. Confirm with `kubectl get deployment myapp`. The cluster now disagrees with the chart values.

Restore with `helm upgrade myapp ./myapp -f values-prod.yaml` (or the values file that declared three replicas). In a real GitOps lab, the controller would reconcile without that Helm command. Treat an emergency scale as temporary unless you commit the new desired state.

</details>

### 9. Assign each item to Terraform/Bicep, CI, Helm/GitOps, or another system

<details>
<summary>Answer</summary>

Azure VNet, AWS VPC, the AKS or EKS cluster, and the cloud database belong to Terraform or Bicep. Those are cloud infrastructure. The application image belongs to CI and the registry. Kubernetes Deployment, Service, environment replica count, and Secret references belong to Helm plus GitOps.

Do not force one tool to own everything. Terraform compares configuration, state, and infrastructure. GitOps compares Git desired state with cluster state. Application teams own charts. The platform team owns the GitOps controller. Infrastructure owns the cloud stack.

</details>

### 10. GitOps interview — Synced and Healthy, but users cannot access the application

<details>
<summary>Answer</summary>

Synced means the controller applied Git desired state. It does not mean users can reach the application. Confirm the Git commit, then that the controller observed it, then that Helm rendered the expected manifest. Next confirm Kubernetes accepted the resources, the rollout succeeded, and Pods are Ready. Then check Service Endpoints, Ingress or the load balancer, and the application response.

Separate desired-state problems from runtime problems. Wrong image in `helm template` is a template problem. `ImagePullBackOff` is registry access. Ready Pods plus connection failures are Service, Ingress, or external networking. Use `helm get manifest myapp`, `kubectl get endpoints`, and `kubectl logs <pod>`.

</details>

### 11. GitOps interview — desired state, who changes it, who reconciles it

<details>
<summary>Answer</summary>

Desired state lives in Git: Helm charts and values, or rendered manifests. Humans change it through pull requests. The GitOps controller reconciles the cluster toward that state. The platform team owns the controller and cluster. Application teams own charts and app values.

When actual state differs from Git, the controller detects drift and restores Git, unless you configured it not to. Incident changes must go into Git if they should stay. Helm alone does not watch Git. `helm upgrade` from a pipeline is still push-style CD.

</details>

### 12. Failure matrix — wrong Helm image tag

<details>
<summary>Answer</summary>

Evidence: rendered Deployment shows the wrong image; Pods may `ImagePullBackOff`. Layer is Helm values or template. Prove with `helm template myapp ./myapp -f values-prod.yaml` and `helm get manifest myapp`. Recovery: correct `image.tag` in the values file, upgrade or let GitOps reconcile, then `kubectl rollout status deployment/myapp`.

This is a template or configuration failure, not a Kubernetes network failure.

</details>

### 13. Failure matrix — wrong Service `targetPort`

<details>
<summary>Answer</summary>

Evidence: Endpoints exist; HTTP through the Service fails; Pod IP on the real port may work. Layer is Service port mapping. Prove with `kubectl get endpoints myapp` and `wget -qO- http://myapp` versus `wget -qO- http://<POD-IP>:8080`. Recovery: set `targetPort` to the listen port and upgrade the release.

Recognize the signature: backends present, requests fail.

</details>

### 14. Failure matrix — Pod fails readiness

<details>
<summary>Answer</summary>

Evidence: Pod `Running` and NotReady; Endpoints omit it; Events show probe failures. Layer is readiness. Prove with `kubectl get pods`, `kubectl describe pod <pod>`, and `kubectl get endpoints`. Recovery: fix the probe path or the application health endpoint.

The Deployment can succeed while the Service has no ready backends. GitOps may still report Synced.

</details>

### 15. Failure matrix — Service has no endpoints

<details>
<summary>Answer</summary>

Evidence: `kubectl get endpoints myapp` is empty. Layer is selector versus Pod labels, or every Pod NotReady. Prove with `kubectl describe svc myapp` and `kubectl get pods --show-labels`. Recovery: restore matching labels or restore readiness.

Do not debug Ingress first. The Service has no backends.

</details>

### 16. Failure matrix — Ingress points to the wrong Service

<details>
<summary>Answer</summary>

Evidence: Ingress object exists; traffic hits the wrong application or returns 404; the intended Service may be healthy. Layer is Ingress rules. Prove by reading the Ingress backend Service name and testing that Service directly.

Recovery: point Ingress at the correct Service and let the controller reload. An Ingress resource without a working controller also fails this layer.

</details>

### 17. Failure matrix — Git change is not reconciled

<details>
<summary>Answer</summary>

Evidence: Git shows the new tag; cluster still runs the old image; controller status is not Synced. Layer is GitOps reconciliation. Prove with Git history, controller application status, and controller logs. Causes include a repo permission problem, a wrong path, or the controller down.

Recovery: restore controller access to Git and the cluster. Do not assume a merge equals a deploy.

</details>

### 18. Failure matrix — manual cluster change conflicts with Git

<details>
<summary>Answer</summary>

Evidence: `kubectl scale` or a live edit changes replicas; minutes later GitOps restores the Git value. Layer is drift versus desired state. Prove with `kubectl get deployment myapp` before and after reconciliation.

Recovery: commit the new desired state if the change should stay. Otherwise leave Git as source of truth. During an incident, know the controller may revert emergency edits.

</details>

### 19. Recall — Why Helm exists when Kubernetes already accepts YAML

<details>
<summary>Answer</summary>

A real application needs many objects and different values per environment. Copying YAML for Dev, UAT, and Prod duplicates the design. Helm packages the resources and templates the values.

Kubernetes still creates Pods and Services. Helm is the package and release layer on top.

</details>

### 20. Recall — `Chart.yaml`, `values.yaml`, and `templates/`

<details>
<summary>Answer</summary>

`Chart.yaml` describes the chart, including name, `version`, and `appVersion`. `values.yaml` holds default configuration. `templates/` holds Kubernetes manifests with Helm expressions.

Helm renders those three together into normal YAML. The API server never evaluates Helm syntax.

</details>

### 21. Recall — Helm chart versus Helm release

<details>
<summary>Answer</summary>

A chart is the package: templates plus default values. A release is an installed instance of that chart in a cluster. The same chart can create one release in Dev and another in Prod.

`helm list` shows releases. Upgrades and rollbacks operate on a release, not on the chart directory alone.

</details>

### 22. Recall — `version` versus `appVersion`

<details>
<summary>Answer</summary>

`version` is the chart version. It changes when Kubernetes configuration in the chart changes. `appVersion` describes the application version the chart represents.

They are related but not the same. A chart can change while the application binary stays the same.

</details>

### 23. Recall — How Helm turns a template into a Kubernetes manifest

<details>
<summary>Answer</summary>

Helm reads the chart, merges values, and replaces expressions such as `{{ .Values.replicaCount }}`. The output is normal Kubernetes YAML. Then Helm sends that YAML to the API server.

Flow: Chart + values → Helm renders templates → manifests → Kubernetes API → Deployment, Service, Pods.

</details>

### 24. Recall — Why `values-dev.yaml` and `values-prod.yaml`

<details>
<summary>Answer</summary>

The chart stays one reusable design. Environment files supply replica count, image tag, hostnames, and resources. Render or install with `-f values-prod.yaml`.

Prefer values files over a long `--set` list. Files are easier to audit and reproduce.

</details>

### 25. Recall — What `helm template` helps you troubleshoot

<details>
<summary>Answer</summary>

`helm template myapp ./myapp -f values-prod.yaml` shows the manifests before the cluster is involved. Check image, replicas, Service port, hostname, and resource requests.

If the YAML is wrong, you have a template problem. If the YAML is right and Pods fail, you have a cluster or runtime problem.

</details>

### 26. Recall — What happens during `helm upgrade`

<details>
<summary>Answer</summary>

Helm renders the chart with current values and updates the existing release. Kubernetes then rolls the Deployment according to its spec. Inspect with `helm history myapp`.

You upgrade one named release. You do not install a second release with a new name for a routine change.

</details>

### 27. Recall — What Helm rollback actually rolls back

<details>
<summary>Answer</summary>

`helm rollback myapp <REVISION>` restores the managed release configuration toward an earlier revision. Kubernetes applies those earlier manifests.

It is not magic recovery for every failure. Database migrations and other application state may not reverse. Treat application rollback and database rollback as separate problems.

</details>

### 28. Recall — Why production secrets must not live in `values.yaml`

<details>
<summary>Answer</summary>

`values.yaml` is source-controlled configuration. A password in Git leaks through history, clones, and PRs. Non-secret values such as database host belong in values.

Use Secret references and a secret manager. Also avoid `--set` of secrets, because they appear in shell history and CI logs.

</details>

### 29. Recall — What GitOps solves that Helm alone does not

<details>
<summary>Answer</summary>

Helm packages, templates, and manages releases. It does not continuously watch Git. GitOps makes Git the desired state and uses a controller to reconcile the cluster.

`helm upgrade` from a pipeline is still push-style CD. GitOps adds drift detection, Git audit, and pull-based apply.

</details>

### 30. Recall — What reconciliation means in GitOps

<details>
<summary>Answer</summary>

The controller compares desired state in Git with actual cluster state. If they differ, it converges the cluster toward Git. If they match, it does nothing.

This extends the Kubernetes controller model. The controller does not simply rerun the pipeline once.

</details>

### 31. Recall — Manual change to a GitOps-managed Deployment

<details>
<summary>Answer</summary>

The cluster temporarily drifts. The controller detects the difference. Depending on configuration, it restores the Git-defined state.

Treat live `kubectl` edits as temporary. Commit the change if the new state should last.

</details>

### 32. Recall — GitOps versus Terraform desired state

<details>
<summary>Answer</summary>

Terraform compares configuration, state, and infrastructure. GitOps compares Git Kubernetes configuration with actual cluster state. Both detect divergence and reconcile deliberately.

Mechanisms differ. The principle is the same. GitOps does not replace Terraform for VNets, VPCs, or managed databases.

</details>

### 33. Recall — Does GitOps replace CI?

<details>
<summary>Answer</summary>

No. CI still builds, tests, scans, and publishes the image. GitOps handles CD by reconciling desired deployment state.

Two loops: CI builds things (code → image). CD applies things (Git state → cluster). GitOps means the cluster pulls. Nobody pushes to production by hand.

</details>

### 34. Recall — Push-style CD versus pull GitOps

<details>
<summary>Answer</summary>

Push-style CD: the pipeline authenticates to the cluster and runs `helm upgrade` or `kubectl`. After the job, nothing continuously corrects drift.

Pull GitOps: a controller in or near the cluster watches Git and applies. Developers and CI then need less direct write access to production Kubernetes APIs.

</details>

### 35. Recall — Can Helm and GitOps be used together?

<details>
<summary>Answer</summary>

Yes. Helm is not GitOps by itself. A GitOps controller can consume Helm charts and values from Git. Architecture: Git → Helm chart and values → GitOps controller → Kubernetes.

Helm packages. GitOps reconciles. They are not competing replacements.

</details>

### 36. Recall — GitOps says synced but users cannot access it

<details>
<summary>Answer</summary>

Investigate the traffic and runtime path, not only controller status. Confirm the rendered image, rollout, Ready Pods, Endpoints, Ingress, load balancer, and application response.

Synchronization is not availability. Use the Day 15 path after you confirm GitOps applied the right manifests.

</details>

### 37. Recall — Where Terraform or Bicep fit relative to GitOps

<details>
<summary>Answer</summary>

Terraform or Bicep manage cloud infrastructure: VNet, VPC, cluster, managed database, load balancer plumbing. GitOps manages Kubernetes workloads and in-cluster configuration.

A mature platform uses both. Do not store the VNet in Helm. Do not manage Deployments only in ad-hoc Terraform applies.

</details>

### 38. Recall — Why “deployment succeeded” is not “application is healthy”

<details>
<summary>Answer</summary>

Helm or GitOps can apply valid objects while Pods are not Ready, Endpoints are empty, Ingress is wrong, or the app returns errors. “Git commit merged” does not mean production is healthy.

Verify with rollout status, Endpoints, logs, and user-facing checks. Desired-state success is one layer only.

</details>

### 39. Recall — What is a paved road, and which two loops does it offer?

<details>
<summary>Answer</summary>

A paved road, also called a golden path, is a ready path for a new service. It includes a repo template, a pipeline, a deploy path, and monitoring defaults. Product teams ship on that path without opening a ticket for each step.

It offers the two loops as a product. The CI loop builds code into an image. The CD loop applies Git state to the cluster. The platform team owns the path. Application teams consume it.

</details>
