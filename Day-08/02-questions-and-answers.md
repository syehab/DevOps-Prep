# Day 8 — Questions and answers

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Then answer each item below before you open the Answer block. After that, do the lab in [03-implementation.md](03-implementation.md).

Write your own answer first. Open the Answer block only after you try. Keep the original numbering.

---

## 1. Three problems of manual DEV, UAT, and Prod infrastructure

# 01 · What Is Infrastructure as Code · 7 min

### 🧪 Exercise

Think about creating the same infrastructure manually for:

```text
DEV
UAT
PROD
```

Write down three problems you could face.

<details>
<summary>Answer</summary>

Creating the same infrastructure by hand for DEV, UAT, and Prod leads to three problems. First, the environments drift apart, because people click different options in each portal. Second, you cannot review the change before it happens, because there is no file to inspect. Third, you cannot repeat the same result, because nobody recorded the exact settings.

A later rebuild then depends on memory, not on a definition. Outages and audits become harder, because you cannot show what should exist.

</details>

---

## 2. How storing the infrastructure definition in Git helps

Then ask:

> How would storing the infrastructure definition in Git help?

<details>
<summary>Answer</summary>

Git stores the desired infrastructure as files, so the team can review, version, and reuse the same definition. A pull request shows the change before anyone applies it. History shows who changed a subnet, a tag, or a rule, and when they changed it.

You then apply the same reviewed code to DEV, UAT, and Prod instead of repeating portal clicks. Git does not create the cloud resources. It holds the definition that Terraform or Bicep will apply.

</details>

---

## 3. `terraform plan` when code wants two subnets and AWS has one

# 02 · Desired State · 7 min

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

<details>
<summary>Answer</summary>

`terraform plan` compares desired state with current state. The code says two subnets should exist. AWS currently has one subnet.

Terraform should propose one create action for the missing subnet. It should not recreate the subnet that already matches. The plan shows required changes. It does not make those changes until you run `terraform apply`.

</details>

---

## 4. `terraform plan` when the cloud already matches the code

Now imagine the cloud already matches the code.

**What should happen when you run `plan` again?**

<details>
<summary>Answer</summary>

When the cloud already matches the code, `terraform plan` should report no changes. Terraform still compares desired state with current state. The comparison finds nothing to create, update, or destroy.

That is the difference from a script that always runs create commands. A second plan after a successful apply should also be empty if nobody changed the code or the cloud.

</details>

---

## 5. Terraform resource type, local name, and cloud resource

# 03 · Terraform Mental Model · 6 min

### 🧪 Exercise

Look at the resource above and identify:

```hcl
resource "aws_s3_bucket" "app" {
  bucket_prefix = "cloud-learning-"
}
```

- Terraform resource type
- Terraform local name
- Cloud resource being requested

<details>
<summary>Answer</summary>

In `resource "aws_s3_bucket" "app"`, the Terraform resource type is `aws_s3_bucket`. The Terraform local name is `app`. Together they form the address `aws_s3_bucket.app`.

The cloud resource being requested is an AWS S3 bucket. `bucket_prefix = "cloud-learning-"` tells AWS how to name it. The block states the desired bucket. It does not list each AWS API call.

</details>

---

## 6. What Terraform is responsible for, and what AWS is responsible for

Then explain in your own words:

> What is Terraform responsible for, and what is AWS responsible for?

<details>
<summary>Answer</summary>

Terraform reads the configuration, talks to the AWS provider, and decides which operations to run. The AWS provider contains the logic that calls AWS APIs. Terraform does not itself know every AWS resource.

AWS is responsible for the real bucket. AWS creates, updates, or deletes the object in the cloud. Terraform asks. AWS executes the API and owns the resource that results.

</details>

---

## 7. Why we separate `main.tf`, `variables.tf`, and `outputs.tf`

# 04 · Terraform Project Files · 6 min

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

<details>
<summary>Answer</summary>

Create `aws/terraform/main.tf`, `variables.tf`, and `outputs.tf`. Put the S3 resource in `main.tf`. Terraform reads all `.tf` files in the working directory together, so the split is for people, not for Terraform.

Keep resources in `main.tf`, inputs in `variables.tf`, and returned values in `outputs.tf`. That layout makes the project easier to review and change. You do not have to split every resource into its own file.

</details>

---

## 8. Did `terraform init` create AWS resources?

# 05 · `terraform init` — Prepare the Project · 10 min

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

<details>
<summary>Answer</summary>

No. Run `terraform init` in the Terraform directory. Inspect `.terraform/` and `.terraform.lock.hcl`. You should see provider files appear. You should not see an S3 bucket in AWS.

`init` prepares the working directory. It downloads providers, sets up modules, and configures the backend. It does not create cloud resources. Creation happens later, during `terraform apply`.

</details>

---

## 9. What Terraform downloaded during `init`

2. What did Terraform download?

<details>
<summary>Answer</summary>

Terraform downloaded the AWS provider into `.terraform/`. That directory holds working files such as provider plugins. Terraform may also create or update `.terraform.lock.hcl`.

The lock file records the selected provider versions and checksums. After `init`, the working directory is ready for `fmt`, `validate`, `plan`, and `apply`. Cloud resources still do not exist.

</details>

---

## 10. Why `.terraform.lock.hcl` is useful

3. Why is the lock file useful?

<details>
<summary>Answer</summary>

The lock file pins provider versions and checksums so every machine uses the same provider package. One engineer can run the project today. Another engineer can run it next week without a silent version change.

Without the lock file, Terraform could pick a newer provider and change behavior. Commit the lock file with the configuration. Do not treat it as optional clutter.

</details>

---

## 11. What you observe when you run `terraform init` again

Then run `terraform init` again.

**Observe:** Terraform should recognize that the project is already initialized.

<details>
<summary>Answer</summary>

Run `terraform init` a second time in the same directory. Terraform should report that the project is already initialized. It should not download the AWS provider again unless something is missing or you asked it to upgrade.

That confirms `init` is preparation, not deployment. Repeat `init` after you clone the repo or change providers. Do not expect it to create or change AWS resources.

</details>

---

## 12. What `terraform fmt` and `terraform validate` catch

# 06 · `terraform fmt` and `terraform validate` · 6 min

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

<details>
<summary>Answer</summary>

Change spacing in `main.tf` and run `terraform fmt`. Terraform rewrites the file to standard style. The intended infrastructure does not change. `fmt` only formats code.

Then break the configuration, such as a missing brace, and run `terraform validate`. Terraform reports a syntax or structure error before `plan` or `apply`. A successful `validate` does not mean the change is safe to deploy. It does not replace `terraform plan`.

</details>

---

## 13. First `terraform plan` for the S3 bucket

# 07 · `terraform plan` — Understand the Change · 10 min

### 🧪 Exercise

Run:

```bash
terraform plan
```

with your S3 bucket configuration.

<details>
<summary>Answer</summary>

Run `terraform plan` with the S3 configuration. If the bucket does not exist yet, the plan should show `+ aws_s3_bucket.app`. That plus sign means Terraform intends to create the bucket.

Read the plan before you apply. `plan` tells you the proposed actions. It does not create the bucket. Confirm the resource, the name prefix, and that nothing unexpected is marked destroy.

</details>

---

## 14. After adding a tag, will plan create a new bucket or modify it?

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

<details>
<summary>Answer</summary>

If you already applied the bucket, adding a tag should update the existing bucket, not create a new one. Predict `~` (update in-place) on `aws_s3_bucket.app`, not `-/+` replace, for a normal tag change.

If you have not applied yet, the first plan still shows create, and the tag is part of that create. Run `terraform plan` after the tag change and compare the action symbols: `+` create, `~` update, `-` destroy, `-/+` replace.

</details>

---

## 15. Why `terraform plan` shows no changes after `apply`

# 08 · `terraform apply` — Make the Change · 8 min

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

<details>
<summary>Answer</summary>

Run `terraform apply` and confirm the S3 bucket create. Terraform then updates state so it records `aws_s3_bucket.app`. Run `terraform plan` again without changing the code.

Terraform should show no changes, because desired state, state, and the real bucket now match. An empty plan is the signal that apply succeeded and nobody drifted the bucket.

</details>

---

## 16. Compare `terraform show`, `state list`, and `output`

# 09 · `terraform show`, `output` and `state` · 7 min

### 🧪 Exercise

Run:

```bash
terraform show
terraform state list
terraform output
```

Compare their results.

<details>
<summary>Answer</summary>

Run `terraform show`, `terraform state list`, and `terraform output` after apply. `terraform show` prints what Terraform knows about managed resources and their attributes. `terraform state list` prints addresses such as `aws_s3_bucket.app`.

`terraform output` prints only values you exposed, such as `bucket_name`. Use `show` for detail, `state list` for the inventory Terraform tracks, and `output` for values other systems need.

</details>

---

## 17. Why `terraform state list` is not a list of everything in AWS

Then answer:

> Why is `terraform state list` not the same thing as listing everything that exists in AWS?

<details>
<summary>Answer</summary>

`terraform state list` shows only resources this configuration manages in its state. AWS can contain many other buckets, VPCs, and accounts that this project never created.

Terraform does not inventory the whole cloud. It tracks the mapping in state. A resource that exists only in AWS, with no matching state entry, will not appear in `terraform state list`.

</details>

---

## 18. Does Terraform need state to manage this project?

# 10 · Terraform State · 8 min

### 🧪 Exercise

Run:

```bash
terraform state list
```

Then manually inspect the state file **without sharing it anywhere**.

Answer:

1. Does Terraform need state to manage this project?

<details>
<summary>Answer</summary>

Yes. Run `terraform state list` and inspect `terraform.tfstate` locally. Do not share that file. State maps `aws_s3_bucket.app` in code to the real bucket ID in AWS.

Without state, Terraform cannot reliably decide whether to create, update, or leave a resource. State is part of how Terraform operates. It is not only a backup of infrastructure.

</details>

---

## 19. Why a team should not use a different local state file per engineer

2. Why would a team not want every engineer using a different local state file?

<details>
<summary>Answer</summary>

Each local `terraform.tfstate` would be a different record of the same infrastructure. One engineer’s apply would not see another engineer’s resources. Plans would fight each other, and Terraform could try to create duplicates or destroy the wrong objects.

Teams move state to a remote backend with access control and locking. One shared state is the source of truth for that project.

</details>

---

## 20. Why you should treat Terraform state as sensitive

3. Why should state be treated as sensitive?

<details>
<summary>Answer</summary>

State can contain resource IDs, attributes, and secrets in plain text, depending on the resources. Anyone who reads the file can learn infrastructure detail they should not have.

Do not commit state to Git. Do not paste it into chat. Protect it with a remote backend, encryption, and tight access. Inspect it locally only for learning.

</details>

---

## 21. Detect drift after a manual AWS change

# 11 · `terraform refresh` Thinking: Detect Drift · 5 min

### 🧪 Exercise

After creating your bucket, make a small supported change manually in AWS.

Then run:

```bash
terraform plan
```

Observe whether Terraform identifies a difference.

The lesson is:

> **IaC does not stop manual changes; it helps you detect and correct differences.**

<details>
<summary>Answer</summary>

After apply, change one supported attribute in AWS, such as a tag on the bucket. Then run `terraform plan`. Terraform should show an update that puts the tag back to the value in code.

IaC does not stop people from changing AWS by hand. `plan` detects the difference and proposes a correction. Do not apply blindly. First confirm whether the manual change was a mistake.

</details>

---

## 22. Which resources `terraform destroy` deletes, and why

# 12 · `terraform destroy` — Remove Managed Resources · 5 min

### 🧪 Exercise

Run:

```bash
terraform destroy
```

Before confirming, read the planned changes.

Ask:

> Which resources will be deleted, and why?

<details>
<summary>Answer</summary>

Run `terraform destroy` and read the plan before you confirm. Terraform should list every managed resource in state, such as `aws_s3_bucket.app`, with destroy actions. It deletes those resources because they are in state, not because they are everything in AWS.

This is safer than clicking delete in the portal, because Terraform uses its inventory. Do not make `-target` your normal cleanup. Operate on the whole configuration.

</details>

---

## 23. What `terraform plan` reports after a successful destroy

After completion:

```bash
terraform plan
```

What should Terraform report?

<details>
<summary>Answer</summary>

After destroy completes, run `terraform plan`. Terraform should propose to create the resources again, such as `+ aws_s3_bucket.app`, because the code still describes them and they no longer exist.

If you also removed the configuration, the plan would be empty. With the lab files still present, an empty plan after destroy would mean Terraform still thinks the bucket exists, which would be wrong.

</details>

---

## 24. Identify the parts of the Bicep storage resource

# 13 · Bicep Mental Model · 6 min

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

<details>
<summary>Answer</summary>

In the Bicep resource, the name used inside Bicep is `storage`. The Azure resource type is `Microsoft.Storage/storageAccounts@2023-05-01`. The input used for the name is `storageName`.

The Azure service being created is a Storage Account. Bicep describes that resource. Azure Resource Manager creates it after the file compiles to an ARM template.

</details>

---

## 25. How the Storage Account name changes between `dev` and `prod`

# 14 · Bicep Parameters, Resources and Outputs · 6 min

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

<details>
<summary>Answer</summary>

With `name: 'myapp${environment}'`, `environment = dev` yields a name like `myappdev`. `environment = prod` yields `myappprod`. The same resource block runs in both cases.

The Bicep resource definition is reusable. The parameter value changes. That is how one file serves Dev, UAT, and Prod without copying the resource three times.

</details>

---

## 26. Which part of the Bicep file is reusable, and which part changes

Then ask:

> Which part is reusable and which part changes?

<details>
<summary>Answer</summary>

The resource block, SKU, location, and output are the reusable design. The parameter `environment` (and any name built from it) is what changes per deployment.

Keep design in the Bicep file. Keep environment values in parameters. Then Dev, UAT, and Prod share one definition and differ only by input.

</details>

---

## 27. Which Bicep step is most like `terraform plan`

# 15 · Bicep Validate, What-If and Deploy · 8 min

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

<details>
<summary>Answer</summary>

Run `az bicep build --file main.bicep` first. That compiles and helps catch file problems. Then run `az deployment group what-if --resource-group <resource-group> --template-file main.bicep`.

`what-if` is the step most like `terraform plan`. It previews the change. It does not deploy. Deploy only after you understand the proposal, using `az deployment group create`.

</details>

---

## 28. Private application network described before Terraform or Bicep syntax

# 16 · Terraform vs Bicep: Keep the Mental Model Simple · 6 min

Take this requirement:

> "Create a private application network with an application subnet and database subnet."

Describe the architecture first **without using Terraform or Bicep syntax**.

Only after that, decide how you would express it in:

```text
AWS → Terraform
Azure → Bicep
```

<details>
<summary>Answer</summary>

You need a private application network with an application subnet and a database subnet. Put application workloads in one subnet. Put the database in the other subnet. Control traffic between them with security rules so the database is not public.

On AWS, express that design in Terraform as a VPC, two subnets, and security groups. On Azure, express the same design in Bicep as a VNet, two subnets, and NSG rules. Describe the architecture first. Then choose the IaC syntax.

</details>

---

## 29. Classify each change as application pipeline or IaC pipeline

# 17 · Infrastructure Pipeline vs Application Pipeline · 6 min

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

<details>
<summary>Answer</summary>

Ask: am I changing the software, or the platform that runs it? Fix Java code and build a new container are application pipeline work. Add an AWS subnet, change an Azure NSG rule, and change VM size through IaC are IaC pipeline work.

A Kubernetes deployment change depends on ownership. If the team stores that manifest with the app, it can ride the application pipeline. If platform IaC owns the cluster objects, it belongs in the IaC pipeline.

</details>

---

## 30. Scenario 1 — `terraform plan` after someone deletes the S3 bucket

# 18 · Break & Reason · 7 min

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

<details>
<summary>Answer</summary>

The code still says the S3 bucket should exist. State still records `aws_s3_bucket.app`. AWS no longer has the bucket. Run `terraform plan`.

Terraform should propose to create the bucket again (`+`). Plan detects that real infrastructure no longer matches desired state. It does not recreate the bucket until apply.

</details>

---

## 31. Scenario 1 — `terraform apply` after the manual delete

Then:

```bash
terraform apply
```

What should Terraform do?

<details>
<summary>Answer</summary>

`terraform apply` should create the bucket again so AWS matches the code and state. That restores the intended resource. It does not “ignore” the delete.

After apply, run `terraform plan` once more. You should see no remaining changes. Then stop repeating portal deletes. Change infrastructure through code and review.

</details>

---

## 32. Scenario 2 — Detect that Azure no longer matches Bicep

### Scenario 2 — Bicep

Someone manually changes an Azure resource property that your Bicep configuration controls.

Ask:

> How would you detect that the deployed Azure configuration differs from the intended Bicep configuration?

<details>
<summary>Answer</summary>

Run `az deployment group what-if` against the same Bicep file and resource group. What-if compares the intended configuration with the deployed Azure resource. A manual property change should appear as a difference.

Review that preview. Then deploy with `az deployment group create` if you want Azure to match Bicep. Bicep has no Terraform-style state file. Azure Resource Manager is the comparison point.

</details>

---

## 33. Operational flow for both drift scenarios

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

<details>
<summary>Answer</summary>

The change happened outside IaC. Detect it with `terraform plan` on AWS or `az deployment group what-if` on Azure. Read the proposed difference so you understand create, update, or revert.

Restore intended state with `terraform apply` or an Azure deployment when the code is the source of truth. Prevent repeats by review, pipeline apply, and access control, so people do not keep changing the portal by hand.

</details>

---

## 34. Exit Check — What problem does IaC solve?

# 21 · Exit Check · 7 min

Answer without looking:

1. What problem does IaC solve?

<details>
<summary>Answer</summary>

IaC solves the problem of building infrastructure by hand in a portal. You define the desired infrastructure in files. An engine such as Terraform or Bicep then creates or changes the cloud to match.

The team can review, version, and repeat the same result across DEV, UAT, and Prod. IaC is the concept. Terraform and Bicep are implementations.

</details>

---

## 35. Exit Check — What does desired state mean?

2. What does desired state mean?

<details>
<summary>Answer</summary>

Desired state is what you declare in code: the infrastructure that should exist. The IaC tool compares that intention with current infrastructure and calculates the required changes.

If the code says two subnets and the cloud has one, the required change is to create the missing subnet. Desired state is not a script of create commands that always run.

</details>

---

## 36. Exit Check — What does `terraform init` actually prepare?

3. What does `terraform init` actually prepare?

<details>
<summary>Answer</summary>

`terraform init` prepares the working directory. It downloads providers, initializes modules, and configures the backend for state. It often creates `.terraform/` and `.terraform.lock.hcl`.

After init, Terraform can validate, plan, and apply. Init does not itself change cloud infrastructure.

</details>

---

## 37. Exit Check — Does `terraform init` create cloud resources?

4. Does `terraform init` create cloud resources?

<details>
<summary>Answer</summary>

No. `terraform init` does not create cloud resources. It only prepares the project so later commands can run.

The S3 bucket appears only after `terraform apply`. If you inspect AWS right after init, the lab bucket should not exist yet.

</details>

---

## 38. Exit Check — Difference between `terraform validate` and `terraform plan`

5. What is the difference between `terraform validate` and `terraform plan`?

<details>
<summary>Answer</summary>

`terraform validate` checks that the configuration is syntactically and structurally valid. It does not query the live cloud to propose creates and deletes. A valid configuration can still be a dangerous change.

`terraform plan` compares configuration, state, and real infrastructure. It shows `+`, `~`, `-`, and `-/+` actions. Use validate before plan. Use plan before apply.

</details>

---

## 39. Exit Check — What does `terraform plan` tell you?

6. What does `terraform plan` tell you?

<details>
<summary>Answer</summary>

`terraform plan` tells you what Terraform intends to change before it changes anything. You see creates, in-place updates, destroys, and replacements.

Read the plan in production before apply. Plan is inspection. Apply is execution.

</details>

---

## 40. Exit Check — What does `terraform apply` do?

7. What does `terraform apply` do?

<details>
<summary>Answer</summary>

`terraform apply` performs the changes Terraform proposed. It usually shows the plan and asks for confirmation. After it succeeds, Terraform updates state to match the resources it now manages.

You can also apply a saved file from `terraform plan -out=tfplan` with `terraform apply tfplan`. Plan says what Terraform will do. Apply does it.

</details>

---

## 41. Exit Check — Why `terraform plan -out=tfplan` is useful in a pipeline

8. Why is `terraform plan -out=tfplan` useful in a pipeline?

<details>
<summary>Answer</summary>

`terraform plan -out=tfplan` writes the reviewed plan to a file. The pipeline later runs `terraform apply tfplan` so Terraform applies that exact plan, not a newly calculated one.

Review and approval then sit between plan and apply. That is safer than apply immediately after a code change.

</details>

---

## 42. Exit Check — What is Terraform state?

9. What is Terraform state?

<details>
<summary>Answer</summary>

Terraform state is the record that connects configuration to real infrastructure. It stores which cloud object belongs to which resource address, plus attributes Terraform needs for the next plan.

For a local lab that file is often `terraform.tfstate`. State is not merely a backup. Terraform uses it to calculate future changes.

</details>

---

## 43. Exit Check — Why is local state difficult for a team?

10. Why is local state difficult for a team?

<details>
<summary>Answer</summary>

Local state lives on one laptop. Each engineer can hold a different copy. Plans then disagree, and two applies can conflict.

Teams use a remote backend with access control and locking so everyone shares one state. A laptop copy is fine for a personal lab, not for shared infrastructure.

</details>

---

## 44. Exit Check — What is drift?

11. What is drift?

<details>
<summary>Answer</summary>

Drift is when real infrastructure no longer matches what the configuration and state expect. A common case is a manual portal change after Terraform created the resource.

IaC does not block that manual change. It helps you detect and correct the difference on the next plan.

</details>

---

## 45. Exit Check — How `terraform plan` helps detect drift

12. How can `terraform plan` help detect drift?

<details>
<summary>Answer</summary>

During `terraform plan`, Terraform checks real infrastructure through the provider and compares it with configuration and state. A manual tag change then appears as an update in the plan.

Modern workflows detect remote changes while planning. You do not rely on a standalone `terraform refresh` as the main daily tool.

</details>

---

## 46. Exit Check — Bicep’s relationship with Azure Resource Manager

13. What is Bicep's relationship with Azure Resource Manager?

<details>
<summary>Answer</summary>

Bicep compiles to an ARM template. Azure Resource Manager then runs the deployment and manages Azure resources. The path is Bicep → ARM template → Azure Resource Manager → Azure resources.

That is different from Terraform’s provider model. Terraform talks to AWS through the AWS provider. Bicep does not use that same provider path on Azure.

</details>

---

## 47. Exit Check — Bicep equivalent of previewing changes

14. What is the Bicep equivalent of previewing changes?

<details>
<summary>Answer</summary>

The Bicep preview is `az deployment group what-if`. It plays the same operational role as `terraform plan`: inspect the change, then deploy.

`az bicep build` compiles the file. It is closer to validate than to plan. Deploy with `az deployment group create` only after you understand what-if.

</details>

---

## 48. Exit Check — Why Terraform and Bicep stay separate in this course

15. Why are Terraform and Bicep separate in this course?

<details>
<summary>Answer</summary>

This course uses Terraform for AWS and Bicep for Azure. Both implement IaC, but they use different engines: AWS provider versus Azure Resource Manager.

Keep the shared questions: what do I need, what will change, what could break. Change only the syntax and the cloud path. OpenTofu is a Terraform fork with the same HCL workflow, not a third mental model.

</details>

---

## 49. Exit Check — Application pipeline versus IaC pipeline

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

<details>
<summary>Answer</summary>

An application pipeline moves software: code, build, test, artifact, deploy. An IaC pipeline moves infrastructure: validate, plan or what-if, review, apply, infrastructure.

They can share Git. They solve different problems. AWS infrastructure uses a Terraform pipeline. Azure infrastructure uses a Bicep pipeline. Application code uses the application pipeline.

</details>
