# Pinned versions

Pin these versions in ShopSphere unless a Day file names a newer patch. Bump only after you read the changelog. Do not use `@latest` in GitHub Actions.

Checked against public release pages on 2026-10-13. Anything marked **not executed in CI** was not run in the authoring environment.

| Tool / artifact | Pin | Source |
|:--|:--|:--|
| Terraform CLI | `1.16.5` | https://releases.hashicorp.com/terraform/1.16.5/ |
| `hashicorp/azurerm` | `5.9.0` | Terraform Registry, 2026-10-08 |
| `hashicorp/aws` | `~> 6.0` (lock the exact version after `terraform init`) | Terraform Registry |
| `hashicorp/local` | `2.5.3` | Terraform Registry |
| `hashicorp/random` | `3.7.2` | Terraform Registry |
| `kind` | `v0.33.0` | https://kind.sigs.k8s.io/ |
| `kindest/node` | `v1.37.0@sha256:a1ed56cfb0e7b93589bdf97c8cd566405a265939e3620fc4f5de89adff580ae5` | kind v0.33.0 release notes |
| `kubectl` | match the cluster (`v1.37.x` for the pin above) | Kubernetes release |
| Helm | `v3.16.4` or the current 3.16+ patch on your OS | https://helm.sh |
| Python | `3.12` | `python:3.12-slim` |
| nginx (debug workloads) | `1.27` | Docker Hub `nginx:1.27` |
| Argo CD | `v2.14.11` (Helm chart `argo-cd` 7.8.x line) | https://argo-cd.readthedocs.io — **confirm chart version at install** |
| kube-prometheus-stack | Helm chart `69.x` or the current stable at install time | prometheus-community |
| Kyverno | Helm chart `3.3.x` | https://kyverno.io |
| Trivy | `0.58.1` or current 0.58+ | aquasecurity/trivy |
| Syft | `v1.19.0` or current 1.19+ | anchore/syft |
| Cosign | `v2.4.3` or current 2.4+ | sigstore/cosign |
| Gitleaks | `v8.24.0` or current 8.24+ | gitleaks/gitleaks |
| `actions/checkout` | `@v4` (pin a full commit SHA in production workflows) | GitHub |
| Checkov | `3.2.x` | Prisma / Bridgecrew |
| tflint | `v0.55.1` or current 0.55+ | terraform-linters/tflint |
| Infracost | `v0.10.x` | infracost/infracost |
| Bicep CLI | `0.33+` via `az bicep install` | Azure CLI |

## Terraform version constraint

Use this block in every root module:

```hcl
terraform {
  required_version = ">= 1.9.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "5.9.0"
    }
  }
}
```

After the first `terraform init`, commit `.terraform.lock.hcl`. That file is the exact provider set a teammate will download.

## Images

Prefer digest pins when you push to a registry:

```text
nginx:1.27
python:3.12-slim
kindest/node:v1.37.0@sha256:a1ed56cfb0e7b93589bdf97c8cd566405a265939e3620fc4f5de89adff580ae5
```

Do not run `latest` in Prod values.

## Not executed in CI

The authoring VM for this capstone scaffold did not run Docker, `kind`, Helm, Azure CLI, or AWS CLI. Version numbers above come from public release pages dated 2026-10-13. Day labs that include commands we did run will say so in that Day file.
