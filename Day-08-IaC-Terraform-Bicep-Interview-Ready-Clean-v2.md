

# Day 8 · L08 · Infrastructure as Code

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

Without IaC, an engineer might manually create a VPC, subnets, routes and security rules. With IaC, those decisions are written down and can be reviewed, versioned, reused and applied again.

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

### 🧪 Exercise

Think about creating the same infrastructure manually for:

```text
DEV
UAT
PROD
```

Write down three problems you could face.

Then ask:

> How would storing the infrastructure definition in Git help?

---

## 02 · Desired State · 7 min

IaC usually works by describing the **desired state**. You define what should exist, and the IaC tool compares that intention with the current infrastructure and determines what needs to happen.

For example, your desired configuration might say:

```text
VPC
 ├── Public Subnet
 └── Private Subnet
```

If the VPC does not exist, Terraform can create it. If one required subnet is missing, Terraform can determine that it needs to be created.

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

### 🧪 Exercise

Imagine your code says:

```text
2 subnets should exist
```

but AWS currently has:

```text
1 subnet
```

Before running Terraform, predict what should happen during `plan`.

Now imagine the cloud already matches the code.

**What should happen when you run `plan` again?**

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

### 🧪 Exercise

Look at the resource above and identify:

- Terraform resource type
- Terraform local name
- Cloud resource being requested

Then explain in your own words:

> What is Terraform responsible for, and what is AWS responsible for?

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

### 🧪 Exercise

Create:

```text
aws/terraform/
├── main.tf
├── variables.tf
└── outputs.tf
```

Put the S3 resource in `main.tf`.

Then ask:

> If Terraform reads all `.tf` files together, why do we separate them?

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

### 🧪 Exercise

Run:

```bash
terraform init
```

Then inspect:

```text
.terraform/
.terraform.lock.hcl
```

Answer:

1. Did AWS resources get created?
2. What did Terraform download?
3. Why is the lock file useful?

Then run `terraform init` again.

**Observe:** Terraform should recognize that the project is already initialized.

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

### 🧪 Exercise

Intentionally make a small formatting change in `main.tf`.

Run:

```bash
terraform fmt
```

Then introduce a simple configuration mistake and run:

```bash
terraform validate
```

Observe how Terraform catches configuration problems before you reach `apply`.

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

which means the existing resource will be replaced.

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

### 🧪 Exercise

Run:

```bash
terraform plan
```

with your S3 bucket configuration.

Then make one small change, such as adding a tag:

```hcl
tags = {
  Environment = "lab"
}
```

Run:

```bash
terraform plan
```

again.

Before looking at the result, predict:

> Will Terraform create a new bucket or modify the existing one?

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

This is useful in CI/CD because the reviewed plan can become the exact plan that is applied.

The important distinction is:

```text
plan  → tells you what Terraform intends to do

apply → asks Terraform to perform those changes
```

After `apply`, Terraform updates its state to reflect the resources it manages.

### 🧪 Exercise

Run:

```bash
terraform apply
```

Create the S3 bucket.

Then run:

```bash
terraform plan
```

again without changing your code.

Ask:

> Why should Terraform now normally show no changes?

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

### 🧪 Exercise

Run:

```bash
terraform show
terraform state list
terraform output
```

Compare their results.

Then answer:

> Why is `terraform state list` not the same thing as listing everything that exists in AWS?

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

Do not think of state as simply "a backup of your infrastructure." It is part of Terraform's operation and needs to be protected because it can contain sensitive information depending on the resources and configuration.

### 🧪 Exercise

Run:

```bash
terraform state list
```

Then manually inspect the state file **without sharing it anywhere**.

Answer:

1. Does Terraform need state to manage this project?
2. Why would a team not want every engineer using a different local state file?
3. Why should state be treated as sensitive?

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

because the plan process checks the real infrastructure and determines whether changes are needed.

### 🧪 Exercise

After creating your bucket, make a small supported change manually in AWS.

Then run:

```bash
terraform plan
```

Observe whether Terraform identifies a difference.

The lesson is:

> **IaC does not stop manual changes; it helps you detect and correct differences.**

---

## 12 · `terraform destroy` — Remove Managed Resources · 5 min

When the lab is finished:

```bash
terraform destroy
```

Terraform calculates which managed resources need to be removed and asks for confirmation.

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

### 🧪 Exercise

Run:

```bash
terraform destroy
```

Before confirming, read the planned changes.

Ask:

> Which resources will be deleted, and why?

After completion:

```bash
terraform plan
```

What should Terraform report?

---

# Bicep

## 13 · Bicep Mental Model · 6 min

Bicep is an Azure-focused language for describing Azure resources. Bicep files are compiled into Azure Resource Manager (ARM) templates, and Azure Resource Manager performs the deployment.

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

### 🧪 Exercise

Look at this Bicep resource:

```bicep
resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageName
  location: resourceGroup().location
  sku: {
    name: 'Standard_LRS'
  }
}
```

Identify:

- Resource name used inside Bicep
- Azure resource type
- Input being used for the name
- Azure service being created

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

This becomes important when the same Bicep code is used for Dev, UAT and Prod with different parameter values.

### 🧪 Exercise

Imagine:

```text
environment = dev
```

and:

```text
environment = prod
```

Predict how the resource name changes.

Then ask:

> Which part is reusable and which part changes?

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

### 🧪 Exercise

Use your Storage Account Bicep file.

First:

```bash
az bicep build --file main.bicep
```

Then run `what-if`.

Only after understanding the proposed change should you deploy.

Ask:

> Which Bicep step plays the role most similar to Terraform `plan`?

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

### 🧪 Exercise

Take this requirement:

> "Create a private application network with an application subnet and database subnet."

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

### 🧪 Exercise

Classify each change:

| Change | Pipeline |
|---|---|
| Fix Java code | Application |
| Build a new container | Application |
| Add AWS subnet | IaC |
| Change Azure NSG rule | IaC |
| Change Kubernetes deployment configuration | Depends on ownership/design |
| Change VM size through IaC | IaC |

The question to ask is:

> **Am I changing the software, or the platform that runs it?**

---

## 18 · Break & Reason · 7 min

### Scenario 1 — Terraform

Your code says:

```text
S3 bucket should exist
```

Someone deletes it manually from AWS.

Run:

```bash
terraform plan
```

Predict the result.

Then:

```bash
terraform apply
```

What should Terraform do?

### Scenario 2 — Bicep

Someone manually changes an Azure resource property that your Bicep configuration controls.

Ask:

> How would you detect that the deployed Azure configuration differs from the intended Bicep configuration?

### 🧪 Exercise

For both scenarios, write:

```text
Change happened
      ↓
How do I detect it?
      ↓
How do I understand the difference?
      ↓
How do I restore intended state?
      ↓
How do I prevent repeated manual changes?
```

This is the beginning of **IaC operational thinking**, not just IaC syntax.

---

## 19 · Cost Check · 2 min

The lab should use very small resources.

For AWS, an S3 bucket may create small usage-based charges depending on operations and storage.

For Azure, a Storage Account can also incur usage-based charges.

The bigger operational lesson is:

> **IaC makes infrastructure repeatable, so expensive infrastructure can also become repeatable.**

Cost should therefore be considered during design, not only after the bill arrives.

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

## 21 · Exit Check · 7 min

Answer without looking:

1. What problem does IaC solve?
2. What does desired state mean?
3. What does `terraform init` actually prepare?
4. Does `terraform init` create cloud resources?
5. What is the difference between `terraform validate` and `terraform plan`?
6. What does `terraform plan` tell you?
7. What does `terraform apply` do?
8. Why is `terraform plan -out=tfplan` useful in a pipeline?
9. What is Terraform state?
10. Why is local state difficult for a team?
11. What is drift?
12. How can `terraform plan` help detect drift?
13. What is Bicep's relationship with Azure Resource Manager?
14. What is the Bicep equivalent of previewing changes?
15. Why are Terraform and Bicep separate in this course?
16. What is the difference between an application pipeline and an IaC pipeline?

### 🎯 Exit Criteria

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

## Part 7 — Terraform Providers, Resource Replacement and Existing Infrastructure

A **Terraform provider** is the plugin that knows how to communicate with a particular platform or API. Terraform itself provides the workflow and language, while the provider implements the resource types and data sources for a target platform. For this course, AWS infrastructure uses the AWS provider. Other providers can manage Azure, Kubernetes, GitHub, DNS platforms, databases and many other systems. A provider is not the cloud itself; it is the bridge between Terraform and that platform's API.

A useful interview explanation is: **Terraform decides what needs to change; the provider knows how to perform that change against the target API.** During `terraform init`, Terraform installs the provider version required by the configuration and records the selected package checksums in `.terraform.lock.hcl`. During planning and applying, Terraform uses that provider to read resources and perform the required operations.

Providers can be configured with a required source and version constraint, and a provider configuration can contain things such as region or credentials. Provider aliases can also be used when one configuration needs to work with multiple provider configurations, such as two AWS regions or two AWS accounts. The important design rule is to keep provider configuration and credentials controlled rather than hard-coding secrets into resource code.

Practice by explaining this flow:

```text
Terraform Code
      ↓
Provider
      ↓
Cloud/API
      ↓
Resource
```

Then answer: **What would happen if Terraform had the resource configuration but the required provider was not initialized?**

Terraform cannot perform the normal resource operation because it does not have the provider plugin required to interpret and execute that resource.

---

## Part 8 — What Happens When a Resource Must Be Recreated?

Terraform normally tries to update a resource in place when the provider supports that operation. Some changes, however, require the existing resource to be destroyed and a new resource created. `terraform plan` shows this as a replacement, commonly represented by `-/+`. This is important because a replacement can cause downtime, data loss, a new resource identifier, or other operational effects depending on the resource.

For example, if an EC2 instance has an attribute that cannot be changed in place, Terraform may propose:

```text
-/+ aws_instance.app
```

This means the resource will be replaced rather than simply modified.

Terraform also provides a way to explicitly request replacement when you want Terraform to recreate a resource even though the configuration itself may not require replacement:

```bash
terraform apply -replace="aws_instance.app"
```

Older Terraform workflows often used:

```bash
terraform taint aws_instance.app
```

`taint` marks the resource as needing replacement on the next plan/apply. For modern workflows, prefer `terraform apply -replace=...` because it expresses the replacement directly as part of the planned operation and avoids relying on the older taint workflow.

Practice by identifying a safe lab resource and predicting the difference between:

```text
Normal update
Replacement caused by configuration
Explicit replacement requested by the engineer
```

The interview point is simple: **replacement is a lifecycle decision, not just another update. Always inspect the plan before accepting it.**

---

## Part 9 — What Happens If Someone Deletes a Terraform-Managed Resource?

Suppose Terraform created an S3 bucket and the resource is still present in Terraform configuration and state. Someone then deletes the bucket manually from AWS.

The Terraform code still says:

```text
Bucket should exist
```

but the real infrastructure says:

```text
Bucket does not exist
```

On a later `terraform plan`, Terraform refreshes information from the provider and can discover that the resource is missing. Terraform can then propose creating it again.

The important distinction is:

```text
Configuration
→ says what should exist

State
→ records what Terraform manages

Provider
→ tells Terraform what exists now

Plan
→ determines what action is required
```

Practice this in a disposable lab by creating a resource, deleting it manually, and running:

```bash
terraform plan
```

Before running `apply`, predict what Terraform will do and why.

---

### Interview Recall

You should now be able to explain:

1. What is a Terraform provider?
2. Why does `terraform init` download providers?
3. What is the purpose of `.terraform.lock.hcl`?
4. What is the difference between an in-place update and replacement?
5. What does `terraform apply -replace` do?
6. What is `terraform taint` and why is `-replace` generally preferred now?
7. What happens when someone manually deletes a Terraform-managed resource?
8. Why should you inspect a replacement in `terraform plan` before applying it?

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
