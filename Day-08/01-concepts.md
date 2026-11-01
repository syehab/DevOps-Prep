# Day 8 — Infrastructure as Code

This Day uses three files. Read them in this order.

1. [01-concepts.md](01-concepts.md) — lesson content (this file)
2. [02-questions-and-answers.md](02-questions-and-answers.md) — practice items, each with a model answer
3. [03-implementation.md](03-implementation.md) — hands-on lab

> **The goal is not to memorize Terraform and Bicep commands.**  
> The goal is to understand how IaC turns code into repeatable, reviewable cloud infrastructure.

| | |
|---|---|
| ⏱️ Time | 75–90 min |
| 🎯 Level | Senior DevOps |
| ☁️ Cost | ₹0–low |
| 🧪 Lab | Local + AWS/Azure |

---

## 01 · What Is Infrastructure as Code · 7 min

Infrastructure as Code (IaC) means defining infrastructure in files instead of creating everything manually through a cloud portal. The code describes what infrastructure you want, and an IaC engine communicates with the cloud platform to create or change it.

Without IaC, an engineer might manually create a VPC, subnets, routes and security rules. With IaC, you write those decisions down, and the team can review, version, reuse and apply them again.

```text
IaC Code
   ↓
IaC Engine
   ↓
Cloud API
   ↓
Cloud Resources
```

For this course:

```text
AWS    → Terraform → AWS resources
Azure  → Bicep    → Azure resources
```

The important point is that **IaC is the concept; Terraform and Bicep are implementations of that concept.**

---

## 02 · Desired State · 7 min

IaC usually works by describing the **desired state**. You define what should exist, and the IaC tool compares that intention with the current infrastructure and determines what needs to happen.

For example, your desired configuration might say:

```text
VPC
 ├── Public Subnet
 └── Private Subnet
```

If the VPC does not exist, Terraform can create it. If one required subnet is missing, Terraform can detect that and create it.

The important idea is:

```text
Desired state
      ↓
Compare
      ↓
Current state
      ↓
Required changes
```

This is why IaC is different from a simple script that blindly runs `create` commands every time.

---

# Terraform

## 03 · Terraform Mental Model · 6 min

Terraform is a declarative IaC tool. You describe resources in configuration files, and Terraform uses a provider to communicate with the target platform.

For AWS:

```text
Terraform Configuration
          ↓
     AWS Provider
          ↓
       AWS API
          ↓
      AWS Resources
```

The **provider** is important because Terraform itself does not know how to create every cloud resource. The AWS provider contains the logic needed to communicate with AWS APIs.

Terraform configuration normally contains resources such as:

```hcl
resource "aws_s3_bucket" "app" {
  bucket_prefix = "cloud-learning-"
}
```

This says:

> I want an AWS S3 bucket represented by `aws_s3_bucket.app`.

It does not tell Terraform step-by-step which API call to make. Terraform decides the required operations.

---

## 04 · Terraform Project Files · 6 min

Terraform configuration is normally split into `.tf` files based on responsibility. Terraform reads all `.tf` files in the working directory together, so the filenames are mainly for organization.

A simple project can look like:

```text
aws/
└── terraform/
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    └── terraform.tfvars
```

A common pattern is:

- `main.tf` → resources and main configuration
- `variables.tf` → inputs
- `outputs.tf` → useful values returned after deployment
- `terraform.tfvars` → values supplied to variables

You do not have to split every resource into separate files. The goal is to make the code easy to understand.

---

## 05 · `terraform init` — Prepare the Project · 10 min

`terraform init` is normally the **first Terraform command** you run in a new working directory.

It prepares that directory so Terraform can work with the configuration. It can download the required providers, initialize modules, and configure the backend used for Terraform state.

For an AWS project:

```bash
terraform init
```

You will commonly see Terraform downloading the AWS provider.

After initialization, Terraform creates a `.terraform` directory containing working information such as downloaded provider components.

If you use a dependency lock file, Terraform also creates or updates:

```text
.terraform.lock.hcl
```

The lock file records the selected provider versions/checksums so different machines can use consistent provider packages.

### Why does this matter?

Imagine one engineer runs the project today and another engineer runs it next week. You do not want Terraform silently choosing an unexpected provider version.

The normal flow is:

```text
terraform init
      ↓
Download / prepare dependencies
      ↓
Working directory ready
```

`init` **does not create your S3 bucket**.

---

## 06 · `terraform fmt` and `terraform validate` · 6 min

Before planning infrastructure, make the configuration clean and valid.

```bash
terraform fmt
```

`fmt` formats Terraform configuration into Terraform's standard style. It changes formatting, not the intended infrastructure.

Then:

```bash
terraform validate
```

`validate` checks whether the configuration is syntactically and structurally valid for the current Terraform configuration.

Think of them as two different checks:

```text
fmt
 ↓
Make code consistent

validate
 ↓
Check configuration is valid
```

A successful `validate` does **not** mean the infrastructure is safe to deploy. It does not replace `plan`.

---

## 07 · `terraform plan` — Understand the Change · 10 min

`terraform plan` is one of the most important Terraform commands because it lets you inspect what Terraform **intends to change** before it changes the infrastructure.

Run:

```bash
terraform plan
```

Terraform reads your configuration, considers its state and queries the provider as needed to understand the current infrastructure. It then produces a proposed set of actions.

You will commonly see:

```text
+ create
~ update in-place
- destroy
-/+ replace
```

A simplified example:

```text
+ aws_s3_bucket.app
```

means Terraform plans to create the bucket.

If you change something that can be updated:

```text
~ aws_instance.app
```

Terraform plans an update.

Some changes cannot safely happen in place. Terraform may show:

```text
-/+ aws_instance.app
```

which means Terraform will replace the existing resource.

### Why is `plan` so important?

In production, you do not want:

```text
Developer changes code
        ↓
Apply immediately
        ↓
Discover what happened
```

A safer workflow is:

```text
Change code
    ↓
Validate
    ↓
Plan
    ↓
Review
    ↓
Apply
```

---

## 08 · `terraform apply` — Make the Change · 8 min

`terraform apply` executes the changes proposed by Terraform.

```bash
terraform apply
```

Terraform normally shows the proposed plan and asks for confirmation.

You can also apply a previously saved plan:

```bash
terraform plan -out=tfplan
terraform apply tfplan
```

This is useful in CI/CD because the reviewed plan becomes the exact plan that Terraform applies.

The important distinction is:

```text
plan  → tells you what Terraform intends to do

apply → asks Terraform to perform those changes
```

After `apply`, Terraform updates its state to reflect the resources it manages.

---

## 09 · `terraform show`, `output` and `state` · 7 min

After deployment, you need to inspect what Terraform knows.

```bash
terraform show
```

shows information about the current Terraform state and managed resources.

If you define an output:

```hcl
output "bucket_name" {
  value = aws_s3_bucket.app.bucket
}
```

you can use:

```bash
terraform output
```

to see the output value.

You can also list resources Terraform currently tracks:

```bash
terraform state list
```

For example:

```text
aws_s3_bucket.app
```

These commands answer different questions:

```text
show       → What does Terraform know about the infrastructure?

output     → What useful values did I expose?

state list → Which resources does Terraform track?
```

---

## 10 · Terraform State · 8 min

Terraform state connects Terraform configuration with real infrastructure. It allows Terraform to remember which real resource corresponds to a resource in your configuration and stores information Terraform needs to calculate future changes.

A simplified mental model is:

```text
Terraform Code
      │
      ↓
Terraform State
      │
      ↓
Real Infrastructure
```

For a small local lab, Terraform may use:

```text
terraform.tfstate
```

In a team environment, keeping state only on one engineer's laptop is unsafe. Teams normally move state to a **remote backend**, with appropriate access control and locking/concurrency protection.

Do not think of state as simply "a backup of your infrastructure." It is part of Terraform's operation. Protect it, because it can contain sensitive information, depending on the resources and configuration.

---

## 11 · `terraform refresh` Thinking: Detect Drift · 5 min

Infrastructure can change outside Terraform.

For example:

```text
Terraform says:
Bucket should have tag A

Someone changes AWS manually:
Tag becomes B
```

This creates **drift**: the real infrastructure no longer matches the configuration Terraform expects.

Modern Terraform workflows generally detect remote changes while planning rather than requiring users to rely on the old standalone `terraform refresh` workflow.

A useful command for learning is:

```bash
terraform plan
```

because the plan process checks the real infrastructure and decides whether anything needs to change.

> **IaC does not stop manual changes; it helps you detect and correct differences.**

---

## 12 · `terraform destroy` — Remove Managed Resources · 5 min

When the lab is finished:

```bash
terraform destroy
```

Terraform calculates which managed resources it must remove and asks for confirmation.

This is safer than manually deleting every resource because Terraform knows the resources represented in its state.

The normal lifecycle is therefore:

```text
init
 ↓
fmt / validate
 ↓
plan
 ↓
apply
 ↓
inspect
 ↓
change
 ↓
plan
 ↓
apply
 ↓
destroy
```

Do not make `-target` your normal cleanup method. Targeting can be useful for exceptional troubleshooting or controlled operations, but normal Terraform workflows should generally operate on the configuration as a whole.

---

# Bicep

## 13 · Bicep Mental Model · 6 min

Bicep is an Azure-focused language for describing Azure resources. The Bicep tooling compiles your files into Azure Resource Manager (ARM) templates, and Azure Resource Manager runs the deployment.

The flow is:

```text
Bicep
  ↓
ARM Template
  ↓
Azure Resource Manager
  ↓
Azure Resources
```

This is different from Terraform's provider model.

```text
AWS:
Terraform → AWS Provider → AWS API

Azure:
Bicep → ARM → Azure Resources
```

Both are IaC, but their execution models are different.

---

## 14 · Bicep Parameters, Resources and Outputs · 6 min

Bicep uses parameters for values that may change between deployments.

```bicep
param environment string

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: 'myapp${environment}'
  location: resourceGroup().location
}

output storageName string = storage.name
```

The same basic mental model applies:

```text
Input → Resource → Output
```

This becomes important when you use the same Bicep code for Dev, UAT and Prod with different parameter values.

---

## 15 · Bicep Validate, What-If and Deploy · 8 min

A simple Azure workflow is:

```text
Write Bicep
    ↓
Build / Validate
    ↓
What-If
    ↓
Review
    ↓
Deploy
```

You can compile the Bicep file:

```bash
az bicep build --file main.bicep
```

You can preview deployment changes with:

```bash
az deployment group what-if \
  --resource-group <resource-group> \
  --template-file main.bicep
```

Then deploy:

```bash
az deployment group create \
  --resource-group <resource-group> \
  --template-file main.bicep
```

The names differ from Terraform, but the operational idea is very similar:

```text
Terraform:
init → validate → plan → apply

Bicep:
build/validate → what-if → deployment
```

Azure Landing Zone pipelines that ship Bicep often add two named tests before deploy. Pester runs unit-style tests on the module (does this parameter produce the resource we expect?). PSRule checks the compiled template against Azure Policy-shaped rules (public IP, missing tag, open store). Look-up the cmdlets when a JD names them. Do not memorise the flags.

This course's analogue is `terraform test` plus a policy scan on the plan. The idea is the same: prove the template before apply. Day 11 is where that landing zone sits in the hierarchy.

> **Remember:** `what-if` previews the change. Pester and PSRule test the Bicep the way `terraform test` tests Terraform. Look the names up. Do not invent a Pester lab.

---

## 16 · Terraform vs Bicep: Keep the Mental Model Simple · 6 min

You do not need two completely different ways of thinking.

| Question | AWS | Azure |
|---|---|---|
| IaC tool | Terraform | Bicep |
| Main language | HCL | Bicep |
| Cloud interaction | AWS Provider | Azure Resource Manager |
| Preview | `terraform plan` | `az ... what-if` |
| Apply | `terraform apply` | Azure deployment |
| State model | Terraform state | Azure Resource Manager resource/deployment model |
| Typical target | AWS resources | Azure resources |

The syntax changes, but your engineering questions stay the same:

```text
What do I need?
Why do I need it?
What depends on it?
What will change?
What could break?
How will I verify it?
How will I remove or recover it?
```

One more name you will meet in job descriptions: **OpenTofu**. It is an open-source fork of Terraform that keeps the same language (HCL) and the same workflow (`init`, `plan`, `apply`), so everything you practised in this lesson applies to it directly. When a JD says "Terraform or OpenTofu", it is asking for one skill, not two. You do not need to study it separately; recognise the name and know that your Terraform skills transfer as they are.

Describe the architecture first **without using Terraform or Bicep syntax**.

Only after that, decide how you would express it in:

```text
AWS → Terraform
Azure → Bicep
```

This is the learning method we will use for the rest of the IaC section.

---

## 17 · Infrastructure Pipeline vs Application Pipeline · 6 min

Your application pipeline moves software:

```text
Code
 ↓
Build
 ↓
Test
 ↓
Artifact
 ↓
Deploy
```

Your IaC pipeline moves infrastructure changes:

```text
IaC Code
 ↓
Validate
 ↓
Plan / What-If
 ↓
Review
 ↓
Apply
 ↓
Infrastructure
```

They solve different problems, but they can work together.

```text
                 Git
              ┌───────┐
              │       │
          App Code   IaC Code
              │       │
              ↓       ↓
       App Pipeline   IaC Pipeline
              │       │
              ↓       ↓
         Application  Infrastructure
```

For your course:

```text
AWS infrastructure  → Terraform pipeline
Azure infrastructure → Bicep pipeline
Application          → Application pipeline
```

The question to ask is:

> **Am I changing the software, or the platform that runs it?**

---

## 19 · Cost Check · 2 min

The lab should use very small resources.

For AWS, an S3 bucket may create small usage-based charges depending on operations and storage.

For Azure, a Storage Account can also incur usage-based charges.

The bigger operational lesson is:

> **IaC makes infrastructure repeatable, so expensive infrastructure can also become repeatable.**

Therefore consider cost during design, not only after the bill arrives.

---

## 20 · Cleanup · 3 min

### AWS

From the Terraform directory:

```bash
terraform destroy
```

Verify the resources are gone.

### Azure

Remove the lab resource group when finished:

```bash
az group delete \
  --name <resource-group> \
  --yes
```

Verify the resource group is gone.

---

You should be able to explain this flow from memory:

```text
                 INFRASTRUCTURE AS CODE
                          │
             ┌────────────┴────────────┐
             ↓                         ↓
            AWS                      Azure
             ↓                         ↓
        Terraform                    Bicep
             ↓                         ↓
      AWS Provider                    ARM
             ↓                         ↓
       AWS Resources            Azure Resources
```

And for Terraform:

```text
Write
  ↓
init
  ↓
fmt / validate
  ↓
plan
  ↓
review
  ↓
apply
  ↓
inspect
  ↓
change
  ↓
plan / apply
  ↓
destroy
```

> **Takeaway:** Learn the IaC thinking once.  
> Then use **Terraform to implement it on AWS** and **Bicep to implement it on Azure**.

---

### Next · Day 9 · L09

**Terraform Modules & Environments**

We will start building reusable AWS infrastructure with Terraform:

```text
Terraform
   ↓
Variables
   ↓
Modules
   ↓
DEV / UAT / PROD
   ↓
Reusable AWS Infrastructure
```

Alongside it, we will start the equivalent Bicep structure for Azure:

```text
Bicep
  ↓
Parameters
  ↓
Modules
  ↓
DEV / UAT / PROD
  ↓
Reusable Azure Infrastructure
```

The two implementations will stay separate, while the **architecture and IaC concepts remain shared**.
