# 10 — PDB-blocked drain

**Timer:** 15 minutes.

## Symptom

```text
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data
# cannot evict pod as it would violate the pod's disruption budget
```

or the command waits forever.

## Setup

```bash
kubectl apply -f drills/kubernetes-broken-cluster/scenarios/10-pdb-drain/setup.yaml
kubectl -n drill-10 rollout status deploy/catalog
```

Then:

```bash
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
kubectl drain "$NODE" --ignore-daemonsets --delete-emptydir-data --timeout=30s || true
```

On one-node kind you also cannot reschedule. Read the PDB anyway.

## Hints

1. `kubectl -n drill-10 get pdb catalog`
2. `minAvailable: 2` with `replicas: 2` means **zero** allowed disruptions.
3. `kubectl uncordon` before you leave.

## Solution

<details>
<summary>Open after you tried.</summary>

The PDB requires two available Pods. Evicting one would drop availability to 1. The eviction API denies the drain.

Fix for a voluntary drain in a real cluster: raise replica count, or set `minAvailable: 1` / `maxUnavailable: 1` so one Pod can leave.

Fix for this drill:

```bash
kubectl -n drill-10 patch pdb catalog --type merge -p '{"spec":{"minAvailable":1}}'
kubectl uncordon "$NODE"
```

Do not use `--disable-eviction` as the normal path. That flag exists to break the guarantee.

Always uncordon when you finish a one-node kind drain.

</details>
