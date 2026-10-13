# ShopSphere capstone

This folder is the map for the hands-on track. You build **one Git repository of your own**, named ShopSphere. Each Day adds one stage to that repository. You do not start again in `/tmp`. Files accumulate. That is how a Senior engineer works on a real platform.

Day 31 in the lesson describes ShopSphere as a full e-commerce product (Angular, Spring Boot, PostgreSQL). This track uses a **thin catalog API** so every lab stays inside 90 minutes and still trains the same platform skills. You may later replace the API with Spring Boot. Do not add that work on Day 1.

Copy [shopsphere-starter/](shopsphere-starter/) into a new Git repository that you own. Then follow [STAGE-MAP.md](STAGE-MAP.md). Each Day file lives in `Day-NN/03-implementation.md`. This folder does not replace those labs. It tells you where each lab lands.

---

## One mental model

```text
You write desired state in Git
        ↓
CI proves the change (test, scan, plan)
        ↓
A human reviews the plan
        ↓
CD applies the change (pipeline or GitOps)
        ↓
The cluster and the cloud converge
        ↓
Signals tell you if users are still healthy
```

ShopSphere is one product. Azure is the default cloud. AWS is the second track on Days 26 to 29. Local tools (`kind`, Docker, Terraform `local` / `azurerm` with Azurite, LocalStack) keep the path open when you have no cloud account.

> **Remember:** The interview story is the whole loop, not a single command. Build one repo so you can point at every stage.

---

## Architecture

Azure is the preferred path. AWS names sit in parentheses.

```text
                         Internet users
                                |
                         DNS / TLS edge
                                |
                    Azure Front Door or App Gateway
                         (AWS ALB / CloudFront)
                                |
                         +------+------+
                         |            |
                    ShopSphere     Grafana
                    catalog API    (as code)
                         |
                    AKS (EKS)
                    |    |    |
                  Helm  HPA  PDB
                    |
              Argo CD app-of-apps
                 /          \
              dev            prod
                 \          /
              same image digest
                    |
         Workload Identity (IRSA / Pod Identity)
                    |
         Key Vault CSI (AWS Secrets Manager CSI)
                    |
         Kyverno + NetworkPolicy + RBAC
                    |
    kube-prometheus-stack + OpenTelemetry
                    |
         SLO burn-rate alerts (multi-window)

Delivery (outside the cluster)
  GitHub Actions  →  plan on PR  →  gated apply
  OIDC to Entra ID (IAM)  →  no long-lived cloud secrets
  Trivy + Syft SBOM + Cosign + Gitleaks
  tflint + checkov + terraform test
  Infracost PR diff

Platform (under the cluster)
  Terraform azurerm modules  (aws modules on Days 26-29)
  Remote state: Azure Storage + blob lease lock
                 (S3 + DynamoDB or S3 native lock)
  One Bicep module + what-if (Azure only)
  Management groups + policy  (Organizations + SCP)
  Budget alert created first
```

The local fallback uses the same Git repo. Docker runs the API. `kind` stands in for AKS or EKS. Azurite or LocalStack stand in for storage and lock APIs where those APIs exist. `kind` is not AKS. LocalStack is not AWS Organizations. Write that limit in your notes when you use the fallback.

---

## Prerequisites

Install these tools before Day 8. Pin the versions in [VERSIONS.md](VERSIONS.md).

| Tool | Why you need it | Local without a cloud account |
|:--|:--|:--|
| Git 2.43+ | The ShopSphere repo | Yes |
| Docker Engine 27+ | Images and `kind` nodes | Yes |
| Terraform 1.16.5 | IaC plan and apply | Yes |
| `tflint` 0.55+ | Terraform lint | Yes |
| Checkov 3.2+ | IaC policy scan | Yes |
| Python 3.12 | The catalog API and drills | Yes |
| `kind` v0.33.0 | Local Kubernetes | Yes |
| `kubectl` matching the cluster | Cluster API | Yes |
| Helm 3.16+ | Chart install | Yes |
| Azure CLI 2.67+ | Azure labs | Cloud path only |
| AWS CLI 2.22+ | AWS labs (Days 26-29) | Cloud path only |
| Bicep CLI 0.33+ | Day 8 Bicep what-if | Needs Azure or `az bicep build` locally |

Check the tools:

```bash
git --version
docker version
terraform version
python3 --version
kind version
kubectl version --client
helm version
```

You do **not** need an Azure or AWS account to finish the track. You do need Docker and Terraform for the senior-depth labs. If a cloud lab is the goal of that Day, the Day file still gives a local fallback that trains the same skill.

Create a GitHub repository you own. Clone it next to this course, not inside it.

```bash
# Example. Use your GitHub user and a repo you created.
git clone git@github.com:<you>/shopsphere.git ~/src/shopsphere
cp -R capstone/shopsphere-starter/. ~/src/shopsphere/
cd ~/src/shopsphere
git add .
git commit -m "chore: import ShopSphere starter from DevOps-Prep capstone"
```

Keep DevOps-Prep as the lesson. Keep ShopSphere as the product. Do not commit ShopSphere state files, kubeconfig, or secrets into DevOps-Prep.

---

## Cost and teardown

Read [COST.md](COST.md) before any cloud command. The short rules are:

1. Create a **budget alert first**. Do not create AKS, EKS, or a load balancer before the budget exists.
2. Use the smallest SKU the Day names. Aim for **under USD 5 per session**.
3. Every cloud lab ends with `make destroy` or `terraform destroy`. Confirm the destroy plan. Then confirm the portal or CLI shows no leftover resource group or VPC.
4. Never write "cost stays at INR 0" when a cloud API can bill you. Storage, AKS nodes, EKS control planes, and public IPs cost money.
5. If you have no cloud account, use the **local fallback** in that Day. The fallback is required content, not an afterthought.

```bash
# From your ShopSphere repo, after you copy the starter Makefile
make destroy          # Terraform destroy in the active env
make destroy-kind     # kind delete cluster --name shopsphere
make destroy-azure    # az group delete for the lab resource group
make destroy-aws      # terraform destroy in infra/aws
```

---

## How to use a Day lab

1. Read `Day-NN/01-concepts.md`. Learn the model first.
2. Answer `Day-NN/02-questions-and-answers.md`.
3. Open `Day-NN/03-implementation.md`. The **Capstone stage** section tells you which folder to add in ShopSphere.
4. Work in `~/src/shopsphere` (or your clone). Do not use `/tmp` as the home of the product.
5. Commit the stage when Verify passes. Destroy paid resources before you stop.

Each rewritten lab has the same shape: Goal, Capstone stage, What you need, Steps, Verify, Break and fix, Stretch, Clean up, Interview story, Self-score checklist.

---

## Azure track versus AWS track

| Topic | Azure (default) | AWS (Days 26-29, plus local fallback) |
|:--|:--|:--|
| Remote state | Azure Storage + blob lease | S3 + DynamoDB lock, or S3 native lock |
| Cluster | AKS | EKS via Terraform |
| Workload identity | Workload Identity + Key Vault CSI | IRSA or EKS Pod Identity |
| Federation from GitHub | OIDC to Entra ID | OIDC to IAM |
| Guardrails | Management groups + Azure Policy | Organizations + SCP |
| Native IaC extra | One Bicep module + `what-if` | One CloudFormation or AWS CDK note only |

Days 1 to 25 and 30 to 41 stay Azure-first. Days 26 to 29 build the AWS equivalent of the same ShopSphere product. Do not maintain two unrelated repos.

---

## Stage map (short)

The full table is [STAGE-MAP.md](STAGE-MAP.md).

| Stage | Days | What lands in ShopSphere |
|:--|:--|:--|
| Map and runtime | 1-3 | Running API + system map from live traffic |
| Delivery | 4-7 | GitHub Actions CI, branch flow |
| IaC foundation | 8-10 | Terraform loop, modules, remote state, Bicep what-if |
| Landing zone | 11-12 | Hierarchy + network module |
| Containers | 13, 23 | Multi-stage non-root image, then golden-image / PaaS |
| Kubernetes | 14-17, 34, 37 | kind, then AKS; Helm; HPA/PDB; migration |
| Identity and supply chain | 18-19 | OIDC, Workload Identity, Trivy, Syft, Cosign, Kyverno |
| Observability | 20, 35 | Prometheus, Grafana as code, burn-rate alerts |
| Azure pipelines | 22-25 | Plan on PR, gated apply, tflint, checkov, `terraform test` |
| AWS overlay | 26-29 | Organizations/SCP, EKS, VPC, S3 backend, OIDC |
| Design mocks | 21, 30, 40 | Timed design + rubric + capacity math |
| Hardening and DR | 31-33, 36, 38-39 | ADRs, promotion, state hardening, multi-account, backup, Infracost |
| Game day | 41 | Incident exercise on the live stack |

Duplicate lesson pairs are **progression**, not copies. Day 36 is harder than Day 10. Day 35 is harder than Day 20. Day 38 is harder than Day 9. Day 23 is harder than Day 13. Day 33 is harder than Day 29.

---

## Interview use

When a panel asks "tell me about a platform you built", open this repo. Walk the diagram. Show the PR that planned Terraform. Show the Argo CD app-of-apps. Show the burn-rate alert. Show the destroy and the budget. That is a Senior story. A folder of `local_file` labs is not.

> **Remember:** One product. One repo. Real tools. Destroy what you create. Keep a local path so cost never blocks learning.
