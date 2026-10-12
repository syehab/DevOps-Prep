# Day 22 — Azure Overlay 01: Azure Platform Architecture

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

Practice: Take a familiar AWS architecture and translate only its organizational structure into Azure before mapping individual services.

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

Practice: Explain why a user can exist once in Entra ID but have different Azure RBAC permissions in Dev and Prod.

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

Practice: Design a management-group hierarchy for an organization with 50 development subscriptions, 20 UAT subscriptions, and 10 production subscriptions. Focus on governance boundaries rather than simply creating one group per subscription.

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

Practice: Decide whether the following should share a subscription:

```text
Dev
UAT
Production
Shared networking
Security tooling
Central monitoring
```

For each decision, explain the benefit and trade-off.

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

Practice: Take a production application and decide whether its database should share the same resource group as its application resources. Explain the lifecycle and access implications.

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

Practice: Compare these three assignments:

```text
Contributor at subscription
Contributor at resource group
Reader on one storage account
```

Ask:

```text
What can each identity potentially affect?
Which has the smallest blast radius?
Which would be easiest to justify for a narrow task?
```

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

Practice: For every major component in your ShopSphere architecture, determine:

```text
What is its Azure scope?
Is it regional?
Is it zonal?
Can it use zone redundancy?
What happens if one zone fails?
```

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

Practice: Design three policies for ShopSphere:

1. Restrict production resources to approved regions.
2. Require an `Environment` tag.
3. Audit public network exposure.

Then decide which should be `Deny` and which should initially be `Audit`.

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

Practice: Create a lab identity that can read one resource group but cannot modify resources. Verify the result.

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

Practice: Pick three resources in your Azure lab and identify:

```text
Provider namespace
Resource type
Region
Resource group
Subscription
```

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

Practice: Create one simple Azure resource with the portal, inspect it with Azure CLI, and then represent the same resource in Terraform or Bicep. Focus on understanding that the management plane is common underneath the tools.

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

Practice: Take Storage Account, Key Vault, and Azure SQL/PostgreSQL and identify one control-plane operation and one data-plane operation for each.

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

Practice: Create a naming standard containing:

```text
Application
Environment
Region
Resource type
Ownership
```

Then test whether someone unfamiliar with the environment could identify the purpose of a resource from its name and tags.

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

Practice: Decide which of these should be centralized and which should remain workload-owned:

```text
DNS
Network hub
Log workspace
Key Vault
Container registry
AKS cluster
Database
Security tooling
```

There is no universal answer. Explain the ownership and blast-radius trade-off.

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

Practice: Identify one resource in your lab where accidental deletion would be especially damaging. Explain whether a lock would improve the design and what operational inconvenience it might introduce.

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

Practice: For ShopSphere, identify the top five likely cost drivers and one optimization opportunity for each.

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

Practice: Create an Azure resource in the portal, then inspect the same resource using CLI. Identify at least five properties that matter operationally.

---

## Part 18 — Senior/Lead Architecture Exercise

Design an Azure landing structure for an organization with:

```text
50 development teams
20 UAT workloads
10 production workloads
Central security team
Central networking team
Central platform team
```

Requirements:

- Production must have stronger access controls than Dev.
- Networking is centrally governed.
- Security policies apply consistently.
- Teams should manage their own application resources.
- Costs must be attributable to teams.
- Production changes must be auditable.
- Different workloads should have limited blast radius.
- The platform should support future AKS workloads.

Design:

```text
Entra Tenant
   ↓
Management Groups
   ↓
Subscriptions
   ↓
Resource Groups
   ↓
Resources
```

Then define:

```text
RBAC boundaries
Policy boundaries
Network ownership
Logging ownership
Cost boundaries
Terraform state boundaries
Production deployment boundaries
```

Finally, explain why you chose each boundary.

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

## Part 20 — Practice: Build a Small Azure Platform

Create a small lab using Azure CLI and either Terraform or Bicep.

Build:

```text
Resource Group
    ↓
VNet
    ↓
Subnet
    ↓
Storage Account
    ↓
Key Vault
```

Then inspect:

```text
Subscription
Resource Group
Resource IDs
Locations
Tags
RBAC
Policy
```

Use:

```bash
az account show
az group create \
  --name rg-azure-architecture-lab \
  --location centralindia

az resource list \
  --resource-group rg-azure-architecture-lab \
  --output table
```

Add tags to the resources:

```text
Environment=Lab
ManagedBy=Terraform
Owner=DevOps
```

Then answer:

```text
Which resources are regional?
Which are global?
Which belong to the control plane?
Which operations are data-plane operations?
Who can manage them?
Who can use their data?
What policy applies?
What happens if the resource group is deleted?
```

Do not leave unnecessary billable resources running after the exercise.

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

Practice: Create a lab policy that audits or restricts a resource configuration, then observe the deployment behavior.

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

Practice: Create a lab identity with insufficient data-plane permission. Verify the failure, then grant only the required access.

---

## Part 23 — 5-Minute Recall

What is the difference between an Entra tenant and an Azure subscription?

**The tenant is the identity directory boundary; the subscription is an Azure resource-management/billing boundary. One tenant can be associated with multiple subscriptions.**

What is the hierarchy?

**Tenant → Management Groups → Subscriptions → Resource Groups → Resources**

What do management groups provide?

**Governance and organization across subscriptions, including inherited RBAC and Policy scope.**

What is a resource group?

**A logical Azure resource-management boundary inside a subscription, commonly aligned with lifecycle, ownership, and access needs.**

What is Azure RBAC?

**Scope-based authorization controlling who can perform which Azure actions.**

What is Azure Policy?

**Governance that evaluates or controls whether resource configurations comply with organizational rules.**

RBAC vs Policy?

**RBAC asks “Can you perform this action?” Policy asks “Is this resource configuration allowed/compliant?”**

What is the control plane?

**The management layer used to create, configure, update, and delete resources.**

What is the data plane?

**The interface through which the resource's actual data or service functionality is consumed.**

Region vs Availability Zone?

**A region is a geographic Azure area; availability zones are separate physical locations within supported regions designed to improve resilience.**

What is Azure Resource Manager?

**The Azure management layer through which Azure resources are organized and managed.**

Why do subscriptions matter?

**They provide important boundaries for resources, billing, access, quotas, and blast radius.**

Why do resource groups matter?

**They help organize resources around lifecycle, ownership, permissions, and operational boundaries.**

Why are tags important?

**They support ownership, cost attribution, automation, governance, and resource discovery.**

What is the Senior/Lead Azure architecture mindset?

**Do not begin with “Which Azure service?” Begin with “What boundary, responsibility, traffic flow, security requirement, reliability requirement, and operational model do I need?”**

**Final mental model:**

> **Azure architecture is the design of boundaries and responsibilities around resources: identity, governance, subscription, resource group, network, service, workload, and operations.**

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

## Answers to practice

### 1. Translate AWS organizational structure into Azure

<details>
<summary>Answer</summary>

Map AWS Organizations to Azure management groups. Map an AWS account to an Azure subscription. Map IAM Identity Center or IAM users to Microsoft Entra ID identities. Keep AWS VPC as Azure VNet only after the org map is done.

Do not start with “S3 becomes Blob Storage.” Translate tenant, management groups, subscriptions, and resource groups first. Then map individual services. The boundary model is the Azure overlay, not the service catalog.

</details>

### 2. One Entra user, different Dev and Prod RBAC

<details>
<summary>Answer</summary>

The user lives once in the Entra tenant. Azure RBAC assignments sit on subscriptions, resource groups, or resources. Dev can grant Contributor at the Dev subscription. Prod can grant Reader, or no assignment, on the Prod subscription.

Authentication is tenant-wide. Authorization is scope-based. The same identity can open the portal and still fail a Prod create because no role exists at that scope.

</details>

### 3. Management-group hierarchy for 50 Dev, 20 UAT, 10 Prod

<details>
<summary>Answer</summary>

Use Root → Platform, Production, and NonProduction. Put Shared Services and Network subscriptions under Platform. Put the 10 production subscriptions under Production. Put the 50 development and 20 UAT subscriptions under NonProduction, with optional Dev and UAT child groups.

Do not create one management group per subscription. Assign region, tag, and public-exposure policy at Production and NonProduction. Teams still own resources inside their subscriptions. Management groups govern subscriptions. They do not hold VMs or AKS.

</details>

### 4. Should Dev, UAT, Prod, networking, security, and monitoring share a subscription?

<details>
<summary>Answer</summary>

Keep Production in its own subscription so blast radius, RBAC, quota, and billing stay separate. Dev and UAT can share a NonProduction subscription only if quotas and access stay acceptable. Prefer separate Dev and UAT when many teams deploy.

Put shared networking in a platform/network subscription. Put security tooling and central monitoring in platform or security subscriptions. Sharing Prod with Dev is cheaper to operate and much larger in blast radius. Splitting everything increases integration work and cost attribution stays clearer.

</details>

### 5. Should the production database share the application resource group?

<details>
<summary>Answer</summary>

Prefer a separate data resource group, such as `rg-shopsphere-prod-data`, from `rg-shopsphere-prod-api`. Deleting the API resource group must not delete PostgreSQL. Database RBAC can stay narrower than application Contributor.

Same-lifecycle resources can share a group. A database usually outlives app restarts and has different owners. Resource-group delete is a blast-radius decision, not a folder choice.

</details>

### 6. Compare Contributor at subscription, Contributor at RG, Reader on one storage account

<details>
<summary>Answer</summary>

Contributor at subscription can create, change, and delete most resources under that subscription. Contributor at one resource group can change only resources in that group. Reader on one storage account can inspect that account and cannot change it.

The storage Reader has the smallest blast radius and is easiest to justify for a narrow read task. Do not always pick the smallest scope. A platform operator who must create resource groups needs subscription scope. Always name what broader scope can damage.

</details>

### 7. ShopSphere component region, zone, and zone-failure behavior

<details>
<summary>Answer</summary>

Place AKS node pools, App Service, PostgreSQL, and VNet in one region, such as `centralindia`. Use zone-redundant or zonal capacity for AKS nodes, the load balancer, and the database when the SKU supports it. ACR and some DNS or Entra capabilities behave as global or multi-region services.

Same region is not high availability. If one availability zone fails, zonal VMs or disks in that zone go down. Zone-redundant PostgreSQL and a zone-spanning AKS node pool should keep serving. A regional-only dependency still fails the chain.

</details>

### 8. Three ShopSphere policies: region, Environment tag, public exposure

<details>
<summary>Answer</summary>

1. Restrict production resources to approved regions with `Deny` at the Production management group. A wrong-region deploy should fail immediately. 2. Require an `Environment` tag. Start as `Audit` so you find gaps, then move to `Deny` or `Modify`. 3. Audit public network exposure first. Public IP or public database access is often accidental, and an immediate `Deny` can break a known public front door.

Introduce governance carefully. An aggressive `Deny` can stop legitimate deployments. Use `Audit` to learn, then tighten Production.

</details>

### 9. Lab identity that can read one resource group and cannot modify

<details>
<summary>Answer</summary>

Create a lab user or service principal. Run `az role assignment create` with `--role Reader` and `--scope` set to that resource group ID. Confirm `az role assignment list` shows Reader only at that scope.

Then try a read with `az resource list --resource-group <name>` and a write such as creating a storage account. The write must fail. Reader at resource-group scope inherits to resources underneath and does not grant Contributor.

</details>

### 10. Identify provider, type, region, group, and subscription for three resources

<details>
<summary>Answer</summary>

Pick a VM, a VNet, and a storage account. Run `az resource show --ids <RESOURCE-ID>` or `az resource list --resource-group <name>`. Record `Microsoft.Compute/virtualMachines`, `Microsoft.Network/virtualNetworks`, and `Microsoft.Storage/storageAccounts`.

Also record region, resource group, and subscription ID from the resource ID path. A registered provider does not mean every SKU works in every region. Quota and API version still matter.

</details>

### 11. Create in portal, inspect with CLI, represent in Terraform or Bicep

<details>
<summary>Answer</summary>

Create one storage account or resource group in the portal. Run `az resource show --ids <RESOURCE-ID>` and compare name, location, SKU, and tags. Then write the same resource in Terraform `azurerm` or Bicep.

Portal, Azure CLI, Terraform, and Bicep all talk to Azure Resource Manager. The management plane is common. Terraform still keeps its own state. Bicep compiles toward ARM. Do not treat the portal as a different Azure.

</details>

### 12. Control-plane vs data-plane for Storage, Key Vault, and Azure SQL/PostgreSQL

<details>
<summary>Answer</summary>

Storage: create or lock down the account (control plane); read or write a blob (data plane). Key Vault: create the vault and set networking (control plane); get a secret (data plane). Azure SQL/PostgreSQL: create the server and firewall rules (control plane); run `SELECT` as the application (data plane).

“Can I see the Key Vault resource?” is not “Can the app read this secret?” RBAC on the vault resource does not automatically grant secret get.

</details>

### 13. Naming standard with application, environment, region, type, and ownership

<details>
<summary>Answer</summary>

Use a pattern such as `rg-shopsphere-prod-api`, `vnet-shopsphere-prod-cin`, `aks-shopsphere-prod`, `kv-shopsphere-prod`. Tags: `Environment=Production`, `Application=ShopSphere`, `Owner=PlatformTeam`, `CostCenter=FIN-001`, `ManagedBy=Terraform`.

A stranger should read purpose, environment, and owner from the name plus tags. Follow Azure length and character rules per resource type. Names are operational, not decoration.

</details>

### 14. Centralize vs workload-own DNS, hub, logs, Key Vault, ACR, AKS, database, security

<details>
<summary>Answer</summary>

Centralize the network hub, private DNS, security tooling, and often the log workspace so inspection and audit stay consistent. Workload-own the AKS cluster and the database when teams need independent blast radius and release cadence.

Key Vault and ACR can be either: one platform registry and vault, or one per workload for isolation. Central services reduce duplication and become a delivery dependency. Workload ownership increases isolation and duplicates cost and operational skill.

</details>

### 15. Resource lock on a lab resource that must not be deleted by accident

<details>
<summary>Answer</summary>

Lock the production-like Key Vault or the Terraform state storage account with `CanNotDelete`. Accidental `az group delete` or a portal delete then fails. A lock does not replace RBAC, change control, or IaC.

The inconvenience is real: Terraform destroy and legitimate deletes need the lock removed first. Use locks on few high-impact resources. Do not lock every lab VM.

</details>

### 16. ShopSphere top five cost drivers and one optimization each

<details>
<summary>Answer</summary>

1. Compute (AKS nodes or App Service plan): right-size SKUs and scale non-prod to zero after hours. 2. Database: pick the SKU that matches load; use reserved capacity only when usage is steady. 3. Monitoring and log ingestion: cap retention and drop noisy debug logs. 4. Data transfer and NAT/firewall: keep private traffic on Private Endpoint instead of hairpinning through the internet. 5. Non-production copies: share SKUs down and shut idle labs.

Do not cut Production HA to save money. Optimize consumption while keeping security and reliability.

</details>

### 17. Create in portal, inspect with CLI, name five operational properties

<details>
<summary>Answer</summary>

Create the resource in the portal. Run `az resource show --ids <RESOURCE-ID>`. Record at least: resource ID, location, SKU or kind, tags, provisioning state, and identity or network settings.

Also compare expected configuration with actual ARM properties, then Policy, RBAC, network, and the application. The portal view can hide JSON fields the CLI shows. Those fields matter in incidents.

</details>

### 18. Lab policy that audits or restricts a configuration

<details>
<summary>Answer</summary>

Assign a policy at the lab resource group that audits a required tag or denies an unapproved location. Deploy a non-compliant resource. Confirm Audit writes a non-compliant result, or Deny blocks the ARM request.

Then deploy a compliant resource and confirm it succeeds. Read the policy assignment and the deployment error. Policy is not RBAC. The identity can be Contributor and still fail a Deny effect.

</details>

### 19. Lab identity with insufficient data-plane permission

<details>
<summary>Answer</summary>

Give an identity Reader or control-plane access on a Key Vault resource. Do not grant `Key Vault Secrets User` or the data-plane get action. Have the app or `az keyvault secret show` fail.

Then grant only secret get on that vault, or only on named secrets if the model supports it. Confirm the secret read works. Seeing the vault in `az resource show` never proved data-plane access.

</details>

### 20. Difference between an Entra tenant and an Azure subscription

<details>
<summary>Answer</summary>

The tenant is the identity directory boundary. The subscription is an Azure resource-management and billing boundary. One tenant can associate with many subscriptions.

A user authenticates to the tenant. Access to create VMs still needs Azure RBAC on a subscription, resource group, or resource.

</details>

### 21. What is the hierarchy?

<details>
<summary>Answer</summary>

Tenant → Management Groups → Subscriptions → Resource Groups → Resources. Identity, Policy, networking, monitoring, and cost sit around that tree.

Management groups organize subscriptions. They do not contain application resources themselves.

</details>

### 22. What do management groups provide?

<details>
<summary>Answer</summary>

They provide governance and organization across subscriptions. You assign Policy and RBAC at a group, and child subscriptions inherit that scope.

Use them for environment or platform boundaries, not as a folder per team resource.

</details>

### 23. What is a resource group?

<details>
<summary>Answer</summary>

A logical Azure resource-management boundary inside a subscription. Teams commonly align it with lifecycle, ownership, and access.

Deleting the group can delete the resources it contains. That is a blast-radius property.

</details>

### 24. What is Azure RBAC?

<details>
<summary>Answer</summary>

Scope-based authorization. A security principal plus a role plus a scope produce effective permission on Azure management actions.

Roles include Reader, Contributor, and Owner. Custom roles can be narrower.

</details>

### 25. What is Azure Policy?

<details>
<summary>Answer</summary>

Governance that evaluates or controls whether resource configuration complies with organizational rules. Effects include Audit, Deny, and Modify.

Policy does not replace RBAC. It constrains what a permitted identity may create or leave non-compliant.

</details>

### 26. RBAC vs Policy

<details>
<summary>Answer</summary>

RBAC asks whether the identity can perform the action. Policy asks whether the resource configuration is allowed or compliant.

A Contributor can still fail a Deny policy. A user with no RBAC never reaches the Policy question.

</details>

### 27. What is the control plane?

<details>
<summary>Answer</summary>

The management layer used to create, configure, update, authorize, and delete resources. Portal, Azure CLI, Bicep, and Terraform all use it through ARM.

Control-plane success does not prove the application can read data.

</details>

### 28. What is the data plane?

<details>
<summary>Answer</summary>

The interface that consumes the resource’s actual data or service function. Examples: blob read, secret get, SQL query.

Data-plane authorization and networking are separate from “can I manage this resource.”

</details>

### 29. Region vs Availability Zone

<details>
<summary>Answer</summary>

A region is a geographic Azure area. Availability zones are separate physical locations inside supported regions.

Not every service or region offers the same zone behavior. Same region does not mean zone failure is survivable.

</details>

### 30. What is Azure Resource Manager?

<details>
<summary>Answer</summary>

The Azure management layer that organizes and manages resources. Tools call ARM APIs, then resource providers, then resources.

ARM is why the portal and Terraform can manage the same VM.

</details>

### 31. Why do subscriptions matter?

<details>
<summary>Answer</summary>

They bound resources, billing, access, quotas, and blast radius. Production isolation often starts at subscription scope.

One subscription per environment is a design choice, not a law. Explain why the boundary exists.

</details>

### 32. Why do resource groups matter?

<details>
<summary>Answer</summary>

They organize resources around lifecycle, ownership, permissions, and operations. RBAC and Policy often use them as scope.

Group delete is a real operational risk. Design groups so accidental delete matches intended blast radius.

</details>

### 33. Why are tags important?

<details>
<summary>Answer</summary>

They support ownership, cost attribution, automation, governance, and discovery. A tag such as `CostCenter` or `Environment` makes bills and Policy useful.

Meaningless tags do not help. Require the few tags operators actually query.

</details>

### 34. Senior/Lead Azure architecture mindset

<details>
<summary>Answer</summary>

Do not begin with “Which Azure service?” Begin with boundary, responsibility, traffic flow, security, reliability, and the operational model.

Azure architecture is the design of those boundaries around resources: identity, governance, subscription, resource group, network, service, workload, and operations.

</details>

### 35. Design Azure landing structure for 50 Dev teams, 20 UAT, 10 Prod

<details>
<summary>Answer</summary>

Use one Entra tenant. Management groups: Platform, Production, NonProduction. Subscriptions: Network, Security/Logs, Shared Services under Platform; one or few Prod subscriptions with per-workload resource groups; Dev subscriptions per team or per cluster of teams; UAT subscriptions under NonProduction.

RBAC: teams get Contributor on their app resource groups, not Owner on Prod subscriptions. Policy: Deny unapproved regions and public data-plane exposure at Production. Network: hub in the Network subscription, spokes in workload subscriptions. Logs and security tooling in the Security subscription. Cost: tags plus subscription bills. Terraform state: one backend per environment, not one global file. Prod deploys: pipeline identity plus approval, not standing human Contributor.

Each boundary exists to limit blast radius and to keep platform ownership separate from workload ownership.

</details>

### 36. Build RG → VNet → Subnet → Storage → Key Vault and answer the post-build questions

<details>
<summary>Answer</summary>

Create `rg-azure-architecture-lab` with `az group create`. Deploy a VNet, one subnet, a storage account, and a Key Vault. Tag `Environment=Lab`, `ManagedBy=Terraform`, `Owner=DevOps`. Inspect IDs, locations, RBAC, and Policy with `az account show`, `az resource list`, and `az resource show`.

VNet, subnet, storage, and Key Vault are regional. Some names and Microsoft Entra objects are global. Creating and tagging them is control plane. Blob read and secret get are data plane. ARM RBAC identities manage resources. Data-plane roles or access policies use the data. Assigned Policy at group or subscription applies. Deleting the resource group deletes these lab resources.

Stop the lab afterward. Do not leave billable resources running.

</details>

### 37. What each RBAC assignment can affect, smallest blast radius, easiest narrow justification

<details>
<summary>Answer</summary>

Subscription Contributor can change almost every resource in that subscription, including new resource groups. Resource-group Contributor is limited to that group. Storage Reader can only read that one account.

Smallest blast radius: Reader on one storage account. Easiest to justify for a narrow task: the same Reader assignment. Use broader Contributor only when the job must create or change many resources.

</details>

### 38. Developer deploys a production VM in an unapproved region

<details>
<summary>Answer</summary>

Do not blame RBAC first. Trace: was the user authenticated in Entra? Was the user authorized to create VMs at that scope? Did Azure Policy allow the region? Did the subscription have quota? Was the VM size and resource type supported there?

RBAC is permission to act. Policy is the configuration constraint. Quota is platform capacity. A Deny region policy explains this failure even when the developer is Contributor.

</details>
