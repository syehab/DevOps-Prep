# Day 10 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 10 teaches Terraform State as the record of what Terraform manages, and why a team does not keep that record on a laptop. Day 8 and Day 9 still used local state. This Day adds a **remote backend**: Azure Storage, a private blob container, and a lock. Day 36 is the harder sibling. It adds `tflint`, Checkov, and more `terraform test` after this backend exists.

Work in **your ShopSphere repository**. You need the Day 8 `modules/rg` layout. If it is missing, create it from [Day-08/03-implementation.md](../Day-08/03-implementation.md) first.

---

## Goal

Write a bootstrap module that would create the state Storage account. Run `terraform test` on that module. Configure the Dev environment with a partial `backend "azurerm"` block. Practice a saved plan (`-out` then `apply` of that file). Practice a real state lock on your machine with two Terraform processes.

When you finish, you can explain local state versus remote state, why a lock exists, and why you do not commit `terraform.tfstate`. If you have Azure, you may apply the bootstrap and migrate Dev state. If you do not, the test plus the lock drill still complete the Day.

Time box: 60 to 90 minutes.

---

## Capstone stage

| Path in ShopSphere | What it adds |
|:--|:--|
| `infra/azure/backend/` | Bootstrap: RG + Storage account + `tfstate` container |
| `infra/azure/backend/tests/backend.tftest.hcl` | `terraform test` for those names |
| `infra/azure/environments/dev/backend.hcl` | Partial backend config (no secrets) |
| `docs/day-10-state-lab.md` | Lock ID, saved-plan note, migrate decision |

Do not put access keys in `backend.hcl`. Use Azure AD. `use_azuread_auth = true` is the flag.

---

## What you need

You need Terraform 1.16.5 (or 1.9+) and a shell.

```bash
terraform version
```

Azure CLI is optional. The bootstrap apply needs a logged-in account and a budget alert. The lock drill does not.

```bash
az account show --query name -o tsv
```

If that command fails, stay on the local path: test the bootstrap module, write `backend.hcl`, run the lock drill, run the saved plan on `terraform_data`. Do not invent an S3 backend today. Azure is the default track.

---

## Cost

| Path | Estimated USD | Why it is not always zero |
|:--|:--|:--|
| `terraform test` + lock drill + saved plan | **0.00** | Local only |
| Apply bootstrap Storage account (`Standard` / `LRS`) + container | **0.05-0.40** | Capacity and operations. Soft-delete can keep data after delete. |
| Empty resource group only | **0.00-0.10** | The group is free. The account inside it is not. |

Create a budget alert before you apply the Storage account. See [../capstone/COST.md](../capstone/COST.md). Do not write "cost stays at INR 0" if you created the account.

Destroy the account at the end of the session unless you will reuse it for later Days. A leftover empty account is cheap. Say so in the notes if you keep it on purpose.

---

## Steps

1. Open ShopSphere. Create the bootstrap folder.

```bash
mkdir -p infra/azure/backend/tests
mkdir -p docs
```

2. Write `infra/azure/backend/main.tf`. These resource types and arguments are valid on `hashicorp/azurerm` 5.9.0. `azurerm_storage_container` uses `storage_account_id` in this provider line.

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

variable "rg_name" {
  type = string
}

variable "location" {
  type = string
}

variable "storage_account_name" {
  type = string
}

resource "azurerm_resource_group" "state" {
  name     = var.rg_name
  location = var.location
  tags = {
    project = "shopsphere"
    purpose = "tfstate"
    day     = "10"
  }
}

resource "azurerm_storage_account" "state" {
  name                            = var.storage_account_name
  resource_group_name             = azurerm_resource_group.state.name
  location                        = azurerm_resource_group.state.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  https_traffic_only_enabled      = true
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.state.id
  container_access_type = "private"
}
```

Storage account names are 3 to 24 lowercase letters and numbers, globally unique. Pick a name you own, for example `stshop` plus six random digits. Write that name in `backend.tfvars`. Do not commit a name that includes a company secret.

`infra/azure/backend/backend.tfvars` (local values, you may gitignore this file):

```hcl
rg_name              = "rg-shopsphere-tfstate"
location             = "eastus"
storage_account_name = "stshopCHANGE_ME"
```

3. Write `infra/azure/backend/tests/backend.tftest.hcl`.

```hcl
mock_provider "azurerm" {}

run "names" {
  command = plan

  variables {
    rg_name              = "rg-shopsphere-tfstate"
    location             = "eastus"
    storage_account_name = "stshopspheretfstate"
  }

  assert {
    condition     = azurerm_resource_group.state.name == "rg-shopsphere-tfstate"
    error_message = "state resource group name"
  }

  assert {
    condition     = azurerm_storage_container.tfstate.name == "tfstate"
    error_message = "container must be tfstate"
  }
}
```

4. Test the bootstrap. This does not create Azure resources.

```bash
cd infra/azure/backend
terraform init
terraform fmt
terraform validate
terraform test
```

Expected: `Success! 1 passed, 0 failed.` Copy that line into `docs/day-10-state-lab.md`.

5. Write the Dev backend config. Put this **partial** block in `infra/azure/environments/dev/backend.tf`. Do not put keys here.

```hcl
terraform {
  backend "azurerm" {}
}
```

Put this in `infra/azure/environments/dev/backend.hcl`.

```hcl
resource_group_name  = "rg-shopsphere-tfstate"
storage_account_name = "stshopCHANGE_ME"
container_name       = "tfstate"
key                  = "dev/terraform.tfstate"
use_azuread_auth     = true
```

`backend.tf` already exists as the `terraform { required_providers ... }` block from Day 8. Merge the `backend` argument into that same `terraform` block. Terraform allows one `terraform` block, or several that Terraform merges. Prefer one block so readers see providers and backend together.

If you are **not** logged in to Azure, leave the `backend "azurerm"` line in the file and **do not** run `terraform init -backend-config=backend.hcl` yet. That init talks to Azure. Use the lock drill in step 7 instead. Write `remote init skipped — no Azure login` in the notes.

If you **are** logged in and you already applied the bootstrap:

```bash
cd infra/azure/environments/dev
terraform init -backend-config=backend.hcl
```

Terraform asks whether to copy existing local state to the new backend. Read the prompt. Type `yes` only when you intend that migrate. Then `terraform state list` still shows `module.rg.azurerm_resource_group.lab` if Day 8 or 9 applied that group.

6. Practice a saved plan. Use a tiny local root so this step does not need Azure. Create `infra/azure/loop-local/main.tf` only for this drill.

```hcl
resource "terraform_data" "marker" {
  input = "shopsphere-state-lab"
}
```

```bash
mkdir -p infra/azure/loop-local
# write main.tf, then:
cd infra/azure/loop-local
terraform init
terraform plan -out=tfplan
terraform show tfplan
terraform apply tfplan
```

Expected `show`: one `terraform_data.marker` to add. Expected apply: `Apply complete! Resources: 1 added`. A second `terraform plan` shows no changes.

`terraform apply tfplan` applies **that file**. It does not recompute a new plan. That is the production habit: review the file, then apply the file.

7. Practice a real lock. Keep `loop-local`. Change the resource so apply takes time.

```hcl
resource "terraform_data" "marker" {
  input = "shopsphere-state-lab-lock"
  provisioner "local-exec" {
    command = "sleep 20"
  }
}
```

Start apply. In a **second** terminal, run plan in the same folder.

```bash
# terminal 1
cd infra/azure/loop-local
terraform apply -auto-approve
```

```bash
# terminal 2, while terminal 1 still runs
cd infra/azure/loop-local
terraform plan
```

Expected plan error (Terraform 1.16.5 wording):

```text
Error: Error acquiring the state lock
Error message: resource temporarily unavailable
Lock Info:
  ID:        <uuid>
  Path:      terraform.tfstate
  Operation: OperationTypeApply
```

Copy the Lock Info into the notes. Wait for terminal 1 to finish. Run `terraform plan` again. Expected: no lock error.

If a process dies while it holds the lock, the unlock command is `terraform force-unlock <ID>`. Run that only when you know the other process is dead. Do not use `-lock=false` as a habit.

8. Optional Azure apply of the bootstrap. Budget first. Then:

```bash
cd infra/azure/backend
terraform plan -var-file=backend.tfvars -input=false
terraform apply -var-file=backend.tfvars -input=false
```

Expected plan: `+ azurerm_resource_group.state`, `+ azurerm_storage_account.state`, `+ azurerm_storage_container.tfstate`. After apply, go to step 5 and run `terraform init -backend-config=backend.hcl` in Dev.

Write two sentences in the notes: the Dev environment now reads and writes `dev/terraform.tfstate` in the container; two applies at once lose because of the blob lease (or the local lock you already saw).

---

## Verify

Read the notes on a call. You should name what is in state, where a team stores it, and what a lock prevents.

Check these points:

- `infra/azure/backend/main.tf` contains `azurerm_storage_account` and `azurerm_storage_container`.
- `terraform test` in `backend/` printed `1 passed, 0 failed`.
- `backend.hcl` has `use_azuread_auth = true` and no access key.
- You ran `terraform plan -out=tfplan`, `terraform show tfplan`, and `terraform apply tfplan`.
- You captured Lock Info from a second `terraform plan` during apply.
- You did not commit `terraform.tfstate` or `tfplan`.
- If you applied the Storage account, the notes include the USD estimate and a destroy or keep decision.

---

## Break and fix

Do both failures.

### Failure 1 — apply while a lock is held

You already ran this in step 7. If the second plan did **not** fail, the first apply finished too soon. Increase `sleep` to `30` and try once more.

If you killed the first process, the lock may remain. Diagnose:

```bash
terraform plan
```

Read the lock ID. Confirm no other Terraform process is running (`ps aux | grep terraform`). Then:

```bash
terraform force-unlock -force <ID>
```

`force-unlock` is for a dead process. It is not a way to skip a live apply.

### Failure 2 — drift, then decide the source of truth

Change the marker **outside** the next apply. Edit `loop-local/main.tf` so `input` is `changed-by-hand`. Do not apply yet.

```bash
cd infra/azure/loop-local
terraform plan
```

Expected: Terraform wants to update `terraform_data.marker`. State still holds `shopsphere-state-lab-lock` (or the last input). The file now says `changed-by-hand`.

Write the decision in the notes before you apply. If the edit is the new desired state, apply so state records it. If the edit was a mistake, put `input` back and apply to restore.

This is the same decision you make when someone changes a tag in the Azure portal. Investigate, then reconcile or codify. Do not apply as the first reflex.

---

## Stretch

- Run `terraform state pull` after a remote migrate and show that the JSON contains the resource address. Do not paste secrets from state into chat.
- Add `backend "azurerm"` to Prod with `key = "prod/terraform.tfstate"`. Same container. Different key. That is one state file per environment.
- Read `terraform force-unlock -help`. Write one sentence about when `-force` is justified.

---

## Clean up

Destroy the local drill:

```bash
cd infra/azure/loop-local
terraform destroy -auto-approve
rm -f tfplan terraform.tfstate terraform.tfstate.backup
```

You may keep `loop-local/main.tf` as a teaching file or delete the folder after the notes exist.

If you applied the bootstrap and you **will reuse** the account for Day 25 and Day 36, keep it. Write `KEEP_TFSTATE=yes` in the notes. Add a reminder to destroy it after the capstone.

If you will **not** reuse it:

```bash
cd infra/azure/backend
terraform destroy -var-file=backend.tfvars -input=false
az storage account show --name stshopCHANGE_ME --resource-group rg-shopsphere-tfstate
```

Expected after destroy: the account is gone. Soft-deleted accounts can remain for a few days and may still bill a little. Purge only lab accounts you created.

Commit `backend/main.tf`, the test, `backend.hcl` **without** a unique account name you do not want public, and the notes. Prefer a placeholder in Git and the real name in a gitignored `backend.tfvars`.

Do not commit state files.

---

## Interview story

**Situation:** ShopSphere Dev still stored Terraform state on one laptop after Day 9, so a second engineer could apply at the same time and lose the record. **Task:** Move state to Azure Storage with locking, and prove the lock on my machine before I paid for the account. **Action:** I wrote a bootstrap module for a `Standard` `LRS` account and a private `tfstate` container, and I covered the names with `terraform test` and `mock_provider`. I added a partial `backend "azurerm"` block with `use_azuread_auth = true` so no storage key sits in Git. I practiced `plan -out` and `apply tfplan`. I ran two Terraform processes and captured `Error acquiring the state lock`. **Result:** I can explain that state is Terraform's inventory, a remote backend is the team copy, and a lock is what stops two applies from writing at once.

---

## Self-score checklist

- [ ] I can say what state contains and why Git is the wrong place for it.
- [ ] Bootstrap module validates and `terraform test` passed.
- [ ] `backend.hcl` uses Azure AD and names `dev/terraform.tfstate`.
- [ ] I applied a saved `tfplan` file.
- [ ] I reproduced a state lock and I copied the lock ID.
- [ ] I decided source of truth on drift before I applied.
- [ ] I destroyed the local drill state.
- [ ] I either destroyed the Storage account or I recorded why I kept it.
- [ ] Files live in ShopSphere, not only under `/tmp`.

Count the boxes. 8 or 9 is done.
