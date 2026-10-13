# Day 24 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 24 teaches Azure traffic as a path: DNS, route, NSG, then port. Day 12 already created the spoke VNet `10.20.0.0/16` with tier NSGs. This lab is the **next network stage**: a **hub VNet**, **two-way peering**, and a **Private DNS zone** linked to both VNets. You still do not create a NAT Gateway or an Application Gateway.

Work in **your ShopSphere repository**. If `infra/azure/modules/network` from Day 12 is missing, this module still creates a thin spoke so the test stands alone. Prefer to call the Day 12 module when it exists.

---

## Goal

Add `infra/azure/modules/hub-spoke` that creates hub `10.10.0.0/16`, spoke `10.20.0.0/16`, both peering directions, and Private DNS zone `shopsphere.internal` with a link on each VNet. Run `terraform test`. Draw the packet path from a hub jump box to the spoke database subnet. Apply only when the plan has no NAT Gateway and a budget exists.

Time box: 60 to 90 minutes.

---

## Capstone stage

| Path in ShopSphere | What it adds |
|:--|:--|
| `infra/azure/modules/hub-spoke/` | Hub VNet, spoke VNet, two peerings, Private DNS |
| `infra/azure/modules/hub-spoke/tests/hubspoke.tftest.hcl` | CIDR and peering asserts |
| `docs/day-24-peering.md` | Path diagram, NSG table, destroy evidence |

Day 32 adds a Private Endpoint on the spoke `snet-pe` (or on `snet-db`). Do not create a Private Endpoint today.

---

## What you need

```bash
terraform version
az account show --query name -o tsv
```

Terraform 1.16.5 and azurerm 5.9.0 are the pins this lab tested. Azure login is optional.

---

## Cost

| Path | Estimated USD (1–2 hours, then destroy) | Why it is not always zero |
|:--|:--|:--|
| `terraform test` + notes | **0.00** | Local only |
| Two empty VNets + peering + Private DNS zone | **0.00–0.20** | VNet and DNS zone control-plane objects are cheap. Queries and leftover links are not always zero. |
| NAT Gateway, Firewall, Application Gateway, VPN Gateway | **Stop. Change the code.** | Those SKUs blow the USD 5 cap. |

Create a budget first ([../capstone/COST.md](../capstone/COST.md)). Do not write "INR 0" if the VNets exist.

---

## Steps

1. Open ShopSphere. Create folders.

```bash
mkdir -p infra/azure/modules/hub-spoke/tests docs
```

Draw the path in `docs/day-24-peering.md`:

```text
Hub 10.10.0.0/16                          Spoke 10.20.0.0/16
  snet-hub 10.10.1.0/24                     snet-web 10.20.1.0/24
         |                                  snet-app 10.20.2.0/24
         +----- peering both ways ---------- snet-db  10.20.3.0/24
Private DNS shopsphere.internal linked to both
```

Write: peering is the route. NSG is the allow. Private DNS is the name. A missing link looks like a "network outage" and is a DNS miss.

2. Write `infra/azure/modules/hub-spoke/versions.tf`. No provider block.

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

3. Write `infra/azure/modules/hub-spoke/variables.tf`.

```hcl
variable "location" {
  type    = string
  default = "eastus"
}

variable "resource_group_name" {
  type = string
}

variable "hub_address_space" {
  type    = list(string)
  default = ["10.10.0.0/16"]
}

variable "spoke_address_space" {
  type    = list(string)
  default = ["10.20.0.0/16"]
}
```

4. Write `infra/azure/modules/hub-spoke/main.tf`. These arguments are valid on azurerm 5.9.0. Peering is directional. You need two resources. `azurerm_private_dns_zone_virtual_network_link` requires `private_dns_zone_id` and `virtual_network_id` on azurerm 5.9.0. It does **not** take `resource_group_name`. The zone already sits in the group.

```hcl
resource "azurerm_virtual_network" "hub" {
  name                = "vnet-shopsphere-hub"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.hub_address_space
  tags = {
    project = "shopsphere"
    tier    = "hub"
    day     = "24"
  }
}

resource "azurerm_subnet" "hub" {
  name                 = "snet-hub"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.10.1.0/24"]
}

resource "azurerm_virtual_network" "spoke" {
  name                = "vnet-shopsphere-spoke"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.spoke_address_space
  tags = {
    project = "shopsphere"
    tier    = "spoke"
    day     = "24"
  }
}

resource "azurerm_subnet" "spoke_db" {
  name                 = "snet-db"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = ["10.20.3.0/24"]
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                      = "peer-hub-to-spoke"
  resource_group_name       = var.resource_group_name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke.id
  allow_forwarded_traffic   = false
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                      = "peer-spoke-to-hub"
  resource_group_name       = var.resource_group_name
  virtual_network_name      = azurerm_virtual_network.spoke.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
  allow_forwarded_traffic   = false
}

resource "azurerm_private_dns_zone" "internal" {
  name                = "shopsphere.internal"
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "hub" {
  name                 = "link-hub"
  private_dns_zone_id  = azurerm_private_dns_zone.internal.id
  virtual_network_id   = azurerm_virtual_network.hub.id
  registration_enabled = false
}

resource "azurerm_private_dns_zone_virtual_network_link" "spoke" {
  name                 = "link-spoke"
  private_dns_zone_id  = azurerm_private_dns_zone.internal.id
  virtual_network_id   = azurerm_virtual_network.spoke.id
  registration_enabled = false
}
```

`allow_forwarded_traffic = false` until you have an NVA. A lab does not need a firewall SKU.

5. Write `infra/azure/modules/hub-spoke/tests/hubspoke.tftest.hcl`. `address_space` is a set. Use `contains`.

```hcl
mock_provider "azurerm" {}

run "hub_spoke" {
  command = plan

  variables {
    resource_group_name = "rg-shopsphere-net-dev"
  }

  assert {
    condition     = contains(azurerm_virtual_network.hub.address_space, "10.10.0.0/16")
    error_message = "hub must be 10.10.0.0/16"
  }

  assert {
    condition     = contains(azurerm_virtual_network.spoke.address_space, "10.20.0.0/16")
    error_message = "spoke must be 10.20.0.0/16"
  }

  assert {
    condition     = azurerm_virtual_network_peering.hub_to_spoke.name == "peer-hub-to-spoke"
    error_message = "hub-to-spoke peering name"
  }

  assert {
    condition     = azurerm_virtual_network_peering.spoke_to_hub.name == "peer-spoke-to-hub"
    error_message = "spoke-to-hub peering name"
  }

  assert {
    condition     = azurerm_private_dns_zone.internal.name == "shopsphere.internal"
    error_message = "private DNS zone name"
  }
}
```

```bash
cd infra/azure/modules/hub-spoke
terraform init
terraform fmt
terraform validate
terraform test
```

Expected: `1 passed`. Executed on Terraform 1.16.5 / azurerm 5.9.0.

6. NSG table in the notes. Reuse Day 12 rules on the spoke. Hub `snet-hub` may reach spoke App `8080` only if you add that allow. Default: hub is not a backdoor into postgres. Write that sentence.

7. Optional apply. Dedicated root `infra/azure/environments/net-hub/`. Plan must show two VNets, two peerings, one zone, two links. No public IP. No NAT Gateway.

If Azure is missing, write `apply skipped`. The test is the evidence.

---

## Verify

- Hub is `10.10.0.0/16`. Spoke is `10.20.0.0/16`.
- Two peering resources exist. One direction is not enough.
- Private DNS zone `shopsphere.internal` has two VNet links.
- `terraform test` passed.
- No NAT Gateway in the plan.
- Files live in ShopSphere.

---

## Break and fix

Do both failures.

### Failure 1 — one-way peering

Remove `azurerm_virtual_network_peering.spoke_to_hub`. Run `terraform test`. Expected: the spoke-to-hub name assert fails. On a live network, hub-to-spoke packets would have a route and the return path would not. Restore the second peering. Peering is not a cable. It is two objects.

### Failure 2 — DNS zone with no VNet link

Comment out both `azurerm_private_dns_zone_virtual_network_link` resources. The zone still exists. Name resolution from the hub VM (or from `kind` extra network) would miss. Restore the links. Diagnose with `nslookup db.shopsphere.internal` (cloud) or with "zone exists, link missing" in the notes (local). Do not open the database NSG to the Internet to "make DNS work."

---

## Stretch

- Add `azurerm_private_dns_a_record` `db.shopsphere.internal` pointing at a dummy `10.20.3.10`.
- Replace the inline spoke VNet with `module.network` from Day 12.
- Map hub-spoke to AWS Transit Gateway in one paragraph. Do not apply TGW (it bills).

---

## Clean up

```bash
terraform -chdir=infra/azure/environments/net-hub destroy
az network vnet peering list --resource-group rg-shopsphere-net-dev --vnet-name vnet-shopsphere-hub
```

Expected after destroy: the list fails or is empty. Confirm both VNets are gone.

---

## Interview story

**Situation:** ShopSphere had a spoke VNet from Day 12 and no path from a hub, so Private DNS and peering were interview words only. **Task:** Build hub-spoke as Terraform a teammate can test without Azure. **Action:** I wrote hub `10.10.0.0/16` and spoke `10.20.0.0/16` with two `azurerm_virtual_network_peering` resources and a `shopsphere.internal` Private DNS zone linked to both VNets on azurerm 5.9.0. I covered CIDRs and peering names with `terraform test`. I broke one-way peering and a zone without links, then restored both. I refused NAT Gateway and Firewall SKUs. **Result:** I can walk DNS → route (peering) → NSG → port, and I can say why one peering object is not a path.

---

## Self-score checklist

- [ ] `terraform test` passed on hub-spoke.
- [ ] Two peering resources exist.
- [ ] Private DNS zone has two links.
- [ ] I broke one-way peering and a missing DNS link.
- [ ] I destroyed the VNets, or I never applied.
- [ ] Files live in ShopSphere.

**Executed:** `terraform fmt`, `validate`, `terraform test` on Terraform 1.16.5 / azurerm 5.9.0. **Not executed:** live peering apply, `nslookup`, NAT Gateway (forbidden).
