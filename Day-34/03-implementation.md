# Day 34 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 34 teaches reliability as traffic control, health, and a known-good recovery path. This lab makes a rolling Deployment visible on a local cluster. You apply two replicas, change the image, wait with `kubectl rollout status`, then ship a tag that does not exist. The rollout sticks. You recover with `kubectl rollout undo`. Kubernetes rolling update is the hands-on stand-in for ShopSphere. Blue/green and canary stay design notes from the lesson. They are not required steps here.

Work in a temporary directory. Do not apply manifests inside the DevOps-Prep course repository. Prefer `kind` over `minikube`. If neither tool is installed, still write the YAML and type the same `kubectl` commands in this file. Install `kind` from [kind.sigs.k8s.io](https://kind.sigs.k8s.io). Then create the cluster and run those commands. Do not invent other cluster tools or flags.

---

## Goal

Create a local Kubernetes cluster with `kind` if you do not already have a disposable cluster. Apply a Deployment with two replicas of a known-good nginx image. Confirm both Pods are Ready. Change the image with `kubectl set image` or by applying a new image in the YAML. Wait with `kubectl rollout status`. Then set a tag that does not exist.

Watch the rollout stick, often with `ImagePullBackOff`. Recover with `kubectl rollout undo`. Confirm both replicas return to the known-good image. When you finish, you can explain rolling replacement, why `rollout status` is not the same as "pipeline green," and why undo is the recovery path for this lab.

Time box: 45 to 75 minutes. Cost stays at ₹0. Stop when the good rollout finished, the bad tag stuck, undo restored Ready Pods, notes are written, and cleanup has deleted the lab objects. If this lab created the `kind` cluster, delete that cluster too.

---

## What you need

You need a shell, Docker, `kind` or `minikube`, and `kubectl`. `kind` runs Kubernetes nodes as Docker containers. `kubectl` talks to the API Server. Check what is already on your `PATH`:

```bash
command -v docker
command -v kind
command -v minikube
command -v kubectl
docker version
kubectl version --client
```

If `kind` is missing, install it from [kind.sigs.k8s.io](https://kind.sigs.k8s.io). Follow that site. Come back and run the same commands in this file. `minikube` is an alternative local cluster. Prefer `kind` for this lab. Do not mix both tools against the same kubeconfig context unless you already know which context is active. Do not use a production cluster. Do not create AKS, EKS, or cloud load balancers.

If you have no cluster yet, still write `deployment.yaml` and keep every `kubectl` command below. Those commands do not change. Create the cluster when you can, then run them. Do not skip writing the manifest because the API is not up.

Create a throwaway directory under `/tmp`. Keep notes in `day-34-rollout-lab.md` in that directory. Record the context, replica count, image before and after the change, whether `rollout status` succeeded, and whether this lab created the cluster. Do not paste kubeconfig secrets, tokens, or registry passwords into a shared place.

This lab uses the public `nginx:1.27` image. It does not need Azure, AWS, or a paid registry. You pull that image through the cluster runtime when the Pod starts. Delete the Deployment and any `kind` cluster you created when you finish.

---

## Steps

1. Create a lab directory and enter it. Confirm the path is under `/tmp`. Stay in this directory for every file you write.

```bash
LAB_DIR="/tmp/day-34-rollout-lab-$$"
mkdir -p "$LAB_DIR"
cd "$LAB_DIR"
pwd
```

Write the date and the path at the top of `day-34-rollout-lab.md`. Write one sentence: you will roll two replicas to a new image, then recover from a bad tag with `kubectl rollout undo`.

2. Decide whether you need a new cluster. List `kind` clusters if `kind` is installed. If you already have a disposable local cluster and `kubectl get nodes` works, you may use it. Record the context. If you have no cluster, create one named `day34`.

```bash
kind get clusters
kubectl config current-context
```

Create a cluster only when you need one:

```bash
kind create cluster --name day34
```

If you use `minikube` instead, start it only when you have no cluster:

```bash
minikube start
```

`kind create cluster --name day34` writes kubeconfig for that cluster. It does not deploy nginx. Wait until the command exits. Then confirm the API answers:

```bash
kubectl cluster-info
kubectl get nodes
kubectl get pods -A
```

`cluster-info` shows control-plane endpoints. `get nodes` lists worker capacity. `get pods -A` lists workloads in all namespaces. You are asking the API for cluster state. You are not talking to a node by hand.

Write `CREATED_KIND=yes` in your notes if you ran `kind create cluster --name day34`. Write `CREATED_MINIKUBE=yes` if you ran `minikube start` for this lab. Write `CREATED_KIND=no` and `CREATED_MINIKUBE=no` if you reused an existing cluster. Cleanup uses those notes.

If you still have no cluster, write `deployment.yaml` now. Keep typing the `kubectl` commands. Install `kind` from [kind.sigs.k8s.io](https://kind.sigs.k8s.io), create `day34`, and run the same commands. Do not invent a substitute for `kubectl rollout status` or `kubectl rollout undo`.

3. Write `deployment.yaml`. This Deployment declares two nginx replicas. The container name is `nginx`. Kubernetes should keep two Pods. You do not create Pods by hand.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - containerPort: 80
```

4. Apply the Deployment. `kubectl apply` sends desired state to the API Server.

```bash
kubectl apply -f deployment.yaml
```

If the cluster is not up, this command fails. Keep the file. Create the cluster, then run the same apply. The YAML does not change.

5. Wait until both replicas are Ready. `kubectl rollout status` watches the Deployment until the new ReplicaSet is available, or until it reports a problem. It does not mean users are healthy in Production. It means this rolling update reached the declared replica count.

```bash
kubectl rollout status deployment/nginx
kubectl get deployment nginx
kubectl get pods -l app=nginx -o wide
```

You should see `2/2` on the Deployment and two Running Pods. Record the Pod names and the image `nginx:1.27`.

6. Inspect rollout history before you change the image. History is the recovery map for undo.

```bash
kubectl rollout history deployment/nginx
```

Copy the revision number into your notes. The first successful apply is usually revision `1`.

7. Roll to a second known-good tag. The live Pods still run `nginx:1.27`. Change the container named `nginx` to `nginx:1.25` with `kubectl set image`. That is a real rolling update. You can instead edit `image:` in `deployment.yaml` and apply again. Both paths update desired state. This lab uses `set image` first.

```bash
kubectl set image deployment/nginx nginx=nginx:1.25
kubectl rollout status deployment/nginx
```

Wait until status reports success. Then inspect:

```bash
kubectl get deployment nginx
kubectl get pods -l app=nginx -o wide
kubectl describe deployment nginx
kubectl rollout history deployment/nginx
```

Record the new revision and the image on the Pods. One ReplicaSet should be replacing the other. Both replicas should become Ready again. This is rolling replacement: old Pods leave, new Pods start, desired count stays two.

If you prefer apply instead of `set image`, change `image:` in `deployment.yaml` to `nginx:1.25`, then run:

```bash
kubectl apply -f deployment.yaml
kubectl rollout status deployment/nginx
```

Use one path for the good change. Do not mix a half-edited YAML with a live `set image` without recording which source of truth you used.

---

## Verify

Read your notes as if you are on a call. You should name the Deployment, the replica count, the good image, and the command that waited for the rollout.

Check these points:

- `kubectl get nodes` returned at least one Ready node, or you wrote the YAML and commands while you install `kind`.
- `kubectl get deployment nginx` shows `2/2` after the good image change.
- `kubectl rollout status deployment/nginx` returned success for that good change.
- `kubectl rollout history deployment/nginx` lists more than one revision after the image change.
- `kubectl get pods -l app=nginx` shows two Running Pods on the good tag before you break the rollout.

If a Pod stays Pending, run `kubectl describe pod <pending-pod>` and read scheduling events. Pending is not `ImagePullBackOff`. If you have no cluster, stop after the YAML exists and the commands are in your notes. Create the cluster, then continue from apply. Do not invent a fake status output.

---

## Break and fix

A bad image tag is a desired-state problem that becomes a runtime problem. `kubectl set image` still updates the Deployment. Kubernetes then cannot pull the image. New Pods stick. Old Ready Pods may remain until the rolling update replaces them. `kubectl rollout undo` moves the Deployment back to the previous ReplicaSet. It does not reverse a database migration. This lab has no database.

1. Set a tag that does not exist. Keep the container name `nginx`.

```bash
kubectl set image deployment/nginx nginx=nginx:not-a-real-tag-day34
```

2. Watch status with a timeout. Without a timeout, `rollout status` waits. The bad tag will not become Ready. `--timeout` is a real flag on `kubectl rollout status`.

```bash
kubectl rollout status deployment/nginx --timeout=60s
kubectl get pods -l app=nginx
kubectl get replicasets
kubectl rollout history deployment/nginx
```

Status should fail or time out. At least one new Pod should leave Ready. Events often show `ImagePullBackOff` or `ErrImagePull`. Describe a stuck Pod and copy the image name from the events into your notes.

```bash
kubectl get pods -l app=nginx
kubectl describe pod <stuck-pod-name>
```

Replace `<stuck-pod-name>` with a real name from `kubectl get pods`. Record that the Deployment still asks for two replicas and that the new ReplicaSet cannot become available. The rollout is stuck. The previous known-good Pods may still be running. That overlap is why rolling updates need spare capacity and a recovery command.

3. Undo the rollout. This returns the Deployment to the previous revision. `kubectl rollout undo` is the recovery command for this lab.

```bash
kubectl rollout undo deployment/nginx
kubectl rollout status deployment/nginx
```

If history shows that the previous revision is not the known-good image, pick the revision that had `nginx:1.25` or `nginx:1.27` and pass it. `--to-revision` is a real flag on `kubectl rollout undo`. Do not run undo twice unless the first undo did not land on the good image.

```bash
kubectl rollout history deployment/nginx
kubectl rollout undo deployment/nginx --to-revision=2
kubectl rollout status deployment/nginx
```

Use the revision number from history, not a guessed number. Then confirm:

```bash
kubectl get deployment nginx
kubectl get pods -l app=nginx -o wide
kubectl describe pod -l app=nginx
```

Pods should become Ready again. The image should be the good tag, not `nginx:not-a-real-tag-day34`. Record the new history row. Undo creates another revision. It does not delete the failed one.

Do not leave the bad tag applied. Confirm `2/2` Ready before you clean up. Recovery in this lab is Ready Pods on the known-good image, not only that the undo command returned.

---

## Clean up

Delete the lab Deployment. This lab used the default namespace, so delete the object you applied.

```bash
kubectl delete -f deployment.yaml
```

Confirm it is gone:

```bash
kubectl get deployment nginx
kubectl get pods -l app=nginx
```

Those gets should report that the resources were not found, or they should show no nginx Pods. Do not delete shared cluster resources that belong to other workloads.

If your notes say `CREATED_KIND=yes`, delete the cluster you created. This removes the `kind` nodes for `day34`.

```bash
kind delete cluster --name day34
```

If your notes say `CREATED_MINIKUBE=yes`, stop and delete that profile only when you created it for this lab:

```bash
minikube delete
```

If your notes say `CREATED_KIND=no` and `CREATED_MINIKUBE=no`, do not delete the cluster. You reused a cluster that you did not create for this lab.

Leave the lab directory and remove it:

```bash
cd /tmp
rm -rf "$LAB_DIR"
```

If you want to keep notes, copy `day-34-rollout-lab.md` out before `rm -rf`. You created no Azure or AWS resources, so there is no resource group or VPC to delete.

---

## Interview story

I treat a Deployment as rolling traffic change, not as a pipeline badge. I apply two replicas of a known-good image, then I change the image with `kubectl set image` or apply. I wait with `kubectl rollout status` so I know the new ReplicaSet became available. When I ship a tag that does not exist, status times out and Pods show `ImagePullBackOff`. I do not debug DNS first. I run `kubectl rollout undo`, wait for status again, and confirm Ready Pods on the last good image. Recovery is users served again, which in this lab means `2/2` Ready, not only that undo exited. Capacity, health, and a known-good revision are the same reliability model I would use for ShopSphere.
