# Day 39 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 39 teaches Disaster Recovery as a restore you can **prove**, not as a backup file you hope exists. ShopSphere's business numbers in the lesson are an **RPO of 15 minutes** and an **RTO of 60 minutes**. The old lab tarred a file in `/tmp`. This lab still measures a restore with a clock. It then adds a **second-region copy** (the cross-region drill) and a real `azurerm_data_protection_backup_vault` that `terraform test` can cover. A backup that has never been restored is an assumption.

Work in **your ShopSphere repository** for the vault module and the notes. The timed restore may use a data directory under ShopSphere `var/dr-lab/` that you delete in Clean up.

---

## Goal

1. Write RPO and RTO as one-liners **before** you restore.
2. Take a backup of a durable marker. Copy that backup to a second "region" directory (`eastus` → `eastus2`).
3. Delete the marker. Restore **from the second region**. Record elapsed seconds. That is measured RTO. The age of the backup versus the last write is measured RPO.
4. Add `infra/azure/modules/backup` with a GeoRedundant Data Protection vault and `cross_region_restore_enabled = true`. Run `terraform test`.
5. Optional: copy a blob between two Storage accounts in different Azure regions. Destroy both.

Time box: 70 to 90 minutes.

---

## Capstone stage

| Path in ShopSphere | What it adds |
|:--|:--|
| `var/dr-lab/` (gitignored) | Timed backup / cross-region restore data |
| `infra/azure/modules/backup/` | Data Protection vault |
| `infra/azure/modules/backup/tests/backup.tftest.hcl` | Redundancy and CRR asserts |
| `docs/day-39-dr.md` | RPO line, RTO line, elapsed seconds, USD estimate |

Add `var/dr-lab/` to `.gitignore`. Do not commit backup payloads.

---

## What you need

```bash
terraform version
command -v tar
command -v date
az account show --query name -o tsv
command -v infracost || true
```

Terraform 1.16.5 and azurerm 5.9.0 are the pins for the vault. `tar` and `date` are enough for the measured drill. Azure CLI is optional. Infracost is optional (stretch).

Docker / `velero` on `kind` is an extra local path if you already have the Day 20 cluster. It is not required.

---

## Cost

| Path | Estimated USD (1–2 hours, then destroy) | Why it is not always zero |
|:--|:--|:--|
| Local tar + second-directory restore | **0.00** | Disk only |
| Data Protection vault GeoRedundant, empty | **0.50–1.50** | Vault and protected-instance minimums. Soft-delete retains. |
| Two Storage accounts in `eastus` and `eastus2` + a few blob copies | **0.10–0.80** | Capacity, operations, egress between regions. |
| GRS database, paired-region AKS, or a leftover vault | **Stop. Change the SKU or destroy.** | Can exceed USD 5 quickly. |

Create a budget first ([../capstone/COST.md](../capstone/COST.md)). Do not write "INR 0" if a vault or a second-region Storage account exists. Do not create a NAT Gateway.

---

## Steps

1. Write the numbers first. Open `docs/day-39-dr.md` and put these two lines **before** any backup command:

```text
RPO target: 15 minutes (maximum data loss ShopSphere accepts)
RTO target: 60 minutes (maximum time to serve /health again)
```

You may not change those lines after you see the clock. You may add a "measured" pair under them.

2. Create the primary "region" and a marker.

```bash
mkdir -p var/dr-lab/eastus/data var/dr-lab/eastus2/backups
printf 'sku=SKU-100\nlast_order=42\n' > var/dr-lab/eastus/data/marker.txt
date -u +%Y-%m-%dT%H:%M:%SZ | tee var/dr-lab/eastus/data/last_write.txt
sleep 2
```

`sleep 2` makes RPO measurable. In production the gap is the time since the last successful backup.

3. Take a backup. Copy it to the second region. This is the cross-region drill without a bill.

```bash
tar -C var/dr-lab/eastus -czf var/dr-lab/eastus/backup.tar.gz data
cp -a var/dr-lab/eastus/backup.tar.gz var/dr-lab/eastus2/backups/backup.tar.gz
date -u +%Y-%m-%dT%H:%M:%SZ | tee var/dr-lab/eastus2/backups/copied_at.txt
sha256sum var/dr-lab/eastus/backup.tar.gz var/dr-lab/eastus2/backups/backup.tar.gz
```

Expected: two identical hashes. The second path is the only copy you will restore from. Pretend `eastus` is gone.

4. Delete the primary data. Start the RTO clock. Restore from `eastus2`. Stop the clock.

```bash
rm -rf var/dr-lab/eastus/data
test ! -f var/dr-lab/eastus/data/marker.txt

START=$(date +%s)
mkdir -p var/dr-lab/eastus-restored
tar -C var/dr-lab/eastus-restored -xzf var/dr-lab/eastus2/backups/backup.tar.gz
END=$(date +%s)
echo "RTO_seconds=$((END - START))" | tee -a docs/day-39-dr.md
cat var/dr-lab/eastus-restored/data/marker.txt
```

Expected: `sku=SKU-100` is back. `RTO_seconds` is a small integer. That number is the lab RTO. Compare it to 60 minutes. Write one sentence: a 2-second restore on a laptop is not a 60-minute regional failover. The habit is the clock. The production number includes DNS, identity, and data replay.

Measure RPO:

```bash
python3 - <<'PY'
from datetime import datetime, timezone
from pathlib import Path
write = Path("var/dr-lab/eastus-restored/data/last_write.txt").read_text().strip()
copied = Path("var/dr-lab/eastus2/backups/copied_at.txt").read_text().strip()
fmt = "%Y-%m-%dT%H:%M:%SZ"
delta = datetime.strptime(copied, fmt).replace(tzinfo=timezone.utc) - datetime.strptime(write, fmt).replace(tzinfo=timezone.utc)
print("RPO_seconds=%d" % int(delta.total_seconds()))
PY
```

Copy `RPO_seconds` into the notes. Compare it to 15 minutes. If you waited two seconds between write and backup, RPO is about two seconds. If you skip backups for a day, RPO is a day. The target does not magically apply.

This timed restore was **executed** in the authoring environment: `RTO_seconds=0`, `RPO_seconds=2`, identical SHA-256 on both tar copies, marker `sku=SKU-100` present after restore.

5. Write the vault module. `infra/azure/modules/backup/versions.tf` with azurerm 5.9.0, no provider block.

`infra/azure/modules/backup/variables.tf`:

```hcl
variable "name" {
  type = string
}

variable "location" {
  type    = string
  default = "eastus"
}

variable "resource_group_name" {
  type = string
}
```

`infra/azure/modules/backup/main.tf`. Valid on azurerm 5.9.0. `datastore_type` and `redundancy` are required. Cross-region restore needs geo redundancy.

```hcl
resource "azurerm_data_protection_backup_vault" "this" {
  name                         = var.name
  resource_group_name          = var.resource_group_name
  location                     = var.location
  datastore_type               = "VaultStore"
  redundancy                   = "GeoRedundant"
  cross_region_restore_enabled = true
  soft_delete                  = "Off"
}
```

`soft_delete = "Off"` is a lab choice so destroy is clean. Production vaults keep soft-delete on.

`infra/azure/modules/backup/tests/backup.tftest.hcl`:

```hcl
mock_provider "azurerm" {}

run "crr" {
  command = plan

  variables {
    name                = "bvault-shopsphere-dev"
    resource_group_name = "rg-shopsphere-dr-dev"
  }

  assert {
    condition     = azurerm_data_protection_backup_vault.this.redundancy == "GeoRedundant"
    error_message = "CRR needs GeoRedundant"
  }

  assert {
    condition     = azurerm_data_protection_backup_vault.this.cross_region_restore_enabled == true
    error_message = "cross_region_restore_enabled must be true"
  }

  assert {
    condition     = azurerm_data_protection_backup_vault.this.datastore_type == "VaultStore"
    error_message = "datastore_type"
  }
}
```

```bash
cd infra/azure/modules/backup
terraform init
terraform fmt
terraform validate
terraform test
```

Expected: `1 passed`.

6. Optional Azure blob copy (the billed cross-region path). Budget first. Two **StorageV2** accounts, `LRS` in `eastus`, `LRS` in `eastus2`. Do **not** enable GRS on one account and call it a drill. A GRS failover is a different control. This drill is an explicit copy you can restore from.

```bash
# sketch only — replace names; destroy the same session
az group create --name rg-shopsphere-dr-dev --location eastus
az storage account create --name stshopeastusXXXX --resource-group rg-shopsphere-dr-dev \
  --location eastus --sku Standard_LRS --kind StorageV2
az storage account create --name stshopeastus2XXXX --resource-group rg-shopsphere-dr-dev \
  --location eastus2 --sku Standard_LRS --kind StorageV2
```

Then `az storage blob upload` the tar to eastus and `az storage blob copy start` to eastus2. Record copy duration as a second RTO sample. **Not executed** in the authoring environment.

If you apply the vault, destroy it the same session. GeoRedundant empty vaults still bill.

7. Cost note. Write three numbers in `docs/day-39-dr.md`: local USD 0.00, vault estimate, blob-copy estimate. If you used Infracost:

```bash
infracost breakdown --path infra/azure/modules/backup
```

**Not executed** here. A missing binary is not a free vault.

---

## Verify

- Notes contain RPO target 15 minutes and RTO target 60 minutes **written before restore**.
- `RTO_seconds` and `RPO_seconds` are numbers from this run.
- Restore used `eastus2/backups`, not the deleted primary tree.
- `terraform test` passed on the vault.
- Notes do **not** say a GeoRedundant vault is free.
- `var/dr-lab/` is gitignored or deleted.

---

## Break and fix

Do both failures.

### Failure 1 — restore from the dead region

Delete `var/dr-lab/eastus2/backups/backup.tar.gz`. Try to restore from `var/dr-lab/eastus/backup.tar.gz` after you also deleted `eastus/data`. If you deleted the primary tar too, restore fails. That is a single-region backup. Copy the tar to `eastus2` **before** the delete. Diagnose: two hashes after `cp`, then delete primary.

### Failure 2 — LocallyRedundant vault with CRR promised

Set `redundancy = "LocallyRedundant"` and keep `cross_region_restore_enabled = true`. Run `terraform test`. Expected: the GeoRedundant assert fails. A live apply may also reject CRR on LRS. Restore `GeoRedundant`. Do not claim cross-region restore on a local vault.

---

## Stretch

- Install Velero on `kind` and back up namespace `shopsphere`. Restore into a second namespace. Record that Velero is not Azure Backup.
- Add `azurerm_data_protection_backup_policy_blob_storage` and an instance. Destroy both.
- Run `infracost breakdown` and paste the USD line (not a screenshot of a marketing page).

---

## Clean up

```bash
rm -rf var/dr-lab
cd infra/azure/modules/backup
# if you applied from a root:
terraform destroy
az group delete --name rg-shopsphere-dr-dev --yes --no-wait
az storage account show --name stshopeastusXXXX
```

Expected after destroy: Storage show fails. Confirm both regions. Soft-deleted vaults can remain. Purge only lab names.

---

## Interview story

**Situation:** ShopSphere quoted a 15-minute RPO and a 60-minute RTO but had never restored a backup, and the old homework never left one region. **Task:** Prove a restore from a second region with a clock, then describe the Azure vault that would hold production copies. **Action:** I wrote the RPO and RTO lines first, tarred a marker, copied the archive to an `eastus2` directory, deleted primary data, and restored from the copy while recording `RTO_seconds` and `RPO_seconds`. I added `azurerm_data_protection_backup_vault` with `GeoRedundant` and `cross_region_restore_enabled` and covered both with `terraform test` on azurerm 5.9.0. I broke a single-region tar and an LRS vault that promised CRR. **Result:** I can say a backup is not DR until a restore from another region meets the numbers, and I never called a GeoRedundant vault free.

---

## Self-score checklist

- [ ] RPO and RTO targets were written before restore.
- [ ] I restored from the second-region copy and recorded seconds.
- [ ] Vault module `terraform test` passed.
- [ ] I broke single-region backup and LRS+CRR.
- [ ] I destroyed billed objects, or I never applied.
- [ ] Files live in ShopSphere. `var/dr-lab` is gone or gitignored.

**Executed:** timed local tar copy/restore (`RTO_seconds=0`, `RPO_seconds=2`, matching SHA-256) and vault `terraform test` (1 passed) on Terraform 1.16.5 / azurerm 5.9.0. **Not executed:** Azure blob copy, vault apply, Infracost, Velero.
