# Day 11 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 11 teaches the structure above individual resources. A landing zone is identity, governance, isolation, and ownership that workloads deploy into. The old lab wrote HarborMart in `/tmp` and forbade Terraform. This lab still designs HarborMart (the lesson company). It lands the files in **your ShopSphere repository** and adds a real `azurerm` management group plus a custom policy that `terraform test` can cover.

Do not apply a management group in a tenant you do not own.

---

## Goal

Write `docs/landing-zone.md` for HarborMart. Add `infra/azure/landing-zone/` with `azurerm_management_group` `mg-shopsphere` and a custom HTTPS policy. Run `terraform test`. Then break the design: Dev and Production share one subscription. Restore the split and write the blast radius.

Time box: 60 to 80 minutes.

---

## Capstone stage

| Path | Adds |
|:--|:--|
| `docs/landing-zone.md` | HarborMart design + Azure/AWS map |
| `infra/azure/landing-zone/` | Management group + policy |
| `infra/azure/landing-zone/tests/lz.tftest.hcl` | Name asserts |
| `docs/day-11-landing-zone.md` | Test output + blast-radius note |

HarborMart is the fictional retailer in the lesson. ShopSphere is the repo you keep. The module names stay `shopsphere` so later Days reuse them.

---

## What you need

```bash
terraform version
```

Terraform 1.16.5 and `hashicorp/azurerm` `5.9.0` are the pins this lab tested. Azure login is optional. `terraform test` does not need a tenant.

---

## Cost

| Path | Estimated USD |
|:--|:--|
| Design + `terraform test` | **0.00** |
| Apply a management group + custom policy in a tenant you own | **0.00** (policy documents do not bill) |
| `az account create` / new subscriptions | **Do not run** |

A leftover policy is cheap. A leftover extra subscription is not. Stay on the test path unless this is a throwaway sandbox. Do not write "INR 0" if you created subscriptions.

---

## Steps

1. Open ShopSphere. Create folders.

```bash
mkdir -p docs infra/azure/landing-zone/tests
```

2. Write `infra/azure/landing-zone/main.tf`. These arguments are valid on **azurerm 5.9.0**. `features {}` is required. `resource_provider_registrations = "none"` keeps plan-only tenants quiet.

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

resource "azurerm_management_group" "platform" {
  display_name = "mg-shopsphere"
  name         = "mg-shopsphere"
}

resource "azurerm_policy_definition" "require_https" {
  name         = "shopsphere-require-https"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "ShopSphere require HTTPS"
  policy_rule = jsonencode({
    if = {
      allOf = [
        { field = "type", equals = "Microsoft.Storage/storageAccounts" },
        { field = "Microsoft.Storage/storageAccounts/supportsHttpsTrafficOnly", equals = "false" }
      ]
    }
    then = { effect = "deny" }
  })
}
```

3. Write `infra/azure/landing-zone/tests/lz.tftest.hcl`.

```hcl
mock_provider "azurerm" {}

run "names" {
  command = plan

  assert {
    condition     = azurerm_management_group.platform.name == "mg-shopsphere"
    error_message = "mg name"
  }

  assert {
    condition     = azurerm_policy_definition.require_https.name == "shopsphere-require-https"
    error_message = "policy name"
  }
}
```

```bash
cd infra/azure/landing-zone
terraform init
terraform validate
terraform test
```

Expected: `Success! 1 passed, 0 failed.` Executed on Terraform 1.16.5 / azurerm 5.9.0. Copy that line into `docs/day-11-landing-zone.md`.

4. Write `docs/landing-zone.md`. Required sections (prose, not empty headings):

- Identity: one Entra tenant / one AWS Organization. A tenant is not a subscription.
- Governance: root management group; Production, Non-Production, Security branches. Five guardrails: allowed regions, required tags, mandatory logging, who may create subscriptions, ban on public databases.
- Isolation: Dev, UAT, Production **subscriptions** (AWS: accounts). Security / log-archive under Security.
- Resource groups for the catalog: compute, database, storage, monitoring share a lifecycle. A resource group is not a region and not the isolation unit.
- Region: pick one primary. Record latency, residency, availability, cost. Production compute across two zones.
- Terraform state: Network, Platform, catalog; Prod state separate from Dev. A Dev identity must not write Prod state.
- Azure ↔ AWS table:

```markdown
| Job | Azure | AWS |
|:--|:--|:--|
| Identity boundary | Entra ID tenant | Organization |
| Governance grouping | Management groups | Organizational Units |
| Guardrails | Azure Policy | Service Control Policies |
| Isolation unit | Subscription | Account |
| Lifecycle grouping | Resource group | Tags and accounts (no exact RG equivalent) |
| Workload | Resource | Resource |
```

Write two sentences: equivalent jobs, not identical services. Day 26 is the AWS SCP twin.

- Ownership: Network, Platform, Security, catalog team. Developers write in Dev. They do not hold unrestricted Production administration.
- Lead close: hierarchy, governance, environment boundaries, owners, state lines, which pipeline may apply.

---

## Verify

- `terraform test` printed 1 passed.
- Document names one tenant, three environment subscriptions, and split state.
- Table is complete. The note says equivalent, not identical.
- You did not run `az account create`.

---

## Break and fix

### Failure 1 — shared subscription

Copy `docs/landing-zone.md` to `docs/landing-zone-broken.md`. Put Dev and Production in one subscription. Keep tidy RG names. Write **Blast radius**: who can delete Prod data, what happens to Prod bills when Dev runs away, how far one apply reaches if one state holds both. Restore the main file so they are separate. A Dev mistake must not reach Production.

### Failure 2 — rename the management group

Change `name` to `mg-wrong`. `terraform test` fails. Restore `mg-shopsphere`.

---

## Stretch

- Add `azurerm_management_group_policy_assignment` that assigns the HTTPS policy to `mg-shopsphere`.
- Map this file to Day 26 `DenyLeaveOrganization`.

---

## Clean up

Do not apply the management group unless you own the tenant. If you applied, destroy the same session.

```bash
terraform destroy
```

Keep the markdown in Git.

---

## Interview story

**Situation:** The landing-zone homework lived in `/tmp` and forbade Terraform. **Task:** Show HarborMart isolation in Git and a real `azurerm` policy. **Action:** I wrote one Entra tenant, Production / Non-Production / Security management groups, and separate Dev, UAT, and Prod subscriptions. I added `azurerm_management_group.platform` and a deny-HTTP storage policy, covered both with `terraform test` on azurerm 5.9.0. I then put Dev and Prod in one subscription on purpose and wrote the blast radius: access, bills, and one apply. **Result:** I can map subscription ↔ account and Azure Policy ↔ SCP, and I can say why a resource group is not the isolation unit.

---

## Self-score checklist

- [ ] `terraform test` passed.
- [ ] `docs/landing-zone.md` has identity, governance, isolation, state, and the table.
- [ ] Broken file shows the shared-subscription blast radius.
- [ ] I did not create a subscription.

**Executed:** landing-zone `validate` + `terraform test` (1 passed) on Terraform 1.16.5 / azurerm 5.9.0. **Not executed:** live management group apply, new subscriptions, AWS Organizations.
