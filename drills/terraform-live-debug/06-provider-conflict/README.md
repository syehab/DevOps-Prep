# 06 — Provider version conflict

**Timer:** 15 minutes.

## Symptom

```text
Error: Failed to query available provider packages
Could not retrieve the list of available versions for provider hashicorp/local:
no available releases match the given constraints 2.5.3, 2.4.0
```

Root wants `2.5.3`. The child module wants `2.4.0`. `terraform init` fails.

## Setup

```bash
bash drills/terraform-live-debug/06-provider-conflict/setup.sh /tmp/tf-debug-provider
cd /tmp/tf-debug-provider
terraform init
```

## Hints

1. Read **both** `required_providers` blocks.
2. Align on one version. Prefer the root pin and a `>=` in the module.
3. Do not delete `.terraform.lock.hcl` as the first move. The lock is not the conflict here. The constraints are.

## Solution

<details>
<summary>Open after the timer or after you tried the hints.</summary>

Change the child to:

```hcl
version = ">= 2.4.0, < 3.0.0"
```

Then `terraform init`. Expected: local 2.5.3 installs. Keep the exact pin in the **root**. Modules stay open on the minor line.

This is the same class of error as `azurerm` 4 vs 5, or `aws` 4 vs 5, when a module lags.

</details>
