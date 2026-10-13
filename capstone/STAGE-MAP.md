# ShopSphere stage map

Each row is one Day lab. The **Adds** column is the folder or file you commit to your ShopSphere repository. The **Cloud** column is the preferred path. The **Local fallback** column is required when you have no cloud account.

Work in the ShopSphere repo. Do not restart the product in `/tmp`. Scratch files for a single experiment may live under `/tmp`. The stage itself must land in Git.

Costs are **estimated USD per session** for the smallest SKU the Day names, with destroy at the end. They are not invoices. Prices change. Read the Day file before you apply.

| Day | Stage name | Adds to ShopSphere | Cloud (preferred) | Est. USD | Local fallback |
|:--|:--|:--|:--|:--|:--|
| 01 | System map from a live app | `docs/system-map.md` drawn from `curl` against the starter API | None | 0.00 | Docker or `python3` on the starter API |
| 02 | Runtime evidence | `docs/runtime.md` plus process, logs, and health | None | 0.00 | Same API process |
| 03 | Request path | `docs/request-path.md` with DNS → process | None | 0.00 | Loopback + `curl` |
| 04 | CI mental model | `.github/workflows/ci.yml` (lint + test) | GitHub-hosted minutes | ~0.00 | `act` or run the same commands locally |
| 05 | Branches and environments | `docs/promotion.md` + `dev`/`prod` values | None | 0.00 | Git branches in ShopSphere |
| 06 | Application pipeline | App workflow: test, build, push digest | GitHub Actions + local registry | ~0.00 | Docker build only |
| 07 | Deploy strategy | Helm values for rolling, then a canary note | None | 0.00 | `helm template` |
| 08 | IaC loop + Bicep | `infra/azure/` first root module + `infra/bicep/rg.bicep` | Azure RG + storage (or what-if only) | 0.20-1.00 | Terraform `local` + `az bicep build` |
| 09 | Modules and environments | `modules/` + `environments/dev` + `environments/prod` | Two tiny RGs | 0.20-1.00 | Two env folders, `local_file` or Azurite |
| 10 | Remote state and lock | Azure Storage backend + lock; no laptop state | Storage account + blob lease | 0.05-0.40 | Local backend + a lock-file drill |
| 11 | Landing zone | `infra/azure/landing-zone/` management group + policy | Sandbox tenant / MG | 0.00-1.00 | Terraform `azurerm` plan-only + JSON mock |
| 12 | Cloud network | `modules/network` VNet + NSG | Small VNet | 0.10-0.50 | Terraform plan + `kind` extra network |
| 13 | Multi-stage image | `app/Dockerfile` non-root, then `docker build` | None | 0.00 | Docker only |
| 14 | Desired state | `k8s/base/` Deployment + Service on `kind` | None | 0.00 | `kind` |
| 15 | Cluster networking | NetworkPolicy + Service debug | None | 0.00 | `kind` |
| 16 | Helm + GitOps start | `charts/shopsphere` + Argo CD app-of-apps (local) | None | 0.00 | `kind` + Argo CD on `kind` |
| 17 | Managed Kubernetes | AKS module **or** EKS note; Workload Identity wiring | AKS 1-node (`Standard_B2s`) | 1.50-4.50 | `kind` + identity YAML (no cloud token) |
| 18 | Identity and secrets | GitHub OIDC to Entra; Key Vault CSI | Key Vault + federated credential | 0.10-0.80 | External Secrets + dummy Secret |
| 19 | Supply chain | Trivy, Syft SBOM, Cosign, Gitleaks, Kyverno | Optional ACR | 0.00-0.50 | Local Trivy + Cosign key pair |
| 20 | First signals | kube-prometheus-stack + OTel sidecar + one SLO | None on `kind` | 0.00 | `kind` |
| 21 | Design mock | `docs/design-mock-21.md` + timed rubric | None | 0.00 | Paper + this repo |
| 22 | Azure platform | Platform module (RG, LAW, budget) | RG + budget | 0.20-1.00 | Plan-only |
| 23 | Azure compute (harder than 13) | Container Apps or VMSS from a golden image | Small CA or 1 VM | 1.00-4.00 | Docker Compose + image scan |
| 24 | Azure networking | Private DNS / peering sketch + NSG flow | Optional peering | 0.20-2.00 | Plan-only |
| 25 | Plan on PR, gated apply | Infra workflow: `fmt`, `validate`, `tflint`, `checkov`, `terraform test`, plan artifact, environment approval | GitHub + OIDC | 0.00-0.50 | Local `terraform test` |
| 26 | AWS landing zone | `infra/aws/org/` Organizations + one SCP | Sandbox org | 0.00-1.00 | JSON SCP + LocalStack org stub |
| 27 | EKS via Terraform | `modules/eks` + managed node group | EKS + 1 × `t3.small` | 2.00-5.00 | `kind` + IRSA annotation files |
| 28 | AWS network + IRSA | VPC module + IRSA / Pod Identity | Small VPC | 0.20-1.00 | Terraform plan + `kind` |
| 29 | AWS delivery | S3 backend + DynamoDB or S3 lock + OIDC | S3 + table | 0.05-0.40 | Local backend + lock drill |
| 30 | Assessment | Timed design + capacity math | None | 0.00 | Rubric in `drills/system-design/` |
| 31 | Foundation ADRs | `docs/adr/` + real modules (not `local_file`) | Reuse Day 8-12 stack | 0.20-1.00 | Local providers |
| 32 | Private connectivity | Private Endpoint or PrivateLink module | One PE | 0.50-2.00 | Plan-only + `kind` extra |
| 33 | Promotion (harder than 29) | Same digest Dev → Prod via GitOps | Same cluster pair | 0.00-1.00 | Two Argo apps on `kind` |
| 34 | Reliability | HPA, PDB, drain drill, rollout | None on `kind` | 0.00 | `kind` |
| 35 | Observability as code (harder than 20) | Grafana dashboard JSON + multi-window burn-rate | None on `kind` | 0.00 | `kind` |
| 36 | Terraform hardening (harder than 10) | `terraform test`, tflint, checkov, moved blocks | Remote state already live | 0.05-0.40 | Local tests |
| 37 | Kubernetes migration | App-of-apps prod, Karpenter vs Cluster Autoscaler note | AKS/EKS or `kind` | 0.00-4.00 | `kind` |
| 38 | Multi-account (harder than 9) | Separate state + tagging policy + budget | Second RG or account | 0.20-1.00 | Two backends on disk |
| 39 | DR and FinOps | Backup, cross-region restore, RTO/RPO, Infracost | Backup vault or S3 copy | 0.50-3.00 | `velero` on `kind` or file copy + clock |
| 40 | Lead review | Design pack + timed defense | None | 0.00 | Rubric |
| 41 | Game day | Incident on the running stack | Reuse existing cluster | 0.00-5.00 | `kind` + `drills/kubernetes-broken-cluster/` |

---

## Progression pairs (do not treat these as copies)

| First Day | Second Day | What gets harder |
|:--|:--|:--|
| 09 modules / two envs | 38 multi-account + policy | Shared module now crosses account and tagging policy |
| 10 remote state | 36 test + lint + policy | State already remote; you add `terraform test`, tflint, checkov |
| 13 Dockerfile | 23 golden image / PaaS | Image is now baked, scanned, and published |
| 20 first metrics | 35 Grafana as code + burn-rate | Alerts become SLO multi-window and dashboards live in Git |
| 29 AWS CI / backend | 33 same-digest promotion | The artifact does not rebuild between environments |

---

## Suggested week order (interview impact)

1. Capstone starter (this folder)
2. Days 8, 9, 10, 25, 31, 36, 38 (IaC)
3. Days 14, 15, 16, 17, 34, 37 (Kubernetes and GitOps)
4. `drills/kubernetes-broken-cluster/`
5. Days 20, 35 (observability)
6. Days 19, 18 (security)
7. Days 26-29 (AWS)
8. `drills/system-design/` and Days 21, 30, 40
9. Remaining Days and the other drill packs

If you have little time, finish the current Day cleanly. Do not skip Clean up.
