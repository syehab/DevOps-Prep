# Day 17 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 17 teaches AKS and EKS as managed Kubernetes plus cloud integrations. The old lab **forbade** `az aks create` and produced a comparison table. This lab writes a real `azurerm_kubernetes_cluster` module. You apply it only after a budget alert, on **one** `Standard_B2s` node, and you destroy it the same session. If you have no subscription, you still write the module, run `terraform test`, and wire Workload Identity YAML on `kind`.

---

## Goal

Add `infra/azure/modules/aks` that creates a one-node AKS cluster with OIDC and Workload Identity enabled. Call it from Dev. Run `terraform test`. Apply only when the estimate stays under USD 5 and a budget exists. Map the same idea to EKS / IRSA in the notes.

Time box: 75 to 90 minutes. Destroy before you walk away.

---

## Capstone stage

| Path | Adds |
|:--|:--|
| `infra/azure/modules/aks/` | `azurerm_kubernetes_cluster` |
| `k8s/identity/serviceaccount.yaml` | Workload Identity annotations |
| `docs/day-17-aks-eks.md` | Ownership table + destroy evidence |

---

## What you need

```bash
terraform version
az account show --query name -o tsv
kind get clusters
```

Azure is optional. Terraform 1.16.5 and azurerm 5.9.0 are required for the module. `kind` cluster `shopsphere` is the fallback.

---

## Cost

| Path | Estimated USD (1–2 hours, then destroy) |
|:--|:--|
| `terraform test` + kind YAML | **0.00** |
| AKS `sku_tier = "Free"` + 1 × `Standard_B2s` + OS disk | **1.50–4.50** |
| Extra node, NAT Gateway, or Standard load balancer SKU | **Stop. Change the code.** |

Create the budget first ([../capstone/COST.md](../capstone/COST.md)). Do not write "cost stays at INR 0". AKS nodes bill.

Teardown:

```bash
make destroy
# or
terraform -chdir=infra/azure/environments/dev destroy
az aks list -o table
```

---

## Steps

1. Write `infra/azure/modules/aks/main.tf`. This block **validates** on azurerm 5.9.0. The provider requires `node_provisioning_profile`.

```hcl
variable "name" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }

resource "azurerm_kubernetes_cluster" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = replace(var.name, "-", "")
  sku_tier            = "Free"

  default_node_pool {
    name       = "sys"
    node_count = 1
    vm_size    = "Standard_B2s"
  }

  identity {
    type = "SystemAssigned"
  }

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  node_provisioning_profile {
    mode = "Manual"
  }
}

output "name" {
  value = azurerm_kubernetes_cluster.this.name
}

output "oidc_issuer_url" {
  value = azurerm_kubernetes_cluster.this.oidc_issuer_url
}
```

2. Call it from Dev only if you will apply. Otherwise keep it as a module and test it from a tiny root in `modules/aks/tests` by making `modules/aks` a testable module. Simpler: add the module to a file `infra/azure/environments/dev/aks.tf` and **leave it commented** until you apply. Better: write `infra/azure/modules/aks/tests/aks.tftest.hcl` next to a `terraform { required_providers }` wrapper.

Create `infra/azure/modules/aks/versions.tf`. Do **not** put a `provider` block in the module. The Dev root already has one.

```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "5.9.0"
    }
  }
}
```

`infra/azure/modules/aks/tests/aks.tftest.hcl`:

```hcl
mock_provider "azurerm" {}

run "sku" {
  command = plan
  variables {
    name                = "aks-shopsphere-dev"
    location            = "eastus"
    resource_group_name = "rg-shopsphere-aks-dev"
  }
  assert {
    condition     = azurerm_kubernetes_cluster.this.sku_tier == "Free"
    error_message = "lab cluster must use sku_tier Free"
  }
  assert {
    condition     = azurerm_kubernetes_cluster.this.default_node_pool[0].vm_size == "Standard_B2s"
    error_message = "lab node must be Standard_B2s"
  }
}
```

```bash
cd infra/azure/modules/aks
terraform init
terraform validate
terraform test
```

Expected: `1 passed`. This was executed on Terraform 1.16.5 / azurerm 5.9.0 in the authoring environment.

3. If Azure is available and the budget exists, create the resource group (or reuse Day 8), then apply **only** the AKS module from a dedicated root `infra/azure/environments/aks-dev/` so you can destroy it without touching state for other Days.

```bash
mkdir -p infra/azure/environments/aks-dev
# root that calls module.aks and creates rg-shopsphere-aks-dev
terraform -chdir=infra/azure/environments/aks-dev init
terraform -chdir=infra/azure/environments/aks-dev plan
# read the plan. one cluster, one node, no NAT Gateway.
terraform -chdir=infra/azure/environments/aks-dev apply
az aks get-credentials --resource-group rg-shopsphere-aks-dev --name aks-shopsphere-dev --overwrite-existing
kubectl get nodes
```

If apply would exceed USD 5, stop. Use the kind path.

4. Workload Identity YAML (works as a document on kind; the token exchange works only on AKS).

`k8s/identity/serviceaccount.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: catalog
  namespace: shopsphere
  annotations:
    azure.workload.identity/client-id: "00000000-0000-0000-0000-000000000000"
  labels:
    azure.workload.identity/use: "true"
```

On AKS you replace the GUID with a federated Entra app. On `kind` the annotation does nothing. Write that limit in the notes.

5. Fill the ownership table in `docs/day-17-aks-eks.md`.

| Layer | AKS / Azure | EKS / AWS | Who owns it |
|:--|:--|:--|:--|
| Control plane | Managed | Managed | Cloud |
| Node pool / node group | `Standard_B2s` / `t3.small` | You |
| Workload identity | Workload Identity | IRSA / Pod Identity | You |
| Network | VNet / NSG | VPC / SG | You |

---

## Verify

- `terraform validate` and `terraform test` passed on `modules/aks`.
- The module sets `workload_identity_enabled = true` and one `Standard_B2s` node.
- You either applied and listed a Ready node, or you recorded `apply skipped`.
- ServiceAccount YAML exists.
- Notes do **not** say the lab is free if AKS ran.

---

## Break and fix

### Failure 1 — missing `node_provisioning_profile`

Remove the block. Run `terraform validate`. Expected on azurerm 5.9.0:

```text
Insufficient node_provisioning_profile blocks
At least 1 "node_provisioning_profile" blocks are required.
```

Restore the block. Validate again.

### Failure 2 — over-privileged cluster identity

On paper (or in the notes), give the kubelet identity `Owner` on the subscription. Write the blast radius: a stolen node identity can delete other teams' resource groups. Shrink it: the cluster identity manages the node resource group only. The app uses Workload Identity to one Key Vault secret. Kubernetes RBAC does not limit ARM.

---

## Stretch

- Add `azurerm_federated_identity_credential` for the `catalog` ServiceAccount.
- Write the EKS twin: `aws_eks_cluster` + `aws_eks_node_group` + IRSA annotation `eks.amazonaws.com/role-arn`. Do not apply EKS today unless you are on the AWS week (Days 26-29). EKS control plane is about USD 0.10/hour.

---

## Clean up

If you applied AKS:

```bash
terraform -chdir=infra/azure/environments/aks-dev destroy
az aks show --resource-group rg-shopsphere-aks-dev --name aks-shopsphere-dev
```

Expected: the show command fails with `ResourceNotFound`. If a public IP or disk remains, delete it. Do not leave the node running overnight.

Keep `kind` cluster `shopsphere` for later Days.

---

## Interview story

**Situation:** The old homework said "do not create AKS," so I had no cluster story. **Task:** Describe and, if the budget allowed, create a one-node AKS cluster with Workload Identity, then destroy it. **Action:** I wrote `azurerm_kubernetes_cluster` on provider 5.9.0, including the required `node_provisioning_profile`, and I covered SKU and VM size with `terraform test`. I set `oidc_issuer_enabled` and `workload_identity_enabled`. I applied only after a budget alert, on `Standard_B2s`, then ran `terraform destroy` the same day. On `kind` I still committed the ServiceAccount annotations. **Result:** I can explain what Azure manages versus what I own, and I never claimed AKS was free.

---

## Self-score checklist

- [ ] AKS module validates and tests pass.
- [ ] I saw the `node_provisioning_profile` validate error when I removed the block.
- [ ] I wrote the least-privilege identity shrink.
- [ ] I destroyed AKS the same session, or I never applied.
- [ ] Files live in ShopSphere.
