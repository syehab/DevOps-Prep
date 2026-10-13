# Day 34 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 34 teaches reliability: rolling updates, health, HPA, PDB, and drain. The old lab only did `rollout undo`. This lab adds **HPA**, a **PDB**, and a drain that the PDB blocks.

Work in **your ShopSphere repository** on `kind` cluster `shopsphere`.

---

## Goal

Keep two catalog replicas. Add resource requests. Add an HPA (CPU 70 percent, min 2, max 4). Add a PDB `minAvailable: 1`. Cordon and drain the only node and watch the drain **wait**. Lower the PDB or uncordon to recover. Then ship a bad image and `rollout undo`.

Time box: 70 to 90 minutes.

---

## Capstone stage

| Path | Adds |
|:--|:--|
| `k8s/base/hpa.yaml` | HorizontalPodAutoscaler |
| `k8s/base/pdb.yaml` | PodDisruptionBudget |
| `charts/shopsphere/templates/` | Same objects if you already moved to Helm |
| `docs/day-34-reliability.md` | Drain log + undo |

---

## What you need

`kind`, `kubectl`, metrics-server for HPA. On kind, metrics-server needs a kubelet TLS skip.

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.7.2/components.yaml
kubectl -n kube-system patch deploy metrics-server --type json \
  -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
kubectl -n kube-system rollout status deploy/metrics-server
```

If metrics-server never becomes Ready, you can still apply the HPA object. `kubectl get hpa` may show `<unknown>` CPU. Record that. The PDB and drain still work.

---

## Cost

kind: **USD 0.00**. Do not create a cloud load balancer.

---

## Steps

1. Ensure Day 14 Deployment exists with `resources.requests.cpu: 50m` and `memory: 64Mi`. Apply it.

2. Write `k8s/base/hpa.yaml`.

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: catalog
  namespace: shopsphere
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: catalog
  minReplicas: 2
  maxReplicas: 4
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

```bash
kubectl apply -f k8s/base/hpa.yaml
kubectl -n shopsphere get hpa catalog
```

3. Write `k8s/base/pdb.yaml`.

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: catalog
  namespace: shopsphere
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: catalog
```

```bash
kubectl apply -f k8s/base/pdb.yaml
kubectl -n shopsphere get pdb catalog
```

Expected: `ALLOWED DISRUPTIONS` is `1` when two pods are Ready (one may be evicted).

4. Drain the node.

```bash
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
echo "$NODE"
kubectl drain "$NODE" --ignore-daemonsets --delete-emptydir-data
```

On a one-node kind cluster the drain **cannot** place replacements. The PDB then blocks eviction when it would drop available Pods below `minAvailable`. Expected: drain waits or errors with a PDB message. Diagnose:

```bash
kubectl -n shopsphere describe pdb catalog
kubectl get events -A --field-selector reason=FailedEviction
```

Recover:

```bash
kubectl uncordon "$NODE"
```

If drain already evicted everything, `kubectl -n shopsphere get deploy catalog` should still show desired 2. The ReplicaSet creates Pods when the node is schedulable again.

5. Bad rollout, then undo.

```bash
kubectl -n shopsphere set image deploy/catalog catalog=nginx:1.27-does-not-exist
kubectl -n shopsphere rollout status deploy/catalog --timeout=30s || true
kubectl -n shopsphere rollout undo deploy/catalog
kubectl -n shopsphere rollout status deploy/catalog
```

---

## Verify

- HPA object exists (`minReplicas: 2`).
- PDB exists.
- You captured a drain that waited or failed because of the PDB, **or** you recorded that a one-node cluster cannot reschedule and you uncordoned.
- `rollout undo` restored Ready Pods.

---

## Break and fix

### Failure 1 — PDB blocks drain (step 4)

That is the intended break. Do not `--disable-eviction` unless you are exercising the unsafe escape. Write why production drains must respect PDBs.

### Failure 2 — HPA cannot read metrics

`kubectl top pods -n shopsphere` fails. Diagnose metrics-server logs. Patch `--kubelet-insecure-tls` on kind. Do not set `minReplicas: 1` to "fix" missing metrics.

---

## Stretch

- Write a Karpenter versus Cluster Autoscaler note (Day 17 / Day 37). HPA adds Pods. Node autoscaling adds nodes.
- `kubectl -n shopsphere debug` and generate CPU load to watch HPA if metrics work.

---

## Clean up

Keep HPA and PDB in Git. Keep the cluster for Day 37.

```bash
kubectl uncordon "$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')"
```

`make destroy-kind` when the Kubernetes week is over.

---

## Interview story

**Situation:** ShopSphere on kind could roll images but could not explain disruption. **Task:** Add HPA and a PDB, then drain. **Action:** I applied `autoscaling/v2` HPA (2–4) and a PDB `minAvailable: 1`. I ran `kubectl drain` on the only node and used `describe pdb` when eviction stopped. I uncordoned, then forced a bad image and recovered with `rollout undo`. **Result:** I can separate scale-out (HPA) from node replacement (drain / autoscaler) and I do not disable the PDB to make drain "work."

---

## Self-score checklist

- [ ] HPA and PDB YAML are in ShopSphere.
- [ ] I drained and I read the PDB.
- [ ] I undid a bad rollout.
- [ ] I uncordoned the node.
- [ ] Files live in ShopSphere.

> **Note:** drain / metrics-server were **not executed in CI** (no cluster).
