# 05 — NetworkPolicy deny

**Timer:** 15 minutes.

kindnet does **not** enforce NetworkPolicy. If curl still returns 200 after setup, install Calico (see Day 15) or treat this as a read-the-object drill.

## Symptom

```text
kubectl -n drill-05 get endpoints catalog   # has an address
kubectl -n drill-05 exec client -- curl -m 5 http://catalog
# timeout
```

## Setup

```bash
kubectl apply -f drills/kubernetes-broken-cluster/scenarios/05-networkpolicy/setup.yaml
```

## Hints

1. Endpoints are full. This is not Day 14 selector mismatch.
2. `kubectl -n drill-05 get networkpolicy`
3. An Ingress policy with no `ingress:` rules denies all ingress.

## Solution

<details>
<summary>Open after you tried.</summary>

`deny-all-catalog` selects `app: catalog` and lists `Ingress` with no allow rule. That is default-deny for those Pods.

Fix: delete the policy, or add an `ingress` from the client Pod.

```bash
kubectl -n drill-05 delete networkpolicy deny-all-catalog
kubectl -n drill-05 exec client -- curl -sS -o /dev/null -w "%{http_code}\n" http://catalog
```

Expected: `200`.

</details>
