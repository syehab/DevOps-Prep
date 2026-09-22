

# Day 9 · L09 · IaC Modules & Environments

> **The goal is simple:** write infrastructure once, reuse it, and change only what should be different between environments.

| | |
|---|---|
| ⏱️ Time | 80–100 min |
| 🎯 Level | Senior DevOps |
| ☁️ Cost | ₹0–low |
| 🧪 Lab | AWS + Azure |

Today we use the same IaC idea in two ways:

```text
AWS    → Terraform Modules
Azure  → Bicep Modules
```

---

## 01 · Why Do We Need Modules? · 6 min

Imagine you need the same basic application infrastructure in Dev, UAT and Prod. Copying the same Terraform or Bicep code three times works at first, but it becomes difficult to maintain because a change must be made in several places.

A **module** is a reusable piece of infrastructure code. You define the common design once and pass different values to it.

```text
Reusable Module
      ↓
 ┌────┼────┐
 ↓    ↓    ↓
DEV  UAT  PROD
```

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

---

# Terraform · AWS

## 02 · Terraform Module Structure · 7 min

A Terraform module is simply a directory containing Terraform files. The directory can contain resources, variables and outputs.

A simple project can look like:

```text
aws/
├── modules/
│   └── s3/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
│
└── environments/
    └── dev/
        └── main.tf
```

The `s3` directory is the reusable module. The environment calls that module and provides values.

### 🧪 Exercise

Create:

```text
aws/modules/s3/
aws/environments/dev/
```

Put the S3 resource inside the module.

Then ask:

> Which folder contains the reusable design, and which folder represents one environment?

---

## 03 · Terraform Module Inputs · 7 min

The module should not hard-code values that are expected to change. Instead, define variables inside the module.

```hcl
# modules/s3/variables.tf

variable "bucket_name" {
  type = string
}

variable "environment" {
  type = string
}
```

The resource uses those variables:

```hcl
# modules/s3/main.tf

resource "aws_s3_bucket" "app" {
  bucket = var.bucket_name

  tags = {
    Environment = var.environment
  }
}
```

The environment provides the values:

```hcl
module "app_bucket" {
  source = "../../modules/s3"

  bucket_name = "cloud-learning-dev"
  environment = "dev"
}
```

Think of it as:

```text
Environment
     ↓
Module input
     ↓
Resource
```

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

---

## 04 · Terraform Module Outputs · 5 min

A module can return useful information to the environment that called it.

```hcl
# modules/s3/outputs.tf

output "bucket_name" {
  value = aws_s3_bucket.app.bucket
}
```

The environment can use that value:

```hcl
output "app_bucket_name" {
  value = module.app_bucket.bucket_name
}
```

The flow is:

```text
Input
  ↓
Module
  ↓
Resource
  ↓
Output
```

### 🧪 Exercise

After deployment, run:

```bash
terraform output
```

Then explain:

> Why would another part of the infrastructure need a module's output?

For example, an application might need the name or endpoint of a resource created by the module.

---

## 05 · Same Module, Different Environments · 8 min

Now create:

```text
environments/
├── dev/
│   └── main.tf
├── uat/
│   └── main.tf
└── prod/
    └── main.tf
```

All three environments can call the same module.

Dev:

```hcl
module "app_bucket" {
  source = "../../modules/s3"

  bucket_name = "cloud-learning-dev"
  environment = "dev"
}
```

UAT can use:

```hcl
bucket_name = "cloud-learning-uat"
environment = "uat"
```

Prod can use:

```hcl
bucket_name = "cloud-learning-prod"
environment = "prod"
```

The module stays the same. Only environment-specific inputs change.

### 🧪 Exercise

Create the three environment directories.

Do **not** copy the S3 resource into each environment.

Instead, make all three call the same module.

Then change one common setting inside the module and run `plan` for Dev.

Ask:

> What would happen when UAT and Prod use that same module version?

---

## 06 · Common vs Environment-Specific Values · 7 min

Not every value should be different between environments. Some settings should normally be common, while others need to change based on the environment.

For example:

```text
Common:
Encryption
Required tags
Security rules
Resource structure

Different:
Environment name
Instance count
Instance size
CIDR values
Resource names
```

Variables allow these values to stay outside the reusable resource definition.

```hcl
variable "instance_count" {
  type = number
}
```

The environment can provide:

```hcl
instance_count = 1
```

while Prod can use:

```hcl
instance_count = 4
```

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

---

## 07 · Terraform `.tfvars` · 7 min

Instead of putting environment values directly into `main.tf`, you can keep them in a variable file.

Example:

```text
environments/
└── dev/
    ├── main.tf
    └── dev.tfvars
```

`main.tf`:

```hcl
variable "environment" {
  type = string
}

variable "bucket_name" {
  type = string
}

module "app_bucket" {
  source = "../../modules/s3"

  environment = var.environment
  bucket_name = var.bucket_name
}
```

`dev.tfvars`:

```hcl
environment = "dev"
bucket_name = "cloud-learning-dev"
```

Run:

```bash
terraform plan -var-file="dev.tfvars"
```

Now the same Terraform configuration can use another variable file:

```text
dev.tfvars
uat.tfvars
prod.tfvars
```

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

---

# Bicep · Azure

## 08 · Bicep Structure · 6 min

Bicep also supports reusable modules. A Bicep module is another `.bicep` file that can be called from a main Bicep file.

A useful structure is:

```text
azure/
├── modules/
│   └── storage.bicep
│
└── environments/
    ├── dev/
    │   ├── main.bicep
    │   └── dev.bicepparam
    ├── uat/
    │   ├── main.bicep
    │   └── uat.bicepparam
    └── prod/
        ├── main.bicep
        └── prod.bicepparam
```

Here:

- `storage.bicep` → reusable resource design
- `main.bicep` → environment deployment entry point
- `.bicepparam` → environment-specific values

### 🧪 Exercise

Create:

```text
azure/modules/storage.bicep
azure/environments/dev/main.bicep
azure/environments/dev/dev.bicepparam
```

Keep each file's responsibility separate.

---

## 09 · Bicep Module Code · 7 min

The reusable Storage Account module can contain:

```bicep
// modules/storage.bicep

param storageName string
param environment string

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageName
  location: resourceGroup().location

  sku: {
    name: 'Standard_LRS'
  }

  kind: 'StorageV2'

  tags: {
    Environment: environment
  }
}

output storageName string = storage.name
```

The module receives values instead of deciding the environment itself.

### 🧪 Exercise

Find these two parameters:

```bicep
param storageName string
param environment string
```

Now identify where each value should come from.

Ask:

> Should the reusable module know that it is being used for Dev, UAT or Prod?

The answer should normally be **no**. The caller supplies that information.

---

## 10 · Bicep `main.bicep` and Module Connection · 8 min

The environment's `main.bicep` calls the reusable module.

```bicep
// environments/dev/main.bicep

param storageName string
param environment string

module appStorage '../../modules/storage.bicep' = {
  name: 'dev-storage'
  params: {
    storageName: storageName
    environment: environment
  }
}
```

There are two important things here.

First:

```bicep
module appStorage '../../modules/storage.bicep'
```

means:

> Use the module located at this path.

Second:

```bicep
params: {
  storageName: storageName
  environment: environment
}
```

passes values from `main.bicep` into the module.

So the flow is:

```text
main.bicep
    │
    │ parameters
    ↓
storage.bicep
    │
    ↓
Azure Storage Account
```

### 🧪 Exercise

Change the value of `environment` in the main deployment input.

Do not edit `storage.bicep`.

Then answer:

> How did the module know which environment it was deploying to?

This is the Bicep equivalent of passing variables into a Terraform module.

---

## 11 · What Is a `.bicepparam` File? · 8 min

A `.bicepparam` file stores values for parameters defined by a Bicep deployment.

This is useful because the same `main.bicep` can be reused for Dev, UAT and Prod while each environment has its own values.

Example:

```text
main.bicep
dev.bicepparam
uat.bicepparam
prod.bicepparam
```

`main.bicep`:

```bicep
param storageName string
param environment string

module appStorage '../../modules/storage.bicep' = {
  name: '${environment}-storage'
  params: {
    storageName: storageName
    environment: environment
  }
}
```

`dev.bicepparam`:

```bicep
using './main.bicep'

param storageName = 'cloudlearningdev001'
param environment = 'dev'
```

`uat.bicepparam`:

```bicep
using './main.bicep'

param storageName = 'cloudlearninguat001'
param environment = 'uat'
```

The important relationship is:

```text
dev.bicepparam
       ↓
   main.bicep
       ↓
storage.bicep
       ↓
Azure Resource
```

The parameter file does **not** replace `main.bicep`. It supplies values to it.

### 🧪 Exercise

Read this:

```bicep
using './main.bicep'

param environment = 'dev'
```

Then answer:

> What does `using './main.bicep'` connect?

It tells the parameter file which Bicep file contains the parameter definitions that this parameter file will provide values for.

---

## 12 · Deploying with a `.bicepparam` File · 7 min

You can deploy the environment using its parameter file.

For example:

```bash
az deployment group create \
  --resource-group <resource-group> \
  --parameters ./dev.bicepparam
```

The `.bicepparam` file points to `main.bicep` using:

```bicep
using './main.bicep'
```

So Azure can follow the relationship:

```text
dev.bicepparam
      ↓
main.bicep
      ↓
module
      ↓
Azure resources
```

For UAT, you use:

```bash
az deployment group create \
  --resource-group <resource-group> \
  --parameters ./uat.bicepparam
```

The Bicep code remains the same; the environment values change.

### 🧪 Exercise

Create `dev.bicepparam` and `uat.bicepparam`.

Use the same `main.bicep`.

Deploy each one to a suitable lab resource group.

Then answer:

> Did you create two different Bicep templates?

No. You used **one deployment definition with different parameter values**.

---

## 13 · `.bicepparam` vs Terraform `.tfvars` · 6 min

The two files solve a very similar problem.

Terraform:

```text
main.tf
   +
dev.tfvars
   ↓
Terraform deployment
```

Bicep:

```text
main.bicep
   +
dev.bicepparam
   ↓
Azure deployment
```

The syntax is different, but the idea is the same:

> **Keep reusable infrastructure code separate from environment-specific values.**

A useful comparison is:

| Purpose | Terraform | Bicep |
|---|---|---|
| Resource code | `.tf` | `.bicep` |
| Environment values | `.tfvars` | `.bicepparam` |
| Reuse | Module | Module |
| Preview | `plan` | `what-if` |
| Deploy | `apply` | Azure deployment |

### 🧪 Exercise

Without looking back, complete:

```text
Terraform:
Code → ______ → Deployment

Bicep:
Code → ______ → Deployment
```

Then explain why separating values from code is useful.

---

## 14 · Bicep Parameters → Main → Module · 8 min

This is the complete Bicep chain you should understand.

### Parameter file

```bicep
using './main.bicep'

param environment = 'dev'
param storageName = 'cloudlearningdev001'
```

### Main file

```bicep
param environment string
param storageName string

module appStorage '../../modules/storage.bicep' = {
  name: '${environment}-storage'
  params: {
    environment: environment
    storageName: storageName
  }
}
```

### Module

```bicep
param environment string
param storageName string

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageName
  location: resourceGroup().location

  tags: {
    Environment: environment
  }
}
```

The complete flow is:

```text
dev.bicepparam
       │
       │ provides values
       ↓
main.bicep
       │
       │ passes values
       ↓
storage.bicep
       │
       ↓
Azure Storage Account
```

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

---

## 15 · Bicep Outputs · 5 min

A module can also return information to the calling file.

Inside the module:

```bicep
output storageName string = storage.name
```

The main file can reference the module output:

```bicep
output deployedStorageName string = appStorage.outputs.storageName
```

The flow becomes:

```text
Parameter
   ↓
Main
   ↓
Module
   ↓
Resource
   ↓
Module Output
   ↓
Main Output
```

### 🧪 Exercise

Add the output to your lab.

Then ask:

> Why might the main template need a module output?

For example, another resource or deployment process may need the resource name.

---

# Common IaC Design

## 16 · Module vs Environment · 6 min

This distinction is one of the most important ideas in this lesson.

A **module describes how something is built**. An **environment describes where and with which values it is deployed**.

Think:

```text
MODULE
"How should this application platform be built?"

ENVIRONMENT
"Build it for PROD with these values."
```

For example:

```text
AWS
Terraform Module → VPC design
Prod              → CIDR / sizing values

Azure
Bicep Module      → VNet design
Prod              → CIDR / sizing values
```

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

---

## 17 · One Design, Three Environments · 7 min

A common environment model is:

```text
                 Reusable Design
                       │
          ┌────────────┼────────────┐
          ↓            ↓            ↓
         DEV          UAT          PROD
          │            │            │
       smaller       medium       larger
       config        config       config
```

The environments often share the same architecture but use different capacity and values.

For example:

```text
DEV  → 1 application instance
UAT  → 2 application instances
PROD → 4 application instances
```

The module stays reusable while the environment controls the value.

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

---

## 18 · What Should NOT Become a Module? · 5 min

Not every small resource needs its own module. A module should represent a useful reusable unit, such as a network, application platform, database pattern or common security configuration.

Creating a module for every tiny resource can make the code harder to understand because engineers must jump through many directories to understand one deployment.

A simple rule is:

> **Create a module when it gives you reuse, consistency or a clear boundary.**

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

---

## 19 · Application Pipeline + IaC Pipeline · 6 min

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
Application Deployment
```

The IaC pipeline moves infrastructure changes:

```text
Terraform / Bicep Code
        ↓
Validate
        ↓
Plan / What-If
        ↓
Review
        ↓
Apply / Deploy
        ↓
Infrastructure
```

For your course:

```text
AWS Infrastructure  → Terraform
Azure Infrastructure → Bicep
Application          → Application Pipeline
```

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

---

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
2. How would you detect the change before Prod?
3. Why should the change go through Git review?
4. Why should Dev be tested before Prod?
5. What should the pipeline show before applying the change?

A simple flow is:

```text
Change module
     ↓
Review
     ↓
Plan / What-If
     ↓
DEV
     ↓
UAT
     ↓
PROD
```

The exact promotion model can differ, but the principle is **controlled infrastructure change**.

---

## 21 · Cost Check · 2 min

Modules and parameter files cost nothing.

The resources they create can cost money. Environment-specific values are useful for cost control because Dev and UAT can use smaller infrastructure than Prod.

```text
DEV  → small
UAT  → medium
PROD → production capacity
```

> **IaC makes infrastructure repeatable. Make sure expensive infrastructure is not accidentally repeated.**

---

## 22 · Cleanup · 3 min

### AWS

From the Terraform environment directory:

```bash
terraform destroy
```

### Azure

Remove the lab resource group:

```bash
az group delete \
  --name <resource-group> \
  --yes
```

Verify that the resources are gone.

---

## Part 7 — Migrating Existing Infrastructure Into Terraform

A common interview situation is: **“We already have cloud infrastructure. How would you bring it under Terraform?”** You normally do not destroy the existing infrastructure and recreate it just to start using Terraform. Instead, you identify the existing resource, write the Terraform resource configuration that should represent it, and import the existing resource into Terraform's state.

For example, if an EC2 instance already exists, you can define the corresponding resource:

```hcl
resource "aws_instance" "app" {
  # configuration describing the intended resource
}
```

Then import the existing cloud resource into that Terraform address:

```bash
terraform import aws_instance.app <existing-instance-id>
```

Import connects the real resource to Terraform's state. It does **not** magically create perfect Terraform code for every setting. After importing, run:

```bash
terraform plan
```

and use the result to bring the configuration into alignment with the real resource.

The safe mental model is:

```text
Existing Cloud Resource
        ↓
Write Terraform Resource
        ↓
terraform import
        ↓
Terraform State
        ↓
terraform plan
        ↓
Reconcile Configuration
```

Practice with a small non-production resource. Import it, run `terraform plan`, identify differences, then update the configuration until the plan is clean.

---

## Part 8 — Sharing Modules With Other Teams

A module becomes especially useful when several teams need the same infrastructure pattern. Instead of copying a directory between repositories, a team can publish a reusable module in a shared Git repository or an appropriate module registry. Consumers then reference the module using a source and, for versioned modules, a specific version.

For example:

```hcl
module "network" {
  source  = "git::https://example.com/platform/network.git"
  version = "..."
}
```

The exact source and version syntax depends on how the organization publishes its modules. The important idea is that the consuming team should use a **versioned contract** rather than silently depending on whatever code happens to be on a moving branch.

A platform team might publish:

```text
network module
database module
application-platform module
logging module
security-baseline module
```

An application team then consumes those modules and supplies environment-specific values.

This creates an important Lead DevOps responsibility: module ownership must be clear. Someone must maintain the module, document its inputs and outputs, test changes, publish versions, communicate breaking changes, and decide how consumers upgrade.

Practice by designing a shared `network` module contract. Decide which values should be inputs, which values should be outputs, which settings should be fixed by the platform team, and how Dev/UAT/Prod consumers should receive different values.

---

## Part 9 — Module Versioning and Safe Change

A shared module can affect many teams at once. Suppose 30 applications consume version `v2.0` of a network module. You release `v3.0` with a breaking change. If every team automatically receives the new code, one module change could affect many environments.

A safer model is:

```text
Module v2.0
    ↓
Teams use v2.0

Module v3.0
    ↓
Teams test
    ↓
Teams upgrade deliberately
```

This is why reusable IaC is not only about code reuse. It is also about **versioning, contracts and controlled change**.

Practice by imagining that your module changes a security rule. Explain how you would test the change in Dev, promote it to UAT, communicate the change, and then allow Production consumers to upgrade.

---

### Interview Recall

You should now be able to explain:

1. How would you migrate an existing AWS server into Terraform?
2. What does `terraform import` actually change?
3. Why does import not mean the Terraform code is automatically complete?
4. Why should you run `terraform plan` after importing?
5. How can a Terraform module be shared with another team?
6. Why should shared modules be versioned?
7. What happens if 30 teams consume the same module and you make a breaking change?
8. Who should own and maintain a shared platform module?
9. What belongs inside a reusable module versus environment-specific configuration?

---

## 23 · Exit Check · 8 min

Answer without looking:

1. What is a module?
2. Why do we use modules?
3. What belongs inside a module?
4. What belongs at the environment level?
5. How does Terraform pass values into a module?
6. What is `.tfvars` used for?
7. How does Bicep call another Bicep file as a module?
8. What is a `.bicepparam` file?
9. What does `using './main.bicep'` mean?
10. How does a `.bicepparam` value reach a Bicep module?
11. What is the difference between `.tfvars` and `.bicepparam`?
12. Why should Dev, UAT and Prod not need three copies of the same resource code?
13. Why should not every tiny resource become a module?
14. What is the difference between an application pipeline and an IaC pipeline?

### 🎯 Exit Criteria

You should be able to explain this without looking:

```text
                    IaC
                     │
          ┌──────────┴──────────┐
          ↓                     ↓
         AWS                   Azure
          ↓                     ↓
     Terraform                 Bicep
          ↓                     ↓
      Module                  Module
          ↑                     ↑
     tfvars                 bicepparam
          │                     │
       DEV/UAT/PROD          DEV/UAT/PROD
```

And especially this Bicep flow:

```text
dev.bicepparam
       ↓
main.bicep
       ↓
module
       ↓
Azure Resource
```

> **Takeaway:** The reusable code defines **how** infrastructure is built. Parameter files define **which values** to use for a particular environment.

---

### Next · Day 10 · L10

**Terraform State & Enterprise Workflow**

We will go deeper into:

```text
Local State
    ↓
Remote State
    ↓
State Locking
    ↓
Teams
    ↓
CI/CD
    ↓
Plan → Approval → Apply
```

For Azure, we will continue the Bicep path with:

```text
Bicep
  ↓
Parameters
  ↓
Modules
  ↓
What-If
  ↓
Deployment
  ↓
Azure Resource Management
```

The goal is to make both workflows feel familiar without pretending Terraform and Bicep work exactly the same way.
