# Remote state bootstrap (Day 10)

Do not store production state on a laptop. Day 10 creates:

- one resource group
- one Storage account (smallest SKU, `Standard` / `LRS`)
- one blob container named `tfstate`
- blob lease locking (`use_lockfile` or the Azure backend lock)

Estimated session cost: **USD 0.05-0.40**. Destroy or keep this account if you will reuse it for later Days. A leftover empty account is cheap. A leftover AKS cluster is not.

Local fallback: `backend "local" {}` plus the lock-stuck drill in `drills/terraform-live-debug/`.
