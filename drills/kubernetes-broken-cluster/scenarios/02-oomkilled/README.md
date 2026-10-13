# 02 — OOMKilled

**Timer:** 15 minutes.

## Symptom

```text
kubectl -n drill-02 get pod hog
# hog   0/1   OOMKilled   or   CrashLoopBackOff after OOM
```

`describe` shows **Reason: OOMKilled** and **Exit Code: 137**.

## Setup

```bash
kubectl apply -f drills/kubernetes-broken-cluster/scenarios/02-oomkilled/setup.yaml
```

## Hints

1. `kubectl -n drill-02 describe pod hog` — Last State, Exit Code 137.
2. Look at `resources.limits.memory`. Compare it to the `dd` size.
3. Raising the limit **or** shrinking the write both work. Pick one and say why.

## Solution

<details>
<summary>Open after you tried.</summary>

The container writes 64Mi into `/dev/shm` and the limit is 16Mi. The kubelet (cgroup) kills the process. That is OOM (out of memory).

Fix A — raise the limit to `128Mi` (lab only).

Fix B — lower `count=8` so the write fits.

Do not remove the limit in production as the first reflex. A limit without a request also makes scheduling less predictable. Here both request and limit exist.

```bash
kubectl -n drill-02 delete pod hog
# re-apply a fixed YAML with memory limit 128Mi
```

</details>
