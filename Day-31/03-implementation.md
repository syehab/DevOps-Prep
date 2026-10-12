# Day 31 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 31 starts the ShopSphere engineering phase. The lesson rule is that you write architecture decisions before you write infrastructure code. This lab is a foundation slice only. You write three short ADRs, then a Terraform skeleton that uses the `hashicorp/local` provider. The skeleton stands in for network and app modules. You do not build Spring Boot, Angular, a real VPC, or the rest of the multi-day project.

Work only in a temporary directory that you create for this lab. Do not run Terraform inside the DevOps-Prep course repository. Do not create AWS or Azure resources. Local files are enough here.

---

## Goal

Write three Architecture Decision Records for ShopSphere v1: runtime, private database, and IaC. Use the ADR fields from this Day: context, decision, why, trade-offs, alternatives, and consequences. Then create a Terraform layout with `modules/network` and `modules/app`. Call both modules from an `environments/dev` folder. Use `local_file` resources so apply writes files that record those decisions.

After apply, you can show a reviewer the ADR files, the module folders, and the files Terraform wrote. You can also explain why the app module describes a managed container runtime, not a Kubernetes cluster.

Time box: 45 to 75 minutes. Cost stays at ₹0. Stop when three ADRs exist, `terraform plan` shows no remaining changes after apply, the README names the three decisions, and `terraform destroy` has removed the lab files. Do not continue into CI/CD, UAT, Production, or failure drills.

---

## What you need

You need Terraform 1.0 or later, a text editor, and a shell. Check the version first:

```bash
terraform version
```

You do not need Maven, Docker, AWS, Azure, Kubernetes, or a cloud account. This lab uses the `hashicorp/local` provider and local state in `terraform.tfstate`. Remote backends stay a design note in ADR-003. They are not a required apply step.

Create the lab under `/tmp`, not under this course clone. Terraform writes `terraform.tfstate` in the working directory. You must be able to delete that directory when you clean up.

Keep a notes file named `day-31-foundation-lab.md` in the same temp directory. Record the three decisions, the plan resource addresses, and the break-and-fix result. Do not paste secrets. This lab should not create any.

---

## Steps

1. Create a throwaway directory and enter it. Use a unique folder name so you do not collide with another lab. Confirm the path is under `/tmp`.

```bash
LAB_DIR="/tmp/day-31-shopsphere-foundation-lab-$$"
mkdir -p "$LAB_DIR"
cd "$LAB_DIR"
pwd
```

2. Create the foundation folders. Match the ownership split from this Day: documentation, reusable modules, and one environment. Do not add UAT or Prod folders in this lab.

```bash
mkdir -p docs/adr modules/network modules/app environments/dev
ls -R
```

3. Write `docs/adr/ADR-001-runtime.md` first. Do not open a `.tf` file yet. ShopSphere v1 is a long-running Spring Boot API. The initial requirements do not name Kubernetes APIs, operators, or cluster networking.

```markdown
# ADR-001: Application Runtime

Context:
ShopSphere v1 is a containerized Spring Boot API with Dev, UAT, and Prod. The first production-style loop needs deploy, scale, identity, and a health check. It does not name custom controllers or cluster networking.

Decision:
Use a managed container runtime for v1, not Kubernetes.

Why:
A managed container runtime gives deploy, scale, and workload identity with a smaller operational surface. Kubernetes is a second control plane. v1 does not require it.

Trade-offs:
Less cluster control. No Kubernetes Service or NetworkPolicy yet. A later move to AKS or EKS is a new architecture, not a tag change.

Alternatives:
AKS or EKS now. Virtual machines.

Consequences:
The app Terraform module describes a container app or ECS service stand-in. It does not describe a cluster, node pool, or in-cluster Service.
```

Write one extra sentence at the bottom of the file in your own words. Name the requirement that would justify Kubernetes later. Do not write “because Kubernetes is more powerful.”

4. Write `docs/adr/ADR-002-private-database.md`. The security NFR is no public database access.

```markdown
# ADR-002: Private Database

Context:
PostgreSQL holds orders and customer data. Internet users must not reach the database port. The application must reach the database on a private path.

Decision:
Place the database on a private subnet. Allow the application subnet or Security Group only. Do not give the database a public endpoint.

Why:
Public TCP 5432 is out of scope for this project’s security NFR. Resolve, route, connect, authenticate, and query are five different checks. The private path is the only intended path.

Trade-offs:
You cannot debug the database from the public internet. Operators need a controlled jump path or an equivalent private session.

Alternatives:
A public database with a tight firewall. A public endpoint plus IP allow lists.

Consequences:
The network module records public ingress, application, and database subnets. The app module records a private database hostname, not a public one.
```

5. Write `docs/adr/ADR-003-iac.md`. Infrastructure is Terraform-managed. Modules hold design. Environments hold values.

```markdown
# ADR-003: Infrastructure as Code

Context:
ShopSphere needs a repeatable network and application runtime. Several people and a pipeline will change it. A laptop apply against Production is not an approval process.

Decision:
Use Terraform. Put reusable design in `modules/network` and `modules/app`. Pass environment values from `environments/dev`. Keep state per environment. Review `terraform plan` before apply.

Why:
One architecture pattern with environment-specific inputs. A Java change must not apply a VPC change. Plan review answers why each resource exists, who owns it, what depends on it, and what happens if it is deleted.

Trade-offs:
More repository structure. You must not copy three unrelated Terraform trees.

Alternatives:
Click the portal. Copy the whole stack for every environment. One giant state file for the platform.

Consequences:
This lab uses local state because the goal is the skeleton. A team would use a remote backend with locking and separate keys for `dev`, `uat`, and `prod`.
```

6. Write `README.md` at the lab root. This is the decision index, not a product brochure. Name the three ADRs and the Terraform layout in prose. Write at least one short paragraph. Do not leave the README as headings with no text.

```markdown
# ShopSphere foundation lab

This directory is a local stand-in for the ShopSphere foundation. Read the ADRs before you read the Terraform.

ADR-001 chooses a managed container runtime for v1, not Kubernetes. ADR-002 keeps PostgreSQL private. ADR-003 puts network and app design in Terraform modules and keeps Dev values in `environments/dev`.

`modules/network` writes a local file that records public, application, and database subnets. `modules/app` writes a local file that records a managed container runtime and a private database hostname. Neither module creates a cloud VPC or a Kubernetes cluster.

Work in a temp directory. Run `terraform init`, `terraform fmt`, `terraform validate`, and `terraform plan` from `environments/dev` before apply. Destroy the lab when you finish.
```

7. Write the network module. Put this in `modules/network/variables.tf`. The module must not hard-code the environment name.

```hcl
variable "environment" {
  type = string
}

variable "network_plan" {
  type = string
}
```

Put this in `modules/network/main.tf`. The resource writes the network plan that ADR-002 requires: public ingress, application, and database subnets.

```hcl
resource "local_file" "network_plan" {
  filename = "${path.root}/network-${var.environment}.txt"
  content  = var.network_plan
}
```

Put this in `modules/network/outputs.tf`.

```hcl
output "filename" {
  value = local_file.network_plan.filename
}
```

8. Write the app module. Put this in `modules/app/variables.tf`.

```hcl
variable "environment" {
  type = string
}

variable "runtime_plan" {
  type = string
}
```

Put this in `modules/app/main.tf`. The content comes from the caller. ADR-001 says that content is a managed container runtime, not a cluster.

```hcl
resource "local_file" "runtime_plan" {
  filename = "${path.root}/app-${var.environment}.txt"
  content  = var.runtime_plan
}
```

Put this in `modules/app/outputs.tf`.

```hcl
output "filename" {
  value = local_file.runtime_plan.filename
}
```

9. Write `environments/dev/main.tf`. This is the caller. It passes Dev values. It does not copy the resources. The `runtime_plan` string must match ADR-001 and ADR-002.

```hcl
terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

module "network" {
  source = "../../modules/network"

  environment = "dev"
  network_plan = <<-EOT
    environment: dev
    public_ingress: yes
    application_subnet: private
    database_subnet: private
    database_public_endpoint: no
  EOT
}

module "app" {
  source = "../../modules/app"

  environment = "dev"
  runtime_plan = <<-EOT
    environment: dev
    runtime: managed-container
    kubernetes_cluster: no
    database_hostname: shopsphere.internal
    database_public: no
  EOT
}

output "network_file" {
  value = module.network.filename
}

output "app_file" {
  value = module.app.filename
}
```

10. Initialize Terraform from `environments/dev`. This downloads the `hashicorp/local` provider into `.terraform` in that folder. It does not write the plan files yet.

```bash
cd "$LAB_DIR/environments/dev"
terraform init
```

11. Format and validate. Run `terraform fmt` in the environment folder and in each module folder. Read the output. Fix syntax before you plan.

```bash
terraform fmt
terraform fmt ../../modules/network
terraform fmt ../../modules/app
terraform validate
```

`terraform fmt` rewrites `.tf` files in that directory. Confirm it reports the files it rewrote, or reports nothing if they were already formatted.

12. Preview the create. Read the plan. You should see `module.network.local_file.network_plan` and `module.app.local_file.runtime_plan` to add. Do not apply until the plan matches that expectation.

```bash
terraform plan
```

Copy both resource addresses into `day-31-foundation-lab.md`. For each resource write why Terraform is creating it, who owns it, what depends on it, and what happens if it is deleted. That is the plan-review habit from this Day.

13. Apply the configuration. Type `yes` when Terraform asks to confirm. After apply, this folder should contain `network-dev.txt`, `app-dev.txt`, and `terraform.tfstate`.

```bash
terraform apply
```

14. Read the files Terraform wrote. Confirm they match the ADRs. The app file must say `managed-container` and `kubernetes_cluster: no`. The network file must say `database_public_endpoint: no`.

```bash
cat network-dev.txt
cat app-dev.txt
terraform state list
terraform output
```

Copy `terraform state list` into your notes. You should see two `local_file` addresses. Do not commit `terraform.tfstate`. Do not copy it into the course repository.

---

## Verify

Read the ADRs and the two output files as if you are on a call. You should name the runtime, the private database path, and the module split without opening the lesson.

Check these points:

- `docs/adr/` contains `ADR-001-runtime.md`, `ADR-002-private-database.md`, and `ADR-003-iac.md`. Each file has context, decision, why, trade-offs, alternatives, and consequences.
- `README.md` names those three decisions and the `modules/network` plus `modules/app` layout.
- You ran `terraform init`, `terraform fmt`, `terraform validate`, and `terraform plan` before apply.
- `terraform state list` shows `module.network.local_file.network_plan` and `module.app.local_file.runtime_plan`.
- `app-dev.txt` records a managed container runtime, not a Kubernetes cluster.
- `network-dev.txt` records a private database subnet and no public database endpoint.
- You created no AWS VPC, Azure VNet, AKS cluster, or RDS instance.

If `app-dev.txt` mentions a node pool or a Deployment, stop. That file does not match ADR-001. Change the `runtime_plan` value, plan, and apply so the file matches the decision.

---

## Break and fix

The lesson says you make the decision before you write the code. Break that rule on purpose, then repair it.

Create a second throwaway copy of the layout so you do not destroy the good lab. Stay under `/tmp`.

```bash
BROKEN_DIR="/tmp/day-31-shopsphere-skip-adr-$$"
mkdir -p "$BROKEN_DIR"
cd "$BROKEN_DIR"
mkdir -p modules/k8s environments/dev
```

Skip the ADR. Jump straight to Terraform. Put this in `modules/k8s/main.tf`. This module assumes Kubernetes is the v1 runtime even though no requirement asked for it.

```hcl
variable "environment" {
  type = string
}

resource "local_file" "cluster_plan" {
  filename = "${path.root}/k8s-${var.environment}.txt"
  content  = <<-EOT
    environment: ${var.environment}
    runtime: kubernetes
    node_pool: default
    kubernetes_cluster: yes
  EOT
}
```

Put this in `environments/dev/main.tf`. There is no ADR file in this broken copy yet.

```hcl
terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

module "k8s" {
  source = "../../modules/k8s"

  environment = "dev"
}
```

Initialize and apply from `environments/dev`.

```bash
cd "$BROKEN_DIR/environments/dev"
terraform init
terraform apply
cat k8s-dev.txt
```

You now have Terraform that describes a cluster. No requirement asked for a node pool. Write `docs/adr/ADR-001-runtime.md` in `$BROKEN_DIR` using the same managed-container decision from step 3. Then record the mismatch in `day-31-foundation-lab.md`:

The ADR says managed containers. The code says Kubernetes. The decision that changes the code is ADR-001. Remove `modules/k8s`. Add `modules/app` with the managed-container `runtime_plan` from step 9. Replace the `module "k8s"` block with the `module "app"` block. Run `terraform plan`. The plan should want to destroy `module.k8s.local_file.cluster_plan` and create `module.app.local_file.runtime_plan`.

```bash
mkdir -p "$BROKEN_DIR/modules/app"
```

Copy `modules/app` from the good lab, or write the same three files you wrote in step 8. Update `environments/dev/main.tf` so it calls `module.app` and does not call `module.k8s`. Run `terraform init` again because the module source changed. Then plan and apply.

```bash
cd "$BROKEN_DIR/environments/dev"
terraform init
terraform plan
terraform apply
cat app-dev.txt
```

Confirm `k8s-dev.txt` is gone and `app-dev.txt` says `managed-container`. Write one sentence in your notes: skipping the ADR produced a Kubernetes module; adding ADR-001 changed the module from `k8s` to `app`.

Do not keep the broken Kubernetes module as the good design. The good lab in `$LAB_DIR` already matches the ADRs. Destroy the broken copy after you have the plan evidence.

```bash
cd "$BROKEN_DIR/environments/dev"
terraform destroy
cd /tmp
rm -rf "$BROKEN_DIR"
```

---

## Clean up

Destroy the good lab resource, then remove the temp directory. Run destroy only after the last plan reports no remaining changes, so Terraform still knows the resources. Type `yes` when Terraform asks to confirm destroy.

```bash
cd "$LAB_DIR/environments/dev"
terraform destroy
ls
```

Confirm `network-dev.txt` and `app-dev.txt` are gone. Then leave the lab directory and delete it, including `.terraform` and `terraform.tfstate`.

```bash
cd /tmp
rm -rf "$LAB_DIR"
```

If you copied notes you want to keep, move `day-31-foundation-lab.md` out before `rm -rf`. Do not leave state files in the course repository. You created no AWS or Azure resources, so there is no VPC, cluster, database, or resource group to delete.

The ShopSphere platform in later Days is a separate project. This lab was a local skeleton. Do not keep billable cloud leftovers from an experiment you did not run here.

---

## Interview story

I do not start ShopSphere by opening the Terraform provider docs. I write ADRs first. v1 is a containerized Spring Boot API, so I choose a managed container runtime instead of Kubernetes. PostgreSQL stays private. Terraform modules hold the network and app design, and the environment folder holds Dev values. In this lab those modules write `local_file` stand-ins, so I can run `terraform init`, `fmt`, `validate`, `plan`, and `apply` without a cloud account. When I skipped the runtime ADR, I created a Kubernetes module that no requirement asked for. Adding ADR-001 changed the code: I deleted `modules/k8s` and described a managed container runtime in `modules/app`. That is the foundation habit. Decision, then code.
