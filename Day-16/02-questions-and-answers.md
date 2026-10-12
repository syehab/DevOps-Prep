# Day 16 — Questions and answers

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Then answer each item below before you open the Answer block. After that, do the lab in [03-implementation.md](03-implementation.md).

Write your own answer first. Open the Answer block only after you try. Keep the original numbering.

---

## 1. List Kubernetes objects and values that change across environments

**Practice**

Take the Spring Boot application from Day 14 and list all the Kubernetes objects it currently needs. Ask yourself which values would probably change between Dev, UAT and Prod.

<details>
<summary>Answer</summary>

The Day 14 Spring Boot application needs a Deployment, a Service, a ConfigMap, Secret references, probes, resource requests, and often an Ingress or NetworkPolicy. List those objects once. Do not copy the whole YAML set for Dev, UAT, and Prod.

Values that usually change are `image.tag`, `replicaCount`, resource requests and limits, Ingress host, and environment names. The template structure stays. Only environment values change. Helm exists to keep that split.

</details>

---

## 2. Create a chart skeleton and identify the three core files

**Practice**

Create a chart skeleton:

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

<details>
<summary>Answer</summary>

Run `helm create myapp`. Then run `ls` and `find . -maxdepth 2 -type f` inside `myapp`. Do not deploy yet.

`Chart.yaml` holds chart metadata, including `version` and `appVersion`. `values.yaml` holds default configuration. Files under `templates/` are Kubernetes manifests with Helm expressions. Kubernetes never sees `{{ .Values.replicaCount }}` until Helm renders it.

</details>

---

## 3. Render Dev with one replica and Prod with three

**Practice**

Create:

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

<details>
<summary>Answer</summary>

Create `values-dev.yaml` with `replicaCount: 1`. Create `values-prod.yaml` with `replicaCount: 3`. Render with `helm template myapp ./myapp -f values-dev.yaml` and `helm template myapp ./myapp -f values-prod.yaml`.

Compare the Deployment manifests. Dev should show one replica. Prod should show three. The chart stays the same. If the rendered YAML is wrong, fix the template before Kubernetes is involved.

</details>

---

## 4. Install, upgrade, introduce a bad image, then roll back

**Practice**

Install the chart, change the image tag or replica count, upgrade it, and inspect the history. Then deliberately introduce a bad application image and observe the resulting failure. Roll back and verify recovery.

<details>
<summary>Answer</summary>

Install with `helm install myapp ./myapp`. Inspect with `helm list`, `helm status myapp`, and `kubectl get all`. Change the image tag or replica count. Upgrade with `helm upgrade myapp ./myapp -f values-prod.yaml`. Inspect history with `helm history myapp`.

Point the values at a bad image. Observe the Deployment fail, often `ImagePullBackOff`. Roll back with `helm rollback myapp <REVISION>`. Verify with `helm status myapp`, `kubectl rollout status deployment/myapp`, and `kubectl get pods`. Helm rollback restores an earlier release revision. It does not reverse database migrations.

</details>

---

## 5. Make the database host a value and the password a Secret reference

**Practice**

Modify your chart so the database host is configurable through values, but the database password is represented only as a Secret reference. Do not put a real password into the repository.

<details>
<summary>Answer</summary>

Put `database.host` in values, for example `db.internal`. In the Deployment template, inject the host from `.Values`. Inject the password only from a Secret, using `secretKeyRef` or a volume mount.

Do not put a real password in `values.yaml` or Git. The chart describes how the application consumes the secret. Azure Key Vault or AWS Secrets Manager can supply the value later. `--set` of a password also leaks through shell history and CI logs.

</details>

---

## 6. Traditional pipeline versus GitOps: who owns the deploy action

**Practice**

Draw both architectures:

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

<details>
<summary>Answer</summary>

Traditional: Git → pipeline → Helm → Kubernetes. The pipeline owns the deploy action. It pushes with `helm upgrade` or `kubectl`. After the job ends, the cluster can drift.

GitOps: Git holds desired Kubernetes configuration. A GitOps controller pulls and reconciles. CI still builds and publishes the image. CD is the controller, not a push job. Manual `kubectl` changes may be reverted.

</details>

---

## 7. Spring Boot pipeline: system and artifact on every arrow

**Practice**

Design a simple pipeline for the Spring Boot application:

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

<details>
<summary>Answer</summary>

Source is the Git commit. Build/Test is CI and produces compiled artifacts plus test results. Docker Image is the build job and produces an image. Registry stores that image. Update Helm values is CI or a release job writing `image.tag` into Git.

Git holds desired state. The GitOps controller reads Git and applies Helm or manifests. AKS or EKS runs the Pods. A merge does not prove production is healthy. You still need rollout checks from Day 15.

</details>

---

## 8. Scale by hand, then restore desired state through Helm

**Practice**

Deploy your application through Helm, then manually scale the Deployment:

```bash
kubectl scale deployment myapp --replicas=1
```

Observe the change:

```bash
kubectl get deployment myapp
```

Then restore the desired configuration through Helm. In a real GitOps lab, repeat this with an actual GitOps controller and observe automatic reconciliation.

<details>
<summary>Answer</summary>

Deploy with Helm. Then run `kubectl scale deployment myapp --replicas=1`. Confirm with `kubectl get deployment myapp`. The cluster now disagrees with the chart values.

Restore with `helm upgrade myapp ./myapp -f values-prod.yaml` (or the values file that declared three replicas). In a real GitOps lab, the controller would reconcile without that Helm command. Treat an emergency scale as temporary unless you commit the new desired state.

</details>

---

## 9. Assign each item to Terraform/Bicep, CI, Helm/GitOps, or another system

**Practice**

For each item below, decide which layer you would normally use:

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

<details>
<summary>Answer</summary>

Azure VNet, AWS VPC, the AKS or EKS cluster, and the cloud database belong to Terraform or Bicep. Those are cloud infrastructure. The application image belongs to CI and the registry. Kubernetes Deployment, Service, environment replica count, and Secret references belong to Helm plus GitOps.

Do not force one tool to own everything. Terraform compares configuration, state, and infrastructure. GitOps compares Git desired state with cluster state. Application teams own charts. The platform team owns the GitOps controller. Infrastructure owns the cloud stack.

</details>

---

## 10. GitOps interview — Synced and Healthy, but users cannot access the application

**Practice**

Your GitOps deployment says Synced/Healthy, but users still cannot access the application. What do you check?

<details>
<summary>Answer</summary>

Synced means the controller applied Git desired state. It does not mean users can reach the application. Confirm the Git commit, then that the controller observed it, then that Helm rendered the expected manifest. Next confirm Kubernetes accepted the resources, the rollout succeeded, and Pods are Ready. Then check Service Endpoints, Ingress or the load balancer, and the application response.

Separate desired-state problems from runtime problems. Wrong image in `helm template` is a template problem. `ImagePullBackOff` is registry access. Ready Pods plus connection failures are Service, Ingress, or external networking. Use `helm get manifest myapp`, `kubectl get endpoints`, and `kubectl logs <pod>`.

</details>

---

## 11. GitOps interview — desired state, who changes it, who reconciles it

**Practice**

Where is the desired state? Who changes it? Who reconciles it? Who owns the cluster? What happens when actual state differs from desired state?

<details>
<summary>Answer</summary>

Desired state lives in Git: Helm charts and values, or rendered manifests. Humans change it through pull requests. The GitOps controller reconciles the cluster toward that state. The platform team owns the controller and cluster. Application teams own charts and app values.

When actual state differs from Git, the controller detects drift and restores Git, unless you configured it not to. Incident changes must go into Git if they should stay. Helm alone does not watch Git. `helm upgrade` from a pipeline is still push-style CD.

</details>

---

## 12. Failure matrix — wrong Helm image tag

**Practice — Full Deployment Investigation**

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

Use at least these scenarios. This item is scenario 1:

```text
1. Wrong Helm image tag
```

The goal is to recognize the difference between **template failure, deployment failure, Kubernetes networking failure and application failure**.

<details>
<summary>Answer</summary>

Evidence: rendered Deployment shows the wrong image; Pods may `ImagePullBackOff`. Layer is Helm values or template. Prove with `helm template myapp ./myapp -f values-prod.yaml` and `helm get manifest myapp`. Recovery: correct `image.tag` in the values file, upgrade or let GitOps reconcile, then `kubectl rollout status deployment/myapp`.

This is a template or configuration failure, not a Kubernetes network failure.

</details>

---

## 13. Failure matrix — wrong Service `targetPort`

**Practice — Full Deployment Investigation**

```text
2. Wrong Service targetPort
```

<details>
<summary>Answer</summary>

Evidence: Endpoints exist; HTTP through the Service fails; Pod IP on the real port may work. Layer is Service port mapping. Prove with `kubectl get endpoints myapp` and `wget -qO- http://myapp` versus `wget -qO- http://<POD-IP>:8080`. Recovery: set `targetPort` to the listen port and upgrade the release.

Recognize the signature: backends present, requests fail.

</details>

---

## 14. Failure matrix — Pod fails readiness

**Practice — Full Deployment Investigation**

```text
3. Pod fails readiness
```

<details>
<summary>Answer</summary>

Evidence: Pod `Running` and NotReady; Endpoints omit it; Events show probe failures. Layer is readiness. Prove with `kubectl get pods`, `kubectl describe pod <pod>`, and `kubectl get endpoints`. Recovery: fix the probe path or the application health endpoint.

The Deployment can succeed while the Service has no ready backends. GitOps may still report Synced.

</details>

---

## 15. Failure matrix — Service has no endpoints

**Practice — Full Deployment Investigation**

```text
4. Service has no endpoints
```

<details>
<summary>Answer</summary>

Evidence: `kubectl get endpoints myapp` is empty. Layer is selector versus Pod labels, or every Pod NotReady. Prove with `kubectl describe svc myapp` and `kubectl get pods --show-labels`. Recovery: restore matching labels or restore readiness.

Do not debug Ingress first. The Service has no backends.

</details>

---

## 16. Failure matrix — Ingress points to the wrong Service

**Practice — Full Deployment Investigation**

```text
5. Ingress points to wrong Service
```

<details>
<summary>Answer</summary>

Evidence: Ingress object exists; traffic hits the wrong application or returns 404; the intended Service may be healthy. Layer is Ingress rules. Prove by reading the Ingress backend Service name and testing that Service directly.

Recovery: point Ingress at the correct Service and let the controller reload. An Ingress resource without a working controller also fails this layer.

</details>

---

## 17. Failure matrix — Git change is not reconciled

**Practice — Full Deployment Investigation**

```text
6. Git change is not reconciled
```

<details>
<summary>Answer</summary>

Evidence: Git shows the new tag; cluster still runs the old image; controller status is not Synced. Layer is GitOps reconciliation. Prove with Git history, controller application status, and controller logs. Causes include a repo permission problem, a wrong path, or the controller down.

Recovery: restore controller access to Git and the cluster. Do not assume a merge equals a deploy.

</details>

---

## 18. Failure matrix — manual cluster change conflicts with Git

**Practice — Full Deployment Investigation**

```text
7. Manual cluster change conflicts with Git desired state
```

<details>
<summary>Answer</summary>

Evidence: `kubectl scale` or a live edit changes replicas; minutes later GitOps restores the Git value. Layer is drift versus desired state. Prove with `kubectl get deployment myapp` before and after reconciliation.

Recovery: commit the new desired state if the change should stay. Otherwise leave Git as source of truth. During an incident, know the controller may revert emergency edits.

</details>

---

## 19. Recall — Why Helm exists when Kubernetes already accepts YAML

1. Why does Helm exist when Kubernetes already accepts YAML manifests?

<details>
<summary>Answer</summary>

A real application needs many objects and different values per environment. Copying YAML for Dev, UAT, and Prod duplicates the design. Helm packages the resources and templates the values.

Kubernetes still creates Pods and Services. Helm is the package and release layer on top.

</details>

---

## 20. Recall — `Chart.yaml`, `values.yaml`, and `templates/`

2. What are `Chart.yaml`, `values.yaml` and `templates/` responsible for?

<details>
<summary>Answer</summary>

`Chart.yaml` describes the chart, including name, `version`, and `appVersion`. `values.yaml` holds default configuration. `templates/` holds Kubernetes manifests with Helm expressions.

Helm renders those three together into normal YAML. The API server never evaluates Helm syntax.

</details>

---

## 21. Recall — Helm chart versus Helm release

3. What is the difference between a Helm chart and a Helm release?

<details>
<summary>Answer</summary>

A chart is the package: templates plus default values. A release is an installed instance of that chart in a cluster. The same chart can create one release in Dev and another in Prod.

`helm list` shows releases. Upgrades and rollbacks operate on a release, not on the chart directory alone.

</details>

---

## 22. Recall — `version` versus `appVersion`

4. What is the difference between `version` and `appVersion` in a chart?

<details>
<summary>Answer</summary>

`version` is the chart version. It changes when Kubernetes configuration in the chart changes. `appVersion` describes the application version the chart represents.

They are related but not the same. A chart can change while the application binary stays the same.

</details>

---

## 23. Recall — How Helm turns a template into a Kubernetes manifest

5. How does Helm turn a template into a Kubernetes manifest?

<details>
<summary>Answer</summary>

Helm reads the chart, merges values, and replaces expressions such as `{{ .Values.replicaCount }}`. The output is normal Kubernetes YAML. Then Helm sends that YAML to the API server.

Flow: Chart + values → Helm renders templates → manifests → Kubernetes API → Deployment, Service, Pods.

</details>

---

## 24. Recall — Why `values-dev.yaml` and `values-prod.yaml`

6. Why would you use `values-dev.yaml` and `values-prod.yaml`?

<details>
<summary>Answer</summary>

The chart stays one reusable design. Environment files supply replica count, image tag, hostnames, and resources. Render or install with `-f values-prod.yaml`.

Prefer values files over a long `--set` list. Files are easier to audit and reproduce.

</details>

---

## 25. Recall — What `helm template` helps you troubleshoot

7. What does `helm template` help you troubleshoot?

<details>
<summary>Answer</summary>

`helm template myapp ./myapp -f values-prod.yaml` shows the manifests before the cluster is involved. Check image, replicas, Service port, hostname, and resource requests.

If the YAML is wrong, you have a template problem. If the YAML is right and Pods fail, you have a cluster or runtime problem.

</details>

---

## 26. Recall — What happens during `helm upgrade`

8. What happens conceptually during `helm upgrade`?

<details>
<summary>Answer</summary>

Helm renders the chart with current values and updates the existing release. Kubernetes then rolls the Deployment according to its spec. Inspect with `helm history myapp`.

You upgrade one named release. You do not install a second release with a new name for a routine change.

</details>

---

## 27. Recall — What Helm rollback actually rolls back

9. What is Helm rollback actually rolling back?

<details>
<summary>Answer</summary>

`helm rollback myapp <REVISION>` restores the managed release configuration toward an earlier revision. Kubernetes applies those earlier manifests.

It is not magic recovery for every failure. Database migrations and other application state may not reverse. Treat application rollback and database rollback as separate problems.

</details>

---

## 28. Recall — Why production secrets must not live in `values.yaml`

10. Why should production secrets not simply be stored in `values.yaml`?

<details>
<summary>Answer</summary>

`values.yaml` is source-controlled configuration. A password in Git leaks through history, clones, and PRs. Non-secret values such as database host belong in values.

Use Secret references and a secret manager. Also avoid `--set` of secrets, because they appear in shell history and CI logs.

</details>

---

## 29. Recall — What GitOps solves that Helm alone does not

11. What problem does GitOps solve that Helm alone does not?

<details>
<summary>Answer</summary>

Helm packages, templates, and manages releases. It does not continuously watch Git. GitOps makes Git the desired state and uses a controller to reconcile the cluster.

`helm upgrade` from a pipeline is still push-style CD. GitOps adds drift detection, Git audit, and pull-based apply.

</details>

---

## 30. Recall — What reconciliation means in GitOps

12. What does reconciliation mean in GitOps?

<details>
<summary>Answer</summary>

The controller compares desired state in Git with actual cluster state. If they differ, it converges the cluster toward Git. If they match, it does nothing.

This extends the Kubernetes controller model. The controller does not simply rerun the pipeline once.

</details>

---

## 31. Recall — Manual change to a GitOps-managed Deployment

13. What happens when someone manually changes a GitOps-managed Deployment?

<details>
<summary>Answer</summary>

The cluster temporarily drifts. The controller detects the difference. Depending on configuration, it restores the Git-defined state.

Treat live `kubectl` edits as temporary. Commit the change if the new state should last.

</details>

---

## 32. Recall — GitOps versus Terraform desired state

14. How is GitOps conceptually similar to Terraform's desired-state model?

<details>
<summary>Answer</summary>

Terraform compares configuration, state, and infrastructure. GitOps compares Git Kubernetes configuration with actual cluster state. Both detect divergence and reconcile deliberately.

Mechanisms differ. The principle is the same. GitOps does not replace Terraform for VNets, VPCs, or managed databases.

</details>

---

## 33. Recall — Does GitOps replace CI?

15. Does GitOps replace CI?

<details>
<summary>Answer</summary>

No. CI still builds, tests, scans, and publishes the image. GitOps handles CD by reconciling desired deployment state.

Two loops: CI builds things (code → image). CD applies things (Git state → cluster). GitOps means the cluster pulls. Nobody pushes to production by hand.

</details>

---

## 34. Recall — Push-style CD versus pull GitOps

16. What is the difference between push-style CD and pull/reconciliation-based GitOps?

<details>
<summary>Answer</summary>

Push-style CD: the pipeline authenticates to the cluster and runs `helm upgrade` or `kubectl`. After the job, nothing continuously corrects drift.

Pull GitOps: a controller in or near the cluster watches Git and applies. Developers and CI then need less direct write access to production Kubernetes APIs.

</details>

---

## 35. Recall — Can Helm and GitOps be used together?

17. Can Helm and GitOps be used together? How?

<details>
<summary>Answer</summary>

Yes. Helm is not GitOps by itself. A GitOps controller can consume Helm charts and values from Git. Architecture: Git → Helm chart and values → GitOps controller → Kubernetes.

Helm packages. GitOps reconciles. They are not competing replacements.

</details>

---

## 36. Recall — GitOps says synced but users cannot access it

18. If GitOps says the application is synced but users cannot access it, what would you investigate?

<details>
<summary>Answer</summary>

Investigate the traffic and runtime path, not only controller status. Confirm the rendered image, rollout, Ready Pods, Endpoints, Ingress, load balancer, and application response.

Synchronization is not availability. Use the Day 15 path after you confirm GitOps applied the right manifests.

</details>

---

## 37. Recall — Where Terraform or Bicep fit relative to GitOps

19. Where would Terraform/Bicep normally fit relative to GitOps?

<details>
<summary>Answer</summary>

Terraform or Bicep manage cloud infrastructure: VNet, VPC, cluster, managed database, load balancer plumbing. GitOps manages Kubernetes workloads and in-cluster configuration.

A mature platform uses both. Do not store the VNet in Helm. Do not manage Deployments only in ad-hoc Terraform applies.

</details>

---

## 38. Recall — Why “deployment succeeded” is not “application is healthy”

20. Why is “deployment succeeded” still different from “application is healthy”?

<details>
<summary>Answer</summary>

Helm or GitOps can apply valid objects while Pods are not Ready, Endpoints are empty, Ingress is wrong, or the app returns errors. “Git commit merged” does not mean production is healthy.

Verify with rollout status, Endpoints, logs, and user-facing checks. Desired-state success is one layer only.

</details>

---

## 39. Recall — What is a paved road, and which two loops does it offer?

21. What is a paved road, and which two loops does it offer as a product?

<details>
<summary>Answer</summary>

A paved road, also called a golden path, is a ready path for a new service. It includes a repo template, a pipeline, a deploy path, and monitoring defaults. Product teams ship on that path without opening a ticket for each step.

It offers the two loops as a product. The CI loop builds code into an image. The CD loop applies Git state to the cluster. The platform team owns the path. Application teams consume it.

</details>
