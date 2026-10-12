# Day 14 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 14 teaches Kubernetes as a reconciliation system. You declare desired state. The control plane keeps actual state close to that declaration. This lab makes that loop visible with a Deployment and a ClusterIP Service. You apply nginx, watch a deleted Pod come back, then break the Service selector so endpoints go empty. You restore the selector and confirm traffic targets exist again.

Work in a temporary directory. Do not apply manifests inside the DevOps-Prep course repository. Prefer `kind` over `minikube`. If neither tool is installed, install `kind` from [kind.sigs.k8s.io](https://kind.sigs.k8s.io). Then run the same commands below. Write the YAML even before the cluster exists. The commands do not change. Do not invent other cluster tools.

---

## Goal

Create a local Kubernetes cluster with `kind` if you do not already have a disposable cluster. Apply an nginx Deployment and a ClusterIP Service. Confirm Pods, describe one Pod, then delete a Pod and watch the ReplicaSet create a replacement.

Next, change the Service selector so it matches no Pod. Confirm endpoints are empty while the Pods stay Running. Restore the selector and confirm endpoints return. When you finish, you can explain desired state, replacement, and why a healthy Pod can still receive no Service traffic.

Time box: 45 to 75 minutes. Cost stays at ₹0. Stop when replacement works, the broken selector is restored, notes are written, and cleanup has removed the lab resources. If you created the `kind` cluster for this lab, delete that cluster too.

---

## What you need

You need a shell, Docker, `kind`, and `kubectl`. `kind` runs Kubernetes nodes as Docker containers. `kubectl` talks to the API Server. Check what is already on your `PATH`:

```bash
command -v docker
command -v kind
command -v kubectl
docker version
kind version
kubectl version --client
```

If `kind` is missing, install it from [kind.sigs.k8s.io](https://kind.sigs.k8s.io). Follow that site. Come back and run the same commands in this file. You also need `kubectl`. The Kubernetes client talks to the cluster that `kind` creates. `minikube` is an alternative local cluster. Prefer `kind` for this lab. Do not mix both tools against the same kubeconfig context unless you already know which context is active.

Create a throwaway directory under `/tmp`. Keep notes in `day-14-k8s-lab.md` in that directory. Record command output, Pod names, endpoint counts, and the selector before and after the break. Do not paste tokens or kubeconfig secrets into a shared place.

This lab uses the public `nginx:1.27` image from the lesson. It does not need Azure, AWS, AKS, or EKS. You pull that image through the cluster runtime when the Pod starts. Delete the Deployment, the Service, and any `kind` cluster you created when you finish.

---

## Steps

1. Create a lab directory and enter it. Confirm the path is under `/tmp`. Stay in this directory for every file you write.

```bash
LAB_DIR="/tmp/day-14-k8s-lab-$$"
mkdir -p "$LAB_DIR"
cd "$LAB_DIR"
pwd
```

2. Decide whether you need a new cluster. List `kind` clusters if `kind` is installed. If you already have a disposable local cluster and `kubectl get nodes` works, you may use it. Record the context. If you have no cluster, create one named `day14`.

```bash
kind get clusters
kubectl config current-context
```

Create a cluster only when you need one:

```bash
kind create cluster --name day14
```

`kind create cluster --name day14` writes kubeconfig for that cluster. It does not deploy nginx. Wait until the command exits. Then confirm the API answers:

```bash
kubectl cluster-info
kubectl get nodes
kubectl get pods -A
```

`cluster-info` shows control-plane endpoints. `get nodes` lists worker capacity. `get pods -A` lists workloads in all namespaces. You are asking the API for cluster state. You are not talking to a node by hand.

Write `CREATED_KIND=yes` in your notes if you ran `kind create cluster --name day14`. Write `CREATED_KIND=no` if you reused an existing cluster. Cleanup uses that note.

3. Write `deployment.yaml`. This Deployment declares two nginx replicas. The Pod template label is `app: nginx`. The container listens on port 80. Kubernetes should keep two Pods. You do not create Pods by hand.

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

4. Write `service.yaml`. This Service is ClusterIP. ClusterIP is the default Service type and stays inside the cluster. The selector must match the Pod label `app: nginx`. Port 80 on the Service forwards to container port 80.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx
spec:
  type: ClusterIP
  selector:
    app: nginx
  ports:
    - port: 80
      targetPort: 80
```

5. Apply both objects. `kubectl apply` sends desired state to the API Server.

```bash
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
```

6. Inspect the workload. You should see a Deployment, a ReplicaSet, two Pods, and a ClusterIP Service. Record the Pod names.

```bash
kubectl get deployment nginx
kubectl get replicasets
kubectl get pods -l app=nginx -o wide
kubectl get service nginx
kubectl describe service nginx
kubectl get endpoints nginx
```

Endpoints should list Pod addresses when the selector matches. If endpoints are empty now, stop and compare the Service selector with the Pod labels before you continue.

7. Describe one Pod. Copy a Pod name from the previous list. Events, IP, and container status live in `describe`. The Pod IP is not a permanent endpoint. A replacement Pod can get a new IP.

```bash
kubectl get pods -l app=nginx
kubectl describe pod <pod-name>
```

Replace `<pod-name>` with a real name from `kubectl get pods`. Record the node, the Pod IP, and the image `nginx:1.27`.

8. Scale to three replicas. The lesson command is `kubectl scale`. Kubernetes should create a third Pod so actual count matches desired count.

```bash
kubectl scale deployment nginx --replicas=3
kubectl get pods -l app=nginx
```

You should see three Pods. The Deployment still owns the ReplicaSet. The ReplicaSet owns the Pods. You manage the Deployment.

9. Delete one Pod and watch the replacement. Desired replica count is still three. Kubernetes should create a new Pod. Do not repair the deleted instance by hand.

```bash
kubectl get pods -l app=nginx
kubectl delete pod <pod-name>
kubectl get pods -l app=nginx -w
```

Stop the watch with `Ctrl-C` after the replacement appears. Record the old Pod name and the new Pod name. They should differ. That is self-healing of the instance, not a fix of application code.

---

## Verify

Read your notes as if you are on a call. You should name the Deployment, the Service type, and why a deleted Pod came back.

Check these points:

- `kubectl get nodes` returned at least one Ready node.
- `kubectl get deployment nginx` shows `3/3` after the scale.
- `kubectl get pods -l app=nginx` shows three Running Pods.
- `kubectl describe pod` showed events and a Pod IP for nginx.
- After `kubectl delete pod`, a new Pod appeared. `kubectl get pods -l app=nginx -w` showed that replacement.
- `kubectl get service nginx` shows type `ClusterIP`.
- Before the break, `kubectl get endpoints nginx` listed addresses.

If a Pod stays Pending, run `kubectl describe pod <pending-pod>` and read scheduling events. Pending is not CrashLoopBackOff. The container may never have started.

---

## Break and fix

The Service finds Pods by label selector. Healthy Pods still receive no traffic when the selector matches nothing. Break that on purpose, observe, then restore.

1. Change only the selector in `service.yaml` to a name that no Pod uses:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx
spec:
  type: ClusterIP
  selector:
    app: wrong-name
  ports:
    - port: 80
      targetPort: 80
```

2. Apply the broken Service and inspect endpoints. Pods can stay Running. Endpoints should be empty.

```bash
kubectl apply -f service.yaml
kubectl get pods -l app=nginx
kubectl get endpoints nginx
kubectl describe service nginx
```

Record that the Pods are still there and that endpoints have no addresses. The application identity is the Service. The Pod labels no longer match.

3. Restore the selector to `app: nginx`. Write the original Service back to `service.yaml`. Apply again. Endpoints should return.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx
spec:
  type: ClusterIP
  selector:
    app: nginx
  ports:
    - port: 80
      targetPort: 80
```

```bash
kubectl apply -f service.yaml
kubectl get endpoints nginx
kubectl describe service nginx
```

Endpoints should list Pod addresses again. The Pods did not need a restart. You fixed the Service selector, not the containers.

Do not leave `app: wrong-name` applied. The next section deletes the objects. Restore first so you have seen both states.

---

## Clean up

Delete the lab Deployment and Service. If you used a dedicated namespace, you would delete that namespace. This lab used the default namespace, so delete the two objects.

```bash
kubectl delete -f deployment.yaml
kubectl delete -f service.yaml
```

Confirm they are gone:

```bash
kubectl get deployment nginx
kubectl get service nginx
kubectl get pods -l app=nginx
```

Those gets should report that the resources were not found, or they should show no nginx Pods. Do not delete shared cluster resources that belong to other workloads.

If your notes say `CREATED_KIND=yes`, delete the cluster you created. This removes the `kind` nodes for `day14`.

```bash
kind delete cluster --name day14
```

If your notes say `CREATED_KIND=no`, do not run `kind delete cluster`. You reused a cluster that you did not create for this lab.

Leave the lab directory and remove it:

```bash
cd /tmp
rm -rf "$LAB_DIR"
```

If you want to keep notes, copy `day-14-k8s-lab.md` out before `rm -rf`. You created no Azure or AWS resources, so there is no resource group or VPC to delete.

---

## Interview story

I treat Kubernetes as a reconciliation system. I declare a Deployment and a ClusterIP Service, then the API Server stores that desired state. When I delete a Pod, the ReplicaSet creates a replacement because actual replicas fell below the declared count. I do not repair that instance by hand. A Service selects Pods by labels, not by a stored Pod IP. When I change the selector to a name that matches nothing, endpoints go empty even though the Pods stay Running. I restore the selector and traffic targets return. That is the mental model I use in production: desired state, replacement, and selector match.
