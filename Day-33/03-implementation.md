# Day 33 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 33 teaches a delivery pipeline as a supply chain. One Git commit produces one artifact. Dev, UAT, and Production run **those same bytes**. The old lab tagged a local image in `/tmp`. Day 29 added the AWS backend and GitHub OIDC so CI can plan. This Day is the **harder sibling of Day 29**: you promote the **same image digest** from Dev to Prod **through GitOps**. You do not rebuild for Production.

Work in **your ShopSphere repository**. You need the Day 16 chart and app-of-apps. If they are missing, create them from [Day-16/03-implementation.md](../Day-16/03-implementation.md) first.

---

## Goal

Pin one digest in `charts/shopsphere/values-dev.yaml`. Copy that digest into `values-prod.yaml` with a promotion script. Render both Helm releases and prove the image field matches. Turn on Prod auto-sync (Day 16 left it off). Then break the rule: change Prod to a new tag from a second build. Show the digests differ. Restore the first digest.

Time box: 60 to 80 minutes.

---

## Capstone stage

| Path in ShopSphere | What it adds |
|:--|:--|
| `charts/shopsphere/values-dev.yaml` | Image **digest** (not a moving tag) |
| `charts/shopsphere/values-prod.yaml` | Same digest, replica count 2 |
| `charts/shopsphere/templates/deployment.yaml` | Image reference uses `@sha256:` |
| `gitops/promote-digest.sh` | Copies digest Dev → Prod |
| `gitops/apps/shopsphere-prod.yaml` | Auto-sync **on** for this Day |
| `docs/day-33-promotion.md` | Both rendered image lines, digest equality |

---

## What you need

```bash
helm version
command -v docker && docker version
kind get clusters
python3 --version
```

Helm 3.16+ is required to render. Docker is optional (to print a real digest). `kind` plus Argo CD from Day 16 is the live path. If Helm is missing, still write the values files and the script. Python can prove the two YAML files share a digest.

You do not need AWS, ECR, or Azure for the required path. Day 29 already showed the OIDC plan role.

---

## Cost

| Path | Estimated USD | Why |
|:--|:--|:--|
| Helm template + Python digest compare | **0.00** | Local only |
| Argo CD on `kind` | **0.00** | Laptop RAM |
| Push the digest to ACR/ECR | **0.00–0.50** | Storage. Delete unused tags. |

Do not write "INR 0" if you pushed to a registry.

---

## Steps

1. Open ShopSphere. Confirm the Day 16 chart exists.

```bash
ls charts/shopsphere/values-dev.yaml charts/shopsphere/values-prod.yaml gitops/apps/shopsphere-prod.yaml
mkdir -p gitops docs
```

2. Pick a digest. If Docker has `nginx:1.27`:

```bash
docker pull nginx:1.27
docker image inspect nginx:1.27 --format '{{index .RepoDigests 0}}'
```

`RepoDigests` stays empty until the image was pulled from a registry. Expected shape: `nginx@sha256:` plus 64 hex characters. Copy the `sha256:...` part.

If Docker is missing, use this **placeholder** and write `digest not pulled — placeholder used`:

```text
sha256:f00dbd7fb5c5d3c4411c1d71c2891ddfd3d50253e9dcb4b64f2a3a4b5c6d7e8f
```

That placeholder is not a real nginx digest. Replace it before Prod. The promotion mechanic does not care. Equality cares.

3. Change the chart so the Deployment uses a digest. In `charts/shopsphere/templates/deployment.yaml` find the image line. Helm's `helm create` default is:

```yaml
image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
```

Replace it with:

```yaml
image: "{{ .Values.image.repository }}@{{ .Values.image.digest }}"
```

A digest reference does **not** also take a tag. `nginx:1.27@sha256:...` is valid OCI. This lab uses `repository@digest` so a moving tag cannot sneak in.

4. Pin both values files.

`charts/shopsphere/values-dev.yaml`:

```yaml
replicaCount: 1
image:
  repository: nginx
  digest: sha256:REPLACE_WITH_DIGEST
```

`charts/shopsphere/values-prod.yaml`:

```yaml
replicaCount: 2
image:
  repository: nginx
  digest: sha256:REPLACE_WITH_DIGEST
```

Put the **same** `sha256:` string in both files by hand once. The script will do it next time.

5. Write `gitops/promote-digest.sh`. Real bash. No invented flags.

```bash
#!/usr/bin/env bash
set -euo pipefail
# Copy image.digest from Dev values to Prod values.
# Usage: gitops/promote-digest.sh

dev="charts/shopsphere/values-dev.yaml"
prod="charts/shopsphere/values-prod.yaml"

digest="$(python3 - <<'PY'
from pathlib import Path
text = Path("charts/shopsphere/values-dev.yaml").read_text().splitlines()
for line in text:
    line = line.strip()
    if line.startswith("digest:"):
        print(line.split(":", 1)[1].strip())
        break
else:
    raise SystemExit("digest missing in values-dev.yaml")
PY
)"

python3 - "$digest" <<'PY'
import sys
from pathlib import Path
digest = sys.argv[1]
path = Path("charts/shopsphere/values-prod.yaml")
lines = path.read_text().splitlines()
out = []
for line in lines:
    if line.strip().startswith("digest:"):
        indent = line[: len(line) - len(line.lstrip())]
        out.append(f"{indent}digest: {digest}")
    else:
        out.append(line)
path.write_text("\n".join(out) + "\n")
print("promoted", digest, "->", path)
PY
```

```bash
chmod +x gitops/promote-digest.sh
./gitops/promote-digest.sh
```

6. Render both. Prove equality.

```bash
helm template shopsphere-dev charts/shopsphere -f charts/shopsphere/values-dev.yaml \
  | grep -E "image:|replicas:" | head
helm template shopsphere-prod charts/shopsphere -f charts/shopsphere/values-prod.yaml \
  | grep -E "image:|replicas:" | head
```

Expected: replica counts differ (1 vs 2). Image lines are **identical** and contain `@sha256:`.

Python check you can run even without Helm:

```bash
python3 - <<'PY'
from pathlib import Path

def digest(path):
    for line in Path(path).read_text().splitlines():
        if line.strip().startswith("digest:"):
            return line.split(":", 1)[1].strip()
    raise SystemExit(path + " has no digest")

d = digest("charts/shopsphere/values-dev.yaml")
p = digest("charts/shopsphere/values-prod.yaml")
print("dev ", d)
print("prod", p)
assert d == p and d.startswith("sha256:"), (d, p)
print("same digest")
PY
```

This Python check was **executed** in the authoring environment against a pair of sample values files.

7. Turn on Prod auto-sync. Edit `gitops/apps/shopsphere-prod.yaml` so it matches Dev, with `values-prod.yaml` and namespace `shopsphere-prod`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: shopsphere-prod
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/REPLACE_ME/shopsphere.git
    targetRevision: main
    path: charts/shopsphere
    helm:
      valueFiles:
        - values-prod.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: shopsphere-prod
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

Commit and push **before** Argo CD reads Git. If Argo CD is not installed, `kubectl apply` is not required. Helm template is the evidence.

```bash
kubectl apply -f gitops/apps/shopsphere-prod.yaml
kubectl -n argocd get applications
```

Expected: both Applications Synced. Pods in both namespaces use the same digest (`kubectl -n shopsphere-prod get pod -o jsonpath='{.items[0].spec.containers[0].image}'`).

---

## Verify

- Both values files contain the same `sha256:` digest.
- Helm image lines match, or the Python assert printed `same digest`.
- Prod replica count is 2. Dev is 1. That is config, not a new artifact.
- Prod Application auto-sync is on.
- Notes say Day 29 was identity and state. This Day is promotion.

---

## Break and fix

Do both failures.

### Failure 1 — rebuild for Production

Change only Prod:

```yaml
digest: sha256:000000000000000000000000000000000000000000000000000000000000dead
```

Run the Python check. Expected: assertion fails. That is a second artifact. It is not a promotion. Restore with `./gitops/promote-digest.sh`. Run the check again. Expected: `same digest`.

### Failure 2 — tag instead of digest

Put `tag: "1.27"` back and remove `digest`. Render. The image line becomes a tag. Tags move. Yesterday's `1.27` is not today's. Restore the digest image line. Diagnose with the rendered manifest, not with `docker ps`.

---

## Stretch

- Add a GitHub Environment `prod` with a required reviewer that must approve the values-prod digest change.
- Record the Git SHA that produced the digest in `docs/day-33-promotion.md`.
- On AWS week, point the same digest at ECR. Do not retag by rebuilding.

---

## Clean up

Keep the values files. They are the capstone stage.

If you applied Argo Prod auto-sync and you want Day 16 behaviour back, set Prod `syncPolicy.automated` to unset. Do not delete the cluster if later Days need it.

```bash
# optional
kubectl delete application shopsphere-prod -n argocd
```

No cloud bill unless you pushed to a registry. Delete unused ACR/ECR tags if you did.

---

## Interview story

**Situation:** Day 29 gave ShopSphere an S3 backend and GitHub OIDC, but Production could still rebuild the catalog and call it a promotion. **Task:** Promote one digest through GitOps so Dev and Prod run the same bytes. **Action:** I changed the Helm image field to `repository@digest`, pinned the same `sha256` in `values-dev.yaml` and `values-prod.yaml`, and wrote `gitops/promote-digest.sh` to copy Dev to Prod. I rendered both releases: replica counts differed, the image line did not. I broke Prod with a fake digest and watched the equality check fail, then restored the script. I turned on Prod auto-sync. **Result:** I can say a tag is a pointer, a digest is the artifact, and OIDC from Day 29 is how CI authenticates — not how the bytes move.

---

## Self-score checklist

- [ ] Image field uses `@sha256`, not a moving tag.
- [ ] Dev and Prod values share one digest.
- [ ] Promote script copied Dev → Prod.
- [ ] I broke a Prod-only digest and the check failed.
- [ ] Prod GitOps auto-sync is on, or I recorded why Argo was missing.
- [ ] Files live in ShopSphere.

**Executed:** Python digest-equality check against sample Dev/Prod values. **Not executed:** `helm template`, `docker pull`, Argo CD sync, registry push.
