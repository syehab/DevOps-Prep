# 04 — CoreDNS failure

**Timer:** 15 minutes.

**Warning:** This drill scales CoreDNS to 0. Every namespace loses in-cluster DNS until you reset. Use a disposable kind cluster.

## Symptom

A Pod can reach an IP. It cannot resolve `kubernetes.default.svc.cluster.local`.

```text
nslookup kubernetes.default.svc.cluster.local
# ;; connection timed out; no servers could be reached
```

## Setup

```bash
bash drills/kubernetes-broken-cluster/scenarios/04-coredns/setup.sh
```

Then start a debug Pod:

```bash
kubectl -n drill-04 run net --image=busybox:1.36 --restart=Never -- sleep 3600
kubectl -n drill-04 exec net -- nslookup kubernetes.default
```

## Hints

1. `kubectl -n kube-system get deploy coredns`
2. `kubectl -n kube-system get pods -l k8s-app=kube-dns`
3. Service `kube-dns` may still exist. The endpoints are empty.

## Solution

<details>
<summary>Open after you tried.</summary>

`setup.sh` ran `kubectl -n kube-system scale deploy/coredns --replicas=0`. Endpoints for `kube-dns` are empty. kubelet still has the cluster DNS IP in `/etc/resolv.conf`, but nothing answers.

Fix:

```bash
kubectl -n kube-system scale deploy/coredns --replicas=2
kubectl -n kube-system rollout status deploy/coredns
kubectl -n drill-04 exec net -- nslookup kubernetes.default
```

Expected: an address in `10.96.0.1` or your cluster IP range.

Do not "fix" this by hard-coding IPs in the application.

</details>
