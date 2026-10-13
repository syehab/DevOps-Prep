# 04 — Kubernetes restart finder

**Timer:** 15 minutes.

## Symptom

`kubectl get pods -A` is a wall of names. One catalog Pod has restarted twelve times. You want a script you can run on saved JSON when you have no cluster.

## Task

Write `find_restarts.py` that reads `kubectl get pods -A -o json` (or the fixture) and prints `namespace/name restarts=N` for restartCount ≥ 5.

```bash
python3 drills/scripting/04-k8s-restarts/find_restarts.py \
  drills/scripting/04-k8s-restarts/pods.json
```

Expected: one line, `shopsphere/catalog-b restarts=12`.

## Hints

1. `status.containerStatuses[].restartCount` is the field.
2. Take the max count if a Pod has two containers.
3. Live path later: `kubectl get pods -A -o json > /tmp/pods.json`.

## Solution

<details>
<summary>Open after the timer or after you tried the hints.</summary>

The fixture has three Pods. Only `catalog-b` is ≥ 5. `coredns-x` has 1. `catalog-a` has 0.

`kind` was **not** required. The JSON shape matches `kubectl` 1.29+ `v1.PodList`.

</details>
