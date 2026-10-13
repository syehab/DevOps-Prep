# Day 16 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 16 teaches Helm as the package and GitOps as the second loop. The old lab stopped at `helm rollback` and left GitOps as a note. This lab installs a chart, then installs **Argo CD** on `kind` and applies an **app-of-apps** that points at Dev and Prod.

Work in **your ShopSphere repository** on cluster `shopsphere`.

---

## Goal

Create `charts/shopsphere`. Render Dev and Prod values. Install the chart once with Helm so you see a release. Then install Argo CD and apply `gitops/bootstrap/root.yaml` plus `gitops/apps/shopsphere-dev.yaml`. Break the image tag, watch the sync stay healthy while the Deployment is not. Roll back or fix the tag in Git.

When you finish, you can say: CI builds the image, GitOps applies the manifest, a green sync is not a healthy Pod.

Time box: 75 to 90 minutes.

---

## Capstone stage

| Path | Adds |
|:--|:--|
| `charts/shopsphere/` | Chart, `values.yaml`, `values-dev.yaml`, `values-prod.yaml` |
| `gitops/bootstrap/root.yaml` | App-of-apps |
| `gitops/apps/shopsphere-dev.yaml` | Dev Application |
| `gitops/apps/shopsphere-prod.yaml` | Prod Application (sync off until Day 33) |
| `docs/day-16-gitops-lab.md` | `helm template` replica counts, Argo sync |

---

## What you need

```bash
helm version
kubectl version --client
kind get clusters
```

Helm 3.16+. Cluster `shopsphere` from Day 14. A GitHub repo Argo CD can read. If the repo is private, create a repo Secret. If you cannot expose Git, `helm install` is the required path and Argo stays apply-from-file.

---

## Cost

kind + Argo CD: **USD 0.00**. Do not create AKS today.

---

## Steps

1. Create the chart.

```bash
cd charts
helm create shopsphere
```

Edit `charts/shopsphere/values.yaml` so the image is `nginx` and the tag is `1.27`. Set `replicaCount` to `1` in the default file.

`charts/shopsphere/values-dev.yaml`:

```yaml
replicaCount: 1
image:
  repository: nginx
  tag: "1.27"
```

`charts/shopsphere/values-prod.yaml`:

```yaml
replicaCount: 2
image:
  repository: nginx
  tag: "1.27"
```

2. Render both.

```bash
helm template shopsphere charts/shopsphere -f charts/shopsphere/values-dev.yaml | grep -A2 replicas
helm template shopsphere charts/shopsphere -f charts/shopsphere/values-prod.yaml | grep -A2 replicas
```

Expected: Dev `replicas: 1`. Prod `replicas: 2`. Record both.

3. Install with Helm once (the CI loop half).

```bash
kubectl create namespace shopsphere-dev --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install shopsphere-dev charts/shopsphere \
  -n shopsphere-dev \
  -f charts/shopsphere/values-dev.yaml
helm list -n shopsphere-dev
```

Expected: status `deployed`. Then uninstall so GitOps owns the namespace:

```bash
helm uninstall shopsphere-dev -n shopsphere-dev
```

4. Install Argo CD. Pin v2.14.11. If that tag 404s, use the latest **v2.14.x** patch on GitHub releases, not `stable`.

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.14.11/manifests/install.yaml
kubectl -n argocd rollout status deploy/argocd-server --timeout=180s
```

5. Write `gitops/apps/shopsphere-dev.yaml`. Replace the repo URL with yours.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: shopsphere-dev
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/REPLACE_ME/shopsphere.git
    targetRevision: main
    path: charts/shopsphere
    helm:
      valueFiles:
        - values-dev.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: shopsphere-dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

`gitops/apps/shopsphere-prod.yaml` is the same with `values-prod.yaml` and namespace `shopsphere-prod`. Leave Prod `syncPolicy.automated` **unset** so Dev is the only auto-sync today. Day 33 promotes the same digest.

6. Write `gitops/bootstrap/root.yaml`.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: shopsphere-root
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/REPLACE_ME/shopsphere.git
    targetRevision: main
    path: gitops/apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

Commit and push these files to `main` **before** you apply the root. Argo CD reads Git, not your dirty working tree.

```bash
kubectl apply -f gitops/bootstrap/root.yaml
kubectl -n argocd get applications
```

Expected: `shopsphere-root` and then `shopsphere-dev`. `Synced` / `Healthy` after the first sync.

If the repo is private:

```bash
kubectl -n argocd create secret generic shopsphere-repo \
  --from-literal=type=git \
  --from-literal=url=https://github.com/REPLACE_ME/shopsphere.git \
  --from-literal=password="$GITHUB_TOKEN" \
  --from-literal=username=git
kubectl -n argocd label secret shopsphere-repo argocd.argoproj.io/secret-type=repository
```

If Git is not available, apply the rendered chart:

```bash
helm template shopsphere charts/shopsphere -f charts/shopsphere/values-dev.yaml \
  | kubectl apply -n shopsphere-dev -f -
```

Write `argocd git pull not executed` in the notes.

7. Watch a green sync hide a bad image. Set `image.tag` to `1.27-does-not-exist` in `values-dev.yaml`. Commit and push. Wait for sync.

```bash
kubectl -n shopsphere-dev get pods
kubectl -n argocd get application shopsphere-dev
```

Expected: Application may still be `Synced`. Pods show `ImagePullBackOff`. GitOps applied what you wrote. It did not make the image exist.

Put the tag back to `1.27`. Push. Wait for Ready.

---

## Verify

- `helm template` showed 1 and 2 replicas.
- Argo CD `argocd-server` is Ready, or you recorded the Git fallback.
- `shopsphere-root` points at `gitops/apps`.
- A bad tag produced `ImagePullBackOff` while you understood sync versus health.
- Prod Application exists but is not auto-synced.

---

## Break and fix

### Failure 1 — bad image (step 7)

Diagnose with `kubectl -n shopsphere-dev describe pod` and `Events: Failed to pull image`. Do not delete Argo CD.

### Failure 2 — Application stuck `Unknown` / `ComparisonError`

```bash
kubectl -n argocd logs deploy/argocd-repo-server --tail=50
kubectl -n argocd get application shopsphere-dev -o yaml | grep -A20 status
```

Usual causes: wrong `repoURL`, missing repo Secret, path typo. Fix Git. Do not `helm install` on top of an Application that already owns the namespace.

---

## Stretch

- `argocd login --core` and `argocd app sync shopsphere-dev`
- Add `targetRevision: HEAD` versus a Git tag. Prefer a tag in Prod.

---

## Clean up

Keep Argo CD if you will do Days 17, 33, or 37.

```bash
kubectl delete -f gitops/bootstrap/root.yaml
kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.14.11/manifests/install.yaml
kind delete cluster --name shopsphere   # only if you are done with K8s Days
```

`make destroy-kind` is the cluster teardown. Cost stays USD 0.00.

---

## Interview story

**Situation:** ShopSphere had raw YAML and no promotion story. **Task:** Package the app with Helm and let GitOps apply Dev. **Action:** I created `charts/shopsphere` with Dev and Prod values, rendered replica counts, then installed Argo CD v2.14.11 on `kind`. I applied an app-of-apps that watches `gitops/apps`. I pushed `nginx:1.27-does-not-exist` and saw `ImagePullBackOff` while the Application was still Synced. **Result:** I can explain the two loops: CI builds the digest, CD reconciles Git, and sync is not health.

---

## Self-score checklist

- [ ] Chart exists with two values files.
- [ ] App-of-apps YAML is in Git.
- [ ] I saw ImagePullBackOff after a bad tag, or I recorded why Git was not reachable.
- [ ] Prod is not auto-synced.
- [ ] Files live in ShopSphere.

> **Note:** Argo CD install and Helm install were **not executed in CI** (no cluster in the authoring VM).
