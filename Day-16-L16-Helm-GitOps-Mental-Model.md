# Day 16 — Helm + GitOps Mental Model

**Goal:** Understand why Helm exists, how Helm charts package Kubernetes applications, and how GitOps changes the way Kubernetes deployments are managed.

**Core idea:** Kubernetes gives you the objects needed to run an application, but a real application quickly needs many YAML files, environment-specific values, versioning, upgrades and rollbacks. Helm helps package and parameterize those Kubernetes resources. GitOps adds another layer: instead of a pipeline directly changing the cluster and becoming the source of truth, Git contains the desired state and a controller continuously reconciles the cluster toward that state.

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

When Helm processes the chart, these expressions are replaced with actual values and produce normal Kubernetes YAML. The Kubernetes API server does not understand `{{ .Values.replicaCount }}`; Helm processes it before Kubernetes receives the final manifest.

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

and define the value in `values.yaml`. This becomes powerful when the same chart is deployed to multiple environments with different configuration.

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

This separates **template problems** from **cluster problems**. If the rendered YAML is wrong, the problem can be investigated before Kubernetes is involved.

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

**Practice:** Install the chart, change the image tag or replica count, upgrade it, inspect the history, then deliberately introduce a bad application image and observe the resulting failure. Roll back and verify recovery.

---

## Part 5 — Helm Dependencies, Secrets and Configuration

1. Real applications often depend on other components. A Helm chart can declare dependencies on other charts, which allows an application package to describe related components. However, dependencies should be used deliberately. Packaging an entire database, message broker and application into one chart may be convenient for a lab but can create an undesirable operational boundary in production when those components have different ownership, scaling and lifecycle requirements.

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

5. Be careful with Helm's `--set` when dealing with sensitive values. Even if a secret is eventually rendered into a Kubernetes Secret, placing credentials directly in shell history, CI logs or pipeline command output can create another exposure path. A secure design considers not only where the secret ends up but also how it travels through the deployment process.

**Practice:** Modify your chart so the database host is configurable through values, but the database password is represented only as a Secret reference. Do not put a real password into the repository.

---

## Part 6 — From Helm to GitOps

1. Helm answers the question **“How do I package and deploy Kubernetes applications?”** GitOps adds the question **“What should be running in the cluster, and where is that desired state defined?”** In a GitOps model, Git becomes the authoritative source for the desired configuration, while a controller running in or around the cluster continuously compares the desired state with the actual cluster state. When they differ, the controller attempts to reconcile the cluster toward the desired state.

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

3. An important security benefit is that the GitOps controller can operate with controlled access to the cluster, while developers and CI systems do not necessarily need unrestricted direct write access to production Kubernetes APIs. The exact permissions depend on the architecture, but the general principle is **reduce the number of systems that need direct production-cluster mutation privileges**.

4. GitOps also creates a strong audit trail because deployment configuration changes are represented as Git commits and pull requests. Instead of asking “Who changed the production Deployment manually?” you can often trace the desired-state change through Git history. This does not eliminate all operational investigation, because cluster-level changes and infrastructure changes can still happen outside Git, but it provides a strong source of evidence.

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

1. Helm and GitOps are not competing replacements. Helm is primarily a packaging and templating/release-management tool for Kubernetes, while GitOps is an operating model in which a controller continuously reconciles cluster state from a declarative source such as Git. A GitOps controller can use Helm charts as part of that process. Therefore, the architecture can be **Git → Helm chart/values → GitOps controller → Kubernetes**.

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

1. Helm and GitOps add deployment layers, so troubleshooting must account for them. If a Helm deployment fails, first determine whether the chart rendered correctly, whether Kubernetes accepted the resources, whether the Pods started, whether Services have endpoints, and whether the application is healthy. If GitOps is involved, add another question: **Did the controller actually observe and reconcile the desired state?** This extends the troubleshooting approach from Day 15 rather than replacing it.

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
