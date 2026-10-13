# ShopSphere (starter)

This is the product repository skeleton. Copy it out of DevOps-Prep. Then commit it to a GitHub repository you own.

ShopSphere is a small catalog API. The Day 31 lesson still describes a larger e-commerce product. This starter is the slice you can run in one evening. Platform work (Terraform, AKS, GitOps, SLOs) lands in the folders below as you complete each Day.

## Layout

```text
app/                    # catalog API (Day 1, 13)
charts/shopsphere/      # Helm chart (Day 16)
infra/azure/            # Terraform azurerm + remote state (Days 8-10, 25, 36)
infra/bicep/            # one Bicep module (Day 8)
infra/aws/              # EKS / S3 backend / OIDC (Days 26-29)
gitops/                 # Argo CD app-of-apps (Days 16, 33, 37)
k8s/                    # raw manifests for kind (Days 14-15)
observability/          # Prometheus rules, Grafana, OTel (Days 20, 35)
policies/               # Kyverno (Day 19)
docs/                   # maps, ADRs, design mocks
.github/workflows/      # app CI + infra plan (Days 4, 6, 25)
```

## First commands

```bash
python3 -m pip install -r app/requirements.txt
python3 app/main.py
curl -sS http://127.0.0.1:8080/health
curl -sS http://127.0.0.1:8080/products
```

Expected `/health` body: `{"status":"ok"}`. Expected `/products` body: a JSON list with at least one SKU.

Then read [../README.md](../README.md) and open Day 1.

## Make targets

| Target | What it does |
|:--|:--|
| `make run` | Start the API on `127.0.0.1:8080` |
| `make test` | Run `app/test_api.py` |
| `make image` | Build the multi-stage image (Day 13 fills the Dockerfile) |
| `make destroy` | `terraform destroy` in `INFRA_DIR` (default Azure dev) |
| `make destroy-kind` | Delete the `shopsphere` kind cluster |
| `make destroy-azure` | Delete `SHOPSPHERE_RG` |
| `make destroy-aws` | Destroy the AWS dev stack |

Set `SHOPSPHERE_RG` and `INFRA_DIR` before you destroy cloud resources. Destroy is not optional.

## Cost

Local `make run` and `kind` cost USD 0.00. Any Azure or AWS apply follows [../COST.md](../COST.md). Create the budget alert first. Aim to stay under USD 5 per session. Never leave AKS or EKS running overnight.
