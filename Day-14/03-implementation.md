# Day 14 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 14 teaches Kubernetes as a reconciliation system. You declare desired state. The control plane keeps actual state close to that declaration. This lab applies a Deployment and a ClusterIP Service **into your ShopSphere repo** on a `kind` cluster named `shopsphere`. You keep that cluster for later Days. You do not restart the product in `/tmp`.

---

## Goal

Create (or reuse) a local Kubernetes cluster with `kind`. Apply the ShopSphere namespace, an nginx stand-in Deployment, and a ClusterIP Service from Git. Delete a Pod and watch the ReplicaSet create a replacement. Then break the Service selector so Endpoints go empty. Restore the selector.

When you finish, you can explain desired state, replacement, and why a healthy Pod can still receive no Service traffic.

Time box: 45 to 75 minutes.

---

## Capstone stage

| Path in ShopSphere | What it adds |
|:--|:--|
| `k8s/namespace.yaml` | `shopsphere` namespace |
| `k8s/base/deployment.yaml` | Two replicas, `nginx:1.27` stand-in |
| `k8s/base/service.yaml` | ClusterIP |
| `docs/day-14-k8s-lab.md` | Pod names, endpoint counts |

Day 13 will replace `nginx` with the catalog API image. Today the stand-in is enough. Day 15 adds NetworkPolicy. Day 16 wraps this in Helm.

---

## What you need

```bash
docker version
kind version
kubectl version --client
```

Install `kind` v0.33.0 from [kind.sigs.k8s.io](https://kind.sigs.k8s.io). Pin the node image from [../capstone/VERSIONS.md](../capstone/VERSIONS.md):

```text
kindest/node:v1.37.0@sha256:a1ed56cfb0e7b93589bdf97c8cd566405a265939e3620fc4f5de89adff580ae5
```

You do not need AKS or EKS today. `minikube` is an alternative. Prefer `kind`. Do not mix contexts.

---

## Cost

`kind` on Docker: **USD 0.00**. Do not run `az aks create` or `eksctl create cluster`. Those paths belong to Day 17 and cost about USD 1.50-5.00 per session.

---

## Steps

1. Work in ShopSphere.

```bash
pwd
mkdir -p k8s/base docs
```

2. Create or reuse the cluster. Always name it `shopsphere` so later Days find it.

```bash
kind get clusters
```

If `shopsphere` is missing:

```bash
kind create cluster --name shopsphere --image kindest/node:v1.37.0@sha256:a1ed56cfb0e7b93589bdf97c8cd566405a265939e3620fc4f5de89adff580ae5
```

```bash
kubectl cluster-info
kubectl get nodes
```

Expected: at least one node `Ready`. Write `CREATED_KIND=yes` only if this Day created the cluster. Later Days should **keep** it.

3. Write `k8s/namespace.yaml`.

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: shopsphere
  labels:
    app.kubernetes.io/name: shopsphere
```

4. Write `k8s/base/deployment.yaml`.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: catalog
  namespace: shopsphere
  labels:
    app.kubernetes.io/name: shopsphere
spec:
  replicas: 2
  selector:
    matchLabels:
      app: catalog
  template:
    metadata:
      labels:
        app: catalog
    spec:
      containers:
        - name: catalog
          image: nginx:1.27
          ports:
            - containerPort: 80
          readinessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 2
            periodSeconds: 5
```

5. Write `k8s/base/service.yaml`.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: catalog
  namespace: shopsphere
spec:
  type: ClusterIP
  selector:
    app: catalog
  ports:
    - port: 80
      targetPort: 80
```

6. Apply from Git.

```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/base/deployment.yaml
kubectl apply -f k8s/base/service.yaml
kubectl -n shopsphere rollout status deployment/catalog
kubectl -n shopsphere get pods -l app=catalog -o wide
kubectl -n shopsphere get endpoints catalog
```

Expected: two Running Pods. Endpoints lists two IPs. `rollout status` exits 0.

7. Delete one Pod.

```bash
POD=$(kubectl -n shopsphere get pods -l app=catalog -o jsonpath='{.items[0].metadata.name}')
echo "$POD"
kubectl -n shopsphere delete pod "$POD"
kubectl -n shopsphere get pods -l app=catalog -w
```

Press Ctrl+C when you see two Running Pods again. The new name is not the name you deleted. The ReplicaSet created a replacement. You did not.

---

## Verify

- Manifests live under `k8s/` in ShopSphere, not only under `/tmp`.
- `kubectl -n shopsphere get deploy catalog` shows `2/2`.
- Endpoints for `catalog` has two addresses.
- A deleted Pod came back with a new name.
- The cluster name is `shopsphere`.

---

## Break and fix

### Failure 1 — selector mismatch

Edit `k8s/base/service.yaml`. Set `selector.app` to `catalog-wrong`. Apply.

```bash
kubectl apply -f k8s/base/service.yaml
kubectl -n shopsphere get endpoints catalog
kubectl -n shopsphere get pods -l app=catalog
```

Expected: Pods still Running. Endpoints is empty. Diagnose with `kubectl -n shopsphere describe svc catalog`. The event or selector line tells you the Service looks for a label the Pods do not have.

Restore `app: catalog`. Apply. Expected: two addresses return.

### Failure 2 — bad readiness probe

Set `readinessProbe.httpGet.path` to `/not-a-page`. Apply the Deployment.

```bash
kubectl apply -f k8s/base/deployment.yaml
kubectl -n shopsphere get pods -l app=catalog
kubectl -n shopsphere describe pod -l app=catalog | grep -A4 Readiness
```

Expected: Pods may be Running but **not Ready**. Endpoints goes empty even though the process is up. `curl` to the Service from a debug Pod would fail. Diagnose with `describe`, not with a restart.

Restore path `/`. Apply. Wait for Ready.

---

## Stretch

- `kubectl -n shopsphere logs deploy/catalog --tail=20`
- Add `resources.requests` (`cpu: 50m`, `memory: 64Mi`) so later HPA has a signal.

---

## Clean up

Delete the Deployment and Service if you will not continue today:

```bash
kubectl delete -f k8s/base/service.yaml
kubectl delete -f k8s/base/deployment.yaml
```

**Keep the `shopsphere` kind cluster** if you will do Day 15 this week. Delete it only when you are done with the Kubernetes Days:

```bash
kind delete cluster --name shopsphere
```

Do not run `az aks delete`. You did not create AKS.

Commit the YAML and notes to ShopSphere.

---

## Interview story

**Situation:** I needed to show that Kubernetes keeps a declared replica count, and that a Service is a separate object. **Task:** Put ShopSphere manifests in Git and exercise replacement plus a silent traffic fail. **Action:** I created `kind` cluster `shopsphere` on Kubernetes 1.37.0, applied a two-replica Deployment and ClusterIP Service, deleted a Pod, and watched a new name appear. I pointed the Service at `catalog-wrong` and Endpoints went empty while Pods stayed Running. I then broke the readiness path so Pods were Running but not Ready. **Result:** I can explain desired state, and I do not debug a "down" app by restarting a Ready-looking Pod when the Service or probe is the fault.

---

## Self-score checklist

- [ ] Manifests are in ShopSphere `k8s/`.
- [ ] Two replicas returned after a delete.
- [ ] I emptied Endpoints with a bad selector and I restored them.
- [ ] I saw Running-but-not-Ready from a bad probe.
- [ ] I did not create AKS.
- [ ] I kept or destroyed `kind` on purpose, not by habit.
