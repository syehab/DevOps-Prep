# 11 — Image pull authentication

**Timer:** 15 minutes.

## Symptom

```text
kubectl -n drill-11 get pods
# catalog-xxxx   0/1   ErrImagePull  or  ImagePullBackOff
```

`describe` events: `Failed to pull image` and often `secret missing-registry not found` or `unauthorized`.

## Setup

```bash
kubectl apply -f drills/kubernetes-broken-cluster/scenarios/11-image-pull/setup.yaml
```

## Hints

1. `kubectl -n drill-11 describe pod` — Events at the bottom.
2. The image name is not on a public registry you can pull.
3. `imagePullSecrets` names a Secret that does not exist.

## Solution

<details>
<summary>Open after you tried.</summary>

Two stacked problems (both realistic):

1. `imagePullSecrets: missing-registry` — the Secret was never created. kubelet cannot authenticate.
2. `ghcr.io/shopsphere-does-not-exist/catalog:1.0.0` is not a real repository.

Fix for the drill: point at a public image and remove the missing secret.

```bash
kubectl -n drill-11 patch deploy catalog --type json -p '[
  {"op":"remove","path":"/spec/template/spec/imagePullSecrets"},
  {"op":"replace","path":"/spec/template/spec/containers/0/image","value":"nginx:1.27"}
]'
kubectl -n drill-11 rollout status deploy/catalog
```

In production you create a `kubernetes.io/dockerconfigjson` Secret and reference it. You do not put the password in the Pod spec.

</details>
