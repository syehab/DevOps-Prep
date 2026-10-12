# Day 22 — Azure Overlay 01: Azure Platform Architecture

This Day uses three files. Read them in this order.

1. [01-concepts.md](01-concepts.md) — lesson content (this file)
2. [02-questions-and-answers.md](02-questions-and-answers.md) — practice items, each with a model answer
3. [03-implementation.md](03-implementation.md) — hands-on lab

**Goal of today:** learn where everything in Azure lives — the boundary hierarchy from tenant down to resource — and who controls each layer, before studying any individual service.

## Part 1 — Why an Azure Overlay Exists

The first 21 days focused on concepts that apply across cloud providers: networking, identity, infrastructure as code, CI/CD, containers, Kubernetes, security, observability, reliability, and cost. Now the goal is to map those concepts deeply onto Azure without relearning the fundamentals. Think of Azure as a concrete implementation of the architecture patterns you already understand: a VNet provides cloud networking, Azure RBAC provides authorization, subscriptions provide an important governance and billing boundary, and services such as AKS provide managed compute capabilities.

The Azure mental model for this overlay is:

```text
Microsoft Entra Tenant
        ↓
Management Groups
        ↓
Subscriptions
        ↓
Resource Groups
        ↓
Azure Resources
```

Around this hierarchy sit:

```text
Identity
Policy
Networking
Security
Monitoring
Cost Management
Automation
```

The objective is not to memorize every Azure service. It is to understand **where a service belongs, what boundary it operates within, who controls it, how it connects to other services, and what happens when it fails**.

**Remember:** Azure architecture is easier when you first understand the boundary and responsibility of each layer.

---

## Part 2 — Microsoft Entra ID, Tenant and Azure Resource Management

Microsoft Entra ID is Azure's cloud identity and access-management system. It contains identities such as users, groups, applications, and service principals (a service principal is the identity a piece of software uses — like a user account, but for an application or automation instead of a person). It provides authentication and identity-related capabilities for Azure and other applications. The **tenant** is the identity boundary associated with an Entra directory; it is not the same thing as a subscription. A subscription is an Azure resource-management and billing boundary that trusts identities from the tenant.

A simplified relationship is:

```text
Entra Tenant
     │
     ├── Users
     ├── Groups
     ├── Applications
     └── Service Principals
             │
             ↓
        Azure RBAC
             │
             ↓
       Azure Resources
```

One tenant can be associated with multiple Azure subscriptions. Therefore:

```text
Tenant ≠ Subscription
```

This distinction is extremely important in interviews.

For example, a company could have:

```text
One Entra Tenant
      ↓
Management Group
      ↓
Dev Subscription
UAT Subscription
Prod Subscription
Shared Services Subscription
```

The identity directory remains the common identity authority while subscriptions provide resource/governance boundaries.

---

## Part 3 — Management Groups: Governance Above Subscriptions

Management groups provide a hierarchy above subscriptions so that you can apply governance consistently across groups of subscriptions. They are useful for large organizations where applying every policy individually to hundreds of subscriptions would be difficult.

A conceptual structure is:

```text
Root Management Group
        │
        ├── Platform
        │     ├── Shared Services Subscription
        │     └── Network Subscription
        │
        ├── Production
        │     └── Production Subscription
        │
        └── NonProduction
              ├── Dev Subscription
              └── UAT Subscription
```

The exact hierarchy should reflect organizational ownership and governance rather than arbitrary folder-like organization.

Management groups are particularly useful for:

- Azure Policy assignment.
- Azure RBAC inheritance.
- Governance standards.
- Regulatory boundaries.
- Environment or business-unit organization.

For example, you could assign a policy that requires specific regions at management-group scope, and the subscriptions underneath inherit it.

The important hierarchy is:

```text
Management Group
      ↓
Subscription
      ↓
Resource Group
      ↓
Resource
```

**Remember:** Management groups organize and govern subscriptions; they do not contain application resources directly.

---

## Part 4 — Subscriptions: Resource, Billing and Isolation Boundary

An Azure subscription is a major boundary for resource management, billing, quotas, access control, and operational isolation. Resources belong to subscriptions, and resource groups exist inside subscriptions. Multiple subscriptions can exist under the same Entra tenant and management-group hierarchy.

A useful mental model is:

```text
Tenant
  ↓
Management Group
  ↓
Subscription
  ├── Resource Group A
  │      ├── VM
  │      └── Storage
  │
  └── Resource Group B
         ├── AKS
         └── Key Vault
```

Subscriptions are often separated when an organization needs stronger boundaries around:

```text
Production vs non-production
Business units
Clients
Billing
Quotas
Security
Blast radius
Ownership
```

Blast radius means: when something goes wrong inside a boundary — a bad deployment, a deleted resource, a leaked credential — how much can it damage? A smaller boundary limits the damage.

Do not make “one subscription per environment” a universal rule. It is a design choice. A Senior/Lead engineer should be able to explain why the chosen subscription boundary is useful.

---

## Part 5 — Resource Groups: Lifecycle and Ownership Boundary

A resource group is a logical container for Azure resources within a subscription. It is commonly used to group resources that share a lifecycle, ownership model, or operational purpose. Resource groups are also an important scope for Azure RBAC and policy.

For example:

```text
rg-shopsphere-prod-api
    ├── AKS-related resources
    ├── Supporting resources
    └── Monitoring integration

rg-shopsphere-prod-data
    ├── PostgreSQL
    └── Data-related resources
```

A resource group is not the same as a subnet, VNet, region, or availability zone. It is an Azure resource-management boundary.

A critical operational property: when you delete a resource group, you can delete the resources it contains. Therefore resource-group design affects blast radius.

Ask:

```text
Who owns these resources?
Do they have the same lifecycle?
Would they be deleted together?
Do they require the same permissions?
Do they have similar governance requirements?
```

---

## Part 6 — Azure Resource IDs and Scope

Azure resources have globally meaningful resource IDs within Azure's resource-management model. A resource ID identifies the hierarchy in which the resource exists.

Conceptually:

```text
/subscriptions/<subscription-id>
  /resourceGroups/<resource-group>
    /providers/<provider>
      /<resource-type>/<resource-name>
```

For example, an RBAC assignment can be scoped at different levels:

```text
Management Group
Subscription
Resource Group
Individual Resource
```

This is why Azure RBAC is described as **scope-based authorization**.

A role assigned at subscription scope can affect many resources underneath that scope. A role assigned to one resource has a much smaller blast radius.

Do not automatically choose the smallest scope without considering the actual operational requirement, but always understand the consequences of broader scope.

---

## Part 7 — Azure Regions, Availability Zones and Resource Scope

An Azure **region** is a geographic area containing Azure infrastructure. Some Azure regions provide availability zones, which are physically separate locations within the region designed to reduce the impact of certain infrastructure failures. Not every Azure service or region has identical zone capabilities, so architecture must account for service-specific behavior.

The relationship is:

```text
Azure
 └── Region
      ├── Availability Zone 1
      ├── Availability Zone 2
      └── Availability Zone 3
```

But not every resource is naturally deployed across zones.

Some resources are:

```text
Regional
Zonal
Zone-redundant
Global
```

This distinction matters when designing availability.

For example, a workload may run across zones while another dependency remains regional or zone-specific. The architecture is only as resilient as its relevant dependencies.

**Remember:** “Same region” does not automatically mean “highly available.”

---

## Part 8 — Azure Policy: Governance as Code

Azure Policy evaluates resources against organizational rules and can audit, deny, modify, or otherwise govern resource configurations depending on the policy definition and effect. It is different from Azure RBAC. RBAC answers **who can perform an action**, while Policy answers **whether a resource configuration complies with a defined rule**.

For example:

```text
RBAC:
Can this user create a VM?

Policy:
If a VM is created, is its configuration compliant?
```

Possible governance requirements include:

```text
Only approved regions
Required tags
Allowed resource types
Required security settings
Required diagnostic settings
Disallowed public exposure
Approved SKUs
```

A policy might require:

```text
Environment = Prod
Owner = Team-A
CostCenter = 1234
```

or restrict deployment to approved regions.

A useful governance flow is:

```text
Management Group
      ↓
Policy
      ↓
Subscriptions
      ↓
Resource Groups
      ↓
Resources
```

Senior point: Governance should be introduced carefully. An overly aggressive policy can break legitimate deployments.

---

## Part 9 — Azure RBAC: Authorization in Practice

Azure RBAC controls access to Azure resources using security principals, role definitions, and scopes.

The mental model is:

```text
Security Principal
        +
Role
        +
Scope
        ↓
Effective Permission
```

A security principal can be:

```text
User
Group
Service Principal
Managed Identity
```

Common built-in roles include:

```text
Reader
Contributor
Owner
```

But built-in roles are not automatically appropriate for every situation. Custom roles can provide narrower permissions where required.

A command-line example:

```bash
az role assignment create \
  --assignee <IDENTITY-ID> \
  --role Reader \
  --scope /subscriptions/<SUBSCRIPTION-ID>/resourceGroups/rg-shopsphere-prod
```

The important part is not memorizing the command. Understand:

```text
Who receives access?
Which role?
At what scope?
What permissions does that role contain?
How is access inherited?
```

---

## Part 10 — Azure Resource Providers

Azure resources are organized through **resource providers**. A resource type is represented using a namespace and resource type, such as:

```text
Microsoft.Compute
Microsoft.Network
Microsoft.Storage
Microsoft.ContainerService
Microsoft.KeyVault
```

For example:

```text
Microsoft.Compute/virtualMachines
Microsoft.Network/virtualNetworks
Microsoft.Storage/storageAccounts
```

This matters when working with ARM, Terraform, Bicep, Azure CLI, and troubleshooting because Azure's resource-management API uses these resource types.

You can inspect provider information with Azure CLI commands such as:

```bash
az provider list --output table
```

For a specific provider:

```bash
az provider show \
  --namespace Microsoft.Network \
  --query registrationState
```

A registered resource provider does not mean every possible resource configuration works in every region or subscription. Service capabilities can depend on region, SKU (the size or pricing tier of a service, such as a VM size or a storage performance level), API version, quota, and other constraints.

---

## Part 11 — ARM, Azure Resource Manager and Control Plane

Azure Resource Manager (ARM) is the management layer through which you create, update, organize, secure, and govern Azure resources. When you use Azure CLI, PowerShell, Bicep, Terraform's Azure provider, or the Azure portal, those tools ultimately interact with Azure management APIs.

Conceptually:

```text
Portal
Azure CLI
PowerShell
Terraform
Bicep
   ↓
Azure Management APIs / ARM
   ↓
Azure Resource Providers
   ↓
Azure Resources
```

This explains why different tools can manage the same resource. They are different interfaces and automation approaches around the same underlying Azure management plane.

Bicep has a particularly direct relationship with ARM:

```text
Bicep
  ↓
ARM deployment representation
  ↓
Azure Resource Manager
  ↓
Resources
```

Terraform uses a different state/configuration model:

```text
Terraform configuration
        ↓
AzureRM provider
        ↓
Azure APIs
        ↓
Resources
```

---

## Part 12 — Control Plane vs Data Plane

This distinction is essential in Azure architecture.

The **control plane** is concerned with managing resources:

```text
Create
Update
Delete
Configure
Authorize
```

The **data plane** is concerned with using the resource itself.

For a storage account:

```text
Control plane:
Create storage account
Configure networking
Assign RBAC

Data plane:
Read/write blobs
```

For Key Vault:

```text
Control plane:
Manage the vault resource
Configure settings

Data plane:
Read secrets
Read keys
Use certificates
```

A user may have permission to manage a resource without automatically having permission to use its data, depending on the service and authorization model.

This distinction becomes extremely important during troubleshooting.

Example:

```text
"Can I access the Key Vault resource?"
```

is not necessarily the same question as:

```text
"Can my application read this secret?"
```

---

## Part 13 — Azure Tags, Naming and Resource Organization

Azure tags are key-value metadata attached to supported resources and are commonly used for cost allocation, ownership, environment identification, automation, and governance.

Example:

```text
Environment = Production
Application = ShopSphere
Owner       = PlatformTeam
CostCenter  = FIN-001
ManagedBy   = Terraform
```

Tags should support operational decisions rather than become meaningless metadata.

A naming convention should similarly make resources understandable without requiring someone to open the portal.

For example:

```text
rg-shopsphere-prod-api
rg-shopsphere-prod-data
vnet-shopsphere-prod
aks-shopsphere-prod
kv-shopsphere-prod
acrshopsphereprod
```

Exact naming conventions vary by organization and resource-specific Azure naming rules.

---

## Part 14 — Azure Architecture: Shared Platform vs Workload Resources

Enterprise Azure environments often separate shared platform services from individual workload resources.

A conceptual architecture is:

```text
                    Management Group
                          │
             ┌────────────┴────────────┐
             │                         │
       Platform Subscriptions     Workload Subscriptions
             │                         │
      ┌──────┼──────┐             ┌────┼────┐
      │      │      │             │         │
   Network  Logs  Security      Shop A    Shop B
```

Shared platform capabilities may include:

```text
Central networking
Identity integration
Monitoring
Security tooling
Private DNS
Connectivity
Policy
```

Workload subscriptions contain application-specific resources.

This separation can improve ownership and reduce blast radius, but it also creates integration complexity. For example, a workload may depend on centrally managed DNS or networking, so the platform team becomes a dependency for application delivery.

---

## Part 15 — Azure Resource Locks

Resource locks provide an additional protection mechanism against accidental deletion or modification of supported resources.

Common lock concepts include:

```text
CanNotDelete
ReadOnly
```

A lock can be useful for particularly important resources, but it should not replace proper RBAC, change control, or IaC practices.

For example, a production resource group may be protected against accidental deletion while authorized IaC remains responsible for normal configuration management.

---

## Part 16 — Azure Cost Management Mental Model

Azure cost is affected by the resources you deploy, their utilization, pricing model, region, data transfer, storage, monitoring ingestion, and other consumption dimensions. A resource being “small” does not necessarily mean it is free, and some supporting services can create costs that are easy to overlook.

Use the cost model:

```text
Resource
   ↓
Consumption
   ↓
Pricing dimension
   ↓
Cost
```

For a production platform, identify:

```text
Compute
Database
Storage
Networking
Data transfer
Monitoring/log ingestion
Security services
Non-production environments
```

Tags and subscription boundaries can help with cost attribution.

Senior point: Cost optimization should preserve required security, reliability, and business functionality.

---

## Part 17 — Azure Resource Explorer and CLI as Troubleshooting Tools

A Senior/Lead engineer should be comfortable inspecting Azure resources without relying entirely on the portal.

Useful commands include:

```bash
az account show
az account list --output table
az group list --output table
az resource list --output table
```

Inspect a specific resource:

```bash
az resource show \
  --ids <RESOURCE-ID>
```

Inspect a resource group:

```bash
az group show \
  --name <RESOURCE-GROUP>
```

For a resource, inspect its properties and configuration:

```bash
az resource show \
  --resource-group <RESOURCE-GROUP> \
  --name <RESOURCE-NAME> \
  --resource-type <RESOURCE-TYPE>
```

The exact command syntax varies by resource type.

When troubleshooting, compare:

```text
Expected configuration
        ↓
Actual Azure configuration
        ↓
Policy
        ↓
RBAC
        ↓
Network
        ↓
Application
```

---

## Part 19 — Azure vs AWS Mapping

Use this mapping to connect the Azure architecture to concepts already learned:

| Concept | Azure | AWS |
|---|---|---|
| Identity directory | Microsoft Entra ID | IAM / IAM Identity Center and related identity services |
| Organization hierarchy | Management Groups | Organizations / OUs |
| Major resource/billing boundary | Subscription | Account |
| Resource grouping | Resource Group | No exact equivalent |
| Region | Azure Region | AWS Region |
| Availability domain | Availability Zone | Availability Zone |
| Cloud network | VNet | VPC |
| Cloud authorization | Azure RBAC | IAM |
| Governance policy | Azure Policy | Service Control Policies / IAM policies / Config-related controls |
| Resource management | Azure Resource Manager | AWS control plane / APIs |
| IaC | Bicep / Terraform | CloudFormation / CDK / Terraform |
| Managed Kubernetes | AKS | EKS |
| Container registry | ACR | ECR |
| Secrets | Key Vault | Secrets Manager / Parameter Store |
| Monitoring | Azure Monitor | CloudWatch |

Do not try to force exact one-to-one equivalence. Some services combine capabilities differently, and some concepts have no direct counterpart.

**Remember:** Learn the architectural concept first; learn the provider implementation second.

---

## Part 21 — Failure Drill: Governance

A developer tries to create a production VM in an unapproved Azure region.

The deployment fails.

Do not immediately assume RBAC is the cause.

Reason:

```text
Was the user authenticated?
        ↓
Was the user authorized to create the resource?
        ↓
Did Azure Policy allow the requested region?
        ↓
Did the subscription have quota?
        ↓
Was the resource type supported?
```

This demonstrates an important distinction:

```text
RBAC = permission to act
Policy = configuration/governance constraint
Quota = available platform capacity
```

---

## Part 22 — Failure Drill: Control Plane vs Data Plane

An application has permission to access a Key Vault resource but cannot retrieve a secret.

Investigate:

```text
Application identity
       ↓
Authentication
       ↓
Azure RBAC / data-plane authorization
       ↓
Key Vault networking
       ↓
Secret existence
       ↓
Application configuration
```

Do not conclude:

```text
"The app can see the Key Vault, so it can read the secret."
```

Resource management access and data access are distinct concepts.

---

## Part 24 — Cleanup

Remove the resources created exclusively for the lab:

```bash
az group delete \
  --name rg-azure-architecture-lab \
  --yes \
  --no-wait
```

Before deleting a resource group, verify that it contains only lab resources.

Then verify:

```bash
az group exists \
  --name rg-azure-architecture-lab
```

Also check for resources accidentally created elsewhere:

```bash
az resource list --output table
```

Review:

```text
Resource groups
Public IPs
Storage
Key Vault
Networking
Monitoring
RBAC assignments
Policy assignments
```

Do not delete shared, production, or centrally managed resources.

---

**Final mental model:**

> **Azure architecture is the design of boundaries and responsibilities around resources: identity, governance, subscription, resource group, network, service, workload, and operations.**

## Next

**Day 23 — Azure Overlay 02: Azure Compute & PaaS**

You will map the compute concepts from the core curriculum to Azure:

```text
VM
VM Scale Sets
App Service
Container Apps
AKS
Functions
```

The focus will be on **how to choose Azure compute**, what each service actually manages, where the application runs, networking behavior, scaling, identity, deployment models, cost, and the trade-offs expected in Senior/Lead interviews.
