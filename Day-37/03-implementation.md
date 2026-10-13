# Day 37 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 37 asks what operational responsibility you gained by moving ShopSphere onto Kubernetes. The old lab rebuilt a tiny app in `/tmp`. This lab uses the **catalog API you already have**, promotes it through process → image → cluster, turns on the **Prod Argo CD Application**, and writes a Karpenter versus Cluster Autoscaler note.

Work in **your ShopSphere repository**.

---

## Goal

1. Run `python3 app/main.py` and curl `/health`.
2. Build `shopsphere-api:dev` (Day 13 Dockerfile) if Docker exists.
3. Deploy that image on `kind` (or keep `nginx:1.27` if you cannot load an image).
4. Enable auto-sync on `gitops/apps/shopsphere-prod.yaml` **only after** Dev is Healthy.
5. Write `docs/autoscaler.md`: HPA vs Cluster Autoscaler vs Karpenter.

Time box: 70 to 90 minutes.

---

## Capstone stage

| Path | Adds |
|:--|:--|
| `docs/migration-path.md` | Process → image → GitOps |
| `gitops/apps/shopsphere-prod.yaml` | Auto-sync after you choose to |
| `docs/autoscaler.md` | Karpenter vs Cluster Autoscaler |

---

## What you need

ShopSphere `app/main.py`, Docker optional, `kind` cluster `shopsphere`, Argo CD from Day 16 if still installed.

---

## Cost

kind: **USD 0.00**. AKS apply is Day 17. Do not create Karpenter in a cloud account today (node spin can exceed USD 5).

---

## Steps

1. Process.

```bash
python3 app/main.py &
curl -sS http://127.0.0.1:8080/health
kill %1
```

Expected: `{"status":"ok"}`.

2. Image, if Docker works.

```bash
docker build -t shopsphere-api:dev -f app/Dockerfile app
docker run --rm -d --name shopsphere-api -p 8080:8080 shopsphere-api:dev
curl -sS http://127.0.0.1:8080/health
docker stop shopsphere-api
kind load docker-image shopsphere-api:dev --name shopsphere
```

The starter `CMD` listens on `127.0.0.1`. If curl from another container fails, change `HOST` to `0.0.0.0` (Day 13 stretch). Record the failure. That is a real migration bug.

3. Cluster. Point the Helm values or `k8s/base/deployment.yaml` at `shopsphere-api:dev` with `imagePullPolicy: IfNotPresent`. Apply. Confirm Ready.

4. Prod GitOps. Edit `gitops/apps/shopsphere-prod.yaml` so `syncPolicy.automated` matches Dev **after** you read the Dev Application and it is Healthy. Commit. If Argo CD is gone, `kubectl apply -f gitops/apps/shopsphere-prod.yaml` still stores the intent.

5. Write `docs/autoscaler.md`.

```text
HPA                → more Pods (needs requests)
Cluster Autoscaler → more nodes when Pods are Pending
Karpenter          → provisions the right node for Pending Pods, faster bin-pack
```

Write three sentences: HPA cannot add a node; Cluster Autoscaler reads Pending Pods and ASG/node pools; Karpenter is a provisioner, not a replacement for HPA. Day 17 already named these. This Day records the choice for ShopSphere v1: **kind has neither**. AKS uses Cluster Autoscaler or a Karpenter add-on later. Do not install Karpenter on kind unless you already know the extra controllers.

---

## Verify

- `/health` worked from the process.
- You either loaded `shopsphere-api:dev` into kind or you recorded why not.
- Prod Application YAML exists.
- `docs/autoscaler.md` does not say Karpenter replaces HPA.

---

## Break and fix

### Failure 1 — image listens on 127.0.0.1

`docker run -p 8080:8080` then curl from the host may work (published port). A Pod curl from another Pod fails. Change `HOST = "0.0.0.0"`. Rebuild. This is the migration bug.

### Failure 2 — Prod auto-syncs a bad tag

If you enable Prod auto-sync while `values-prod.yaml` still has a bad tag, Prod goes `ImagePullBackOff`. Disable auto-sync or revert the commit. Day 33 is the promotion Day. Do not "fix" Prod by rebuilding a different digest.

---

## Stretch

- Measure time from `git push` to Ready Pod (GitOps delay).
- Add a `maxUnavailable: 0` PDB during the migration window.

---

## Clean up

Stop the background Python process and any `docker run`. Keep kind if you will do observability Days. Destroy AKS if you opened Day 17 and forgot.

---

## Interview story

**Situation:** ShopSphere needed a story for "why Kubernetes" that was not a slide. **Task:** Run the same catalog API as a process, an image, and a cluster object, then write when I would add nodes. **Action:** I curled `/health` from `python3`, built `shopsphere-api:dev`, and loaded it into `kind`. I found the process bound to `127.0.0.1` and changed it to `0.0.0.0` before the Pod path worked. I left Prod GitOps off until Dev was Healthy and I wrote that HPA and Karpenter solve different Pending conditions. **Result:** I can walk a panel through the ownership shift: I used to restart a process, now I declare replicas and a probe.

---

## Self-score checklist

- [ ] Process curl worked.
- [ ] I wrote the autoscaler note correctly.
- [ ] Prod sync is a conscious choice.
- [ ] Files live in ShopSphere.

> **Note:** `kind load` and Argo Prod sync were **not executed in CI**. `python3 app/test_api.py` was executed on the starter API in the capstone PR.
