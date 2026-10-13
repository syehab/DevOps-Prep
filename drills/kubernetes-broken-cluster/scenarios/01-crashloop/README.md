# 01 — CrashLoopBackOff

**Timer:** 15 minutes.

## Symptom

```text
kubectl -n drill-01 get pods
# catalog-xxxx   0/1   CrashLoopBackOff
```

The Deployment exists. The container never stays running.

## Setup

```bash
kubectl apply -f drills/kubernetes-broken-cluster/scenarios/01-crashloop/setup.yaml
```

## Hints

1. `kubectl -n drill-01 describe pod` and read **Last State** and **Exit Code**.
2. `kubectl -n drill-01 logs deploy/catalog --previous`
3. The image is fine. The `command` is not.

## Solution

<details>
<summary>Open after the timer or after you tried the hints.</summary>

`command` is `echo boom; exit 1`. Every start exits 1. The kubelet restarts the container. That is CrashLoopBackOff.

Fix: change the command to a long-running process, for example `["sleep", "3600"]`, or use `nginx:1.27` with no custom command. Apply. Wait until `1/1 Running`.

```bash
kubectl -n drill-01 set image deploy/catalog catalog=nginx:1.27
# then remove the broken command via kubectl edit or a patched YAML
```

A patch that replaces the container:

```bash
kubectl -n drill-01 patch deploy catalog --type json -p '[
  {"op":"remove","path":"/spec/template/spec/containers/0/command"},
  {"op":"replace","path":"/spec/template/spec/containers/0/image","value":"nginx:1.27"}
]'
```

</details>
