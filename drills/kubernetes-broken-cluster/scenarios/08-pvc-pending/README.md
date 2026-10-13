# 08 — PVC Pending

**Timer:** 15 minutes.

## Symptom

```text
kubectl -n drill-08 get pvc data
# data   Pending
kubectl -n drill-08 get pod writer
# writer   Pending
```

The Pod waits for a volume that never binds.

## Setup

```bash
kubectl apply -f drills/kubernetes-broken-cluster/scenarios/08-pvc-pending/setup.yaml
```

## Hints

1. `kubectl -n drill-08 describe pvc data`
2. `kubectl get storageclass`
3. kind ships `standard` (local-path) on many installs. The claim asks for `does-not-exist`.

## Solution

<details>
<summary>Open after you tried.</summary>

`storageClassName: does-not-exist` matches no provisioner. The PVC stays Pending. The Pod has `persistentVolumeClaim` and cannot schedule.

Fix: delete the Pod and PVC. Recreate the PVC with `storageClassName: standard` (or the name `kubectl get sc` shows). Re-apply the Pod.

```bash
kubectl -n drill-08 delete pod writer pvc data
# edit setup or apply a fixed PVC, then the Pod
```

If no StorageClass exists, install [local-path-provisioner](https://github.com/rancher/local-path-provisioner) or drop the volume for this drill.

</details>
