# Day 18 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 18 teaches identity and secrets. The old lab only proved `.gitignore`. This lab still does that, then adds the Senior pieces: **GitHub OIDC to Entra** (no client secret) and a **Key Vault CSI** SecretProviderClass for the catalog Pod. Workload Identity YAML from Day 17 is the Kubernetes side of the same chain.

Work in **your ShopSphere repository**. Generate secrets only in ignored files. Never commit them.

---

## Goal

1. Prove Git ignores a secret file.
2. Write Terraform for a user-assigned identity plus two federated credentials: GitHub Actions and the `shopsphere:catalog` ServiceAccount.
3. Write a SecretProviderClass that mounts one Key Vault secret.
4. Run `terraform test` on the identity module. Apply Key Vault only if a budget exists.

Time box: 70 to 90 minutes.

---

## Capstone stage

| Path | Adds |
|:--|:--|
| `secrets/app.env` + `.gitignore` | Ignored secret file |
| `infra/azure/modules/identity/` | UAMI + two federated credentials |
| `k8s/identity/secretproviderclass.yaml` | Key Vault CSI |
| `docs/day-18-identity.md` | Subjects and `check-ignore` output |

---

## What you need

```bash
git version
openssl version
terraform version
```

Azure CLI is optional. kind is optional. `terraform test` does not need Azure.

---

## Cost

| Path | Estimated USD |
|:--|:--|
| Git ignore + `terraform test` + YAML | **0.00** |
| Key Vault Standard + a few operations | **0.10-0.30** |
| Soft-deleted vault retention | small; purge only lab vaults |

Create a budget before you apply a vault. See [../capstone/COST.md](../capstone/COST.md). Do not write "INR 0" if you created a vault.

---

## Steps

1. Secret hygiene in ShopSphere, not in a second clone.

```bash
mkdir -p secrets docs
openssl rand -hex 16 > secrets/app.env
printf 'secrets/\n' >> .gitignore
git check-ignore -v secrets/app.env
git status --porcelain secrets/app.env
```

Expected: `check-ignore` prints a `.gitignore` rule. `git status` does **not** list `secrets/app.env`. Do not paste the hex into notes.

2. Write `infra/azure/modules/identity/main.tf`. These arguments are valid on **azurerm 5.9.0**. The credential resource uses `user_assigned_identity_id`. It does **not** use `parent_id` or `resource_group_name`.

```hcl
variable "rg" { type = string }
variable "location" { type = string }
variable "oidc_issuer_url" { type = string }
variable "github_subject" { type = string }

resource "azurerm_user_assigned_identity" "catalog" {
  name                = "id-shopsphere-catalog"
  resource_group_name = var.rg
  location            = var.location
}

resource "azurerm_federated_identity_credential" "github" {
  name                      = "github-shopsphere"
  user_assigned_identity_id = azurerm_user_assigned_identity.catalog.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = "https://token.actions.githubusercontent.com"
  subject                   = var.github_subject
}

resource "azurerm_federated_identity_credential" "aks" {
  name                      = "aks-catalog"
  user_assigned_identity_id = azurerm_user_assigned_identity.catalog.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = var.oidc_issuer_url
  subject                   = "system:serviceaccount:shopsphere:catalog"
}

output "client_id" {
  value = azurerm_user_assigned_identity.catalog.client_id
}
```

`versions.tf` needs only `required_providers` for `hashicorp/azurerm` `5.9.0`. Do not put a `provider` block in the module.

3. Write `infra/azure/modules/identity/tests/id.tftest.hcl`.

```hcl
mock_provider "azurerm" {}

run "subjects" {
  command = plan

  variables {
    rg              = "rg-shopsphere-dev"
    location        = "eastus"
    oidc_issuer_url = "https://eastus.oic.prod-aks.azure.com/example/"
    github_subject  = "repo:example/shopsphere:environment:azure-dev"
  }

  assert {
    condition     = azurerm_federated_identity_credential.aks.subject == "system:serviceaccount:shopsphere:catalog"
    error_message = "aks subject must match the ServiceAccount"
  }

  assert {
    condition     = azurerm_federated_identity_credential.github.issuer == "https://token.actions.githubusercontent.com"
    error_message = "github issuer"
  }
}
```

```bash
cd infra/azure/modules/identity
terraform init
terraform validate
terraform test
```

Expected: `1 passed, 0 failed`. This block was executed on Terraform 1.16.5 / azurerm 5.9.0.

4. GitHub subject formats that are real:

| When the workflow runs | Subject |
|:--|:--|
| A branch | `repo:ORG/REPO:ref:refs/heads/main` |
| A GitHub Environment | `repo:ORG/REPO:environment:azure-dev` |

Day 25's apply job uses `environment: azure-dev`. Prefer that subject so a push to a random branch cannot apply.

5. Key Vault CSI. `k8s/identity/secretproviderclass.yaml`:

```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: catalog-kv
  namespace: shopsphere
spec:
  provider: azure
  parameters:
    usePodIdentity: "false"
    clientID: "00000000-0000-0000-0000-000000000000"
    keyvaultName: kv-shopsphere-dev
    tenantId: "00000000-0000-0000-0000-000000000000"
    objects: |
      array:
        - |
          objectName: db-password
          objectType: secret
```

Replace the GUIDs when you apply a real vault. On `kind` this object is documentation. The CSI driver is not installed unless you add it. Write that limit in the notes.

Mount it later with:

```yaml
volumes:
  - name: secrets-store
    csi:
      driver: secrets-store.csi.k8s.io
      readOnly: true
      volumeAttributes:
        secretProviderClass: catalog-kv
```

Do not put `db-password` in Git.

6. Optional Azure apply. Budget first. Create a vault with RBAC, `soft_delete_retention_days = 7`, and no public blob. Grant the UAMI `Key Vault Secrets User` on one secret. Then set `clientID` in the SecretProviderClass to `terraform output -raw client_id`. Destroy the vault at the end unless Day 32 will reuse it.

---

## Verify

- `git check-ignore` names `secrets/app.env`.
- `terraform test` passed on both federated subjects.
- The GitHub issuer is `https://token.actions.githubusercontent.com`.
- SecretProviderClass uses `secrets-store.csi.x-k8s.io/v1` and `provider: azure`.
- No secret value is in `docs/`.

---

## Break and fix

### Failure 1 — staged secret

```bash
git add -f secrets/app.env
git status --porcelain
git rm --cached secrets/app.env
git check-ignore -v secrets/app.env
```

Expected: `add -f` stages it. `git rm --cached` unstages it **before** a commit. If you committed it, the secret is in history. Rotate it. Do not rely on a later delete.

### Failure 2 — wrong federated subject

Change the test subject to `system:serviceaccount:default:default`. Run `terraform test`. Expected: assert fails. Restore `shopsphere:catalog`. A matching issuer with the wrong subject still issues a token that Azure will reject.

If you validate the old `parent_id` argument, azurerm 5.9.0 reports `Unsupported argument`. Use `user_assigned_identity_id`.

---

## Stretch

- Add `azurerm_role_assignment` for `Key Vault Secrets User` on one secret id, not on the whole vault.
- Write the AWS twin: IRSA annotation `eks.amazonaws.com/role-arn` (Day 27/28).

---

## Clean up

```bash
rm -f secrets/app.env
```

If you applied a vault:

```bash
terraform destroy
az keyvault list-deleted --query "[?name=='kv-shopsphere-dev'].name" -o tsv
```

Purge only that lab vault, and only if policy allows.

---

## Interview story

**Situation:** ShopSphere still needed a password in GitHub Secrets and had no Pod-to-vault path. **Task:** Federate GitHub and the catalog ServiceAccount to one Entra identity, and mount one secret through CSI. **Action:** I wrote `azurerm_federated_identity_credential` with `user_assigned_identity_id` (azurerm 5.9.0), subjects `environment:azure-dev` and `system:serviceaccount:shopsphere:catalog`, and I covered both with `terraform test`. I kept `secrets/app.env` out of Git with `check-ignore`, then staged it on purpose and ran `git rm --cached` before any commit. **Result:** I can explain OIDC as a token exchange, not as a stored password, and I can say CSI reads Key Vault at start; it is not a secret in the image.

---

## Self-score checklist

- [ ] Secret file is ignored and I never committed it.
- [ ] `terraform test` passed.
- [ ] I used `user_assigned_identity_id`, not `parent_id`.
- [ ] SecretProviderClass is in Git with placeholder GUIDs only.
- [ ] I destroyed any vault I created.

**Executed:** `git check-ignore`, `openssl rand`, federated credential `validate` + `terraform test` on 5.9.0. **Not executed:** Key Vault apply, CSI driver on kind, live GitHub OIDC token.
