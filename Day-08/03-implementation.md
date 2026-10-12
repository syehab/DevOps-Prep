# Day 8 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 8 teaches Infrastructure as Code. This lab runs a real Terraform workflow with the `hashicorp/local` provider. You create a file on disk with a `local_file` resource. You do not create AWS or Azure resources.

---

## Goal

Use Terraform to create, inspect, and destroy one local file. Walk the same path the lesson taught: `init`, `fmt`, `validate`, `plan`, `apply`, `state list`, `show`, then `destroy`.

When you finish, you can say what each command does. You can also explain drift: Terraform notices when the file on disk no longer matches the code, and you restore it with `apply` or you update the code.

---

## What you need

You need a shell and Terraform. Work in a temp directory. Do not run this lab inside the course repository.

If `terraform` is missing, install Terraform from [hashicorp.com](https://www.hashicorp.com/en/terraform). The steps below are the real commands either way. Run them after Terraform is on your `PATH`. Check with:

```bash
terraform version
```

You do not need AWS, Azure, Docker, or a cloud account. The `hashicorp/local` provider writes a file on this machine. Cost stays at ₹0.

Create a notes file named `day-08-iac-lab.md` in a folder you control. You will paste command output into that file. Do not put passwords, keys, or account IDs in the file.

Time box: 45 to 75 minutes. Stop when you have applied, inspected state, seen drift, and destroyed the file.

---

## Steps

1. Create a temp working directory. Do not use the course repo. Stay in this directory for every Terraform command in this lab.

```bash
mkdir -p /tmp/day-08-iac-lab
cd /tmp/day-08-iac-lab
```

Write the hostname and the date at the top of your notes. Write one sentence: this lab manages a local file, not a cloud resource.

2. Create `main.tf`. Write it with uneven spacing on purpose so `terraform fmt` has something to fix. Use the `hashicorp/local` provider and one `local_file` resource.

```hcl
terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

resource "local_file" "lab" {
    content  = "managed by terraform\n"
filename = "${path.module}/hello.txt"
}

output "file_path" {
  value = local_file.lab.filename
}
```

This says: I want a local file represented by `local_file.lab`. Terraform does not need AWS or Azure for this resource. The local provider writes the file on disk.

3. Prepare the working directory. Run the command below. Then inspect `.terraform/` and `.terraform.lock.hcl`. Record whether any cloud resource appeared. Record what Terraform downloaded.

```bash
terraform init
```

`init` prepares the directory. It downloads the local provider. It does not create `hello.txt`. Run `terraform init` a second time. Terraform should report that the project is already initialized.

4. Format and validate the configuration.

```bash
terraform fmt
terraform validate
```

Open `main.tf` after `fmt`. The spacing should now match Terraform style. The intended file has not changed. `validate` checks syntax and structure. It does not replace `plan`.

5. Preview the change. Before you look at the result, predict `+ local_file.lab`.

```bash
terraform plan
```

Copy the action line into your notes. `plan` tells you what Terraform intends to do. It does not create `hello.txt`. Confirm that nothing is marked destroy.

6. Make the change. Terraform shows the plan and asks for confirmation. Type `yes` when you accept it.

```bash
terraform apply
```

After apply, check that the file exists:

```bash
ls -la hello.txt
cat hello.txt
```

The file content should be `managed by terraform`. Record that in the notes.

7. Inspect what Terraform knows. Run these three commands. Compare the results in the notes.

```bash
terraform show
terraform state list
terraform output
```

`show` prints attributes Terraform stored. `state list` should print `local_file.lab`. `output` should print the file path you exposed. `state list` is not a list of every file on the machine. It is the inventory this configuration tracks.

8. Run plan again without changing the code.

```bash
terraform plan
```

Terraform should show no changes. Desired state, state, and the file on disk now match. An empty plan is the signal that apply succeeded.

---

## Verify

Read the notes out loud as if you are in an interview. You should name `init`, `fmt`, `validate`, `plan`, `apply`, `state list`, and `show` without opening extra docs.

Check these points:

- The working directory is `/tmp/day-08-iac-lab`, not the course repo.
- `terraform init` created `.terraform/` and `.terraform.lock.hcl`. It did not create the managed file.
- `hello.txt` exists only after `terraform apply`.
- `terraform state list` shows `local_file.lab`.
- A second `terraform plan` after apply showed no changes.

If any step is missing, run that command again and add the evidence before you continue.

---

## Break and fix

Do this on purpose. Change the file **outside** Terraform. Do not edit `main.tf` yet.

```bash
echo "changed by hand" > hello.txt
cat hello.txt
```

The file on disk no longer matches the configuration. That is drift. Run:

```bash
terraform plan
```

Terraform should propose a change that puts `hello.txt` back to `managed by terraform`. Record the action in the notes. The local provider identifies the file from its content, so the plan often shows `+` create rather than `~` update. Either way, Terraform intends to write the file from code again.

Restore the intended state. Choose one path:

- Apply the plan so Terraform writes the file from code again:

```bash
terraform apply
```

- Or change `main.tf` so `content` matches the file, then `terraform plan` and `terraform apply`.

If you apply without changing the code, `cat hello.txt` should again show `managed by terraform`. Run `terraform plan` once more. You should see no remaining changes.

IaC does not stop a manual edit. `plan` detects the difference. `apply` restores the file, or you update the code when the manual edit was the intended change.

---

## Clean up

Destroy the managed file from the same directory:

```bash
terraform destroy
```

Read the destroy plan before you confirm. Terraform should delete `local_file.lab` because it is in state. Type `yes` to confirm. Then check:

```bash
ls -la /tmp/day-08-iac-lab
terraform state list
```

`hello.txt` should be gone. `terraform state list` should print nothing. Do not make `-target` your cleanup method. Operate on the whole configuration.

You created no cloud resources. You may delete the temp directory when you are done:

```bash
cd /
rm -rf /tmp/day-08-iac-lab
```

Keep `day-08-iac-lab.md` in your notes. Do not copy `terraform.tfstate` into Git or chat. State can contain sensitive values in a real project.

If you opened an AWS or Azure console out of habit, close it. Create nothing. There is no resource group, VPC, or S3 bucket to delete today.

---

## Interview story

I treat IaC as desired state, not as a script of create commands. I run `terraform init` to prepare the directory, then `fmt` and `validate` before I look at a plan. `terraform plan` shows the change. `terraform apply` makes it. `terraform state list` and `terraform show` tell me what this project tracks, not what exists in the whole cloud. If someone edits the resource by hand, the next plan shows drift. I restore from code with apply, or I change the code when that edit was intended. When the lab ends, I run `terraform destroy` so Terraform removes what it manages.
