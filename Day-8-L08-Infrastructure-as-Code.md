

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

This is useful in CI/CD because the reviewed plan becomes the exact plan that Terraform applies.

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

Do not think of state as simply "a backup of your infrastructure." It is part of Terraform's operation. Protect it, because it can contain sensitive information, depending on the resources and configuration.

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

because the plan process checks the real infrastructure and decides whether anything needs to change.

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

This becomes important when you use the same Bicep code for Dev, UAT and Prod with different parameter values.

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

One more name you will meet in job descriptions: **OpenTofu**. It is an open-source fork of Terraform that keeps the same language (HCL) and the same workflow (`init`, `plan`, `apply`), so everything you practised in this lesson applies to it directly. When a JD says "Terraform or OpenTofu", it is asking for one skill, not two. You do not need to study it separately; recognise the name and know that your Terraform skills transfer as they are.

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

## Answers to practice

### 1. Three problems of manual DEV, UAT, and Prod infrastructure

<details>
<summary>Answer</summary>

Creating the same infrastructure by hand for DEV, UAT, and Prod leads to three problems. First, the environments drift apart, because people click different options in each portal. Second, you cannot review the change before it happens, because there is no file to inspect. Third, you cannot repeat the same result, because nobody recorded the exact settings.

A later rebuild then depends on memory, not on a definition. Outages and audits become harder, because you cannot show what should exist.

</details>

### 2. How storing the infrastructure definition in Git helps

<details>
<summary>Answer</summary>

Git stores the desired infrastructure as files, so the team can review, version, and reuse the same definition. A pull request shows the change before anyone applies it. History shows who changed a subnet, a tag, or a rule, and when they changed it.

You then apply the same reviewed code to DEV, UAT, and Prod instead of repeating portal clicks. Git does not create the cloud resources. It holds the definition that Terraform or Bicep will apply.

</details>

### 3. `terraform plan` when code wants two subnets and AWS has one

<details>
<summary>Answer</summary>

`terraform plan` compares desired state with current state. The code says two subnets should exist. AWS currently has one subnet.

Terraform should propose one create action for the missing subnet. It should not recreate the subnet that already matches. The plan shows required changes. It does not make those changes until you run `terraform apply`.

</details>

### 4. `terraform plan` when the cloud already matches the code

<details>
<summary>Answer</summary>

When the cloud already matches the code, `terraform plan` should report no changes. Terraform still compares desired state with current state. The comparison finds nothing to create, update, or destroy.

That is the difference from a script that always runs create commands. A second plan after a successful apply should also be empty if nobody changed the code or the cloud.

</details>

### 5. Terraform resource type, local name, and cloud resource

<details>
<summary>Answer</summary>

In `resource "aws_s3_bucket" "app"`, the Terraform resource type is `aws_s3_bucket`. The Terraform local name is `app`. Together they form the address `aws_s3_bucket.app`.

The cloud resource being requested is an AWS S3 bucket. `bucket_prefix = "cloud-learning-"` tells AWS how to name it. The block states the desired bucket. It does not list each AWS API call.

</details>

### 6. What Terraform is responsible for, and what AWS is responsible for

<details>
<summary>Answer</summary>

Terraform reads the configuration, talks to the AWS provider, and decides which operations to run. The AWS provider contains the logic that calls AWS APIs. Terraform does not itself know every AWS resource.

AWS is responsible for the real bucket. AWS creates, updates, or deletes the object in the cloud. Terraform asks. AWS executes the API and owns the resource that results.

</details>

### 7. Why we separate `main.tf`, `variables.tf`, and `outputs.tf`

<details>
<summary>Answer</summary>

Create `aws/terraform/main.tf`, `variables.tf`, and `outputs.tf`. Put the S3 resource in `main.tf`. Terraform reads all `.tf` files in the working directory together, so the split is for people, not for Terraform.

Keep resources in `main.tf`, inputs in `variables.tf`, and returned values in `outputs.tf`. That layout makes the project easier to review and change. You do not have to split every resource into its own file.

</details>

### 8. Did `terraform init` create AWS resources?

<details>
<summary>Answer</summary>

No. Run `terraform init` in the Terraform directory. Inspect `.terraform/` and `.terraform.lock.hcl`. You should see provider files appear. You should not see an S3 bucket in AWS.

`init` prepares the working directory. It downloads providers, sets up modules, and configures the backend. It does not create cloud resources. Creation happens later, during `terraform apply`.

</details>

### 9. What Terraform downloaded during `init`

<details>
<summary>Answer</summary>

Terraform downloaded the AWS provider into `.terraform/`. That directory holds working files such as provider plugins. Terraform may also create or update `.terraform.lock.hcl`.

The lock file records the selected provider versions and checksums. After `init`, the working directory is ready for `fmt`, `validate`, `plan`, and `apply`. Cloud resources still do not exist.

</details>

### 10. Why `.terraform.lock.hcl` is useful

<details>
<summary>Answer</summary>

The lock file pins provider versions and checksums so every machine uses the same provider package. One engineer can run the project today. Another engineer can run it next week without a silent version change.

Without the lock file, Terraform could pick a newer provider and change behavior. Commit the lock file with the configuration. Do not treat it as optional clutter.

</details>

### 11. What you observe when you run `terraform init` again

<details>
<summary>Answer</summary>

Run `terraform init` a second time in the same directory. Terraform should report that the project is already initialized. It should not download the AWS provider again unless something is missing or you asked it to upgrade.

That confirms `init` is preparation, not deployment. Repeat `init` after you clone the repo or change providers. Do not expect it to create or change AWS resources.

</details>

### 12. What `terraform fmt` and `terraform validate` catch

<details>
<summary>Answer</summary>

Change spacing in `main.tf` and run `terraform fmt`. Terraform rewrites the file to standard style. The intended infrastructure does not change. `fmt` only formats code.

Then break the configuration, such as a missing brace, and run `terraform validate`. Terraform reports a syntax or structure error before `plan` or `apply`. A successful `validate` does not mean the change is safe to deploy. It does not replace `terraform plan`.

</details>

### 13. First `terraform plan` for the S3 bucket

<details>
<summary>Answer</summary>

Run `terraform plan` with the S3 configuration. If the bucket does not exist yet, the plan should show `+ aws_s3_bucket.app`. That plus sign means Terraform intends to create the bucket.

Read the plan before you apply. `plan` tells you the proposed actions. It does not create the bucket. Confirm the resource, the name prefix, and that nothing unexpected is marked destroy.

</details>

### 14. After adding a tag, will plan create a new bucket or modify it?

<details>
<summary>Answer</summary>

If you already applied the bucket, adding a tag should update the existing bucket, not create a new one. Predict `~` (update in-place) on `aws_s3_bucket.app`, not `-/+` replace, for a normal tag change.

If you have not applied yet, the first plan still shows create, and the tag is part of that create. Run `terraform plan` after the tag change and compare the action symbols: `+` create, `~` update, `-` destroy, `-/+` replace.

</details>

### 15. Why `terraform plan` shows no changes after `apply`

<details>
<summary>Answer</summary>

Run `terraform apply` and confirm the S3 bucket create. Terraform then updates state so it records `aws_s3_bucket.app`. Run `terraform plan` again without changing the code.

Terraform should show no changes, because desired state, state, and the real bucket now match. An empty plan is the signal that apply succeeded and nobody drifted the bucket.

</details>

### 16. Compare `terraform show`, `state list`, and `output`

<details>
<summary>Answer</summary>

Run `terraform show`, `terraform state list`, and `terraform output` after apply. `terraform show` prints what Terraform knows about managed resources and their attributes. `terraform state list` prints addresses such as `aws_s3_bucket.app`.

`terraform output` prints only values you exposed, such as `bucket_name`. Use `show` for detail, `state list` for the inventory Terraform tracks, and `output` for values other systems need.

</details>

### 17. Why `terraform state list` is not a list of everything in AWS

<details>
<summary>Answer</summary>

`terraform state list` shows only resources this configuration manages in its state. AWS can contain many other buckets, VPCs, and accounts that this project never created.

Terraform does not inventory the whole cloud. It tracks the mapping in state. A resource that exists only in AWS, with no matching state entry, will not appear in `terraform state list`.

</details>

### 18. Does Terraform need state to manage this project?

<details>
<summary>Answer</summary>

Yes. Run `terraform state list` and inspect `terraform.tfstate` locally. Do not share that file. State maps `aws_s3_bucket.app` in code to the real bucket ID in AWS.

Without state, Terraform cannot reliably decide whether to create, update, or leave a resource. State is part of how Terraform operates. It is not only a backup of infrastructure.

</details>

### 19. Why a team should not use a different local state file per engineer

<details>
<summary>Answer</summary>

Each local `terraform.tfstate` would be a different record of the same infrastructure. One engineer’s apply would not see another engineer’s resources. Plans would fight each other, and Terraform could try to create duplicates or destroy the wrong objects.

Teams move state to a remote backend with access control and locking. One shared state is the source of truth for that project.

</details>

### 20. Why you should treat Terraform state as sensitive

<details>
<summary>Answer</summary>

State can contain resource IDs, attributes, and secrets in plain text, depending on the resources. Anyone who reads the file can learn infrastructure detail they should not have.

Do not commit state to Git. Do not paste it into chat. Protect it with a remote backend, encryption, and tight access. Inspect it locally only for learning.

</details>

### 21. Detect drift after a manual AWS change

<details>
<summary>Answer</summary>

After apply, change one supported attribute in AWS, such as a tag on the bucket. Then run `terraform plan`. Terraform should show an update that puts the tag back to the value in code.

IaC does not stop people from changing AWS by hand. `plan` detects the difference and proposes a correction. Do not apply blindly. First confirm whether the manual change was a mistake.

</details>

### 22. Which resources `terraform destroy` deletes, and why

<details>
<summary>Answer</summary>

Run `terraform destroy` and read the plan before you confirm. Terraform should list every managed resource in state, such as `aws_s3_bucket.app`, with destroy actions. It deletes those resources because they are in state, not because they are everything in AWS.

This is safer than clicking delete in the portal, because Terraform uses its inventory. Do not make `-target` your normal cleanup. Operate on the whole configuration.

</details>

### 23. What `terraform plan` reports after a successful destroy

<details>
<summary>Answer</summary>

After destroy completes, run `terraform plan`. Terraform should propose to create the resources again, such as `+ aws_s3_bucket.app`, because the code still describes them and they no longer exist.

If you also removed the configuration, the plan would be empty. With the lab files still present, an empty plan after destroy would mean Terraform still thinks the bucket exists, which would be wrong.

</details>

### 24. Identify the parts of the Bicep storage resource

<details>
<summary>Answer</summary>

In the Bicep resource, the name used inside Bicep is `storage`. The Azure resource type is `Microsoft.Storage/storageAccounts@2023-05-01`. The input used for the name is `storageName`.

The Azure service being created is a Storage Account. Bicep describes that resource. Azure Resource Manager creates it after the file compiles to an ARM template.

</details>

### 25. How the Storage Account name changes between `dev` and `prod`

<details>
<summary>Answer</summary>

With `name: 'myapp${environment}'`, `environment = dev` yields a name like `myappdev`. `environment = prod` yields `myappprod`. The same resource block runs in both cases.

The Bicep resource definition is reusable. The parameter value changes. That is how one file serves Dev, UAT, and Prod without copying the resource three times.

</details>

### 26. Which part of the Bicep file is reusable, and which part changes

<details>
<summary>Answer</summary>

The resource block, SKU, location, and output are the reusable design. The parameter `environment` (and any name built from it) is what changes per deployment.

Keep design in the Bicep file. Keep environment values in parameters. Then Dev, UAT, and Prod share one definition and differ only by input.

</details>

### 27. Which Bicep step is most like `terraform plan`

<details>
<summary>Answer</summary>

Run `az bicep build --file main.bicep` first. That compiles and helps catch file problems. Then run `az deployment group what-if --resource-group <resource-group> --template-file main.bicep`.

`what-if` is the step most like `terraform plan`. It previews the change. It does not deploy. Deploy only after you understand the proposal, using `az deployment group create`.

</details>

### 28. Private application network described before Terraform or Bicep syntax

<details>
<summary>Answer</summary>

You need a private application network with an application subnet and a database subnet. Put application workloads in one subnet. Put the database in the other subnet. Control traffic between them with security rules so the database is not public.

On AWS, express that design in Terraform as a VPC, two subnets, and security groups. On Azure, express the same design in Bicep as a VNet, two subnets, and NSG rules. Describe the architecture first. Then choose the IaC syntax.

</details>

### 29. Classify each change as application pipeline or IaC pipeline

<details>
<summary>Answer</summary>

Ask: am I changing the software, or the platform that runs it? Fix Java code and build a new container are application pipeline work. Add an AWS subnet, change an Azure NSG rule, and change VM size through IaC are IaC pipeline work.

A Kubernetes deployment change depends on ownership. If the team stores that manifest with the app, it can ride the application pipeline. If platform IaC owns the cluster objects, it belongs in the IaC pipeline.

</details>

### 30. Scenario 1 — `terraform plan` after someone deletes the S3 bucket

<details>
<summary>Answer</summary>

The code still says the S3 bucket should exist. State still records `aws_s3_bucket.app`. AWS no longer has the bucket. Run `terraform plan`.

Terraform should propose to create the bucket again (`+`). Plan detects that real infrastructure no longer matches desired state. It does not recreate the bucket until apply.

</details>

### 31. Scenario 1 — `terraform apply` after the manual delete

<details>
<summary>Answer</summary>

`terraform apply` should create the bucket again so AWS matches the code and state. That restores the intended resource. It does not “ignore” the delete.

After apply, run `terraform plan` once more. You should see no remaining changes. Then stop repeating portal deletes. Change infrastructure through code and review.

</details>

### 32. Scenario 2 — Detect that Azure no longer matches Bicep

<details>
<summary>Answer</summary>

Run `az deployment group what-if` against the same Bicep file and resource group. What-if compares the intended configuration with the deployed Azure resource. A manual property change should appear as a difference.

Review that preview. Then deploy with `az deployment group create` if you want Azure to match Bicep. Bicep has no Terraform-style state file. Azure Resource Manager is the comparison point.

</details>

### 33. Operational flow for both drift scenarios

<details>
<summary>Answer</summary>

The change happened outside IaC. Detect it with `terraform plan` on AWS or `az deployment group what-if` on Azure. Read the proposed difference so you understand create, update, or revert.

Restore intended state with `terraform apply` or an Azure deployment when the code is the source of truth. Prevent repeats by review, pipeline apply, and access control, so people do not keep changing the portal by hand.

</details>

### 34. Exit Check — What problem does IaC solve?

<details>
<summary>Answer</summary>

IaC solves the problem of building infrastructure by hand in a portal. You define the desired infrastructure in files. An engine such as Terraform or Bicep then creates or changes the cloud to match.

The team can review, version, and repeat the same result across DEV, UAT, and Prod. IaC is the concept. Terraform and Bicep are implementations.

</details>

### 35. Exit Check — What does desired state mean?

<details>
<summary>Answer</summary>

Desired state is what you declare in code: the infrastructure that should exist. The IaC tool compares that intention with current infrastructure and calculates the required changes.

If the code says two subnets and the cloud has one, the required change is to create the missing subnet. Desired state is not a script of create commands that always run.

</details>

### 36. Exit Check — What does `terraform init` actually prepare?

<details>
<summary>Answer</summary>

`terraform init` prepares the working directory. It downloads providers, initializes modules, and configures the backend for state. It often creates `.terraform/` and `.terraform.lock.hcl`.

After init, Terraform can validate, plan, and apply. Init does not itself change cloud infrastructure.

</details>

### 37. Exit Check — Does `terraform init` create cloud resources?

<details>
<summary>Answer</summary>

No. `terraform init` does not create cloud resources. It only prepares the project so later commands can run.

The S3 bucket appears only after `terraform apply`. If you inspect AWS right after init, the lab bucket should not exist yet.

</details>

### 38. Exit Check — Difference between `terraform validate` and `terraform plan`

<details>
<summary>Answer</summary>

`terraform validate` checks that the configuration is syntactically and structurally valid. It does not query the live cloud to propose creates and deletes. A valid configuration can still be a dangerous change.

`terraform plan` compares configuration, state, and real infrastructure. It shows `+`, `~`, `-`, and `-/+` actions. Use validate before plan. Use plan before apply.

</details>

### 39. Exit Check — What does `terraform plan` tell you?

<details>
<summary>Answer</summary>

`terraform plan` tells you what Terraform intends to change before it changes anything. You see creates, in-place updates, destroys, and replacements.

Read the plan in production before apply. Plan is inspection. Apply is execution.

</details>

### 40. Exit Check — What does `terraform apply` do?

<details>
<summary>Answer</summary>

`terraform apply` performs the changes Terraform proposed. It usually shows the plan and asks for confirmation. After it succeeds, Terraform updates state to match the resources it now manages.

You can also apply a saved file from `terraform plan -out=tfplan` with `terraform apply tfplan`. Plan says what Terraform will do. Apply does it.

</details>

### 41. Exit Check — Why `terraform plan -out=tfplan` is useful in a pipeline

<details>
<summary>Answer</summary>

`terraform plan -out=tfplan` writes the reviewed plan to a file. The pipeline later runs `terraform apply tfplan` so Terraform applies that exact plan, not a newly calculated one.

Review and approval then sit between plan and apply. That is safer than apply immediately after a code change.

</details>

### 42. Exit Check — What is Terraform state?

<details>
<summary>Answer</summary>

Terraform state is the record that connects configuration to real infrastructure. It stores which cloud object belongs to which resource address, plus attributes Terraform needs for the next plan.

For a local lab that file is often `terraform.tfstate`. State is not merely a backup. Terraform uses it to calculate future changes.

</details>

### 43. Exit Check — Why is local state difficult for a team?

<details>
<summary>Answer</summary>

Local state lives on one laptop. Each engineer can hold a different copy. Plans then disagree, and two applies can conflict.

Teams use a remote backend with access control and locking so everyone shares one state. A laptop copy is fine for a personal lab, not for shared infrastructure.

</details>

### 44. Exit Check — What is drift?

<details>
<summary>Answer</summary>

Drift is when real infrastructure no longer matches what the configuration and state expect. A common case is a manual portal change after Terraform created the resource.

IaC does not block that manual change. It helps you detect and correct the difference on the next plan.

</details>

### 45. Exit Check — How `terraform plan` helps detect drift

<details>
<summary>Answer</summary>

During `terraform plan`, Terraform checks real infrastructure through the provider and compares it with configuration and state. A manual tag change then appears as an update in the plan.

Modern workflows detect remote changes while planning. You do not rely on a standalone `terraform refresh` as the main daily tool.

</details>

### 46. Exit Check — Bicep’s relationship with Azure Resource Manager

<details>
<summary>Answer</summary>

Bicep compiles to an ARM template. Azure Resource Manager then runs the deployment and manages Azure resources. The path is Bicep → ARM template → Azure Resource Manager → Azure resources.

That is different from Terraform’s provider model. Terraform talks to AWS through the AWS provider. Bicep does not use that same provider path on Azure.

</details>

### 47. Exit Check — Bicep equivalent of previewing changes

<details>
<summary>Answer</summary>

The Bicep preview is `az deployment group what-if`. It plays the same operational role as `terraform plan`: inspect the change, then deploy.

`az bicep build` compiles the file. It is closer to validate than to plan. Deploy with `az deployment group create` only after you understand what-if.

</details>

### 48. Exit Check — Why Terraform and Bicep stay separate in this course

<details>
<summary>Answer</summary>

This course uses Terraform for AWS and Bicep for Azure. Both implement IaC, but they use different engines: AWS provider versus Azure Resource Manager.

Keep the shared questions: what do I need, what will change, what could break. Change only the syntax and the cloud path. OpenTofu is a Terraform fork with the same HCL workflow, not a third mental model.

</details>

### 49. Exit Check — Application pipeline versus IaC pipeline

<details>
<summary>Answer</summary>

An application pipeline moves software: code, build, test, artifact, deploy. An IaC pipeline moves infrastructure: validate, plan or what-if, review, apply, infrastructure.

They can share Git. They solve different problems. AWS infrastructure uses a Terraform pipeline. Azure infrastructure uses a Bicep pipeline. Application code uses the application pipeline.

</details>
