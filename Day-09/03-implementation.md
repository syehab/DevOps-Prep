# Day 9 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 9 teaches modules and environments. Day 8 created one module and one Dev root. This Day **reuses that module** from Dev and from Prod. Each environment has its own folder, its own `.tfvars`, and its own state. You do not copy `azurerm_resource_group` into a second file.

Work in **your ShopSphere repository**. If Day 8 is not done, create `infra/azure/modules/rg` from [Day-08/03-implementation.md](../Day-08/03-implementation.md) first. Then continue here.

---

## Goal

Call one Terraform module from `environments/dev` and `environments/prod`. Pass `dev.tfvars` and `prod.tfvars`. Run `terraform test` in both roots. Change the module once and watch **both** plans show the same design change.

When you finish, you can walk this chain: environment values → `-var-file` → root module → child module → `azurerm_resource_group`. You can also explain blast radius: a module edit is a change to every environment that pins that module version.

Time box: 60 to 90 minutes.

---

## Capstone stage

| Path in ShopSphere | What it adds beyond Day 8 |
|:--|:--|
| `infra/azure/environments/prod/` | Second root. Same module. Different values. |
| `environments/dev/dev.tfvars` | Dev name and location |
| `environments/prod/prod.tfvars` | Prod name and location |
| `environments/*/tests/*.tftest.hcl` | A test per environment |
| `infra/bicep/modules/rg.bicep` + two param files | Bicep module called twice |
| `docs/day-09-module-lab.md` | Plan lines from both environments |

Day 38 is the harder sibling: the same module crosses account or subscription boundaries and a tagging policy. Do not add management groups today.

---

## What you need

You need Terraform 1.16.5 (or 1.9+) and the Day 8 module. Check:

```bash
terraform version
test -f infra/azure/modules/rg/main.tf && echo "rg module present"
```

Azure CLI is optional. If `az account show` works, you may plan both environments. Apply only if you will destroy both groups in this session.

```bash
az account show --query name -o tsv
```

If Azure is missing, `terraform test` in each environment folder is the required path. You still write Prod files. You do not fall back to `local_file` as the module resource.

---

## Cost

| Path | Estimated USD |
|:--|:--|
| Local `terraform test` in Dev and Prod | **0.00** |
| Azure apply of two empty resource groups | **0.00-0.10** |
| Bicep `what-if` twice | **0.00** |

Two empty resource groups do not bill. Do not add Storage, AKS, or public IPs today. Create a budget alert before any later Day that adds compute. See [../capstone/COST.md](../capstone/COST.md).

---

## Steps

1. Open ShopSphere. Confirm the Day 8 module exists. Create the Prod tree.

```bash
pwd
mkdir -p infra/azure/environments/prod/tests
mkdir -p infra/bicep/modules
```

If `modules/rg/main.tf` is missing, copy the three files from Day 8 now. Do not rewrite the resource in the environment folders.

2. Move Dev values out of `default` on the root variable. Put this in `infra/azure/environments/dev/dev.tfvars`.

```hcl
name     = "rg-shopsphere-dev"
location = "eastus"
```

Update `infra/azure/environments/dev/main.tf` so the root takes `location` from a variable and passes both values into the module. The module must not contain the string `dev`.

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
  type = string
}

variable "location" {
  type = string
}

module "rg" {
  source   = "../../modules/rg"
  name     = var.name
  location = var.location
}

output "resource_group_name" {
  value = module.rg.name
}
```

Add `location` to `infra/azure/modules/rg` if Day 8 already has it. The module already accepts `name` and `location`.

3. Copy the root into Prod. Do not copy state. Do not copy `.terraform`.

```bash
cp infra/azure/environments/dev/main.tf infra/azure/environments/prod/main.tf
```

Put this in `infra/azure/environments/prod/prod.tfvars`.

```hcl
name     = "rg-shopsphere-prod"
location = "eastus"
```

Prod uses a different name. The module path stays `../../modules/rg`.

4. Write tests that read the same names the tfvars files use.

`infra/azure/environments/dev/tests/rg.tftest.hcl`:

```hcl
mock_provider "azurerm" {}

run "dev_name" {
  command = plan

  variables {
    name     = "rg-shopsphere-dev"
    location = "eastus"
  }

  assert {
    condition     = module.rg.name == "rg-shopsphere-dev"
    error_message = "Dev must use rg-shopsphere-dev"
  }
}
```

`infra/azure/environments/prod/tests/rg.tftest.hcl`:

```hcl
mock_provider "azurerm" {}

run "prod_name" {
  command = plan

  variables {
    name     = "rg-shopsphere-prod"
    location = "eastus"
  }

  assert {
    condition     = module.rg.name == "rg-shopsphere-prod"
    error_message = "Prod must use rg-shopsphere-prod"
  }
}
```

5. Initialize and test Dev. Then initialize and test Prod. Each folder is its own root. Each folder gets its own `.terraform/` and lock file.

```bash
cd infra/azure/environments/dev
terraform init
terraform fmt
terraform validate
terraform test
```

```bash
cd infra/azure/environments/prod
terraform init
terraform fmt
terraform validate
terraform test
```

Expected each time: `Success! 1 passed, 0 failed.`

6. Plan with the variable files. Plan talks to Azure if you are logged in. If plan fails on auth, record `plan skipped` and keep the test evidence.

```bash
cd infra/azure/environments/dev
terraform plan -var-file=dev.tfvars -input=false
```

```bash
cd infra/azure/environments/prod
terraform plan -var-file=prod.tfvars -input=false
```

In `docs/day-09-module-lab.md`, copy the planned address from each side. Write one sentence: the module file did not name Dev or Prod. The tfvars files did.

Apply both only when you will destroy both:

```bash
terraform apply -var-file=dev.tfvars -input=false
# in the prod folder:
terraform apply -var-file=prod.tfvars -input=false
```

7. Add the Bicep module form. A resource group is a subscription-scope resource. Both the parent file and the child module must set `targetScope = 'subscription'`. A child without that line defaults to resource-group scope and will not compile.

Put this in `infra/bicep/modules/rg.bicep`.

```bicep
targetScope = 'subscription'

@description('Resource group name')
param name string

@description('Azure region')
param location string

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: name
  location: location
  tags: {
    project: 'shopsphere'
    purpose: 'lab'
    day: '09'
  }
}

output name string = rg.name
```

Put this in `infra/bicep/main.bicep`. The parent calls the module. Environment values stay in the command line or a `.bicepparam` file.

```bicep
targetScope = 'subscription'

param name string
param location string = 'eastus'

module rg 'modules/rg.bicep' = {
  name: 'rgDeploy'
  params: {
    name: name
    location: location
  }
}

output resourceGroupName string = rg.outputs.name
```

Build when the CLI exists:

```bash
az bicep build --file infra/bicep/main.bicep
```

Expected: `infra/bicep/main.json` exists. If `az` is missing, keep the `.bicep` files and record `az bicep build not executed`.

If you are logged in to Azure, preview Dev values, then Prod values. Use a **different** name from the Terraform groups if those groups already exist.

```bash
az deployment sub what-if \
  --location eastus \
  --template-file infra/bicep/main.bicep \
  --parameters name=rg-shopsphere-bicep-dev location=eastus
```

`what-if` does not create the group. Skip `create` unless you will delete that group in Clean up.

8. Record the chain in `docs/day-09-module-lab.md`. Write four lines: Dev values, Prod values, the module path, and one sentence that a module edit will appear in both plans.

---

## Verify

Read the notes as if you are on a review call. Walk `.tfvars` → `-var-file` → root → `modules/rg` → `azurerm_resource_group`.

Check these points:

- `modules/rg` is the only folder that contains `azurerm_resource_group`.
- `dev.tfvars` and `prod.tfvars` set different `name` values.
- You ran `terraform init` and `terraform test` in **both** environment folders.
- Each test passed with the name for that environment.
- The Bicep child module sets `targetScope = 'subscription'`.
- You did not copy state files between Dev and Prod.

If Dev and Prod would create the same resource group name, stop. Fix the tfvars files before you continue.

---

## Break and fix

Do both failures.

### Failure 1 — environment name hard-coded in the module

Edit `infra/azure/modules/rg/main.tf`. Replace `var.name` with a literal.

```hcl
resource "azurerm_resource_group" "lab" {
  name     = "rg-shopsphere-dev"
  location = var.location
  tags = {
    project = "shopsphere"
    purpose = "lab"
    day     = "09"
  }
}
```

Run the Prod test:

```bash
cd infra/azure/environments/prod
terraform test
```

Expected: `prod_name` fails because the module now always names Dev. Diagnose with `terraform test` and by reading the module. The environment folder is not the bug.

Restore `name = var.name`. Run `terraform test` in Dev and in Prod. Expected: both pass.

### Failure 2 — one module change, two plans

Add a tag in the module only. Do not edit the tfvars files.

```hcl
tags = {
  project = "shopsphere"
  purpose = "lab"
  day     = "09"
  owner   = "platform"
}
```

Plan Dev. Then plan Prod. Use `-var-file` if you are logged in. If you are not, the tests still call the same module. Add a temporary assert on a tag only if you also expose that tag as an output. The simpler evidence is both plans (or both test traces) showing the shared module path `../../modules/rg`.

Write in the notes: the `.tfvars` files did not change. The shared module did. That is the blast radius of a module version.

Keep the `owner` tag if you like it. It is a real tag, not a break.

---

## Stretch

- Add `environments/uat` with `uat.tfvars` and one test. Do not apply UAT on Azure in this lab.
- Pin the module with a Git tag instead of a relative path. Record why a relative path is fine for one repo and why a registry version is safer when two teams share the module.
- Run `terraform fmt -recursive` from `infra/azure` and commit only the formatting diff.

---

## Clean up

If you did not apply, keep the new Prod folder and the Bicep module. Destroy nothing in Azure.

If you applied Dev and Prod:

```bash
cd infra/azure/environments/dev
terraform destroy -var-file=dev.tfvars -input=false
```

```bash
cd infra/azure/environments/prod
terraform destroy -var-file=prod.tfvars -input=false
```

Confirm both groups are gone:

```bash
az group show --name rg-shopsphere-dev
az group show --name rg-shopsphere-prod
```

Expected: `ResourceGroupNotFound` twice.

If you created a Bicep group, delete it by name with `az group delete --yes --no-wait`.

Remove generated ARM if you do not want it in Git:

```bash
rm -f infra/bicep/main.json
```

Commit the environment folders, tests, Bicep module, lock files, and notes to ShopSphere. Do not commit `terraform.tfstate`. Day 10 moves state to Azure Storage.

---

## Interview story

**Situation:** ShopSphere needed the same resource group design in Dev and Prod without copying the resource block. **Task:** Reuse one Terraform module, pass values from each environment, and prove a module edit is a cross-environment change. **Action:** I kept `azurerm_resource_group` in `modules/rg`. I added `environments/prod` with `prod.tfvars` and a `terraform test` that expects `rg-shopsphere-prod`. I ran `init`, `validate`, and `test` in both roots. I hard-coded the Dev name on purpose, watched the Prod test fail, then restored `var.name`. I also compiled a subscription-scope Bicep module so I can tell the Azure-native story. **Result:** I can explain that environments differ by values and state, not by a copied resource, and that a shared module change must go through review before Prod.

---

## Self-score checklist

- [ ] `azurerm_resource_group` lives in the module once, not in each environment file.
- [ ] `dev.tfvars` and `prod.tfvars` set different names.
- [ ] `terraform test` passed in Dev and in Prod.
- [ ] I hard-coded the Dev name and I used the Prod test to catch it.
- [ ] I can explain module blast radius in two sentences.
- [ ] Bicep child and parent both set `targetScope = 'subscription'`.
- [ ] I destroyed every Azure group this lab created, or I never applied.
- [ ] Files live in ShopSphere, not only under `/tmp`.

Count the boxes. 7 or 8 is done.
