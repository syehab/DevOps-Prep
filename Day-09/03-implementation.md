# Day 9 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 9 teaches modules and environments. This lab uses that idea on your machine. You write one Terraform module that creates a `local_file`. You call it from Dev and from Prod with different `.tfvars` files. You do not create AWS or Azure resources.

---

## Goal

Build a reusable Terraform module that writes a local file. Call the same module from two environment folders. Give each environment its own name and content through `dev.tfvars` and `prod.tfvars`.

When you finish, you can explain this chain: environment values → `-var-file` → root module → child module → `local_file`. You can also show why a change inside the module appears in both environment plans.

---

## What you need

You need the Terraform CLI on your `PATH`. You need a local shell. You do not need AWS, Azure, Docker, or a cloud account. Cost stays at ₹0.

This lab uses the HashiCorp `local` provider and the `local_file` resource. Those names are real. The flag `-var-file` is real. Do not invent other flags.

Create a notes file named `day-09-module-notes.md` in a folder you control. You will paste plan lines into that file. Do not put passwords, keys, or account IDs in the file.

Time box: 45 to 75 minutes. Work in a temporary directory. Destroy the files and delete that directory at the end.

---

## Steps

1. Open a shell. Create a temporary lab directory and record its path in your notes.

```bash
LAB=$(mktemp -d)
echo "$LAB"
cd "$LAB"
```

Write one sentence in the notes: this directory is disposable. You will run `terraform destroy` here before you delete it.

2. Create the module and environment folders. The module holds the reusable design. Each environment folder is one place you apply values.

```bash
mkdir -p modules/file_writer
mkdir -p environments/dev
mkdir -p environments/prod
```

3. Write the module. Put this in `modules/file_writer/variables.tf`. These inputs must change between environments. The module must not hard-code Dev or Prod names.

```hcl
variable "filename" {
  type = string
}

variable "content" {
  type = string
}
```

4. Put this in `modules/file_writer/main.tf`. The resource uses the variables. That is the reusable design.

```hcl
resource "local_file" "note" {
  filename = var.filename
  content  = var.content
}
```

5. Put this in `modules/file_writer/outputs.tf`. The module returns the path it wrote. The environment can read that fact without guessing.

```hcl
output "filename" {
  value = local_file.note.filename
}
```

6. Write the Dev environment. Put this in `environments/dev/main.tf`. The `module` block is the caller. `source` points at the reusable folder. The values come from variables, not from hard-coded Dev strings in the module.

```hcl
terraform {
  required_providers {
    local = {
      source = "hashicorp/local"
    }
  }
}

variable "filename" {
  type = string
}

variable "content" {
  type = string
}

module "note" {
  source = "../../modules/file_writer"

  filename = var.filename
  content  = var.content
}

output "written_file" {
  value = module.note.filename
}
```

7. Put this in `environments/dev/dev.tfvars`. These are Dev values only.

```hcl
filename = "dev-app.txt"
content  = "dev environment note"
```

8. Copy the same Terraform code into Prod. Do not copy the module. Do not rewrite the resource.

```bash
cp environments/dev/main.tf environments/prod/main.tf
```

Put this in `environments/prod/prod.tfvars`. Prod uses a different name and different content. The module stays the same.

```hcl
filename = "prod-app.txt"
content  = "prod environment note"
```

9. Initialize and plan Dev. Run these commands from `environments/dev`. `terraform init` downloads the `hashicorp/local` provider. `terraform plan -var-file="dev.tfvars"` shows what Dev would create.

```bash
cd "$LAB/environments/dev"
terraform init
terraform plan -var-file="dev.tfvars"
```

In the notes, copy the planned `local_file` address and the Dev filename. Write one sentence: the plan uses Dev values. The module file did not name Dev.

10. Apply Dev. Confirm the plan when Terraform asks.

```bash
terraform apply -var-file="dev.tfvars"
terraform output
```

Read `dev-app.txt` in this folder. Confirm the content is `dev environment note`. Record `terraform output` in the notes.

11. Initialize, plan, and apply Prod the same way. Use the Prod folder and `prod.tfvars`. Dev state stays in the Dev folder. Prod state stays in the Prod folder.

```bash
cd "$LAB/environments/prod"
terraform init
terraform plan -var-file="prod.tfvars"
terraform apply -var-file="prod.tfvars"
terraform output
```

Read `prod-app.txt`. Confirm the content is `prod environment note`. In the notes, write that both environments called `../../modules/file_writer` and that only the variable files changed.

---

## Verify

Read your notes out loud as if you are in an interview. Walk the chain: `.tfvars` → `-var-file` → environment `main.tf` → module → `local_file`.

Check these points:

- `modules/file_writer/` contains the `local_file` resource. The environment folders do not contain a second copy of that resource.
- `dev.tfvars` and `prod.tfvars` set different `filename` and `content` values.
- You ran `terraform init` in each environment folder.
- You ran `terraform plan -var-file="dev.tfvars"` and `terraform plan -var-file="prod.tfvars"`.
- `environments/dev/dev-app.txt` and `environments/prod/prod-app.txt` both exist after apply.
- `terraform output` in each folder prints the file that environment wrote.

If Dev and Prod wrote the same filename, stop and fix the `.tfvars` files before you continue.

---

## Break and fix

The lesson says a module change is a design change. Every environment that uses that module version can see it. Do this on purpose.

Stay in the lab directory. Change only the module. Add a header line to the file content. Do not edit `dev.tfvars` or `prod.tfvars`.

```hcl
resource "local_file" "note" {
  filename = var.filename
  content  = "# written by the file_writer module\n${var.content}"
}
```

Plan Dev. Then plan Prod.

```bash
cd "$LAB/environments/dev"
terraform plan -var-file="dev.tfvars"
```

```bash
cd "$LAB/environments/prod"
terraform plan -var-file="prod.tfvars"
```

Both plans should show that `module.note.local_file.note` must be replaced. Terraform recreates `local_file` when content changes. Copy the replacement line from each plan into the notes. Write: the `.tfvars` files did not change. The shared module did. That is why both environments would change.

Do not apply this break. Plan is enough evidence. If a plan shows no change, check that you edited `modules/file_writer/main.tf` and that both environment `source` paths still point at that folder.

The fix is the promotion idea from the lesson. Review the module diff. Read the plan in Dev first. Then read the plan in Prod. Do not skip Dev because the files are only local. The habit is the same when the module later describes a network or a storage account.

---

## Clean up

Destroy both environments. Terraform needs the same variable file it used to apply, because the configuration still reads those variables.

```bash
cd "$LAB/environments/dev"
terraform destroy -var-file="dev.tfvars"
```

```bash
cd "$LAB/environments/prod"
terraform destroy -var-file="prod.tfvars"
```

Confirm the local files are gone. Confirm `dev-app.txt` and `prod-app.txt` no longer exist in those folders. Then leave the lab directory and remove it.

```bash
cd
rm -rf "$LAB"
```

Keep `day-09-module-notes.md`. It should contain plan lines and the two filenames, not cloud account IDs. You created no resource group and no VPC. There is nothing to delete in Azure or AWS.

---

## Interview story

I do not copy the same resource into Dev and Prod. I put the design in a Terraform module and I pass values from the environment. In this lab the module writes a `local_file`. `dev.tfvars` and `prod.tfvars` set different names and content. I run `terraform plan -var-file` and `terraform apply -var-file` in each environment folder so each environment keeps its own state. When I change the module, both plans show the same design change. That is the blast radius of a shared module, and it is why the change goes through review and Dev before Prod.
