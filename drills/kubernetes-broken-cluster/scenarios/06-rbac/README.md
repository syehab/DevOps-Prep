# 06 — RBAC Forbidden

**Timer:** 15 minutes.

## Symptom

```text
kubectl -n drill-06 exec catalog -- kubectl -n drill-06 get pods
# Error from server (Forbidden): pods is forbidden:
# User "system:serviceaccount:drill-06:reader" cannot list resource "pods"
```

## Setup

```bash
kubectl apply -f drills/kubernetes-broken-cluster/scenarios/06-rbac/setup.yaml
kubectl -n drill-06 wait --for=condition=Ready pod/catalog --timeout=90s
```

## Hints

1. `kubectl -n drill-06 auth can-i get pods --as=system:serviceaccount:drill-06:reader`
2. `kubectl -n drill-06 describe role reader`
3. The Role allows ConfigMaps only.

## Solution

<details>
<summary>Open after you tried.</summary>

ServiceAccount `reader` is bound to a Role that can `get`/`list` ConfigMaps only. `kubectl get pods` is a different resource.

Fix for the drill: add `pods` to `rules.resources` (and maybe `get`, `list`).

```bash
kubectl -n drill-06 patch role reader --type json -p '[
  {"op":"add","path":"/rules/0/resources/-","value":"pods"}
]'
kubectl -n drill-06 exec catalog -- kubectl -n drill-06 get pods
```

Expected: the `catalog` row. In production, prefer a new Role for the new verb, and keep least privilege.

`kubectl auth can-i` is the diagnosis command. Do not grant `cluster-admin` to "make it work."

</details>
