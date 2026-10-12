# Day 16 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 16 teaches Helm as the package and release layer on Kubernetes, and GitOps as the two-loop operating model. This lab makes the Helm half concrete. You create a chart, render it, install it on a local cluster, upgrade it, then break it with a bad image tag and roll back. GitOps reconciliation stays a design note. You do not install a GitOps controller here.

Work in a temporary directory. Do not create charts or releases inside the DevOps-Prep course repository. Prefer `kind` for the cluster. If Helm or `kind` is missing, still use the real commands in this file. Install Helm from [helm.sh](https://helm.sh). Install `kind` from [kind.sigs.k8s.io](https://kind.sigs.k8s.io). Then come back and run the same commands. Do not invent other cluster or package tools.

---

## Goal

Create a Helm chart with `helm create`, or copy a tiny chart with the same three core files. Render Dev and Prod values with `helm template` so you see replica counts before Kubernetes is involved. Install the release on a local `kind` cluster if one is available. Upgrade the release, then point the image tag at a name that does not exist.

Watch the Deployment fail, often with `ImagePullBackOff`. Roll the release back with `helm rollback`. Confirm Pods recover. When you finish, you can explain chart versus release, template versus cluster, upgrade versus rollback, and why a Helm success is not the same as a healthy application.

Time box: 45 to 75 minutes. Cost stays at ₹0. Stop when template output matches the values files, rollback has restored a good revision, notes are written, and cleanup has uninstalled the release. If this lab created the `kind` cluster, delete that cluster too.

---

## What you need

You need a shell, Helm 3, `kubectl`, Docker, and `kind`. Helm renders charts and manages releases. `kind` runs Kubernetes nodes as Docker containers. `kubectl` talks to the API Server. Check what is already on your `PATH`:

```bash
command -v helm
command -v kubectl
command -v docker
command -v kind
helm version
kubectl version --client
```

If `helm` is missing, install Helm from [helm.sh](https://helm.sh). Follow that site. Come back and run the same `helm create`, `helm template`, `helm install`, `helm upgrade`, `helm rollback`, and `helm uninstall` commands below. The commands do not change. If `kind` is missing, install it from [kind.sigs.k8s.io](https://kind.sigs.k8s.io). You can still run `helm create` and `helm template` without a cluster. `helm install`, `helm upgrade`, `helm rollback`, and `helm uninstall` need a cluster.

`minikube` is an alternative local cluster. Prefer `kind` for this lab. Do not mix both tools against the same kubeconfig context unless you already know which context is active. Do not use a production cluster. Do not create AKS, EKS, or cloud load balancers.

Create a throwaway directory under `/tmp`. Keep notes in `day-16-helm-lab.md` in that directory. Record command output, replica counts from `helm template`, release revisions from `helm history`, and whether this lab created the cluster. Do not paste kubeconfig secrets, tokens, or registry passwords into a shared place.

This lab uses the public `nginx` image from a default `helm create` chart. It does not need Azure, AWS, or a paid registry. You pull that image through the cluster runtime when the Pod starts. Uninstall the release and delete any `kind` cluster you created when you finish.

---

## Steps

1. Create a lab directory and enter it. Confirm the path is under `/tmp`. Stay in this directory for every file you write.

```bash
LAB_DIR="/tmp/day-16-helm-lab-$$"
mkdir -p "$LAB_DIR"
cd "$LAB_DIR"
pwd
```

Write the date and the path at the top of `day-16-helm-lab.md`. Write one sentence: you will render a chart, install a release, then recover from a bad image tag with `helm rollback`.

2. Create the chart. `helm create` writes `Chart.yaml`, `values.yaml`, and `templates/`. If Helm is not installed yet, install it from [helm.sh](https://helm.sh) and run the same command. As a fallback, copy a tiny chart by hand: `Chart.yaml`, `values.yaml`, and one Deployment template that reads `.Values.replicaCount` and `.Values.image`. Prefer `helm create`.

```bash
helm create myapp
ls
find myapp -maxdepth 2 -type f
```

Do not deploy yet. Identify `Chart.yaml`, `values.yaml`, and the files under `templates/`. Copy the `version` and `appVersion` fields from `Chart.yaml` into your notes. They are related. They are not the same thing.

3. Write environment values next to the chart, not inside a copied YAML tree. Dev uses one replica. Prod uses three replicas and an explicit nginx tag.

```yaml
# values-dev.yaml
replicaCount: 1

image:
  tag: "1.27"
```

```yaml
# values-prod.yaml
replicaCount: 3

image:
  tag: "1.27"
```

The chart stays one reusable design. These files supply the values that change.

4. Render both environments. Helm replaces template expressions and prints normal Kubernetes YAML. The API Server is not involved yet.

```bash
helm template myapp ./myapp -f values-dev.yaml
helm template myapp ./myapp -f values-prod.yaml
```

Find the Deployment in each output. Dev should show one replica. Prod should show three. Confirm the image becomes `nginx:1.27` (or the repository from `values.yaml` plus that tag). If the YAML is wrong, fix the values file before you install. Copy both replica lines into your notes.

5. Decide whether you need a new cluster. List `kind` clusters if `kind` is installed. If you already have a disposable local cluster and `kubectl get nodes` works, you may use it. Record the context. If you have no cluster, create one named `day16`.

```bash
kind get clusters
kubectl config current-context
```

Create a cluster only when you need one:

```bash
kind create cluster --name day16
```

Wait until the command exits. Then confirm the API answers:

```bash
kubectl cluster-info
kubectl get nodes
```

Write `CREATED_KIND=yes` in your notes if you ran `kind create cluster --name day16`. Write `CREATED_KIND=no` if you reused an existing cluster. Cleanup uses that note.

If `kind` is not installed and you have no cluster, install `kind` from [kind.sigs.k8s.io](https://kind.sigs.k8s.io) and run the same `kind create cluster --name day16` command. You can keep going through `helm template` while you do that. Still type the install, upgrade, rollback, and uninstall commands in this file. They are the real Helm release commands. Do not substitute a made-up tool.

6. Install the chart as release `myapp` with Dev values. Helm creates a release, then Kubernetes creates the resources.

```bash
helm install myapp ./myapp -f values-dev.yaml
```

Inspect the release and the cluster:

```bash
helm list
helm status myapp
helm get values myapp
kubectl get all
```

`helm list` shows releases. `helm status` shows this release. `kubectl get all` shows the Kubernetes objects Helm created. Copy the revision number into your notes. It should be `1`.

7. Upgrade the same release with Prod values. Do not install a second release with a new name.

```bash
helm upgrade myapp ./myapp -f values-prod.yaml
```

Inspect history and the Deployment:

```bash
helm history myapp
helm get manifest myapp
kubectl get deployment
kubectl get pods
```

`helm history` should show revision `1` and revision `2`. Prod values should raise the replica count to three. Wait until the new Pods are Ready. Record the history table in your notes.

```bash
kubectl rollout status deployment/myapp
```

The default `helm create` chart names the Deployment `myapp` when the release and the chart share that name. If `rollout status` reports a different name, use the name `kubectl get deployment` printed.

---

## Verify

Read the notes as if you are on a call. You should name the chart files, the two replica counts from `helm template`, and the release revisions from `helm history`.

Check these points:

- `helm create myapp` produced `Chart.yaml`, `values.yaml`, and `templates/`, or your tiny chart has those same three parts.
- `helm template` with `values-dev.yaml` rendered one replica. `helm template` with `values-prod.yaml` rendered three replicas.
- `helm install myapp ./myapp -f values-dev.yaml` created release `myapp`. `helm list` shows it.
- `helm upgrade myapp ./myapp -f values-prod.yaml` added a new revision. `helm history myapp` lists more than one revision.
- `kubectl get pods` shows Ready Pods for the good image tag before you break the release.

If `helm template` shows the wrong replica count, read the values file you passed with `-f`. Helm does not use a values file you did not name. If install fails because there is no cluster, finish the template steps and keep the install command in your notes. Then create the `kind` cluster and run install again.

---

## Break and fix

A bad image tag is a desired-state problem that becomes a runtime problem. Helm will still render and apply the manifest. Kubernetes then cannot pull the image. Rollback restores an earlier release revision. It does not reverse database migrations. This lab has no database.

1. Write a values file that keeps three replicas and points the tag at a name that does not exist.

```yaml
# values-bad.yaml
replicaCount: 3

image:
  tag: "not-a-real-tag-day16"
```

Render it first. Confirm the Deployment image is wrong before you touch the cluster.

```bash
helm template myapp ./myapp -f values-bad.yaml
```

2. Upgrade the live release with that file. Then inspect history and Pods.

```bash
helm upgrade myapp ./myapp -f values-bad.yaml
helm history myapp
kubectl get pods
kubectl get pods -o wide
```

Pods should leave Ready. Events often show `ImagePullBackOff` or `ErrImagePull`. Describe one Pod and copy the image name from the events into your notes.

```bash
kubectl describe pod -l app.kubernetes.io/name=myapp
```

If that label prints nothing, run `kubectl get pods` and describe a Pod by name. The failure is the tag. The chart structure is still valid. `helm template` already proved that.

3. Roll back to the last good revision. Read `helm history myapp` and pick the revision that used `values-prod.yaml` and `nginx:1.27`. That is usually revision `2`.

```bash
helm rollback myapp 2
```

If history shows a different good revision, use that number in place of `2`. Then verify:

```bash
helm status myapp
helm history myapp
kubectl rollout status deployment/myapp
kubectl get pods
```

Pods should become Ready again. The image should be the good tag. Helm rollback restored the managed release configuration toward that earlier revision. Record the new history row. Rollback creates another revision. It does not delete the failed one.

Do not leave the bad tag applied. Confirm Ready Pods before you clean up.

---

## Clean up

Uninstall the Helm release. This removes the release and the resources Helm created, subject to how the chart was designed.

```bash
helm uninstall myapp
```

Verify:

```bash
helm list
kubectl get all
```

`helm list` should no longer show `myapp`. Lab Pods, Services, and Deployments for this release should be gone. Do not delete shared cluster resources that belong to other workloads. Do not delete a shared chart repository or production GitOps configuration.

If your notes say `CREATED_KIND=yes`, delete the cluster you created. This removes the `kind` nodes for `day16`.

```bash
kind delete cluster --name day16
```

If your notes say `CREATED_KIND=no`, do not run `kind delete cluster`. You reused a cluster that you did not create for this lab.

Leave the lab directory and remove it, including the chart:

```bash
cd /tmp
rm -rf "$LAB_DIR"
```

If you want to keep notes, copy `day-16-helm-lab.md` out before `rm -rf`. You created no Azure or AWS resources, so there is no resource group or VPC to delete.

---

## Interview story

I treat Helm as the package and release layer, not as GitOps. I keep one chart and change environment values. I run `helm template` before I install so I can see replica count and image tag without asking the cluster. I install one named release, then I upgrade that same release when Prod values change. When I ship a bad image tag, Helm still applies the manifest and Kubernetes fails to pull. I do not debug the Service first. I roll back to the last good revision with `helm rollback`, then I confirm Ready Pods. GitOps would add a controller that pulls desired state from Git. This lab used push-style Helm on a local cluster so I could see upgrade, failure, and rollback on purpose.
