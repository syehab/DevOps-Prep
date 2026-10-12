# Day 38 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 38 teaches environment and Terraform state boundaries. This lab uses the `hashicorp/local` provider and a `local_file` resource. You call one module from three environment folders: Dev, UAT, and Prod. Each folder writes a different file and keeps its own `terraform.tfstate`. You then break the design on purpose: one shared folder and one state for all three environments. You watch later applies replace earlier environments. You split the state again.

Work only in a temporary directory that you create for this lab. Do not run Terraform inside the DevOps-Prep course repository. Do not configure AWS, Azure, or a remote backend. Local state is enough here.

---

## Goal

Build one Terraform module that writes a local file. Call that module from `environments/dev`, `environments/uat`, and `environments/prod`. Pass different names and content through `dev.tfvars`, `uat.tfvars`, and `prod.tfvars`. Run `terraform init`, `plan`, and `apply` inside each folder so each environment keeps its own state.

Then create one shared folder. Apply all three variable files against that one state. Record what happens to the files and to `terraform state list`. Split the work back into the three folders. Write a short blast-radius note. When you finish, you can explain why Dev, UAT, and Prod must not share one Terraform state.

Time box: 45 to 75 minutes. Cost stays at ₹0. Stop when each environment folder has its own state and file, the shared folder is destroyed, the blast-radius note exists, and `terraform destroy` has removed the lab files.

---

## What you need

You need Terraform 1.0 or later and a shell. Check the version first:

```bash
terraform version
```

You do not need AWS, Azure, Docker, or Kubernetes. This lab uses the HashiCorp `local` provider and the `local_file` resource. Those names are real. The flag `-var-file` is real. Do not invent other flags.

Create the lab under `/tmp`, not under this course clone. Terraform writes `terraform.tfstate` in the working directory. You must be able to delete that directory when you clean up.

Keep a notes file named `day-38-env-lab.md` in the same temp directory. Record command output, state addresses, and the blast-radius decision. Do not paste secrets. This lab should not create any.

---

## Steps

1. Create a throwaway directory and enter it. Use a unique folder name so you do not collide with another lab. Confirm the path is under `/tmp`.

```bash
LAB_DIR="/tmp/day-38-env-lab-$$"
mkdir -p "$LAB_DIR"
cd "$LAB_DIR"
pwd
```

Write one sentence in `day-38-env-lab.md`: this directory is disposable. You will run `terraform destroy` here before you delete it.

2. Create the module folder and the three environment folders. The module holds the reusable design. Each environment folder is one place you apply values and one place Terraform stores state.

```bash
mkdir -p modules/marker
mkdir -p environments/dev
mkdir -p environments/uat
mkdir -p environments/prod
```

3. Write the module inputs. Put this in `modules/marker/variables.tf`. These inputs must change between environments. The module must not hard-code Dev, UAT, or Prod names.

```hcl
variable "filename" {
  type = string
}

variable "content" {
  type = string
}
```

4. Put this in `modules/marker/main.tf`. The resource uses the variables. That is the reusable design. The provider block stays in the environment folder, not in the module.

```hcl
resource "local_file" "marker" {
  filename = var.filename
  content  = var.content
}
```

5. Put this in `modules/marker/outputs.tf`. The module returns the path it wrote. The environment can read that fact without guessing.

```hcl
output "filename" {
  value = local_file.marker.filename
}
```

6. Write the Dev environment. Put this in `environments/dev/main.tf`. The `module` block is the caller. `source` points at the reusable folder. The values come from variables, not from hard-coded Dev strings in the module.

```hcl
terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

variable "filename" {
  type = string
}

variable "content" {
  type = string
}

module "marker" {
  source = "../../modules/marker"

  filename = var.filename
  content  = var.content
}

output "written_file" {
  value = module.marker.filename
}
```

7. Put this in `environments/dev/dev.tfvars`. These are Dev values only. Smaller capacity here stands in for the lesson idea: same architecture, different values. Use a plain filename. A `.tfvars` file does not expand `${path.module}`.

```hcl
filename = "shopsphere-dev.txt"
content  = "env=dev nodes=small ha=false\n"
```

8. Copy the same Terraform code into UAT and Prod. Do not copy the module. Do not rewrite the resource.

```bash
cp environments/dev/main.tf environments/uat/main.tf
cp environments/dev/main.tf environments/prod/main.tf
```

Put this in `environments/uat/uat.tfvars`:

```hcl
filename = "shopsphere-uat.txt"
content  = "env=uat nodes=medium ha=false\n"
```

Put this in `environments/prod/prod.tfvars`:

```hcl
filename = "shopsphere-prod.txt"
content  = "env=prod nodes=large ha=true\n"
```

9. Format and validate Dev. Run these commands from `environments/dev`. `terraform init` downloads the `hashicorp/local` provider. `terraform fmt` rewrites the files in this folder. `terraform validate` checks the configuration after init.

```bash
cd "$LAB_DIR/environments/dev"
terraform init
terraform fmt
terraform validate
terraform plan -var-file="dev.tfvars"
```

In the notes, copy the planned `local_file` address and the Dev filename. Write one sentence: the plan uses Dev values. The module file did not name Dev.

10. Apply Dev. Type `yes` when Terraform asks to confirm. After apply, this folder should contain `shopsphere-dev.txt` and `terraform.tfstate`.

```bash
terraform apply -var-file="dev.tfvars"
terraform state list
terraform output
cat shopsphere-dev.txt
ls terraform.tfstate
```

`terraform state list` should show `module.marker.local_file.marker`. Record that address. State lives in this folder. It does not live in UAT or Prod yet.

11. Initialize, plan, and apply UAT the same way. Use the UAT folder and `uat.tfvars`. Dev state stays in the Dev folder.

```bash
cd "$LAB_DIR/environments/uat"
terraform init
terraform validate
terraform plan -var-file="uat.tfvars"
terraform apply -var-file="uat.tfvars"
terraform state list
cat shopsphere-uat.txt
ls terraform.tfstate
```

12. Repeat for Prod. Use the Prod folder and `prod.tfvars`. After this step you have three state files and three different local files.

```bash
cd "$LAB_DIR/environments/prod"
terraform init
terraform validate
terraform plan -var-file="prod.tfvars"
terraform apply -var-file="prod.tfvars"
terraform state list
cat shopsphere-prod.txt
ls terraform.tfstate
```

13. Prove the states are separate. From the lab root, list each environment directory. You should see three `terraform.tfstate` files and three different `shopsphere-*.txt` files. Changing Prod later must not require opening Dev state.

```bash
cd "$LAB_DIR"
ls environments/dev
ls environments/uat
ls environments/prod
```

Copy those listings into `day-38-env-lab.md`. Write: Dev apply does not load UAT or Prod state, because each `terraform apply` ran in its own folder.

14. Write the blast-radius note. Create `day-38-blast-radius.md` in the lab directory. Use this structure. Fill every line from what you just observed, not from memory of a cloud account.

```text
Separate folders:
- Dev state path:
- UAT state path:
- Prod state path:
- What a Dev destroy can delete:
- What a Prod destroy can delete:

Shared-state failure (complete this after Break and fix):
- Shared state path:
- What the last apply left in state:
- Which environment files Terraform stopped tracking:
- Blast radius of one apply:
```

The lesson rule is the same as the course: a Production operation should not require manipulating unrelated Dev infrastructure state.

---

## Verify

Read the notes as if you are on a call. You should name three folders, three state files, and three different `local_file` outputs.

Check these points:

- `modules/marker/` contains the `local_file` resource. The environment folders do not contain a second copy of that resource.
- `dev.tfvars`, `uat.tfvars`, and `prod.tfvars` set different `filename` and `content` values.
- You ran `terraform init` in each environment folder.
- `environments/dev/shopsphere-dev.txt`, `environments/uat/shopsphere-uat.txt`, and `environments/prod/shopsphere-prod.txt` all exist after apply.
- `terraform state list` in each folder prints `module.marker.local_file.marker`.
- Each folder has its own `terraform.tfstate`. There is no shared state file yet.

If two environments wrote the same filename, stop and fix the `.tfvars` files before you continue.

---

## Break and fix

The lesson says Dev and Production must not share a state file. Break that rule on purpose. Then split the state.

1. Create one shared folder. Copy the same environment `main.tf` into it. Copy all three variable files into it. This folder will hold one `terraform.tfstate` for every environment.

```bash
mkdir -p "$LAB_DIR/environments/shared"
cp "$LAB_DIR/environments/dev/main.tf" "$LAB_DIR/environments/shared/main.tf"
cp "$LAB_DIR/environments/dev/dev.tfvars" "$LAB_DIR/environments/shared/dev.tfvars"
cp "$LAB_DIR/environments/uat/uat.tfvars" "$LAB_DIR/environments/shared/uat.tfvars"
cp "$LAB_DIR/environments/prod/prod.tfvars" "$LAB_DIR/environments/shared/prod.tfvars"
cd "$LAB_DIR/environments/shared"
terraform init
```

2. Apply Dev values first. Type `yes` when Terraform asks. Read the file. Record `terraform state list`.

```bash
terraform apply -var-file="dev.tfvars"
ls
terraform state list
cat shopsphere-dev.txt
```

State now tracks one `local_file` whose filename is `shopsphere-dev.txt`.

3. Apply UAT values in the same folder, against the same state. Do not create a new backend. Type `yes`. Then list files and state again.

```bash
terraform apply -var-file="uat.tfvars"
ls
terraform state list
```

Terraform sees the same resource address `module.marker.local_file.marker`. The filename changed, so Terraform replaces the object. `shopsphere-dev.txt` is gone. `shopsphere-uat.txt` remains. One apply in a shared state deleted the Dev marker to make room for UAT. That is the blast radius.

4. Apply Prod values in the same folder. Type `yes`. Then inspect state and disk.

```bash
terraform apply -var-file="prod.tfvars"
ls
terraform state list
terraform show
cat shopsphere-prod.txt
```

State still lists one resource. Disk should show `shopsphere-prod.txt` and should not show the Dev or UAT files Terraform used to manage. Fill the shared-state lines in `day-38-blast-radius.md` now.

5. Split the state. Stop using the shared folder for Dev, UAT, and Prod. Destroy the shared configuration so it does not leave an extra file. Type `yes`. Use the last variable file Terraform applied, because that is what state currently describes.

```bash
cd "$LAB_DIR/environments/shared"
terraform destroy -var-file="prod.tfvars"
ls
```

Confirm `shopsphere-prod.txt` is gone from `environments/shared`. Leave the three separate environment folders in place. They already have their own state from steps 10 to 12. That split is the fix.

6. Confirm the split still holds. From each environment folder, run plan. Each plan should report no remaining changes for its own file. A Dev plan must not mention `shopsphere-prod.txt`.

```bash
cd "$LAB_DIR/environments/dev"
terraform plan -var-file="dev.tfvars"
cd "$LAB_DIR/environments/uat"
terraform plan -var-file="uat.tfvars"
cd "$LAB_DIR/environments/prod"
terraform plan -var-file="prod.tfvars"
```

If a plan wants to create the file again, the earlier apply in that folder is missing. Re-apply only that environment. Do not re-apply from `environments/shared`.

The original three folders are the correct design. One folder per environment. One state per environment. One set of values per environment. Shared modules are allowed. Shared state is not.

---

## Clean up

Destroy each environment. Terraform needs the same variable file it used to apply, because the configuration still reads those variables. Type `yes` when Terraform asks to confirm destroy. Skip `environments/shared` if you already destroyed it.

```bash
cd "$LAB_DIR/environments/dev"
terraform destroy -var-file="dev.tfvars"
```

```bash
cd "$LAB_DIR/environments/uat"
terraform destroy -var-file="uat.tfvars"
```

```bash
cd "$LAB_DIR/environments/prod"
terraform destroy -var-file="prod.tfvars"
```

Confirm the local files are gone. Then leave the lab directory and remove it, including `.terraform` and `terraform.tfstate`.

```bash
cd /tmp
rm -rf "$LAB_DIR"
```

If you copied notes you want to keep, move `day-38-env-lab.md` and `day-38-blast-radius.md` out before `rm -rf`. You created no AWS account, no EKS cluster, and no Azure subscription. There is nothing to delete in the cloud.

---

## Interview story

I do not put Dev, UAT, and Production in one Terraform state. I put the design in a module and I pass values from each environment folder. In this lab the module writes a `local_file`. `dev.tfvars`, `uat.tfvars`, and `prod.tfvars` set different names and content. I run `terraform init`, `plan`, and `apply` in each folder so each environment keeps its own `terraform.tfstate`. When I forced all three variable files through one shared folder, the later apply replaced the earlier file because the resource address was the same. That is the blast radius of shared state. I destroyed the shared folder and went back to three states. A Production apply must not load Dev state.
