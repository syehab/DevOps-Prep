# Day 15 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 15 teaches Kubernetes networking as layers. Day 14 already showed empty Endpoints from a bad selector. This Day is the **harder sibling of that idea**: Endpoints can be full while a NetworkPolicy or a `targetPort` still drops traffic.

Work in **your ShopSphere repository** on the `shopsphere` kind cluster.

---

## Goal

Prove two failures that look like "the app is down":

1. Service has Endpoints, but `targetPort` is wrong. `curl` fails.
2. A NetworkPolicy denies the client. `curl` times out. Endpoints stay full.

When you finish, you can choose the next command from the symptom: Endpoints empty versus Endpoints full.

Time box: 60 to 80 minutes.

---

## Capstone stage

| Path | Adds |
|:--|:--|
| `k8s/base/networkpolicy.yaml` | Default-deny Ingress + allow from `role=client` |
| `k8s/base/client.yaml` | Temporary curl Pod |
| `docs/day-15-net-lab.md` | Two failure tables |

---

## What you need

Day 14 cluster `shopsphere`. Docker, `kind`, `kubectl`.

**NetworkPolicy on kind:** the default CNI (`kindnet`) does **not** enforce NetworkPolicy. If a deny policy does not drop traffic, recreate the cluster with Calico. That recreate deletes Day 14 workloads. Re-apply `k8s/`.

Calico manifest pin used here: `v3.29.3` (Project Calico release). If that URL 404s, use the version on [docs.tigera.io](https://docs.tigera.io).

---

## Cost

kind + Calico: **USD 0.00**. No Azure Load Balancer. No `type: LoadBalancer` on a cloud cluster.

---

## Steps

1. Re-apply Day 14 if the namespace is empty.

```bash
kubectl apply -f k8s/namespace.yaml -f k8s/base/deployment.yaml -f k8s/base/service.yaml
kubectl -n shopsphere get endpoints catalog
```

Expected: two addresses.

2. Add a client Pod. `k8s/base/client.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: client
  namespace: shopsphere
  labels:
    role: client
spec:
  containers:
    - name: curl
      image: curlimages/curl:8.11.1
      command: ["sleep", "3600"]
```

```bash
kubectl apply -f k8s/base/client.yaml
kubectl -n shopsphere wait --for=condition=Ready pod/client --timeout=90s
kubectl -n shopsphere exec client -- curl -sS -o /dev/null -w "%{http_code}\n" http://catalog.shopsphere.svc.cluster.local
```

Expected: `200`.

3. Break `targetPort`. Set `targetPort: 9090` in `k8s/base/service.yaml`. Apply.

```bash
kubectl apply -f k8s/base/service.yaml
kubectl -n shopsphere get endpoints catalog
kubectl -n shopsphere exec client -- curl -sS -m 5 http://catalog.shopsphere.svc.cluster.local || true
```

Expected: Endpoints still show Pod IPs. `curl` fails. Diagnose:

```bash
kubectl -n shopsphere describe svc catalog
```

`TargetPort` is 9090. The container listens on 80. Restore `targetPort: 80`. Confirm `200`.

4. Install Calico only if you need NetworkPolicy enforcement.

```bash
kind delete cluster --name shopsphere
cat <<'EOF' > /tmp/kind-calico.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  disableDefaultCNI: true
  podSubnet: "192.168.0.0/16"
nodes:
  - role: control-plane
    image: kindest/node:v1.37.0@sha256:a1ed56cfb0e7b93589bdf97c8cd566405a265939e3620fc4f5de89adff580ae5
EOF
kind create cluster --name shopsphere --config /tmp/kind-calico.yaml
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.3/manifests/calico.yaml
kubectl -n kube-system rollout status ds/calico-node --timeout=180s
```

Re-apply ShopSphere manifests. Repeat the client `curl` until it returns `200`. If Calico is not ready, Pods stay Pending. Diagnose with `kubectl get pods -n kube-system`.

5. Write `k8s/base/networkpolicy.yaml`.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: catalog-ingress
  namespace: shopsphere
spec:
  podSelector:
    matchLabels:
      app: catalog
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              role: client
      ports:
        - protocol: TCP
          port: 80
```

Apply it. Curl from `client` should still work. Then remove the `role: client` label:

```bash
kubectl -n shopsphere label pod client role-
kubectl -n shopsphere exec client -- curl -sS -m 5 http://catalog.shopsphere.svc.cluster.local || true
kubectl -n shopsphere get endpoints catalog
```

Expected: `curl` times out. Endpoints stay full. Diagnose with `kubectl -n shopsphere get networkpolicy` and `kubectl -n shopsphere describe networkpolicy catalog-ingress`.

Restore the label: `kubectl -n shopsphere label pod client role=client`. Confirm `200`.

If the deny does nothing, you are still on kindnet. Go to step 4.

---

## Verify

- You have a table: empty Endpoints (Day 14) versus full Endpoints + failed curl (this Day).
- `targetPort` 9090 failed while Endpoints stayed populated.
- NetworkPolicy deny failed curl without changing Endpoints (or you recorded that kindnet cannot enforce it, then you installed Calico).
- Manifests are in ShopSphere.

---

## Break and fix

The two failures **are** the lab. Add them to `docs/day-15-net-lab.md` as:

| Symptom | Endpoints | Next command |
|:--|:--|:--|
| curl fail, no addresses | empty | `describe svc` / labels |
| curl fail, addresses present | full | `targetPort`, probe, NetworkPolicy |

Do not restart the Deployment as the first action.

---

## Stretch

- Add an egress NetworkPolicy that allows only DNS (`kube-system` / port 53) plus the catalog Service.
- `kubectl -n shopsphere debug` a second client without the label.

---

## Clean up

Keep the cluster if you will do Day 16. Delete the client Pod if you want fewer running containers:

```bash
kubectl delete -f k8s/base/client.yaml
```

Keep the NetworkPolicy in Git. `make destroy-kind` deletes the cluster when you are done with the Kubernetes Days.

---

## Interview story

**Situation:** A teammate said the ShopSphere Service was down because curl failed. **Task:** Separate "no backends" from "backends exist but the path is blocked." **Action:** I pointed `targetPort` at 9090 and still saw Endpoints, while curl failed. I applied a NetworkPolicy that allowed only `role=client`, removed the label, and curl timed out with Endpoints still full. On kind I had to install Calico because kindnet does not enforce NetworkPolicy. **Result:** I start from Endpoints and policy, not from a restart.

---

## Self-score checklist

- [ ] I reproduced targetPort mismatch.
- [ ] I reproduced NetworkPolicy deny, or I installed Calico and then did.
- [ ] I wrote the symptom table.
- [ ] I did not create a cloud load balancer.
- [ ] Files live in ShopSphere.

> **Note:** Calico apply and kind recreate were **not executed in CI** in the authoring VM (no Docker). Commands match current kind and Calico docs as of 2026-10-13.
