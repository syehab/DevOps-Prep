# Day 8 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 8 teaches Infrastructure as Code. This lab writes **real Azure Terraform** (`hashicorp/azurerm` 5.9.0) and **one Bicep module**. You run `init`, `fmt`, `validate`, `terraform test`, then `plan`. You apply on Azure only after a budget alert exists. If you have no subscription, `terraform test` with `mock_provider` is the apply stand-in. You still walk the same command path.

Work in **your ShopSphere repository**, not in `/tmp`, and not inside this course clone. Copy [../capstone/shopsphere-starter/](../capstone/shopsphere-starter/) first if that repo does not exist yet.

---

## Goal

Create a reusable Terraform module that describes one Azure resource group. Call it from `environments/dev`. Prove the loop: `init` → `fmt` → `validate` → `terraform test` → `plan`. Compile one Bicep file. Run `what-if` when Azure is available.

When you finish, you can say what each command does. You can also say why `terraform test` is not a substitute for a reviewed plan against a real subscription.

Time box: 60 to 90 minutes.

---

## Capstone stage

This stage adds the first IaC root to ShopSphere.

| Path in ShopSphere | What it is |
|:--|:--|
| `infra/azure/modules/rg/` | Reusable resource-group module |
| `infra/azure/environments/dev/` | Dev root module that calls `rg` |
| `infra/azure/environments/dev/tests/rg.tftest.hcl` | `terraform test` with `mock_provider` |
| `infra/bicep/rg.bicep` | Subscription-scope Bicep that creates the same group |
| `docs/day-08-iac-lab.md` | Notes, command output, cost decision |

Later Days add remote state (Day 10), pipelines (Day 25), and `tflint` / Checkov hardening (Day 36). Do not add those today.

---

## What you need

You need Terraform 1.16.5 (or 1.9+), a shell, and Git. Check the version first:

```bash
terraform version
```

Expected first line: `Terraform v1.16.5` or another 1.9+ release. Install 1.16.5 from [releases.hashicorp.com/terraform/1.16.5](https://releases.hashicorp.com/terraform/1.16.5/) if the command is missing.

Azure CLI is optional. Bicep CLI is optional. Check them:

```bash
az version
az bicep version
az account show --query "{name:name,id:id}" -o table
```

If `az account show` fails, use the **local path**. You still write the `azurerm` module and run `terraform test`. You do not invent a different provider. You do not skip the Bicep file. You run `az bicep build` when the CLI exists. If Bicep is missing, keep the `.bicep` file and record `bicep not installed`.

Create notes at `docs/day-08-iac-lab.md` inside ShopSphere. Do not paste subscription GUIDs, tenant IDs, or access tokens.

---

## Cost

| Path | Estimated USD | Why |
|:--|:--|:--|
| Local: `fmt`, `validate`, `terraform test`, `az bicep build` | **0.00** | No Azure API create |
| Azure: budget + `terraform apply` of one resource group | **0.00-0.10** | An empty resource group does not bill. Nested resources would. |
| Azure: `az deployment sub what-if` | **0.00** | Preview only |
| Azure: `az deployment sub create` of the Bicep group | **0.00-0.10** | Same as the Terraform group. Do not create both and leave them. |

Create the budget alert **before** any apply that can build compute. Today you create only a resource group, so the bill stays near zero. The habit still starts today. See [../capstone/COST.md](../capstone/COST.md).

Do not write "cost stays at INR 0" in your notes if you applied in Azure. Write the estimate above.

---

## Steps

1. Open your ShopSphere repository. Confirm you are not inside DevOps-Prep.

```bash
pwd
git rev-parse --show-toplevel
```

Create the folders for this stage:

```bash
mkdir -p infra/azure/modules/rg
mkdir -p infra/azure/environments/dev/tests
mkdir -p infra/bicep
mkdir -p docs
```

Write one sentence in `docs/day-08-iac-lab.md`: this Day manages one resource group as desired state. It does not manage AKS.

2. Write the module. Put this in `infra/azure/modules/rg/variables.tf`.

```hcl
variable "name" {
  type        = string
  description = "Azure resource group name."
}

variable "location" {
  type        = string
  description = "Azure region, for example eastus."
  default     = "eastus"
}
```

Put this in `infra/azure/modules/rg/main.tf`. The resource is `azurerm_resource_group`. That name is real in provider 5.9.0.

```hcl
resource "azurerm_resource_group" "lab" {
  name     = var.name
  location = var.location
  tags = {
    project = "shopsphere"
    purpose = "lab"
    day     = "08"
  }
}
```

Put this in `infra/azure/modules/rg/outputs.tf`.

```hcl
output "name" {
  value = azurerm_resource_group.lab.name
}

output "id" {
  value = azurerm_resource_group.lab.id
}
```

The module does not name Dev or Prod. The caller passes `name`.

3. Write the Dev root. Put this in `infra/azure/environments/dev/main.tf`.

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

variable "name" {
  type    = string
  default = "rg-shopsphere-dev"
}

module "rg" {
  source   = "../../modules/rg"
  name     = var.name
  location = "eastus"
}

output "resource_group_name" {
  value = module.rg.name
}
```

`resource_provider_registrations = "none"` is the azurerm 5.x default. Set it so the plan does not try to register every Azure resource provider.

4. Write the test. Put this in `infra/azure/environments/dev/tests/rg.tftest.hcl`. `mock_provider` is a real `terraform test` block. It does not call Azure.

```hcl
mock_provider "azurerm" {}

run "plan_creates_rg" {
  command = plan

  assert {
    condition     = module.rg.name == "rg-shopsphere-dev"
    error_message = "module.rg.name must be rg-shopsphere-dev"
  }
}
```

5. Prepare the working directory. Stay in `infra/azure/environments/dev` for every Terraform command in this lab.

```bash
cd infra/azure/environments/dev
terraform init
```

Expected: Terraform installs `hashicorp/azurerm` v5.9.0 and writes `.terraform.lock.hcl`. `init` does not create a resource group. Run `terraform init` a second time. Terraform should report that the directory is already initialized.

Commit `.terraform.lock.hcl` later. Do not commit `.terraform/` or `terraform.tfstate`.

6. Format and validate.

```bash
terraform fmt -recursive ../..
terraform validate
```

Expected `validate` line: `Success! The configuration is valid.`

`fmt` changes spacing only. `validate` checks syntax and arguments. It does not replace `plan`.

7. Run the unit test. This is the local apply stand-in.

```bash
terraform test
```

Expected:

```text
tests/rg.tftest.hcl... pass
  run "plan_creates_rg"... pass
Success! 1 passed, 0 failed.
```

Copy that block into `docs/day-08-iac-lab.md`. If the test fails, stop. Fix the module or the assert before you continue.

8. Preview against Azure **only** when `az account show` works. Create the budget first if this subscription has none. See [../capstone/COST.md](../capstone/COST.md).

```bash
terraform plan -input=false
```

Expected action: `+ azurerm_resource_group.lab` inside `module.rg`. Confirm that nothing is marked destroy. If plan fails with an authentication error, stay on the local path. Do not paste the error token.

Apply only when you will destroy in the same session:

```bash
terraform apply -input=false
```

Type `yes` when you accept the plan. Then:

```bash
az group show --name rg-shopsphere-dev --query "{name:name,location:location}" -o table
terraform state list
```

Expected state address: `module.rg.azurerm_resource_group.lab`.

If you have no Azure account, write `plan skipped — no Azure login` in the notes. The test result is your evidence for this Day.

9. Add Bicep. Put this in `infra/bicep/rg.bicep`. `targetScope = 'subscription'` is required because a resource group is a subscription-scope resource.

```bicep
targetScope = 'subscription'

@description('Name of the ShopSphere lab resource group')
param name string

@description('Azure region, for example eastus')
param location string

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: name
  location: location
  tags: {
    project: 'shopsphere'
    purpose: 'lab'
    day: '08'
  }
}

output resourceGroupName string = rg.name
```

Build the file when the Bicep CLI exists:

```bash
az bicep build --file infra/bicep/rg.bicep
```

Expected: `infra/bicep/rg.json` exists. That file is the ARM template. You may commit it or gitignore it. Prefer gitignore and keep the `.bicep` source as the desired state.

If Azure login works, preview. Do not create a second group if Terraform already created `rg-shopsphere-dev`.

```bash
az deployment sub what-if \
  --location eastus \
  --template-file infra/bicep/rg.bicep \
  --parameters name=rg-shopsphere-bicep-dev location=eastus
```

Expected: a what-if report that would create `rg-shopsphere-bicep-dev`. `what-if` does not create it. Skip `az deployment sub create` unless you have time to delete that group in Clean up.

If `az` is missing, keep the `.bicep` file and record `az bicep build not executed`.

10. Write a short comparison in the notes. Terraform talks to Azure through the `azurerm` provider. Bicep compiles to ARM and Azure Resource Manager applies it. Both describe desired state. The review step is `plan` or `what-if`. The change step is `apply` or `create`.

---

## Verify

Read the notes out loud as if you are in an interview. Name `init`, `fmt`, `validate`, `terraform test`, `plan`, `apply`, and `destroy` without opening this file.

Check these points:

- The working directory is your ShopSphere repo, not `/tmp` and not DevOps-Prep.
- `infra/azure/modules/rg/main.tf` contains `azurerm_resource_group`. It does not contain `local_file` as the primary resource.
- `terraform init` created `.terraform.lock.hcl` and selected `azurerm` 5.9.0.
- `terraform validate` printed `The configuration is valid`.
- `terraform test` printed `1 passed, 0 failed`.
- `infra/bicep/rg.bicep` uses `targetScope = 'subscription'`.
- If you applied in Azure, `terraform state list` shows `module.rg.azurerm_resource_group.lab`.
- If you skipped Azure, the notes say so. They do not claim a resource group exists.

If any step is missing, run that command again and add the evidence before you continue.

---

## Break and fix

Do both failures. They are common in reviews.

### Failure 1 — provider block without `features`

The `azurerm` provider requires a `features` block. Remove it on purpose.

```hcl
provider "azurerm" {
  resource_provider_registrations = "none"
}
```

Run:

```bash
cd infra/azure/environments/dev
terraform validate
```

Expected: validate fails. The message names `features`. This is a configuration error, not a cloud outage. Diagnose with `terraform validate`, not with the Azure portal.

Restore `features {}`. Run `terraform validate` again. Expected: `Success! The configuration is valid.`

### Failure 2 — test assert does not match the module

Change the assert so it looks for the wrong name:

```hcl
condition     = module.rg.name == "rg-shopsphere-prod"
```

Run:

```bash
terraform test
```

Expected: `plan_creates_rg` fails. The error_message you wrote should appear. The module is not wrong. The test is. This is the same habit as a pipeline that fails on a bad check, not on a bad plan.

Put the condition back to `rg-shopsphere-dev`. Run `terraform test` again. Expected: `1 passed, 0 failed`.

If you applied the group in Azure, you may also create drift. Change a tag in the portal. Run `terraform plan`. The plan should want to put the tag back. Do not apply that restore until you decide the code is the source of truth. Then apply, or change the code if the portal edit was intended.

---

## Stretch

Do one of these if you have time. They are senior extras, not required for the Day check.

- Add a second `run` block in `rg.tftest.hcl` that sets `variables { name = "rg-shopsphere-uat" }` and asserts that output.
- Install `tflint` and run `tflint --init && tflint` in `environments/dev`. Day 36 makes this a required gate.
- Pin `azurerm` with `= 5.9.0` in the module as well as the root, then run `terraform init -upgrade` and read the lock file diff.

---

## Clean up

If you did **not** apply in Azure, there is no cloud resource to delete. Keep the Terraform and Bicep files. They are the capstone stage.

If you applied `rg-shopsphere-dev`:

```bash
cd infra/azure/environments/dev
terraform destroy -input=false
az group show --name rg-shopsphere-dev
```

Expected destroy plan: `module.rg.azurerm_resource_group.lab` will be destroyed. Type `yes`. Expected `az group show`: `ResourceGroupNotFound`.

If you created `rg-shopsphere-bicep-dev`:

```bash
az group delete --name rg-shopsphere-bicep-dev --yes --no-wait
```

Do not use `-target` as cleanup. Destroy the whole configuration.

Delete `infra/bicep/rg.json` if you do not want generated ARM in Git:

```bash
rm -f infra/bicep/rg.json
```

Commit the `.tf`, `.tftest.hcl`, `.bicep`, lock file, and notes to ShopSphere. Do not commit `terraform.tfstate` if a local state file appeared. Day 10 moves state off the laptop.

---

## Interview story

**Situation:** I needed a repeatable way to create the first ShopSphere platform object, an Azure resource group, without clicking in the portal. **Task:** Put the group in a Terraform module, prove the change without spending money, and show the Azure-native Bicep path the JDs also name. **Action:** I wrote `azurerm_resource_group` in `modules/rg`, called it from `environments/dev` with provider 5.9.0, and ran `terraform test` with `mock_provider` so CI can check the name without Azure credentials. I compiled `rg.bicep` and used `what-if` when a subscription was present. When I applied for real, I destroyed the group in the same session. **Result:** I can walk `init`, `fmt`, `validate`, `test`, `plan`, `apply`, and `destroy`, and I can say why a passing unit test is not the same as a reviewed plan against production.

---

## Self-score checklist

Score 1 only when you have evidence in `docs/day-08-iac-lab.md` or in Git.

- [ ] I can explain desired state versus a create script in two sentences.
- [ ] `modules/rg` contains `azurerm_resource_group`, not a `local_file` stand-in as the primary resource.
- [ ] `terraform validate` succeeded in `environments/dev`.
- [ ] `terraform test` printed `1 passed, 0 failed`.
- [ ] I broke `features {}` and I used `terraform validate` to diagnose it.
- [ ] I broke the test name and I used `terraform test` to diagnose it.
- [ ] `infra/bicep/rg.bicep` exists with `targetScope = 'subscription'`.
- [ ] I either destroyed every Azure group this lab created, or I never applied.
- [ ] The files live in my ShopSphere repo, not only under `/tmp`.

Count the checked boxes. 8 or 9 is done. Below 8, rerun the missing step.
