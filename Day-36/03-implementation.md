# Day 36 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 36 teaches Terraform as a team control system: format, validate, plan, review, then apply. This lab uses the `hashicorp/local` provider and a `local_file` resource in a temporary directory. You initialize Terraform, read `.terraform.lock.hcl`, run `terraform fmt`, `terraform validate`, and `terraform plan`, then apply. You then edit the managed file outside Terraform, watch plan report drift, and you do not apply first. You investigate, then apply to restore the declared content. You destroy the lab when you finish.

Work only in a temporary directory that you create for this lab. Do not run Terraform inside the DevOps-Prep course repository. Do not configure an S3 backend or a DynamoDB lock table. Local state is enough here. Concurrent apply locking stays a design note from the lesson. Do not delete `.terraform.lock.hcl` to manufacture a failure.

---

## Goal

Create one `local_file` with Terraform in a throwaway directory. After `terraform init`, open `.terraform.lock.hcl` and record that this file is what you would commit so provider versions stay reproducible. Run `terraform fmt`, `terraform validate`, and `terraform plan` before the first apply. Apply only after you have read the plan.

Then change the file with a shell command, not with Terraform. Run `terraform plan` again. Record expected content, actual content, owner, and intent before you apply. Restore the declared content with apply. When you finish, you can explain the pipeline order, the lock file, and why drift investigation comes before apply.

Time box: 45 to 75 minutes. Cost stays at ₹0. Stop when plan shows no remaining changes, your notes name the lock file and the drift decision, and `terraform destroy` has removed the lab file.

---

## What you need

You need Terraform 1.0 or later and a shell. Check the version first:

```bash
terraform version
```

You do not need AWS, Azure, an S3 backend, or DynamoDB. This lab uses local state in `terraform.tfstate`. Remote state, `use_lockfile`, and cross-account roles stay a design note at the end. They are not a required apply step.

Create the lab under `/tmp`, not under this course clone. Terraform writes `.terraform/`, `.terraform.lock.hcl`, and `terraform.tfstate` in the working directory. You must be able to delete that directory when you clean up.

Keep a notes file named `day-36-tf-governance-lab.md` in the same temp directory. Record the lock file provider source, the fmt/validate/plan results, the drift investigation, and the restore decision. Do not paste secrets. This lab should not create any.

---

## Steps

1. Create a throwaway directory and enter it. Use a unique folder name so you do not collide with another lab. Confirm the path is under `/tmp`.

```bash
LAB_DIR="/tmp/day-36-tf-governance-lab-$$"
mkdir -p "$LAB_DIR"
cd "$LAB_DIR"
pwd
```

2. Write `main.tf`. Leave the `local_file` block poorly indented on purpose. `terraform fmt` should rewrite that block. This configuration uses the `local` provider only. The resource writes `managed.txt` with content that Terraform owns.

```hcl
terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

resource "local_file" "marker" {
filename = "${path.module}/managed.txt"
content  = "managed by terraform\n"
}
```

3. Initialize Terraform. This downloads the `hashicorp/local` provider into `.terraform` in this directory. It also writes `.terraform.lock.hcl`. It does not create `managed.txt` yet.

```bash
terraform init
```

4. Show the lock file. `ls` should list `.terraform.lock.hcl`. `cat` should show `hashicorp/local` as the selected provider. Copy the provider source and version into your notes. This is the file the lesson says to commit. Do not copy it into the course repository. Do not delete it.

```bash
ls -a
cat .terraform.lock.hcl
```

5. Format the configuration. `terraform fmt` rewrites `main.tf` in place. Open `main.tf` and confirm the `filename` and `content` arguments now align with the resource block.

```bash
terraform fmt
cat main.tf
```

6. Validate the configuration. This checks syntax and arguments against the initialized providers. It does not contact a cloud API. It should report success.

```bash
terraform validate
```

7. Preview the create. Read the plan. You should see one `local_file.marker` to add. Do not apply until the plan matches that expectation. Do not pass `-auto-approve` on apply. The lesson treats a Production auto-approve from a laptop as unsafe.

```bash
terraform plan
```

8. Apply the configuration. Type `yes` when Terraform asks to confirm. After apply, the working directory should contain `managed.txt`, `terraform.tfstate`, and `.terraform.lock.hcl`.

```bash
terraform apply
```

9. Confirm Terraform created the file. `cat managed.txt` should show `managed by terraform`. `terraform state list` should show `local_file.marker`. Copy both results into your notes.

```bash
cat managed.txt
terraform state list
ls
```

10. Edit the file outside Terraform. This is the drift. Do not change `main.tf`. Do not apply yet.

```bash
printf 'changed by hand\n' > managed.txt
cat managed.txt
```

11. Run plan again. Terraform compares configuration, state, and the real file. Record the proposed action in your notes.

```bash
terraform plan
```

The plan should want to write `managed by terraform` back to `managed.txt`. With `local_file`, that action often shows as a create, not an in-place update. The provider uses the file checksum as the resource ID. When you change the file outside Terraform, that old ID no longer matches. The difference is still drift. Terraform is telling you the real file no longer matches the declared content.

12. Investigate before you apply. Write these lines in `day-36-tf-governance-lab.md` before you type `yes`:

```text
Expected Configuration: managed by terraform
Actual Infrastructure: changed by hand
Detected Drift: managed.txt content no longer matches local_file.marker
Change Owner: this lab (manual edit in step 10)
Intent: accidental / unauthorized for this restore path
Resolution: apply to restore the declared content
```

Do not run `terraform apply -auto-approve`. The lesson order is detect, investigate, identify owner, determine intent, then reconcile or codify. Apply is the last step of that path, not the first reflex.

13. Restore the declared content. The configuration is the source of truth for this lab. Type `yes` to confirm. Then `cat managed.txt` should show `managed by terraform`.

```bash
terraform apply
cat managed.txt
```

14. Confirm restore. Plan should report no remaining changes. `terraform state list` should still show `local_file.marker`. `.terraform.lock.hcl` should still exist. You did not delete the lock file.

```bash
terraform plan
terraform state list
ls -a
```

15. Remote backend and locking, as a note only. Do not create an S3 bucket. Write three sentences in `day-36-tf-governance-lab.md`: a team would store this state in an S3 backend with versioning and `use_lockfile`; locking would block a second apply against the same state; this lab keeps `terraform.tfstate` on disk because the goal is fmt, validate, plan, the lock file, and drift investigation, not cloud spend.

---

## Verify

Read the notes as if you are on a call. You should name the lock file, the fmt/validate/plan order, and the drift you caused.

Check these points:

- `terraform init` created `.terraform.lock.hcl`. `cat` showed `hashicorp/local`. You recorded that you would commit this file in a real repository.
- `terraform fmt` rewrote the poorly indented `local_file` block.
- `terraform validate` succeeded before the first apply.
- The first `terraform plan` showed one `local_file.marker` to add. You typed `yes` on apply. You did not use `-auto-approve`.
- After the hand edit, `terraform plan` proposed a write back to the declared content. With `local_file` that often appears as a create. You wrote owner and intent before you applied.
- After restore, a later `terraform plan` reports no remaining changes. `managed.txt` again contains `managed by terraform`.

If plan still wants to change `managed.txt`, read `main.tf` and `cat managed.txt` again. The declared content, the file on disk, and state must match before you stop.

---

## Break and fix

You already broke the file on purpose in step 10. That is the drift this Day trains. The required fix is investigate, then restore.

If you restored with apply, break it once more so the investigation is not a one-time habit. Edit `managed.txt` by hand again. Run `terraform plan`. Fill the same expected/actual/owner/intent block in your notes. Then apply to restore. A later plan should report no changes.

Do not skip the notes. Do not auto-apply. Do not delete `.terraform.lock.hcl` to create a different failure. The lesson rule is detect, investigate, then reconcile. Apply is not the first reflex.

Two engineers applying at once is the other failure drill from this Day. Do not try to demo that against local state here. Write one sentence in your notes: locking prevents concurrent state writes; it does not prove the change is safe. Plan review, permissions, and approvals still matter.

---

## Clean up

Destroy the lab resource, then remove the temp directory. Run destroy only after the last plan reports no changes, so Terraform still knows the resource. Type `yes` when Terraform asks to confirm destroy. In Production, unrestricted destroy is a governance problem. In this lab, destroy is the correct cleanup.

```bash
terraform destroy
ls
```

Confirm `managed.txt` is gone. Then leave the lab directory and delete it, including `.terraform`, `.terraform.lock.hcl`, `terraform.tfstate`, and any `tfplan` file.

```bash
cd /tmp
rm -rf "$LAB_DIR"
```

If you copied notes you want to keep, move `day-36-tf-governance-lab.md` out before `rm -rf`. Do not leave state files in the course repository. You created no AWS or Azure resources, so there is no bucket, storage account, or resource group to delete.

---

## Interview story

I treat Terraform as a team workflow, not as a laptop shortcut. I run `terraform init`, then I read `.terraform.lock.hcl` so provider versions stay reproducible across engineers and CI. I run `terraform fmt`, `terraform validate`, and `terraform plan` before apply. I do not use `-auto-approve` against a change I have not reviewed. When someone edits a managed file outside Terraform, plan shows drift. I do not apply first. I record expected content, actual content, owner, and intent. Then I restore from the configuration, or I update the configuration if the edit was the new desired state. For a team I would move that state to an S3 backend with versioning and `use_lockfile`. Locking would stop a second apply. It would not replace plan review.
