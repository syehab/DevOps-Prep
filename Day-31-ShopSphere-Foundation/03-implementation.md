# Day 31 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 31 starts the ShopSphere engineering phase. The lesson rule is that you write architecture decisions before you write infrastructure code. The old lab used `local_file` as a stand-in for network and app modules. This lab writes **three ADRs** and a real `azurerm` network module: resource group, VNet, and one subnet. The app module records the runtime decision. It does **not** create AKS. Day 17 does that.

Work in **your ShopSphere repository**. Reuse `infra/azure/modules/rg` from Day 8 if it exists. Add `modules/network` beside it.

---

## Goal

Write ADR-001 (runtime), ADR-002 (private data store), and ADR-003 (IaC and state). Then create `modules/network` with `azurerm_virtual_network` and `azurerm_subnet`. Call it from `environments/dev`. Run `terraform test`. Keep the app module as a documented Container Apps or App Service decision, not a Kubernetes cluster.

Time box: 70 to 90 minutes.

---

## Capstone stage

| Path | Adds |
|:--|:--|
| `docs/adr/001-runtime.md` | Container API, not VMs |
| `docs/adr/002-private-data.md` | Private PostgreSQL later, no public IP |
| `docs/adr/003-iac.md` | Terraform + remote state + Bicep extra |
| `infra/azure/modules/network/` | VNet + `snet-app` |
| `infra/azure/modules/app/README.md` | Why this module is not AKS |
| `docs/day-31-foundation-lab.md` | Test output |

---

## What you need

```bash
terraform version
test -d infra/azure/environments/dev && echo "dev root present"
```

Azure is optional. `terraform test` with `mock_provider` is the required path. A live VNet apply costs a little and needs destroy the same day.

---

## Cost

| Path | Estimated USD |
|:--|:--|
| ADRs + `terraform test` | **0.00** |
| Apply one VNet + one subnet, no NAT Gateway, no public IP | **0.00-0.20** |
| NAT Gateway or Application Gateway | **Do not create** (often more than USD 5) |

Budget first if you apply. See [../capstone/COST.md](../capstone/COST.md).

---

## Steps

1. Create the ADR folder.

```bash
mkdir -p docs/adr infra/azure/modules/network infra/azure/modules/app
```

2. Write `docs/adr/001-runtime.md`. Use these headings: Context, Decision, Why, Trade-offs, Alternatives, Consequences.

Decision to record: ShopSphere v1 is the Python catalog API in `app/`, packaged as a container, run on Azure Container Apps in cloud and on `kind` locally. It is not a Kubernetes cluster in v1. Day 17 may change this. Point at that future ADR.

3. Write `docs/adr/002-private-data.md`. Decision: the data store is private. No public IP on PostgreSQL. Local fallback is a Docker `postgres:16` container on a user-defined network. Cloud path (later Day) uses a private endpoint. Do not apply a database today.

4. Write `docs/adr/003-iac.md`. Decision: Terraform `azurerm` 5.9.0 is the primary IaC. State lives in Azure Storage with Azure AD and a lock (Day 10). Bicep remains for what-if on one module. GitHub Actions plans on the PR (Day 25).

5. Write `infra/azure/modules/network/main.tf`. These resources validate on azurerm 5.9.0.

```hcl
variable "name" {
  type = string
}

variable "location" {
  type = string
}

variable "address_space" {
  type = list(string)
}

variable "subnet_prefix" {
  type = string
}

resource "azurerm_resource_group" "net" {
  name     = var.name
  location = var.location
  tags = {
    project = "shopsphere"
    day     = "31"
  }
}

resource "azurerm_virtual_network" "this" {
  name                = "${var.name}-vnet"
  location            = azurerm_resource_group.net.location
  resource_group_name = azurerm_resource_group.net.name
  address_space       = var.address_space
}

resource "azurerm_subnet" "app" {
  name                 = "snet-app"
  resource_group_name  = azurerm_resource_group.net.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.subnet_prefix]
}

output "vnet_name" {
  value = azurerm_virtual_network.this.name
}

output "subnet_name" {
  value = azurerm_subnet.app.name
}
```

6. Call the module from Dev. Add this module block to `infra/azure/environments/dev/main.tf` (keep the Day 8 `rg` module if it is there).

```hcl
module "network" {
  source        = "../../modules/network"
  name          = "rg-shopsphere-net-dev"
  location      = "eastus"
  address_space = ["10.10.0.0/16"]
  subnet_prefix = "10.10.1.0/24"
}

output "vnet_name" {
  value = module.network.vnet_name
}
```

7. Write `infra/azure/environments/dev/tests/network.tftest.hcl`.

```hcl
mock_provider "azurerm" {}

run "cidr" {
  command = plan

  variables {
    name     = "rg-shopsphere-dev"
    location = "eastus"
  }

  assert {
    condition     = module.network.vnet_name == "rg-shopsphere-net-dev-vnet"
    error_message = "vnet name"
  }

  assert {
    condition     = module.network.subnet_name == "snet-app"
    error_message = "subnet name"
  }
}
```

```bash
cd infra/azure/environments/dev
terraform init
terraform validate
terraform test
```

Expected: `1 passed` for this run, or both Day 8 and Day 31 tests passing if both files exist.

8. Write `infra/azure/modules/app/README.md`. Four sentences: this module will describe Azure Container Apps (or App Service) for the catalog API; it will not create AKS; AKS is a later ADR; local fallback is Docker and `kind`.

Do not add `azurerm_kubernetes_cluster` today.

---

## Verify

- Three ADRs exist and each has Why and Trade-offs.
- `modules/network` contains `azurerm_virtual_network` and `azurerm_subnet`.
- `terraform test` passed on the VNet name and `snet-app`.
- The app module README says the runtime is not AKS.
- No NAT Gateway and no public IP appear in the module.

---

## Break and fix

### Failure 1 — overlapping CIDR

Set `subnet_prefix` to `10.20.1.0/24` while `address_space` stays `10.10.0.0/16`. Azure would reject this on apply. `terraform validate` may still pass. Add an assert if you expose the prefix as an output, or write in the notes: validate does not check that the subnet sits inside the VNet. Fix the prefix back to `10.10.1.0/24`.

### Failure 2 — app module secretly becomes AKS

Add `azurerm_kubernetes_cluster` to `modules/app` on purpose, then delete it. Write why that violates ADR-001. The break is the decision, not a crashed cluster. Restore the README-only module.

---

## Stretch

- Add an NSG on `snet-app` that allows TCP 8080 from the VNet only.
- Draw the VNet in `docs/system-map.md` from Day 1.

---

## Clean up

If you did not apply, keep the module. If you applied:

```bash
cd infra/azure/environments/dev
terraform destroy -input=false
```

Confirm `rg-shopsphere-net-dev` is gone. Do not leave a VNet overnight.

---

## Interview story

**Situation:** ShopSphere was about to grow Terraform files without written decisions, which is how a platform becomes a pile of resources. **Task:** Record runtime, data, and IaC choices, then express the network as real `azurerm` code I can test without a subscription. **Action:** I wrote three ADRs. I added `modules/network` with a `/16` VNet and `snet-app`, and I ran `terraform test` with `mock_provider` so the names stay stable. I refused to put AKS in the app module because ADR-001 says Container Apps and `kind` for v1. **Result:** A reviewer can read why the network looks this way, and `terraform test` fails if someone renames the subnet.

---

## Self-score checklist

- [ ] Three ADRs have Why and Trade-offs.
- [ ] Network module uses `azurerm_virtual_network`, not `local_file`.
- [ ] `terraform test` passed.
- [ ] I can explain why validate does not catch a subnet outside the VNet.
- [ ] App module is not AKS.
- [ ] I destroyed any applied VNet.
- [ ] Files live in ShopSphere.
