# Day 32 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 32 teaches who can talk to whom, and why that path is allowed. The old lab used Docker Compose so PostgreSQL had no host port. This lab writes a **Private Endpoint** to Azure Key Vault on a dedicated subnet. The vault has **no public network**. The app reaches it through a private IP and Private DNS `privatelink.vaultcore.azure.net`. Day 12 supplied the VNet. Day 24 supplied peering and Private DNS links. Day 18 supplied Key Vault CSI. This Day is the network path those lessons assumed.

Work in **your ShopSphere repository**. Terraform 1.16.5 and azurerm 5.9.0 are required. Azure apply is optional and costs more than a paper lab.

---

## Goal

Add `infra/azure/modules/private-endpoint` that creates a Key Vault with `rbac_authorization_enabled = true`, a `snet-pe` subnet, a Private Endpoint on subresource `vault`, and a Private DNS zone `privatelink.vaultcore.azure.net`. Run `terraform test`. Apply only after a budget exists and the plan shows no NAT Gateway.

When you finish, you can explain public versus private: a host port on Compose was the toy. A Private Endpoint is the cloud object.

Time box: 70 to 90 minutes. Destroy the vault the same session if you apply. Soft-delete can keep it for days and still bill a little.

---

## Capstone stage

| Path in ShopSphere | What it adds |
|:--|:--|
| `infra/azure/modules/private-endpoint/` | KV + PE subnet + Private Endpoint + Private DNS |
| `infra/azure/modules/private-endpoint/tests/pe.tftest.hcl` | Public-network and subresource asserts |
| `docs/day-32-private-endpoint.md` | Path diagram, public-vs-private, destroy evidence |

---

## What you need

```bash
terraform version
az account show --query name -o tsv
kind get clusters
```

`kind` is the local stand-in: extra network, no public port on a database container. It is **not** a Private Endpoint. Write that limit.

---

## Cost

| Path | Estimated USD (1–2 hours, then destroy) | Why it is not always zero |
|:--|:--|:--|
| `terraform test` + kind/Compose notes | **0.00** | Local only |
| Key Vault standard + few ops + Private Endpoint + DNS zone | **0.50–2.00** | PE has an hourly NIC/IP cost. Soft-deleted vaults retain. |
| NAT Gateway or public Key Vault + PE | **Stop. Change the code.** | |

Create a budget first ([../capstone/COST.md](../capstone/COST.md)). Do not write "INR 0" if the vault or PE exists.

Teardown must **purge** only this lab vault if policy allows. Otherwise record the soft-delete name and the date it will expire.

---

## Steps

1. Open ShopSphere. Create folders.

```bash
mkdir -p infra/azure/modules/private-endpoint/tests docs
```

Draw the path:

```text
Catalog pod / Container App
        ↓ DNS  kv-shopsphere-dev.privatelink.vaultcore.azure.net
        ↓ private IP on snet-pe
        ↓ Private Endpoint
        ↓ Key Vault (public network disabled)
```

2. Write `infra/azure/modules/private-endpoint/versions.tf`. No provider block.

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

3. Write `infra/azure/modules/private-endpoint/variables.tf`. `tenant_id` is **required** on `azurerm_key_vault` in 5.9.0. Pass it in. Do not call `data.azurerm_client_config` inside the module if you want `terraform test` to stay offline.

```hcl
variable "location" {
  type    = string
  default = "eastus"
}

variable "resource_group_name" {
  type = string
}

variable "vnet_name" {
  type = string
}

variable "pe_prefix" {
  type    = string
  default = "10.20.4.0/24"
}

variable "tenant_id" {
  type        = string
  description = "Entra tenant GUID for the Key Vault."
}

variable "key_vault_name" {
  type        = string
  description = "Globally unique vault name, 3 to 24 characters."
}

variable "vnet_id" {
  type        = string
  description = "Resource ID of the spoke VNet from Day 12 or Day 24."
}
```

4. Write `infra/azure/modules/private-endpoint/main.tf`. Valid on azurerm 5.9.0. `rbac_authorization_enabled` is required. `private_endpoint_network_policies` on the subnet is a string. `Disabled` allows the Private Endpoint NIC.

```hcl
resource "azurerm_subnet" "pe" {
  name                              = "snet-pe"
  resource_group_name               = var.resource_group_name
  virtual_network_name              = var.vnet_name
  address_prefixes                  = [var.pe_prefix]
  private_endpoint_network_policies = "Disabled"
}

resource "azurerm_key_vault" "this" {
  name                          = var.key_vault_name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  tenant_id                     = var.tenant_id
  sku_name                      = "standard"
  rbac_authorization_enabled    = true
  public_network_access_enabled = false
  purge_protection_enabled      = false
  soft_delete_retention_days    = 7
}

resource "azurerm_private_dns_zone" "vault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "vault" {
  name                 = "link-vault"
  private_dns_zone_id  = azurerm_private_dns_zone.vault.id
  virtual_network_id   = var.vnet_id
  registration_enabled = false
}

resource "azurerm_private_endpoint" "vault" {
  name                = "pe-kv-shopsphere"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = azurerm_subnet.pe.id

  private_service_connection {
    name                           = "psc-kv-shopsphere"
    is_manual_connection           = false
    private_connection_resource_id = azurerm_key_vault.this.id
    subresource_names              = ["vault"]
  }

  private_dns_zone_group {
    name                 = "vault"
    private_dns_zone_ids = [azurerm_private_dns_zone.vault.id]
  }
}
```

Pass `vnet_id` from the Day 12 or Day 24 VNet output when you apply. The test uses a fake ARM ID. `terraform test` does not talk to Azure.

5. Write `infra/azure/modules/private-endpoint/tests/pe.tftest.hcl`.

```hcl
mock_provider "azurerm" {}

run "private_vault" {
  command = plan

  variables {
    resource_group_name = "rg-shopsphere-net-dev"
    vnet_name           = "vnet-shopsphere-spoke"
    vnet_id             = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-shopsphere-net-dev/providers/Microsoft.Network/virtualNetworks/vnet-shopsphere-spoke"
    tenant_id           = "00000000-0000-0000-0000-000000000000"
    key_vault_name      = "kvshopspherelab"
  }

  assert {
    condition     = azurerm_key_vault.this.public_network_access_enabled == false
    error_message = "vault public network must be disabled"
  }

  assert {
    condition     = azurerm_key_vault.this.rbac_authorization_enabled == true
    error_message = "vault must use RBAC"
  }

  assert {
    condition     = azurerm_subnet.pe.private_endpoint_network_policies == "Disabled"
    error_message = "PE subnet policies must be Disabled"
  }

  assert {
    condition     = azurerm_private_endpoint.vault.private_service_connection[0].subresource_names[0] == "vault"
    error_message = "PE subresource must be vault"
  }

  assert {
    condition     = azurerm_private_dns_zone.vault.name == "privatelink.vaultcore.azure.net"
    error_message = "vault Private DNS zone"
  }
}
```

If `subresource_names` is a set, switch the assert to `contains(azurerm_private_endpoint.vault.private_service_connection[0].subresource_names, "vault")`.

```bash
cd infra/azure/modules/private-endpoint
terraform init
terraform fmt
terraform validate
terraform test
```

Expected: `1 passed`.

6. Local fallback. Compose from the old lab is still useful as the mental model: no `ports` on `db`. On `kind`, do not NodePort the database. Write `compose.yaml` only if it is not already in ShopSphere from an earlier Day. Do not publish `5432`.

7. Optional apply. Dedicated root. Budget first. Pass a real `tenant_id` from `az account show --query tenantId -o tsv`. Vault names are globally unique. Destroy and purge.

---

## Verify

- Vault `public_network_access_enabled` is false. RBAC is true.
- PE subresource is `vault`. DNS zone is `privatelink.vaultcore.azure.net`.
- `terraform test` passed.
- Notes do **not** claim the PE is free.
- Files live in ShopSphere.

---

## Break and fix

Do both failures.

### Failure 1 — public vault plus Private Endpoint

Set `public_network_access_enabled = true`. Run `terraform test`. Expected: the public-network assert fails. A PE with a public vault is two paths. Attackers still hit the public endpoint. Restore `false`. Private Endpoint is not a firewall on a public vault. It is the only path.

### Failure 2 — PE on the database subnet with policies Enabled

Set `private_endpoint_network_policies = "Enabled"` (or omit `snet-pe` and reuse `snet-db`). A live apply often fails to attach the PE NIC, or NSGs on the DB subnet start blocking the PE. Restore `snet-pe` with `Disabled`. Diagnose with the subnet property, not by opening `5432` to the Internet.

---

## Stretch

- Add `azurerm_private_endpoint` for a Storage account blob subresource. Same `snet-pe`.
- Map this to AWS Interface PrivateLink (`aws_vpc_endpoint` Interface type) in the notes. Do not apply it.

---

## Clean up

```bash
terraform destroy
az keyvault show --name kvshopspherelab
az keyvault list-deleted --query "[].name" -o tsv
# purge only the lab vault you created, and only if policy allows
az keyvault purge --name kvshopspherelab
```

Expected: `show` fails. Confirm the PE NIC is gone. Soft-deleted vaults can still bill.

Keep `kind` cluster `shopsphere` for later Days.

---

## Interview story

**Situation:** ShopSphere private connectivity was a Compose file with no host port on PostgreSQL, so I could not show a Private Endpoint in an Azure interview. **Task:** Put Key Vault behind a PE on a dedicated subnet with public network disabled. **Action:** I wrote `azurerm_key_vault` with `rbac_authorization_enabled` and `public_network_access_enabled = false`, a `snet-pe` prefix `10.20.4.0/24`, and `azurerm_private_endpoint` subresource `vault` plus `privatelink.vaultcore.azure.net` on azurerm 5.9.0. I covered those properties with `terraform test`. I broke a public vault plus PE, then restored private-only. **Result:** I can explain that Compose-without-ports is the idea and Private Endpoint is the cloud object, and I can destroy and purge the lab vault.

---

## Self-score checklist

- [ ] PE module validates and `terraform test` passed.
- [ ] Vault public network is disabled.
- [ ] I used `snet-pe`, not the database subnet, for the PE.
- [ ] I broke public-plus-PE and I restored private-only.
- [ ] I destroyed and purged, or I never applied.
- [ ] Files live in ShopSphere.

**Executed:** `terraform fmt`, `validate`, `terraform test` (1 passed) on Terraform 1.16.5 / azurerm 5.9.0. **Not executed:** live PE apply, vault purge, Compose, kind extra network.
