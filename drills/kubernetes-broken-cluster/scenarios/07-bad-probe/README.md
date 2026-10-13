# 07 — Bad readiness probe

**Timer:** 15 minutes.

## Symptom

```text
kubectl -n drill-07 get pods
# catalog-xxxx   0/1   Running
kubectl -n drill-07 get endpoints catalog
# (no addresses)
```

The container is up. The Service has no backends.

## Setup

```bash
kubectl apply -f drills/kubernetes-broken-cluster/scenarios/07-bad-probe/setup.yaml
```

## Hints

1. Ready column is `0/1` while Phase is Running.
2. `kubectl -n drill-07 describe pod` — Readiness probe failed.
3. nginx serves `/`. It does not serve `/healthz-does-not-exist`.

## Solution

<details>
<summary>Open after you tried.</summary>

`readinessProbe.httpGet.path` is a path that returns 404. The kubelet never marks the Pod Ready. The Endpoints controller omits it.

Fix the path to `/`.

```bash
kubectl -n drill-07 patch deploy catalog --type json -p '[
  {"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/"}
]'
kubectl -n drill-07 rollout status deploy/catalog
kubectl -n drill-07 get endpoints catalog
```

Expected: one address. Do not delete the Pod to "restart" a probe.

</details>
