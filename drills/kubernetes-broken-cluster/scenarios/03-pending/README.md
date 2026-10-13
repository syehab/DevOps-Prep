# 03 — Pending (taints / resources / selector)

**Timer:** 15 minutes.

## Symptom

```text
kubectl -n drill-03 get pod stuck
# stuck   0/1   Pending
```

No node will take the Pod.

## Setup

```bash
kubectl apply -f drills/kubernetes-broken-cluster/scenarios/03-pending/setup.yaml
```

## Hints

1. `kubectl -n drill-03 describe pod stuck` — **Events** and **nodeSelector**.
2. `kubectl get nodes --show-labels`
3. There are two blockers. Fix both.

## Solution

<details>
<summary>Open after you tried.</summary>

Two reasons:

1. `nodeSelector: disktype=ssd-does-not-exist` matches no node.
2. `cpu: "16"` is more CPU than a typical kind node has.

`describe` events say `0/1 nodes are available: ... Insufficient cpu` and/or `node(s) didn't match Pod's node affinity/selector`.

Fix: remove the selector and set `cpu: 50m`. Delete the Pod (it has no controller) and apply a corrected spec.

Taint variant (stretch): `kubectl taint node <name> drill=true:NoSchedule` then a Pod without toleration stays Pending. Remove the taint when you finish: `kubectl taint node <name> drill=true:NoSchedule-`.

</details>
