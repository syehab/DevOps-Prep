# Day 9 — Questions and answers

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Then answer each item below before you open the Answer block. After that, do the lab in [03-implementation.md](03-implementation.md).

Write your own answer first. Open the Answer block only after you try. Keep the original numbering.

---

## 1. One common value, one environment-specific value, and why copies are hard

## 01 · Why Do We Need Modules? · 6 min

### 🧪 Exercise

Imagine every environment needs:

```text
Storage
Encryption
Tags
Naming
```

Write down:

- one thing that should be common
- one thing that should change between environments

Then ask:

> Why is copying the whole resource three times harder to maintain?

<details>
<summary>Answer</summary>

Encryption should normally stay common, because every environment needs the same protective default. Environment name, bucket name, or size should change, because Dev is not Prod.

Copying the whole resource three times is harder to maintain, because each fix must land in DEV, UAT, and Prod by hand. One copy will lag. A module defines the design once and takes different values.

</details>

---

## 2. Which folder is the reusable design, and which folder is one environment

## 02 · Terraform Module Structure · 7 min

### 🧪 Exercise

Create:

```text
aws/modules/s3/
aws/environments/dev/
```

Put the S3 resource inside the module.

Then ask:

> Which folder contains the reusable design, and which folder represents one environment?

<details>
<summary>Answer</summary>

Create `aws/modules/s3/` and `aws/environments/dev/`. Put the S3 resource inside the module. `aws/modules/s3/` holds the reusable design: `main.tf`, `variables.tf`, and `outputs.tf`.

`aws/environments/dev/` represents one environment. Its `main.tf` calls the module and supplies Dev values. Do not copy the S3 resource into the environment folder.

</details>

---

## 3. Did the infrastructure design change, or only the input?

# modules/s3/main.tf

### 🧪 Exercise

Change:

```hcl
environment = "dev"
```

to:

```hcl
environment = "uat"
```

without changing the module.

Answer:

> Did the infrastructure design change, or did only the input change?

<details>
<summary>Answer</summary>

Only the input changed. You switched `environment = "dev"` to `environment = "uat"` in the caller. You did not edit `modules/s3`.

The module still creates the same kind of bucket with tags. The tag value and any name built from the variable now say UAT. Design stays in the module. Values stay at the environment.

</details>

---

## 4. Why another part of the infrastructure needs a module output

# modules/s3/outputs.tf

### 🧪 Exercise

After deployment, run:

```bash
terraform output
```

Then explain:

> Why would another part of the infrastructure need a module's output?

For example, an application might need the name or endpoint of a resource created by the module.

<details>
<summary>Answer</summary>

After apply, run `terraform output` from the environment directory. You should see values the environment exposed from the module, such as the bucket name.

Another resource may need that name or endpoint. An application, IAM policy, or second module can consume `module.app_bucket.bucket_name` instead of guessing. Outputs are how a module returns facts without exposing every internal resource.

</details>

---

## 5. Same module in Dev, UAT, and Prod after a common module change

## 05 · Same Module, Different Environments · 8 min

### 🧪 Exercise

Create the three environment directories.

Do **not** copy the S3 resource into each environment.

Instead, make all three call the same module.

Then change one common setting inside the module and run `plan` for Dev.

Ask:

> What would happen when UAT and Prod use that same module version?

<details>
<summary>Answer</summary>

Create `environments/dev`, `environments/uat`, and `environments/prod`. Each `main.tf` should call `../../modules/s3` with different `bucket_name` and `environment` values. Do not copy the S3 resource into each environment.

Change one common setting inside the module and run `terraform plan` in Dev. Dev should show that change. When UAT and Prod later use that same module version, they pick up the same design change with their own inputs. Review and promote. Do not skip Dev.

</details>

---

## 6. Which values should normally be environment-specific

## 06 · Common vs Environment-Specific Values · 7 min

### 🧪 Exercise

Take these values:

```text
region
environment
instance_count
encryption
instance_size
```

Decide which should normally be environment-specific.

There can be valid exceptions. Explain **why** you made each choice.

<details>
<summary>Answer</summary>

`environment`, `instance_count`, and `instance_size` should normally be environment-specific. Dev can use one small instance. Prod can use more, larger instances. `region` is often environment-specific too, if each environment lives in a chosen region, but some teams pin one region for simplicity.

`encryption` should normally stay common, because turning it off in Dev teaches a bad Prod path. Exceptions exist: a sandbox might skip a costly control on purpose. Write that exception in code and review it. Do not hide it as a quiet copy.

</details>

---

## 7. Compare `plan` with `dev.tfvars` and `uat.tfvars`

## 07 · Terraform `.tfvars` · 7 min

### 🧪 Exercise

Create:

```text
dev.tfvars
uat.tfvars
```

Keep the module unchanged.

Run:

```bash
terraform plan -var-file="dev.tfvars"
```

Then:

```bash
terraform plan -var-file="uat.tfvars"
```

Compare the plans.

**Key idea:** the Terraform code can stay the same while the input values change.

<details>
<summary>Answer</summary>

Create `dev.tfvars` and `uat.tfvars`. Keep the module unchanged. Run `terraform plan -var-file="dev.tfvars"`, then `terraform plan -var-file="uat.tfvars"`.

The plans should propose the same resource design with different names, tags, or sizes. The Terraform code stays the same. Only the variable file changes. That is the point of `.tfvars`.

</details>

---

## 8. Keep Bicep file responsibilities separate

## 08 · Bicep Structure · 6 min

### 🧪 Exercise

Create:

```text
azure/modules/storage.bicep
azure/environments/dev/main.bicep
azure/environments/dev/dev.bicepparam
```

Keep each file's responsibility separate.

<details>
<summary>Answer</summary>

Create `azure/modules/storage.bicep`, `azure/environments/dev/main.bicep`, and `azure/environments/dev/dev.bicepparam`. Put the Storage Account resource in `storage.bicep`. Put the module call in `main.bicep`. Put Dev values in `dev.bicepparam`.

`storage.bicep` is reusable design. `main.bicep` is the environment entry point. `.bicepparam` is environment values only. Do not mix those jobs into one file.

</details>

---

## 9. Where Bicep module parameters come from, and whether the module knows the environment

## 09 · Bicep Module Code · 7 min

### 🧪 Exercise

Find these two parameters:

```bicep
param storageName string
param environment string
```

Now identify where each value should come from.

Ask:

> Should the reusable module know whether it builds Dev, UAT or Prod?

The answer should normally be **no**. The caller supplies that information.

<details>
<summary>Answer</summary>

`param storageName` and `param environment` should come from the caller, not from inside the module. The environment’s `main.bicep` and `.bicepparam` file supply those values.

The reusable module should not know whether it builds Dev, UAT, or Prod. If it hard-codes `dev`, you cannot reuse it. The caller supplies that information.

</details>

---

## 10. How the Bicep module knew which environment it was deploying to

## 10 · Bicep `main.bicep` and Module Connection · 8 min

### 🧪 Exercise

Change the value of `environment` in the main deployment input.

Do not edit `storage.bicep`.

Then answer:

> How did the module know which environment it was deploying to?

This is the Bicep equivalent of passing variables into a Terraform module.

<details>
<summary>Answer</summary>

Change `environment` in the main deployment input. Do not edit `storage.bicep`. The module knew the environment because `main.bicep` passed `environment: environment` into the module `params`.

That is the Bicep equivalent of Terraform module variables. The module only reads parameters. The environment file chooses the value.

</details>

---

## 11. What `using './main.bicep'` connects

## 11 · What Is a `.bicepparam` File? · 8 min

### 🧪 Exercise

Read this:

```bicep
using './main.bicep'

param environment = 'dev'
```

Then answer:

> What does `using './main.bicep'` connect?

It tells the parameter file which Bicep file contains the parameter definitions that this parameter file will provide values for.

<details>
<summary>Answer</summary>

`using './main.bicep'` connects the parameter file to the Bicep file that defines the parameters. The `.bicepparam` file then supplies values for those parameters.

It does not replace `main.bicep`. It does not call the module by itself. Azure follows `.bicepparam` → `main.bicep` → module → Azure resource.

</details>

---

## 12. Did two `.bicepparam` files mean two different Bicep templates?

## 12 · Deploying with a `.bicepparam` File · 7 min

### 🧪 Exercise

Create `dev.bicepparam` and `uat.bicepparam`.

Use the same `main.bicep`.

Deploy each one to a suitable lab resource group.

Then answer:

> Did you create two different Bicep templates?

No. You used **one deployment definition with different parameter values**.

<details>
<summary>Answer</summary>

No. Create `dev.bicepparam` and `uat.bicepparam` against the same `main.bicep`. Deploy each with `az deployment group create --resource-group <resource-group> --parameters ./dev.bicepparam` (and the UAT file for UAT).

You used one deployment definition with different parameter values. The Bicep code stays the same. Only names and environment tags change.

</details>

---

## 13. Fill Terraform and Bicep value files, and why you separate values from code

## 13 · `.bicepparam` vs Terraform `.tfvars` · 6 min

### 🧪 Exercise

Without looking back, complete:

```text
Terraform:
Code → ______ → Deployment

Bicep:
Code → ______ → Deployment
```

Then explain why separating values from code is useful.

<details>
<summary>Answer</summary>

Terraform: Code → `.tfvars` → Deployment. Bicep: Code → `.bicepparam` → Deployment. Both keep reusable infrastructure code separate from environment-specific values.

Separating values lets Dev, UAT, and Prod share one module. You review a size or name change without copying the resource. Syntax differs. The idea is the same.

</details>

---

## 14. Trace `environment = "dev"` through the three Bicep files

## 14 · Bicep Parameters → Main → Module · 8 min

### 🧪 Exercise

Trace this value:

```text
environment = "dev"
```

through all three files.

Find:

1. Where is the value created?
2. Where is it received?
3. Where is it passed to the module?
4. Where is it finally used?

If you can trace this without confusion, you understand the basic Bicep parameter flow.

<details>
<summary>Answer</summary>

1. The value is created in `dev.bicepparam` as `param environment = 'dev'`.
2. `main.bicep` receives it as `param environment string`.
3. `main.bicep` passes it into the module with `params: { environment: environment }`.
4. `storage.bicep` uses it on the resource, such as `tags: { Environment: environment }`.

If you can follow that chain, you understand the Bicep parameter flow.

</details>

---

## 15. Why the main Bicep template might need a module output

## 15 · Bicep Outputs · 5 min

### 🧪 Exercise

Add the output to your lab.

Then ask:

> Why might the main template need a module output?

For example, another resource or deployment process may need the resource name.

<details>
<summary>Answer</summary>

Add `output storageName string = storage.name` in the module. In `main.bicep`, expose it with `output deployedStorageName string = appStorage.outputs.storageName`.

The main template needs that output when another resource or process must use the Storage Account name. The caller should not guess internal names. The module returns the fact it created.

</details>

---

## 16. Module versus environment for a network

## 16 · Module vs Environment · 6 min

### 🧪 Exercise

Take a network.

Write:

```text
Module:
?

Environment:
?
```

Try to place:

- subnet structure
- CIDR
- naming
- tags
- region
- security rules

Then explain your reasoning.

<details>
<summary>Answer</summary>

Module: how to build the network. Place subnet structure and security rules here, because they are the design. Environment: where and with which values. Place CIDR, naming, tags, and region here, because they differ per DEV, UAT, and Prod.

A module can still require encryption or a private database subnet as a common rule. The environment then fills `10.0.0.0/16` versus a larger Prod CIDR. Do not put Prod CIDR inside the reusable module.

</details>

---

## 17. One design, three instance counts, with `.tfvars` and `.bicepparam`

## 17 · One Design, Three Environments · 7 min

### 🧪 Exercise

Create these values:

```text
DEV
instances = 1

UAT
instances = 2

PROD
instances = 4
```

Implement this using:

```text
Terraform → tfvars
Bicep     → bicepparam
```

Keep the resource/module code unchanged.

<details>
<summary>Answer</summary>

Keep the module or resource code unchanged. Put `instances = 1` in Dev `.tfvars`, `instances = 2` in UAT, and `instances = 4` in Prod. Run `terraform plan -var-file` for each file.

For Bicep, put the same counts in `dev.bicepparam`, `uat.bicepparam`, and `prod.bicepparam`. Deploy with `--parameters` pointing at each file. Architecture stays shared. Capacity changes with the environment.

</details>

---

## 18. What should probably become a module, and what should not

## 18 · What Should NOT Become a Module? · 5 min

### 🧪 Exercise

Decide whether each should probably be a reusable module:

```text
Application platform
Network
Database platform
Single S3 bucket
One security rule
Reusable monitoring setup
```

There is no universal answer. Explain why you would create or avoid each module.

<details>
<summary>Answer</summary>

An application platform, a network, a database platform, and a reusable monitoring setup are good modules. Each is a useful unit with a clear boundary and reuse across environments.

A single S3 bucket can be a teaching module, but in a large repo it may live with nearby app resources. One security rule is usually too small. Create a module when it gives reuse, consistency, or a clear boundary. Do not wrap every tiny resource.

</details>

---

## 19. Classify each change as application pipeline or IaC pipeline

## 19 · Application Pipeline + IaC Pipeline · 6 min

### 🧪 Exercise

Classify these:

```text
Fix Java code
Add AWS subnet
Increase Azure VM size
Deploy new container image
Change Azure NSG rule
Change application configuration
```

For each one, decide:

```text
Application Pipeline
        or
IaC Pipeline
```

Then explain your choice.

<details>
<summary>Answer</summary>

Fix Java code and deploy a new container image belong to the application pipeline. They change software. Add an AWS subnet, increase Azure VM size, and change an Azure NSG rule belong to the IaC pipeline. They change the platform.

Change application configuration with the application pipeline when the app owns that config. If the setting is infrastructure (instance size, network rule), use the IaC pipeline. Ask: software, or the platform that runs it?

</details>

---

## 20. Break & Reason — Which environments could a module security change affect?

## 20 · Break & Reason · 7 min

### Scenario

You have one Terraform module used by:

```text
DEV
UAT
PROD
```

Someone changes the module and accidentally removes an important security setting.

### 🧪 Exercise

Answer:

1. Which environments could be affected?

<details>
<summary>Answer</summary>

DEV, UAT, and Prod could all be affected, because they call the same module. A removed security setting in the module is a design change, not an environment-only value change.

The blast reaches every environment that uses that module version. That is why a shared module needs review before anyone applies it widely.

</details>

---

## 21. Break & Reason — How to detect the module change before Prod

2. How would you detect the change before Prod?

<details>
<summary>Answer</summary>

Detect it in Git review, then in `terraform plan` or Bicep `what-if` against Dev. The plan should show the missing security setting as a destroy or update.

Apply in DEV first, then UAT, then Prod. If Dev plan already looks wrong, stop. Do not promote that module version.

</details>

---

## 22. Break & Reason — Why the change should go through Git review

3. Why should the change go through Git review?

<details>
<summary>Answer</summary>

Git review shows the module diff before any environment changes. Another engineer can see that a security setting disappeared. Portal clicks and laptop applies hide that.

Review does not replace plan. It catches the code mistake early, while the change is still a file.

</details>

---

## 23. Break & Reason — Why test Dev before Prod

4. Why should Dev be tested before Prod?

<details>
<summary>Answer</summary>

Dev is the low-risk copy of the same design. If the module breaks encryption or a rule, you want that failure in Dev, not in Prod.

Promote along DEV → UAT → Prod after plan and tests look right. Shared modules make this order mandatory, because one merge can otherwise hit Prod immediately.

</details>

---

## 24. Break & Reason — What the pipeline should show before apply

5. What should the pipeline show before applying the change?

<details>
<summary>Answer</summary>

The pipeline should show validate results and a `terraform plan` or `what-if` for the target environment. Reviewers must see creates, updates, and destroys, especially a removed security setting.

Then require approval before apply. The flow is: change module, review, plan or what-if, DEV, UAT, Prod. Controlled change beats a direct Prod apply.

</details>

---

## 25. Exit Check — What is a module?

## 23 · Exit Check · 8 min

Answer without looking:

1. What is a module?

<details>
<summary>Answer</summary>

A module is a reusable piece of infrastructure code. In Terraform it is a directory of `.tf` files. In Bicep it is another `.bicep` file that `main.bicep` can call.

You define the common design once. Environments pass different values. A module answers how to build something, not which environment it is.

</details>

---

## 26. Exit Check — Why do we use modules?

2. Why do we use modules?

<details>
<summary>Answer</summary>

We use modules so we write the design once and reuse it in DEV, UAT, and Prod. Copies drift. Modules keep encryption, structure, and naming rules consistent.

A change to the shared design then lands through one reviewed module version, with environment values still separate.

</details>

---

## 27. Exit Check — What belongs inside a module?

3. What belongs inside a module?

<details>
<summary>Answer</summary>

The reusable resource design belongs in the module: resources, required structure, common security, and variables for anything that must change. Outputs belong there too, so callers can read results.

Do not hard-code Dev names or Prod sizes inside the module. Those values belong at the environment.

</details>

---

## 28. Exit Check — What belongs at the environment level?

4. What belongs at the environment level?

<details>
<summary>Answer</summary>

The environment describes where you deploy and with which values. Put environment name, resource names, CIDR, instance count, and size in `.tfvars` or `.bicepparam`, and in the environment `main` file that calls the module.

The environment should not copy the whole resource definition. It should call the module.

</details>

---

## 29. Exit Check — How Terraform passes values into a module

5. How does Terraform pass values into a module?

<details>
<summary>Answer</summary>

The environment `module` block sets arguments that match the module variables. Example: `environment = var.environment` and `bucket_name = var.bucket_name`, with `source = "../../modules/s3"`.

Those values can come from `.tfvars` through root variables. Flow: environment → module input → resource.

</details>

---

## 30. Exit Check — What is `.tfvars` used for?

6. What is `.tfvars` used for?

<details>
<summary>Answer</summary>

A `.tfvars` file stores environment values for Terraform variables. `dev.tfvars` can set `environment` and `bucket_name` while `main.tf` stays the same.

Run `terraform plan -var-file="dev.tfvars"`. Switch to `uat.tfvars` for UAT. Code stays reusable. Values change.

</details>

---

## 31. Exit Check — How Bicep calls another Bicep file as a module

7. How does Bicep call another Bicep file as a module?

<details>
<summary>Answer</summary>

`main.bicep` declares `module appStorage '../../modules/storage.bicep'` and passes `params`. That path is the reusable file. The `params` object is the input.

The module file then creates the Azure resource. The caller does not paste the Storage Account resource into every environment.

</details>

---

## 32. Exit Check — What is a `.bicepparam` file?

8. What is a `.bicepparam` file?

<details>
<summary>Answer</summary>

A `.bicepparam` file stores values for parameters that a Bicep deployment defines. `dev.bicepparam` and `uat.bicepparam` can share one `main.bicep`.

The parameter file does not replace `main.bicep`. It supplies values. Deploy with `az deployment group create --parameters ./dev.bicepparam`.

</details>

---

## 33. Exit Check — What does `using './main.bicep'` mean?

9. What does `using './main.bicep'` mean?

<details>
<summary>Answer</summary>

It tells the parameter file which Bicep file defines the parameters. Azure then knows that `param environment` in the `.bicepparam` file fills `param environment` in `main.bicep`.

Without `using`, the parameter file is not connected to that template. It is the link, not the resource code.

</details>

---

## 34. Exit Check — How a `.bicepparam` value reaches a Bicep module

10. How does a `.bicepparam` value reach a Bicep module?

<details>
<summary>Answer</summary>

The value starts in the `.bicepparam` file. `main.bicep` receives it as a parameter. `main.bicep` then passes it through `params` into `storage.bicep`. The module uses it on the resource.

Chain: `dev.bicepparam` → `main.bicep` → module → Azure resource.

</details>

---

## 35. Exit Check — Difference between `.tfvars` and `.bicepparam`

11. What is the difference between `.tfvars` and `.bicepparam`?

<details>
<summary>Answer</summary>

They solve the same problem on different tools. Terraform uses `.tfvars` with `.tf` code. Bicep uses `.bicepparam` with `.bicep` code. Both hold environment values, not the reusable resource design.

Preview and deploy names differ (`plan`/`apply` versus `what-if`/Azure deployment). The split of code versus values is the same idea.

</details>

---

## 36. Exit Check — Why Dev, UAT, and Prod should not copy the same resource code three times

12. Why should Dev, UAT and Prod not need three copies of the same resource code?

<details>
<summary>Answer</summary>

Three copies mean three places to fix a security rule or a resource structure. The copies will drift. Review becomes harder, because you cannot see one design.

One module plus three value files keeps architecture shared and lets capacity and names differ. Change the design once. Change values per environment.

</details>

---

## 37. Exit Check — Why not every tiny resource should become a module

13. Why should not every tiny resource become a module?

<details>
<summary>Answer</summary>

A module should be a useful reusable unit. A module per tiny resource forces engineers through many directories to understand one deployment.

Create a module for reuse, consistency, or a clear boundary, such as a network or application platform. Skip a module for one security rule unless that rule is a real shared pattern.

</details>

---

## 38. Exit Check — Application pipeline versus IaC pipeline

14. What is the difference between an application pipeline and an IaC pipeline?

<details>
<summary>Answer</summary>

The application pipeline builds and deploys software: code, build, test, artifact, application deployment. The IaC pipeline changes infrastructure: Terraform or Bicep validate, plan or what-if, review, apply or deploy.

In this course, AWS infrastructure uses Terraform, Azure infrastructure uses Bicep, and the application uses the application pipeline. Classify by whether you change the software or the platform.

</details>
