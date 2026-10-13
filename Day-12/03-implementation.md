# Day 12 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 12 teaches one cloud networking model: name, IP, route, security, then destination. The old lab planned `10.20.0.0/16` on paper and pinged two Docker containers. This lab writes a **real `azurerm` VNet module** with three `/24` subnets and NSG rules. You run `terraform test`. You apply the VNet only after a budget alert exists, and you never create a NAT Gateway. Day 24 adds peering and Private DNS on top of this module. Day 32 adds a Private Endpoint.

Work in **your ShopSphere repository**, not in `/tmp`, and not inside this course clone. You need the Day 8 `modules/rg` layout if you will apply. If it is missing, create it from [Day-08/03-implementation.md](../Day-08/03-implementation.md) first.

---

## Goal

Add `infra/azure/modules/network` that describes one VNet `10.20.0.0/16` with Web `10.20.1.0/24`, App `10.20.2.0/24`, and DB `10.20.3.0/24`. Attach one NSG per subnet. Allow HTTPS to Web, TCP `8080` from Web to App, and TCP `5432` from App to DB. Deny Internet sources to the database port. Run `terraform test`. Apply only when the estimate stays under USD 5 and a budget exists.

When you finish, you can explain address planning, routing versus security, and why a NAT Gateway is the wrong default for this lab.

Time box: 60 to 90 minutes. Destroy the VNet the same session if you apply.

---

## Capstone stage

| Path in ShopSphere | What it adds |
|:--|:--|
| `infra/azure/modules/network/` | VNet, three subnets, three NSGs |
| `infra/azure/modules/network/tests/network.tftest.hcl` | CIDR and NSG asserts |
| `infra/azure/environments/net-dev/` | Optional apply root (destroy-safe) |
| `docs/day-12-network-lab.md` | Test output, allow table, destroy evidence |

Do not add a NAT Gateway, a public IP, or a load balancer today. Day 24 adds peering. Day 32 adds a Private Endpoint.

---

## What you need

You need Terraform 1.16.5 (or 1.9+) and a shell.

```bash
terraform version
```

Expected first line: `Terraform v1.16.5` or another 1.9+ release. Install 1.16.5 from [releases.hashicorp.com/terraform/1.16.5](https://releases.hashicorp.com/terraform/1.16.5/) if the command is missing.

Azure CLI is optional. The apply path needs a logged-in account and a budget alert. The test path does not.

```bash
az account show --query name -o tsv
```

If that command fails, stay on the local path: write the module, run `terraform test`, draw the request path, and skip apply. Do not invent an AWS VPC module today. Azure is the default track. Map VNet → VPC and NSG → Security Group in the notes.

`kind` is the local network stand-in when you want a live path and you have no Azure account. A `kind` extra network is **not** a VNet. Write that limit.

```bash
kind version
kind get clusters
```

---

## Cost

| Path | Estimated USD (1–2 hours, then destroy) | Why it is not always zero |
|:--|:--|:--|
| `terraform test` + notes | **0.00** | Local only |
| Empty VNet + 3 subnets + 3 NSGs | **0.00–0.10** | VNet and NSG control-plane objects do not bill. A leftover public IP or peering would. |
| NAT Gateway, Application Gateway, or Standard Load Balancer | **Stop. Change the code.** | Often more than USD 5 if left on. |

Create a budget alert before you apply. See [../capstone/COST.md](../capstone/COST.md). Do not write "cost stays at INR 0" if you created Azure resources. An empty VNet is cheap. Say so in the notes if you keep it on purpose.

Teardown:

```bash
terraform -chdir=infra/azure/environments/net-dev destroy
az network vnet show --resource-group rg-shopsphere-net-dev --name vnet-shopsphere-dev
```

---

## Steps

1. Open ShopSphere. Confirm you are not inside DevOps-Prep.

```bash
pwd
git rev-parse --show-toplevel
mkdir -p infra/azure/modules/network/tests
mkdir -p infra/azure/environments/net-dev
mkdir -p docs
```

Write one sentence in `docs/day-12-network-lab.md`: this Day manages the ShopSphere address plan as desired state. It does not manage AKS.

2. Write the module variables. Put this in `infra/azure/modules/network/variables.tf`.

```hcl
variable "name" {
  type        = string
  description = "VNet name, for example vnet-shopsphere-dev."
}

variable "location" {
  type        = string
  description = "Azure region, for example eastus."
}

variable "resource_group_name" {
  type        = string
  description = "Existing resource group that owns the VNet."
}

variable "address_space" {
  type        = list(string)
  description = "VNet CIDR list."
  default     = ["10.20.0.0/16"]
}

variable "web_prefix" {
  type    = string
  default = "10.20.1.0/24"
}

variable "app_prefix" {
  type    = string
  default = "10.20.2.0/24"
}

variable "db_prefix" {
  type    = string
  default = "10.20.3.0/24"
}
```

3. Write `infra/azure/modules/network/versions.tf`. Do **not** put a `provider` block in the module. The apply root owns the provider.

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

4. Write `infra/azure/modules/network/main.tf`. These resource types and arguments are valid on `hashicorp/azurerm` 5.9.0. `azurerm_subnet` uses `address_prefixes` (plural). There is no NAT Gateway.

```hcl
resource "azurerm_virtual_network" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.address_space
  tags = {
    project = "shopsphere"
    purpose = "network"
    day     = "12"
  }
}

resource "azurerm_subnet" "web" {
  name                 = "snet-web"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.web_prefix]
}

resource "azurerm_subnet" "app" {
  name                 = "snet-app"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.app_prefix]
}

resource "azurerm_subnet" "db" {
  name                 = "snet-db"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.db_prefix]
}

resource "azurerm_network_security_group" "web" {
  name                = "nsg-web"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "allow-https-in"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = var.web_prefix
  }
}

resource "azurerm_network_security_group" "app" {
  name                = "nsg-app"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "allow-web-to-app"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = var.web_prefix
    destination_address_prefix = var.app_prefix
  }
}

resource "azurerm_network_security_group" "db" {
  name                = "nsg-db"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "allow-app-postgres"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = var.app_prefix
    destination_address_prefix = var.db_prefix
  }

  security_rule {
    name                       = "deny-internet-postgres"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = "Internet"
    destination_address_prefix = var.db_prefix
  }
}

resource "azurerm_subnet_network_security_group_association" "web" {
  subnet_id                 = azurerm_subnet.web.id
  network_security_group_id = azurerm_network_security_group.web.id
}

resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.app.id
}

resource "azurerm_subnet_network_security_group_association" "db" {
  subnet_id                 = azurerm_subnet.db.id
  network_security_group_id = azurerm_network_security_group.db.id
}
```

Write the allowed flows into the notes. Web may receive TCP `443`. Web may reach App on `8080`. App may reach DB on `5432`. Web must not talk to DB. DB must not start connections to Web. This is segmentation, not a full mesh.

5. Write `infra/azure/modules/network/outputs.tf`.

```hcl
output "vnet_id" {
  value = azurerm_virtual_network.this.id
}

output "vnet_name" {
  value = azurerm_virtual_network.this.name
}

output "web_subnet_id" {
  value = azurerm_subnet.web.id
}

output "app_subnet_id" {
  value = azurerm_subnet.app.id
}

output "db_subnet_id" {
  value = azurerm_subnet.db.id
}
```

6. Write `infra/azure/modules/network/tests/network.tftest.hcl`. `mock_provider` does not call Azure.

```hcl
mock_provider "azurerm" {}

run "cidr_and_nsg" {
  command = plan

  variables {
    name                = "vnet-shopsphere-dev"
    location            = "eastus"
    resource_group_name = "rg-shopsphere-net-dev"
  }

  assert {
    condition     = contains(azurerm_virtual_network.this.address_space, "10.20.0.0/16")
    error_message = "VNet must be 10.20.0.0/16"
  }

  assert {
    condition     = azurerm_subnet.web.address_prefixes[0] == "10.20.1.0/24"
    error_message = "web subnet must be 10.20.1.0/24"
  }

  assert {
    condition     = azurerm_subnet.app.address_prefixes[0] == "10.20.2.0/24"
    error_message = "app subnet must be 10.20.2.0/24"
  }

  assert {
    condition     = azurerm_subnet.db.address_prefixes[0] == "10.20.3.0/24"
    error_message = "db subnet must be 10.20.3.0/24"
  }

  assert {
    condition = anytrue([
      for r in azurerm_network_security_group.db.security_rule :
      r.name == "allow-app-postgres" && r.source_address_prefix == "10.20.2.0/24" && r.destination_port_range == "5432"
    ])
    error_message = "postgres source must be the app subnet on 5432"
  }

  assert {
    condition = anytrue([
      for r in azurerm_network_security_group.db.security_rule :
      r.name == "deny-internet-postgres" && r.access == "Deny"
    ])
    error_message = "internet must be denied to postgres"
  }
}
```

`address_space` and `security_rule` are sets on azurerm 5.9.0. The test uses `contains` and `for`. Do not index them with `[0]`. `address_prefixes` on a subnet is a list, so `[0]` is valid.

7. Test the module. This does not create Azure resources.

```bash
cd infra/azure/modules/network
terraform init
terraform fmt
terraform validate
terraform test
```

Expected: `Success! 1 passed, 0 failed.` Copy that line into `docs/day-12-network-lab.md`.

This was executed on Terraform 1.16.5 / azurerm 5.9.0 in the authoring environment.

8. Draw the request path in the notes:

```text
User → DNS → Public Load Balancer → Web 10.20.1.0/24 → App 10.20.2.0/24 → DB 10.20.3.0/24
```

Write where each decision sits. DNS answers the name. The route table answers where the packet goes. The NSG answers whether the packet is allowed. The database port must be listening. These are separate checks. An allow rule is not a route.

Write the Azure to AWS map:

```text
VNet          → VPC
Subnet        → Subnet
NSG           → Security Group (and NACL if you need subnet-level deny)
Route table   → Route table
NAT Gateway   → NAT Gateway (avoid in this lab)
```

9. Optional Azure apply. Use a dedicated root so you can destroy it without touching Day 8 state.

`infra/azure/environments/net-dev/main.tf`:

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

provider "azurerm" {
  features {}
  resource_provider_registrations = "none"
}

resource "azurerm_resource_group" "net" {
  name     = "rg-shopsphere-net-dev"
  location = "eastus"
  tags = {
    project = "shopsphere"
    day     = "12"
  }
}

module "network" {
  source              = "../../modules/network"
  name                = "vnet-shopsphere-dev"
  location            = azurerm_resource_group.net.location
  resource_group_name = azurerm_resource_group.net.name
}

output "vnet_name" {
  value = module.network.vnet_name
}
```

Create the budget first. Then:

```bash
cd infra/azure/environments/net-dev
terraform init
terraform plan -input=false
```

Read the plan. Expected: one resource group, one VNet, three subnets, three NSGs, three associations. Confirm there is **no** `azurerm_nat_gateway` and **no** public IP. If the plan would create either, stop and change the module.

```bash
terraform apply -input=false
az network vnet show --resource-group rg-shopsphere-net-dev --name vnet-shopsphere-dev \
  --query "{name:name,space:addressSpace.addressPrefixes}" -o table
az network nsg rule list --resource-group rg-shopsphere-net-dev --nsg-name nsg-db -o table
```

If `az account show` failed, write `apply skipped — no Azure login` in the notes. The test result is your evidence.

10. Local fallback when you have Docker and `kind` but no Azure. Create (or reuse) cluster `shopsphere` from Day 14. Add one extra Docker network so two pods can share a path that is not the default bridge. This is **not** an NSG.

```bash
kind get clusters
# if shopsphere is missing and you want the fallback:
# kind create cluster --name shopsphere
docker network ls
```

Write in the notes: `kind` proves name resolution and a shared path. It does not enforce CIDR or NSG rules. Azure apply is the only way this module becomes a real VNet.

---

## Verify

Read the notes on a call. You should name the `/16`, the three `/24` subnets, the allowed flows, and the user request path.

Check these points:

- `infra/azure/modules/network/main.tf` contains `azurerm_virtual_network` and three `azurerm_subnet` resources.
- There is no `azurerm_nat_gateway` and no public IP.
- `terraform test` in `modules/network` printed `1 passed, 0 failed`.
- The database NSG allows `5432` from `10.20.2.0/24` and denies Internet.
- You either applied and listed the VNet, or you recorded `apply skipped`.
- Notes do **not** say the lab is free if Azure objects exist.
- Files live in ShopSphere, not only under `/tmp`.

---

## Break and fix

Do both failures.

### Failure 1 — overlapping CIDR

Change `app_prefix` default to `10.20.1.0/24` so App overlaps Web. Run:

```bash
cd infra/azure/modules/network
terraform test
```

`terraform test` with `mock_provider` still plans. Azure apply would fail because two subnets cannot share the same prefix. Restore `10.20.2.0/24`. Then change `address_space` to `10.20.0.0/24` so the `/24` subnets no longer fit inside the VNet. A live apply fails with an address-prefix error. Restore `10.20.0.0/16`. Write one sentence: overlapping CIDR blocks make peering and hybrid links hard later. That is why the plan starts at the `/16`.

### Failure 2 — database open to the Internet

Change `allow-app-postgres` so `source_address_prefix = "*"`. Run `terraform test`. Expected: the source assert fails. That is the pipeline catching a public database.

Restore `10.20.2.0/24`. Then, on paper (or in the notes), remove the App-to-DB allow and keep only the deny. Write what fails for a catalog API that needs TCP `5432`. Routing can be correct and the packet still dies on the NSG. Restore the allow. Do not open the database to the Internet to "make it work."

---

## Stretch

- Add a fourth subnet `10.20.4.0/24` named `snet-pe` for Day 32 Private Endpoints. Do not create a Private Endpoint today.
- Write one `azurerm_route_table` that has only the default Azure routes. Custom routes wait for a firewall or NVA. Day 24 covers that.
- Map this module to an `aws_vpc` + `aws_subnet` + `aws_security_group` twin in the notes. Do not apply AWS today.

---

## Clean up

If you did **not** apply, there is no cloud resource to delete. Keep the module. It is the capstone stage.

If you applied `rg-shopsphere-net-dev`:

```bash
cd infra/azure/environments/net-dev
terraform destroy -input=false
az group show --name rg-shopsphere-net-dev
```

Expected destroy plan: the group, the VNet, the subnets, the NSGs, and the associations. Type `yes`. Expected `az group show`: `ResourceGroupNotFound`.

Do not use `-target` as cleanup. Destroy the whole configuration.

Keep `kind` cluster `shopsphere` if you will do later Kubernetes Days.

Commit the module, the test, the optional root, and the notes to ShopSphere. Do not commit `terraform.tfstate`.

---

## Interview story

**Situation:** ShopSphere still had a paper CIDR plan and no reusable network module, so every later Day would invent its own address space. **Task:** Put `10.20.0.0/16` and the three tier NSGs into Terraform that a teammate can test without Azure. **Action:** I wrote `azurerm_virtual_network` plus Web, App, and DB `/24` subnets on provider 5.9.0, attached one NSG per subnet, and allowed only HTTPS, App `8080`, and App-to-DB `5432`. I covered the prefixes and the Internet deny with `terraform test` and `mock_provider`. I refused a NAT Gateway so the session stays under USD 5. **Result:** I can walk DNS → route → NSG → port, I can map VNet to VPC, and I can destroy the VNet in the same session.

---

## Self-score checklist

Score 1 only when you have evidence in `docs/day-12-network-lab.md` or in Git.

- [ ] I can say what a VNet is and why we cut it into subnets.
- [ ] The module validates and `terraform test` printed `1 passed, 0 failed`.
- [ ] Web, App, and DB prefixes are `10.20.1.0/24`, `10.20.2.0/24`, and `10.20.3.0/24`.
- [ ] The database NSG allows App and denies Internet.
- [ ] There is no NAT Gateway in the plan.
- [ ] I broke overlapping CIDR and I restored the `/16`.
- [ ] I broke a public database source and `terraform test` caught it.
- [ ] I either destroyed the VNet the same session, or I never applied.
- [ ] Files live in ShopSphere, not only under `/tmp`.

Count the checked boxes. 8 or 9 is done.

**Executed:** `terraform fmt`, `validate`, and `terraform test` (1 passed) on Terraform 1.16.5 / azurerm 5.9.0. **Not executed:** live `terraform apply` of the VNet, `az network` list, `kind` extra network, NAT Gateway (forbidden).
