# Day 9 — IaC Modules & Environments

This Day uses three files. Read them in this order.

1. [01-concepts.md](01-concepts.md) — lesson content (this file)
2. [02-questions-and-answers.md](02-questions-and-answers.md) — practice items, each with a model answer
3. [03-implementation.md](03-implementation.md) — hands-on lab

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

Imagine you need the same basic application infrastructure in Dev, UAT and Prod. To copy the same Terraform or Bicep code three times works at first. It then becomes difficult to maintain, because you must make each change in several places.

A **module** is a reusable piece of infrastructure code. You define the common design once and pass different values to it.

```text
Reusable Module
      ↓
 ┌────┼────┐
 ↓    ↓    ↓
DEV  UAT  PROD
```

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

---

## 03 · Terraform Module Inputs · 7 min

The module should not hard-code values that you expect to change. Instead, define variables inside the module.

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

---

# Bicep · Azure

## 08 · Bicep Structure · 6 min

Bicep also supports reusable modules. A Bicep module is another `.bicep` file that a main Bicep file can call.

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

---

## 11 · What Is a `.bicepparam` File? · 8 min

A `.bicepparam` file stores values for parameters defined by a Bicep deployment.

This is useful because you can reuse the same `main.bicep` for Dev, UAT and Prod while each environment has its own values.

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

---

# Common IaC Design

## 16 · Module vs Environment · 6 min

This distinction is one of the most important ideas in this lesson.

A **module describes how to build something**. An **environment describes where you deploy it and with which values**.

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

---

## 18 · What Should NOT Become a Module? · 5 min

Not every small resource needs its own module. A module should represent a useful reusable unit, such as a network, application platform, database pattern or common security configuration.

Creating a module for every tiny resource can make the code harder to understand because engineers must jump through many directories to understand one deployment.

A simple rule is:

> **Create a module when it gives you reuse, consistency or a clear boundary.**

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

> **IaC makes infrastructure repeatable. Make sure you do not accidentally repeat expensive infrastructure.**

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

## 23 · Exit Check · 8 min

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

> **Takeaway:** The reusable code defines **how** to build the infrastructure. Parameter files define **which values** to use for a particular environment.

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

