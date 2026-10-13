# Kubernetes broken-cluster drills

Eleven timed failures on **kind**. Each drill is one symptom, 15 minutes, then hints, then a solution in `<details>`. No gotchas. The setup file is the whole break.

Use cluster `shopsphere` (from the capstone) or create `drill-k8s`.

```bash
kind create cluster --name drill-k8s --image kindest/node:v1.37.0@sha256:a1ed56cfb0e7b93589bdf97c8cd566405a265939e3620fc4f5de89adff580ae5
```

Cost: **USD 0.00**. These drills do not create AKS.

## How to run one drill

1. Start a 15-minute timer.
2. Apply only that folder's `setup.yaml` (or `setup.sh`).
3. Read `README.md` **Symptom**. Do not open Hints yet.
4. Diagnose with `kubectl get`, `describe`, `logs`, `events`.
5. Fix the cluster. Do not delete the namespace unless the solution says so.
6. If you stick, open Hints in order. Then open Solution.

Reset:

```bash
kubectl delete ns drill-01 drill-02 drill-03 drill-05 drill-06 drill-07 drill-08 drill-09 drill-10 drill-11 --ignore-not-found
# drill-04 (CoreDNS) has its own reset.sh — it touches kube-system
```

## Scenarios

| # | Folder | Symptom you will see |
|:--|:--|:--|
| 01 | [01-crashloop](scenarios/01-crashloop/) | `CrashLoopBackOff` |
| 02 | [02-oomkilled](scenarios/02-oomkilled/) | `OOMKilled` |
| 03 | [03-pending](scenarios/03-pending/) | `Pending` (taint or resources) |
| 04 | [04-coredns](scenarios/04-coredns/) | DNS lookup fails |
| 05 | [05-networkpolicy](scenarios/05-networkpolicy/) | curl timeout, Endpoints full |
| 06 | [06-rbac](scenarios/06-rbac/) | `Forbidden` |
| 07 | [07-bad-probe](scenarios/07-bad-probe/) | Running, not Ready |
| 08 | [08-pvc-pending](scenarios/08-pvc-pending/) | PVC / Pod `Pending` |
| 09 | [09-cert-expiry](scenarios/09-cert-expiry/) | TLS handshake fail |
| 10 | [10-pdb-drain](scenarios/10-pdb-drain/) | drain blocked |
| 11 | [11-image-pull](scenarios/11-image-pull/) | `ImagePullBackOff` / `ErrImagePull` |

## Interview use

Pick two drills. Talk out loud. Start with `kubectl get pods -A` and events. That is the evidence habit Day 14 and Day 15 teach.

> **Remember:** The first command is get and describe, not delete.

## Not executed in CI

The authoring VM did not run Docker or `kind`. Manifests use `apps/v1`, `v1`, `policy/v1`, `networking.k8s.io/v1`, and `nginx:1.27` / `busybox:1.36`. Apply them on your machine.
