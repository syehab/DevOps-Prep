# Day 10 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 10 teaches Terraform State as the record of what Terraform manages. This lab uses the `hashicorp/local` provider and a `local_file` resource. You apply the file, inspect state, edit the file outside Terraform, and watch `terraform plan` report drift. You then restore the declared content with apply, or you update the code if you treat the edit as the new desired state.

Work only in a temporary directory that you create for this lab. Do not run Terraform inside the DevOps-Prep course repository. Do not configure AWS S3 or Azure Storage. Local state is enough here.

---

## Goal

Create one `local_file` with Terraform. After apply, run `terraform state list` and `terraform show` so you can see the resource address and the recorded content. Then change the file with a shell command, not with Terraform. Run `terraform plan` and confirm that Terraform detects the difference.

Decide the source of truth before you apply. If the edit was accidental, keep the `.tf` file and apply so Terraform restores the declared content. If the edit was intentional, change the configuration to match, then apply so state records the new content. When you finish, you can explain state, drift, and restore without a cloud account.

Time box: 45 to 75 minutes. Cost stays at ₹0. Stop when plan shows no remaining changes, you have a short notes file, and `terraform destroy` has removed the lab file.

---

## What you need

You need Terraform 1.0 or later and a shell. Check the version first:

```bash
terraform version
```

You do not need AWS, Azure, an S3 backend, or Azure Storage. This lab uses local state in `terraform.tfstate`. Remote backends and locking stay a design note at the end. They are not a required step.

Create the lab under `/tmp`, not under this course clone. Terraform writes `terraform.tfstate` in the working directory. You must be able to delete that directory when you clean up.

Keep a notes file named `day-10-state-lab.md` in the same temp directory. Record command output and the source-of-truth decision. Do not paste secrets. This lab should not create any.

---

## Steps

1. Create a throwaway directory and enter it. Use a unique folder name so you do not collide with another lab. Confirm the path is under `/tmp`.

```bash
LAB_DIR="/tmp/day-10-tf-state-lab-$$"
mkdir -p "$LAB_DIR"
cd "$LAB_DIR"
pwd
```

2. Write `main.tf`. This configuration uses the `local` provider only. The resource writes `managed.txt` with content that Terraform owns.

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

3. Initialize Terraform. This downloads the `hashicorp/local` provider into `.terraform` in this directory. It does not create the file yet.

```bash
terraform init
```

4. Preview the create. Read the plan. You should see one `local_file.marker` to add. Do not apply until the plan matches that expectation.

```bash
terraform plan
```

5. Apply the configuration. Type `yes` when Terraform asks to confirm. After apply, the working directory should contain `managed.txt` and `terraform.tfstate`.

```bash
terraform apply
```

6. Find local state. Run `ls` and confirm `terraform.tfstate` exists. This is the local state file from the lesson. Do not commit it. Do not copy it into the course repository.

```bash
ls
```

7. Inspect the state Terraform recorded. `terraform state list` should show `local_file.marker`. `terraform show` should print the filename and the content `managed by terraform`. Copy both results into your notes.

```bash
terraform state list
terraform show
```

8. Read the real file. Confirm the file on disk matches the content in state. State is Terraform’s record. The file on disk is the real object.

```bash
cat managed.txt
```

9. Edit the file outside Terraform. This is the drift. Do not change `main.tf` yet.

```bash
printf 'changed by hand\n' > managed.txt
cat managed.txt
```

10. Run plan again. Terraform compares configuration, state, and the real file. Record the proposed action in your notes.

```bash
terraform plan
```

The plan should want to write `managed by terraform` back to `managed.txt`. With `local_file`, that action often shows as a create, not an in-place update. The provider uses the file checksum as the resource ID. When you change the file outside Terraform, that old ID no longer matches. The difference is still drift. Terraform is telling you the real file no longer matches the declared content.

11. Decide the source of truth, then pick one path. Write the decision in your notes before you apply.

Accidental change: keep `main.tf`. Apply so Terraform restores the declared content. Type `yes` to confirm. Then `cat managed.txt` should show `managed by terraform`.

```bash
terraform apply
cat managed.txt
```

Intentional change: edit `main.tf` so `content` is `changed by hand\n`. Run `terraform plan` again. You may still see a create, because state still holds the old checksum. Apply so state records the new content. Do not skip that apply if you chose this path.

```bash
terraform plan
terraform apply
```

12. Confirm the chosen path. After restore, or after you update the code and apply, plan should report no changes. `terraform state list` should still show `local_file.marker`.

```bash
terraform plan
terraform state list
```

13. Optional saved plan, if you still have time. This is the production habit from the lesson: review a plan file, then apply that file. Do not skip the review.

```bash
terraform plan -out=tfplan
terraform show tfplan
```

Apply only that file if you generated it:

```bash
terraform apply tfplan
```

14. Remote backend, as a note only. Do not create an S3 bucket or an Azure storage account in this lab. Write two sentences in `day-10-state-lab.md`: a team would store this state in a remote backend such as Azure Storage or an S3-based backend with locking; this lab keeps `terraform.tfstate` on disk because the goal is state and drift, not cloud spend.

---

## Verify

Read the notes as if you are on a call. You should name the resource address, say what `terraform show` recorded, and explain the drift you caused.

Check these points:

- `terraform state list` shows `local_file.marker`.
- `terraform show` recorded the filename and the content Terraform manages.
- `ls` showed `terraform.tfstate` after apply. You did not commit that file.
- After the hand edit, `terraform plan` proposed a write back to the declared content. With `local_file` that often appears as a create. You wrote who is the source of truth before you applied.
- After restore, or after you updated the code and applied, a later `terraform plan` reports no remaining changes.

If plan still wants to change `managed.txt`, read `main.tf` and `cat managed.txt` again. The declared content, the file on disk, and state must match before you stop.

---

## Break and fix

You already broke the file on purpose in step 9. That is the drift this Day trains.

If you restored with apply, break it once more so you can practice the other path. Edit `managed.txt` by hand again. This time treat the edit as desired. Change the `content` argument in `main.tf` to match. Run `terraform plan`, then apply so state records the new checksum. A later plan should report no changes.

If you already codified the first edit, do the restore path now. Put `content` back to `managed by terraform\n`. Apply. Confirm `cat managed.txt` shows the declared line.

Do not skip the investigation. The lesson rule is detect, investigate, then reconcile or codify. Apply is not the first reflex.

---

## Clean up

Destroy the lab resource, then remove the temp directory. Run destroy only after the last plan reports no changes, so Terraform still knows the resource. Type `yes` when Terraform asks to confirm destroy.

```bash
terraform destroy
ls
```

Confirm `managed.txt` is gone. Then leave the lab directory and delete it, including `.terraform`, `terraform.tfstate`, and any `tfplan` file.

```bash
cd /tmp
rm -rf "$LAB_DIR"
```

If you copied notes you want to keep, move `day-10-state-lab.md` out before `rm -rf`. Do not leave state files in the course repository. You created no AWS or Azure resources, so there is no bucket, storage account, or resource group to delete.

---

## Interview story

I treat Terraform State as the record of what Terraform manages, not as an inventory of the whole account. I apply a small `local_file`, then I prove that record with `terraform state list` and `terraform show`. When someone edits the file outside Terraform, `terraform plan` shows drift because plan compares configuration, state, and the real object. I do not apply first. I decide whether the code is the source of truth or the manual change is. Then I restore with apply, or I update the configuration. For a team I would move that state to a remote backend with locking. I would not keep production state on a laptop.
