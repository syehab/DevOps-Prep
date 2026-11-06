# Day 22 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 22 teaches Azure as a stack of boundaries: Entra tenant, management groups, subscriptions, resource groups, then resources. The old lab drew that stack on paper and created one empty resource group. This lab writes a **platform module** that creates the ShopSphere resource group, a **Log Analytics workspace**, and a **resource-group budget** with 80 percent and 100 percent alerts. You create the budget in code so later Days cannot "forget" it. Day 11 already placed the management groups. Day 25 will plan this module on a PR.

Work in **your ShopSphere repository**. You need Terraform 1.16.5. Azure apply is optional.

---

## Goal

Add `infra/azure/modules/platform` that describes one resource group, one Log Analytics workspace (`PerGB2018`, 30-day retention), and one `azurerm_consumption_budget_resource_group` for USD 15 with notifications at 80 and 100. Run `terraform test`. Apply only after you confirm the plan has no compute and no NAT Gateway.

When you finish, you can say who owns each Azure layer, why a budget is a resource, and why Log Analytics is not free once it ingests logs.

Time box: 60 to 90 minutes.

---

## Capstone stage

| Path in ShopSphere | What it adds |
|:--|:--|
| `infra/azure/modules/platform/` | RG + LAW + budget |
| `infra/azure/modules/platform/tests/platform.tftest.hcl` | SKU, retention, budget asserts |
| `infra/azure/environments/platform-dev/` | Optional apply root |
| `docs/day-22-platform-lab.md` | Hierarchy sketch, test output, destroy evidence |

Do not create a VM, VNet, or Key Vault in this module. Day 12 owns the VNet. Day 18 owns Key Vault.

---

## What you need

```bash
terraform version
az account show --query name -o tsv
```

Terraform 1.16.5 and `hashicorp/azurerm` 5.9.0 are the pins this lab tested. Azure login is optional. `terraform test` does not need a subscription.

---

## Cost

| Path | Estimated USD (1–2 hours, then destroy) | Why it is not always zero |
|:--|:--|:--|
| `terraform test` + notes | **0.00** | Local only |
| Empty resource group + budget | **0.00** | Budget alerts do not bill. The resources they watch do. |
| Log Analytics `PerGB2018`, 30-day retention, little or no ingest | **0.20–1.00** | Ingestion and retention. An idle workspace is cheap, not free. |
| LAW 730-day retention or a VM in the same group | **Stop. Change the code.** | Retention and compute blow the USD 5 cap. |

Create the budget **in this module** before any later Day applies AKS or Container Apps. See [../capstone/COST.md](../capstone/COST.md). Do not write "cost stays at INR 0" if the workspace exists.

Teardown:

```bash
terraform -chdir=infra/azure/environments/platform-dev destroy
az group show --name rg-shopsphere-platform-dev
```

---

## Steps

1. Open ShopSphere. Create folders.

```bash
pwd
git rev-parse --show-toplevel
mkdir -p infra/azure/modules/platform/tests
mkdir -p infra/azure/environments/platform-dev
mkdir -p docs
```

Write the hierarchy into `docs/day-22-platform-lab.md` before you write HCL. Keep it short:

```text
Entra tenant
  management groups (Day 11)
    subscription
      rg-shopsphere-platform-dev   ← this Day
        law-shopsphere-dev
        budget shopsphere-lab
```

A tenant is not a subscription. A management group does not hold the workspace. The resource group is the lifecycle boundary.

2. Write `infra/azure/modules/platform/variables.tf`.

```hcl
variable "rg_name" {
  type        = string
  description = "Platform resource group name."
}

variable "location" {
  type    = string
  default = "eastus"
}

variable "law_name" {
  type        = string
  description = "Log Analytics workspace name. Must be unique in the region."
}

variable "budget_amount" {
  type    = number
  default = 15
}

variable "budget_start" {
  type        = string
  description = "First day of the month, RFC3339, for example 2026-10-01T00:00:00Z."
}

variable "budget_email" {
  type        = string
  description = "Alert email. Do not commit a personal inbox you do not want public."
  default     = "ops@example.com"
}
```

3. Write `infra/azure/modules/platform/versions.tf`. No `provider` block in the module.

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

4. Write `infra/azure/modules/platform/main.tf`. These arguments are valid on azurerm 5.9.0. `azurerm_consumption_budget_resource_group` needs `time_period.start_date` and at least one `notification` block.

```hcl
resource "azurerm_resource_group" "this" {
  name     = var.rg_name
  location = var.location
  tags = {
    project = "shopsphere"
    purpose = "platform"
    day     = "22"
  }
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = var.law_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  daily_quota_gb      = 0.1
}

resource "azurerm_consumption_budget_resource_group" "this" {
  name              = "shopsphere-lab"
  resource_group_id = azurerm_resource_group.this.id
  amount            = var.budget_amount
  time_grain        = "Monthly"

  time_period {
    start_date = var.budget_start
  }

  notification {
    enabled        = true
    threshold      = 80
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_emails = [var.budget_email]
  }

  notification {
    enabled        = true
    threshold      = 100
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_emails = [var.budget_email]
  }
}
```

`daily_quota_gb = 0.1` caps ingest for the lab. Production workspaces use a real quota. `PerGB2018` is the current LAW SKU name on this provider line.

5. Write `infra/azure/modules/platform/outputs.tf`.

```hcl
output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "resource_group_id" {
  value = azurerm_resource_group.this.id
}

output "law_id" {
  value = azurerm_log_analytics_workspace.this.id
}
```

6. Write `infra/azure/modules/platform/tests/platform.tftest.hcl`.

```hcl
mock_provider "azurerm" {}

run "sku_budget" {
  command = plan

  variables {
    rg_name       = "rg-shopsphere-platform-dev"
    law_name      = "law-shopsphere-dev"
    budget_start  = "2026-10-01T00:00:00Z"
    budget_email  = "ops@example.com"
  }

  assert {
    condition     = azurerm_log_analytics_workspace.this.sku == "PerGB2018"
    error_message = "LAW sku must be PerGB2018"
  }

  assert {
    condition     = azurerm_log_analytics_workspace.this.retention_in_days == 30
    error_message = "lab retention must be 30 days"
  }

  assert {
    condition     = azurerm_consumption_budget_resource_group.this.amount == 15
    error_message = "budget amount must be 15 USD"
  }

  assert {
    condition     = azurerm_resource_group.this.name == "rg-shopsphere-platform-dev"
    error_message = "platform RG name"
  }
}
```

7. Test the module. This does not create Azure resources.

```bash
cd infra/azure/modules/platform
terraform init
terraform fmt
terraform validate
terraform test
```

Expected: `Success! 1 passed, 0 failed.` Copy that line into the notes.

8. Optional apply root `infra/azure/environments/platform-dev/main.tf`.

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

module "platform" {
  source       = "../../modules/platform"
  rg_name      = "rg-shopsphere-platform-dev"
  law_name     = "law-shopsphere-dev"
  budget_start = "2026-10-01T00:00:00Z"
  budget_email = "ops@example.com"
}
```

Set `budget_start` to the first day of the **current** month. Azure rejects other dates. Set `budget_email` to an inbox you own. Do not commit a personal address if the repo is public. Use a gitignored `terraform.tfvars`.

```bash
cd infra/azure/environments/platform-dev
terraform init
terraform plan -input=false
```

Read the plan. Expected: one resource group, one workspace, one budget. No VM, no NAT Gateway, no public IP. Apply only when you will destroy in the same session.

If `az account show` failed, write `apply skipped — no Azure login`. The test is your evidence.

9. Ownership table in the notes.

```text
Layer              Owner              Delete blast
Entra tenant       Identity           Company-wide
Management group   Platform           Child subscriptions inherit
Subscription       Platform / FinOps  Every RG in it
This resource group ShopSphere platform  LAW + budget
LAW                Platform           Logs and bills for ingest
```

---

## Verify

- `terraform test` printed `1 passed, 0 failed`.
- LAW uses `PerGB2018` and 30-day retention.
- Budget amount is 15 with 80 and 100 percent notifications.
- Plan has no compute and no NAT Gateway.
- Notes do **not** say the workspace is free if it exists.
- Files live in ShopSphere.

---

## Break and fix

Do both failures.

### Failure 1 — 730-day retention

Set `retention_in_days = 730`. Run `terraform test`. Expected: the retention assert fails. That is the pipeline catching a cost leak. Restore `30`. Long retention is a production choice. It is the wrong default for a 90-minute lab.

### Failure 2 — budget after compute

On paper, create AKS in this same group first, then add the budget. Write the blast: the node already billed; the alert cannot prevent a charge that already happened. Restore the module order: budget and LAW here, AKS on Day 17 in a **different** apply root. A resource group that mixes a disposable VM with LAW has the same lifecycle clash as the old lab. Do not add a VM to this module to "try it."

---

## Stretch

- Add `azurerm_monitor_action_group` with one `email_receiver` and point `contact_groups` at it instead of a raw email list.
- Map the same three objects to AWS: account + CloudWatch Logs + AWS Budget.

---

## Clean up

If you applied:

```bash
cd infra/azure/environments/platform-dev
terraform destroy -input=false
az group show --name rg-shopsphere-platform-dev
az monitor log-analytics workspace show --resource-group rg-shopsphere-platform-dev --workspace-name law-shopsphere-dev
```

Expected: both show commands fail with not found. Soft-delete does not apply to LAW the same way as Key Vault. Confirm the group is gone.

Keep the module in Git.

---

## Interview story

**Situation:** ShopSphere Azure work started from a paper tenant sketch, so nothing stopped a later Day from applying AKS before a budget existed. **Task:** Make the platform resource group, the log workspace, and the USD 15 budget real Terraform that CI can test. **Action:** I wrote `azurerm_resource_group`, `azurerm_log_analytics_workspace` (`PerGB2018`, 30 days, 0.1 GB daily quota), and `azurerm_consumption_budget_resource_group` with 80 and 100 percent notifications on azurerm 5.9.0. I covered SKU, retention, and amount with `terraform test`. I refused 730-day retention and I refused a VM in this group. **Result:** I can walk tenant → management group → subscription → resource group, and I can say the budget is a resource that must exist before compute.

---

## Self-score checklist

- [ ] Platform module validates and `terraform test` passed.
- [ ] Budget amount is 15 with two thresholds.
- [ ] LAW retention is 30 days, not 730.
- [ ] I wrote the budget-after-compute blast radius.
- [ ] I destroyed the group, or I never applied.
- [ ] Files live in ShopSphere.

**Executed:** `terraform fmt`, `validate`, `terraform test` (1 passed) on Terraform 1.16.5 / azurerm 5.9.0. **Not executed:** live apply of LAW or the budget, Azure portal.
