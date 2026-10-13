# Day 38 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 38 teaches environment and account boundaries. Day 9 already split Dev and Prod folders. This Day is the **harder sibling**: three environments, **three state keys**, a required-tag policy, and a break that puts all three environments in one state so you can watch later applies replace earlier ones.

Work in **your ShopSphere repository**. Reuse `modules/rg` or `modules/network`. Do not invent a new `local_file` module as the primary resource.

---

## Goal

Give Dev, UAT, and Prod their own backend key (`dev/terraform.tfstate`, `uat/terraform.tfstate`, `prod/terraform.tfstate`). Add a required-tag policy document. Then, on purpose, apply three variable files against **one** local state and record the replacement. Split the state again.

When you finish, you can say why a shared state file is a blast-radius bug, not a convenience.

Time box: 70 to 90 minutes.

---

## Capstone stage

| Path | Adds beyond Day 9 |
|:--|:--|
| `environments/uat/` | Third root + `uat.tfvars` + test |
| `environments/*/backend.hcl` | Different `key` values, same container |
| `infra/azure/policy/require-tags.json` | Azure Policy rule |
| `docs/day-38-boundary-lab.md` | Shared-state failure evidence |

---

## What you need

```bash
terraform version
test -f infra/azure/modules/rg/main.tf && echo "rg module present"
```

Azure is optional. The shared-state break uses a local backend so you do not need three subscriptions. A tagging policy apply needs Owner or Resource Policy Contributor. Skip that apply if you lack the role.

---

## Cost

| Path | Estimated USD |
|:--|:--|
| Three `terraform test` runs + local shared-state drill | **0.00** |
| Three empty resource groups | **0.00-0.10** |
| Azure Policy definition (no effect until assigned) | **0.00** |
| Policy assignment that blocks creates | **0.00** (it denies, it does not bill) |

Do not create three AKS clusters. Budget first if you apply groups. See [../capstone/COST.md](../capstone/COST.md).

---

## Steps

1. Add UAT next to Dev and Prod.

```bash
mkdir -p infra/azure/environments/uat/tests
cp infra/azure/environments/dev/main.tf infra/azure/environments/uat/main.tf
```

`infra/azure/environments/uat/uat.tfvars`:

```hcl
name     = "rg-shopsphere-uat"
location = "eastus"
```

`infra/azure/environments/uat/tests/rg.tftest.hcl`:

```hcl
mock_provider "azurerm" {}

run "uat_name" {
  command = plan

  variables {
    name     = "rg-shopsphere-uat"
    location = "eastus"
  }

  assert {
    condition     = module.rg.name == "rg-shopsphere-uat"
    error_message = "UAT must use rg-shopsphere-uat"
  }
}
```

If your root uses `module.network` instead of `module.rg`, assert the network output. Do not copy the resource block into UAT.

```bash
cd infra/azure/environments/uat
terraform init
terraform validate
terraform test
```

Expected: `1 passed`.

2. Write three backend files. Same Storage account. Different keys.

`environments/dev/backend.hcl` (from Day 10):

```hcl
resource_group_name  = "rg-shopsphere-tfstate"
storage_account_name = "stshopCHANGE_ME"
container_name       = "tfstate"
key                  = "dev/terraform.tfstate"
use_azuread_auth     = true
```

UAT uses `key = "uat/terraform.tfstate"`. Prod uses `key = "prod/terraform.tfstate"`.

If you are not on Azure, still write the three files. Then set each environment to local state for the break in step 4. The lesson is the **key**, not the cloud vendor.

3. Write the tagging policy. `infra/azure/policy/require-tags.json` is an Azure Policy rule. Mode `Indexed` applies to resources that support tags.

```json
{
  "mode": "Indexed",
  "policyRule": {
    "if": {
      "anyOf": [
        { "field": "tags['project']", "exists": "false" },
        { "field": "tags['env']", "exists": "false" }
      ]
    },
    "then": {
      "effect": "deny"
    }
  },
  "parameters": {}
}
```

If `az` works and you have permission:

```bash
az policy definition create \
  --name shopsphere-require-tags \
  --display-name "ShopSphere require project and env tags" \
  --rules infra/azure/policy/require-tags.json \
  --mode Indexed
```

Do not assign this at subscription scope if other teams share the subscription. Assign it to `rg-shopsphere-dev` only, or skip assignment and keep the JSON.

Add `env` to the module tags (`dev`, `uat`, or `prod`) so a future assignment would allow the groups this lab creates.

4. Break: one state, three environments. Create a throwaway folder. Do not use the real Dev folder.

```bash
mkdir -p /tmp/shopsphere-shared-state
cp infra/azure/environments/dev/main.tf /tmp/shopsphere-shared-state/main.tf
cp -R infra/azure/modules /tmp/shopsphere-shared-state/modules
# Fix the module source if the relative path broke.
```

If the module source `../../modules/rg` no longer resolves, write a tiny root that still calls the ShopSphere module with an absolute `source`.

Easier path: stay in ShopSphere and create `infra/azure/environments/shared-bad/`.

```hcl
# same module as Dev
# variables name + location
```

Apply Dev values. Then apply UAT values **without** changing folder or backend.

```bash
cd infra/azure/environments/shared-bad
terraform init
terraform apply -var='name=rg-shopsphere-dev' -var='location=eastus' -auto-approve
terraform state list
terraform apply -var='name=rg-shopsphere-uat' -var='location=eastus' -auto-approve
terraform state list
```

Expected: the second apply **replaces** the Dev group (or the local object) because one resource address cannot hold two names. `terraform state list` still shows one address. Dev is gone from state.

Copy both `state list` outputs into `docs/day-38-boundary-lab.md`. Write: one state file cannot represent three environments.

5. Destroy the bad folder. Delete `shared-bad`. Keep Dev, UAT, and Prod as separate roots.

```bash
cd infra/azure/environments/shared-bad
terraform destroy -var='name=rg-shopsphere-uat' -var='location=eastus' -auto-approve
cd ..
rm -rf shared-bad
```

---

## Verify

- UAT exists as its own root with its own test.
- Three `backend.hcl` files use three keys.
- `require-tags.json` denies missing `project` or `env`.
- You recorded a shared-state apply that replaced the first environment.
- You destroyed `shared-bad`.

---

## Break and fix

### Failure 1 — shared state (already in step 4)

If the second apply did **not** replace the first resource, you used two folders. Repeat in **one** folder with two `-var` names.

### Failure 2 — missing `env` tag

Remove the `env` tag from the module. If you assigned the policy, a live apply should deny. If you did not assign it, add a `terraform test` assert that a tag map includes `env`, or write a Checkov/custom note. Restore the tag.

---

## Stretch

- Sketch a management-group tree in the notes: Platform / Sandbox / Prod. Do not create management groups in a company tenant.
- Add an AWS Organizations SCP JSON next to the Azure policy for the Day 26 track (`DenyLeaveOrganization` or `DenyUnencryptedS3`). Do not attach it.

---

## Clean up

Destroy `shared-bad` if it still exists. Destroy any extra resource groups this lab created.

```bash
az group list --query "[?starts_with(name, 'rg-shopsphere')].name" -o tsv
```

Keep Dev/UAT/Prod folders. Delete policy definitions you created if they are lab-only:

```bash
az policy definition delete --name shopsphere-require-tags
```

---

## Interview story

**Situation:** ShopSphere had two environment folders after Day 9, but someone proposed one state file "to keep it simple" and a resource without an `env` tag. **Task:** Prove that one state cannot hold Dev and UAT, and write a deny policy for missing tags. **Action:** I added `environments/uat` with its own `terraform test` and a backend key `uat/terraform.tfstate`. I applied Dev then UAT in one folder and watched state keep a single address while the first name disappeared. I wrote Azure Policy JSON that denies resources without `project` and `env`. **Result:** I can explain environment isolation as separate state and separate blast radius, not as three tfvars against one backend.

---

## Self-score checklist

- [ ] UAT root and test exist.
- [ ] Three backend keys are written.
- [ ] Policy JSON denies missing tags.
- [ ] Shared-state apply replaced the first environment.
- [ ] `shared-bad` is destroyed.
- [ ] Files live in ShopSphere.
