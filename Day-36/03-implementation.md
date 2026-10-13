# Day 36 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 36 hardens Terraform as a team system. Day 10 already moved state off the laptop and showed a lock. This Day is the **harder sibling**: `tflint` and Checkov are required gates, `terraform test` covers a rename, and a `moved` block prevents destroy-and-create when an address changes.

Work in **your ShopSphere repository**. You need `infra/azure/backend` from Day 10 and `environments/dev` from Days 8 to 31. Do not start a new `local_file` project.

---

## Goal

Run the full gate set on the existing modules: `fmt`, `validate`, `tflint`, Checkov, `terraform test`. Then rename a `terraform_data` resource **with** a `moved` block and **without** one, so you can see `0 to add, 0 to destroy` versus `1 to add, 1 to destroy`.

When you finish, you can explain why an address change without `moved` looks like a replacement, and why a pipeline that only runs `validate` is not enough.

Time box: 60 to 90 minutes.

---

## Capstone stage

| Path | Adds beyond Day 10 |
|:--|:--|
| `.tflint.hcl` at `infra/azure/` | Repo-wide lint |
| `infra/azure/backend/.checkov.yml` | Recorded skips |
| `infra/azure/loop-local/moved-demo/` | `moved` block drill |
| `docs/day-36-hardening-lab.md` | Gate output + move plan |

---

## What you need

```bash
terraform version
tflint --version
checkov --version
```

Use Terraform 1.16.5, tflint 0.55.1, Checkov 3.2.447. Install notes are in [Day-25/03-implementation.md](../Day-25/03-implementation.md). Azure is optional.

---

## Cost

Local gates and the `moved` drill: **USD 0.00**. Do not apply a new cluster. If you still have the Day 10 Storage account, leaving it costs about **USD 0.05-0.40** this month. Destroy it if the capstone is over.

---

## Steps

1. Run the gate set from `infra/azure`.

```bash
cd infra/azure
terraform fmt -check -recursive
```

```bash
cd environments/dev
terraform init -input=false -backend=false
terraform validate
terraform test
tflint --init
tflint
```

```bash
checkov -d ../backend --framework terraform
```

Expected: fmt, validate, test, and tflint exit 0. Checkov may still fail `CKV_AZURE_33`. Day 25 already trained that skip. Put the skip in `backend/.checkov.yml` if it is not there. Re-run Checkov. Record both the fail and the skip in the notes.

2. Pin provider versions in every root you touch. Confirm `azurerm` is `5.9.0`, not `~> 5.0` without a lock file.

```bash
grep -R "required_providers" -A 6 environments/dev/main.tf backend/main.tf
ls environments/dev/.terraform.lock.hcl backend/.terraform.lock.hcl
```

If a lock file is missing, run `terraform init` and commit it.

3. Create the move drill. This uses `terraform_data` so you do not need Azure. It is not a substitute for the `azurerm` modules. It is the safe way to see a move.

```bash
mkdir -p infra/azure/loop-local/moved-demo
```

`infra/azure/loop-local/moved-demo/main.tf` (first apply):

```hcl
resource "terraform_data" "old" {
  input = "shopsphere"
}
```

```bash
cd infra/azure/loop-local/moved-demo
terraform init
terraform apply -auto-approve
terraform state list
```

Expected state address: `terraform_data.old`.

4. Rename the resource **with** a `moved` block.

```hcl
resource "terraform_data" "new" {
  input = "shopsphere"
}

moved {
  from = terraform_data.old
  to   = terraform_data.new
}
```

```bash
terraform plan
```

Expected plan (Terraform 1.16.5 wording):

```text
# terraform_data.old has moved to terraform_data.new
Plan: 0 to add, 0 to change, 0 to destroy.
```

Apply that plan. `terraform state list` now shows `terraform_data.new`. The object did not get a new id.

5. Replay the mistake. Copy state aside, or start a second folder `moved-demo-bad` and apply `terraform_data.old` again. Then change the file to `terraform_data.new` **without** a `moved` block.

```bash
terraform plan
```

Expected:

```text
Plan: 1 to add, 0 to change, 1 to destroy.
```

Do not apply the bad plan on a real Azure resource. Destroying a VNet because you renamed a block is the production incident this Day prevents. Write both plan summaries in the notes.

The older command `terraform state mv terraform_data.old terraform_data.new` still works. Prefer a `moved` block in Git so the next teammate gets the same plan.

---

## Verify

- `terraform fmt -check`, `validate`, `terraform test`, and `tflint` passed on Dev.
- Checkov ran on the backend module. A skip, if any, lives in Git.
- `.terraform.lock.hcl` is committed for each root.
- You captured a move plan with `0 to add` and a bad rename plan with `1 to add, 1 to destroy`.
- You did not apply the destroy-and-create plan against Azure.

---

## Break and fix

### Failure 1 — provider constraint missing

Remove `version = "5.9.0"` from a root on purpose. Run `terraform init`. Read whether Terraform picked a different version. Restore the pin and the lock file. The lock file is what a teammate downloads. A missing pin is how two laptops apply different provider bugs.

### Failure 2 — Checkov gate skipped in CI only

Run `checkov -d infra/azure/backend --framework terraform --check CKV_AZURE_33`. Expected: fail unless you added queue logging. If your workflow from Day 25 does not run Checkov, add the step now. A laptop gate that CI does not run will rot.

---

## Stretch

- `terraform state mv` the demo resource back and forth once, then replace that habit with a `moved` block.
- Add `tflint-ruleset-azurerm` to `.tflint.hcl` and run `tflint --init`. Record the plugin version.

---

## Clean up

```bash
cd infra/azure/loop-local/moved-demo
terraform destroy -auto-approve
rm -f terraform.tfstate terraform.tfstate.backup
```

Destroy `moved-demo-bad` the same way. Keep the `moved` block file in Git if you want the example. Do not commit state.

If this is the last IaC Day and you no longer need `rg-shopsphere-tfstate`, destroy that stack with the Day 10 commands.

---

## Interview story

**Situation:** ShopSphere already had remote state, but engineers still renamed resources and trusted `validate` alone. **Task:** Make lint, policy, and tests required, and show that a rename without `moved` replaces the object. **Action:** I ran `terraform fmt -check`, `tflint` 0.55.1, Checkov 3.2.447, and `terraform test` on the existing Azure modules. I applied `terraform_data.old`, added a `moved` block to `terraform_data.new`, and got `0 to add, 0 to destroy`. I then planned the same rename without `moved` and got `1 to add, 1 to destroy`. **Result:** I can tell a panel the difference between a move and a replacement, and I can point at pipeline gates that fail before apply.

---

## Self-score checklist

- [ ] I ran fmt, validate, test, tflint, and Checkov on the real modules.
- [ ] I have a move plan with zero add/destroy.
- [ ] I have a bad rename plan with add+destroy.
- [ ] Provider version is pinned and locked.
- [ ] I destroyed the local move drill.
- [ ] Files live in ShopSphere.
