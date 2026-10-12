# Day 22 — Questions and answers

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Then answer each item below before you open the Answer block. After that, do the lab in [03-implementation.md](03-implementation.md).

Write your own answer first. Open the Answer block only after you try. Keep the original numbering.

---

## 1. Translate AWS organizational structure into Azure

**Practice**

Take a familiar AWS architecture and translate only its organizational structure into Azure before mapping individual services.

<details>
<summary>Answer</summary>

Map AWS Organizations to Azure management groups. Map an AWS account to an Azure subscription. Map IAM Identity Center or IAM users to Microsoft Entra ID identities. Keep AWS VPC as Azure VNet only after the org map is done.

Do not start with “S3 becomes Blob Storage.” Translate tenant, management groups, subscriptions, and resource groups first. Then map individual services. The boundary model is the Azure overlay, not the service catalog.

</details>

---

## 2. One Entra user, different Dev and Prod RBAC

**Practice**

Explain why a user can exist once in Entra ID but have different Azure RBAC permissions in Dev and Prod.

<details>
<summary>Answer</summary>

The user lives once in the Entra tenant. Azure RBAC assignments sit on subscriptions, resource groups, or resources. Dev can grant Contributor at the Dev subscription. Prod can grant Reader, or no assignment, on the Prod subscription.

Authentication is tenant-wide. Authorization is scope-based. The same identity can open the portal and still fail a Prod create because no role exists at that scope.

</details>

---

## 3. Management-group hierarchy for 50 Dev, 20 UAT, 10 Prod

**Practice**

Design a management-group hierarchy for an organization with 50 development subscriptions, 20 UAT subscriptions, and 10 production subscriptions. Focus on governance boundaries rather than simply creating one group per subscription.

<details>
<summary>Answer</summary>

Use Root → Platform, Production, and NonProduction. Put Shared Services and Network subscriptions under Platform. Put the 10 production subscriptions under Production. Put the 50 development and 20 UAT subscriptions under NonProduction, with optional Dev and UAT child groups.

Do not create one management group per subscription. Assign region, tag, and public-exposure policy at Production and NonProduction. Teams still own resources inside their subscriptions. Management groups govern subscriptions. They do not hold VMs or AKS.

</details>

---

## 4. Should Dev, UAT, Prod, networking, security, and monitoring share a subscription?

**Practice**

Decide whether the following should share a subscription:

```text
Dev
UAT
Production
Shared networking
Security tooling
Central monitoring
```

For each decision, explain the benefit and trade-off.

<details>
<summary>Answer</summary>

Keep Production in its own subscription so blast radius, RBAC, quota, and billing stay separate. Dev and UAT can share a NonProduction subscription only if quotas and access stay acceptable. Prefer separate Dev and UAT when many teams deploy.

Put shared networking in a platform/network subscription. Put security tooling and central monitoring in platform or security subscriptions. Sharing Prod with Dev is cheaper to operate and much larger in blast radius. Splitting everything increases integration work and cost attribution stays clearer.

</details>

---

## 5. Should the production database share the application resource group?

**Practice**

Take a production application and decide whether its database should share the same resource group as its application resources. Explain the lifecycle and access implications.

<details>
<summary>Answer</summary>

Prefer a separate data resource group, such as `rg-shopsphere-prod-data`, from `rg-shopsphere-prod-api`. Deleting the API resource group must not delete PostgreSQL. Database RBAC can stay narrower than application Contributor.

Same-lifecycle resources can share a group. A database usually outlives app restarts and has different owners. Resource-group delete is a blast-radius decision, not a folder choice.

</details>

---

## 6. Compare Contributor at subscription, Contributor at RG, Reader on one storage account

**Practice**

Compare these three assignments:

```text
Contributor at subscription
Contributor at resource group
Reader on one storage account
```

<details>
<summary>Answer</summary>

Contributor at subscription can create, change, and delete most resources under that subscription. Contributor at one resource group can change only resources in that group. Reader on one storage account can inspect that account and cannot change it.

The storage Reader has the smallest blast radius and is easiest to justify for a narrow read task. Do not always pick the smallest scope. A platform operator who must create resource groups needs subscription scope. Always name what broader scope can damage.

</details>

---

## 7. ShopSphere component region, zone, and zone-failure behavior

**Practice**

For every major component in your ShopSphere architecture, determine:

```text
What is its Azure scope?
Is it regional?
Is it zonal?
Can it use zone redundancy?
What happens if one zone fails?
```

<details>
<summary>Answer</summary>

Place AKS node pools, App Service, PostgreSQL, and VNet in one region, such as `centralindia`. Use zone-redundant or zonal capacity for AKS nodes, the load balancer, and the database when the SKU supports it. ACR and some DNS or Entra capabilities behave as global or multi-region services.

Same region is not high availability. If one availability zone fails, zonal VMs or disks in that zone go down. Zone-redundant PostgreSQL and a zone-spanning AKS node pool should keep serving. A regional-only dependency still fails the chain.

</details>

---

## 8. Three ShopSphere policies: region, Environment tag, public exposure

**Practice**

Design three policies for ShopSphere:

1. Restrict production resources to approved regions.
2. Require an `Environment` tag.
3. Audit public network exposure.

Then decide which should be `Deny` and which should initially be `Audit`.

<details>
<summary>Answer</summary>

1. Restrict production resources to approved regions with `Deny` at the Production management group. A wrong-region deploy should fail immediately. 2. Require an `Environment` tag. Start as `Audit` so you find gaps, then move to `Deny` or `Modify`. 3. Audit public network exposure first. Public IP or public database access is often accidental, and an immediate `Deny` can break a known public front door.

Introduce governance carefully. An aggressive `Deny` can stop legitimate deployments. Use `Audit` to learn, then tighten Production.

</details>

---

## 9. Lab identity that can read one resource group and cannot modify

**Practice**

Create a lab identity that can read one resource group but cannot modify resources. Verify the result.

<details>
<summary>Answer</summary>

Create a lab user or service principal. Run `az role assignment create` with `--role Reader` and `--scope` set to that resource group ID. Confirm `az role assignment list` shows Reader only at that scope.

Then try a read with `az resource list --resource-group <name>` and a write such as creating a storage account. The write must fail. Reader at resource-group scope inherits to resources underneath and does not grant Contributor.

</details>

---

## 10. Identify provider, type, region, group, and subscription for three resources

**Practice**

Pick three resources in your Azure lab and identify:

```text
Provider namespace
Resource type
Region
Resource group
Subscription
```

<details>
<summary>Answer</summary>

Pick a VM, a VNet, and a storage account. Run `az resource show --ids <RESOURCE-ID>` or `az resource list --resource-group <name>`. Record `Microsoft.Compute/virtualMachines`, `Microsoft.Network/virtualNetworks`, and `Microsoft.Storage/storageAccounts`.

Also record region, resource group, and subscription ID from the resource ID path. A registered provider does not mean every SKU works in every region. Quota and API version still matter.

</details>

---

## 11. Create in portal, inspect with CLI, represent in Terraform or Bicep

**Practice**

Create one simple Azure resource with the portal, inspect it with Azure CLI, and then represent the same resource in Terraform or Bicep. Focus on understanding that the management plane is common underneath the tools.

<details>
<summary>Answer</summary>

Create one storage account or resource group in the portal. Run `az resource show --ids <RESOURCE-ID>` and compare name, location, SKU, and tags. Then write the same resource in Terraform `azurerm` or Bicep.

Portal, Azure CLI, Terraform, and Bicep all talk to Azure Resource Manager. The management plane is common. Terraform still keeps its own state. Bicep compiles toward ARM. Do not treat the portal as a different Azure.

</details>

---

## 12. Control-plane vs data-plane for Storage, Key Vault, and Azure SQL/PostgreSQL

**Practice**

Take Storage Account, Key Vault, and Azure SQL/PostgreSQL and identify one control-plane operation and one data-plane operation for each.

<details>
<summary>Answer</summary>

Storage: create or lock down the account (control plane); read or write a blob (data plane). Key Vault: create the vault and set networking (control plane); get a secret (data plane). Azure SQL/PostgreSQL: create the server and firewall rules (control plane); run `SELECT` as the application (data plane).

“Can I see the Key Vault resource?” is not “Can the app read this secret?” RBAC on the vault resource does not automatically grant secret get.

</details>

---

## 13. Naming standard with application, environment, region, type, and ownership

**Practice**

Create a naming standard containing:

```text
Application
Environment
Region
Resource type
Ownership
```

Then test whether someone unfamiliar with the environment could identify the purpose of a resource from its name and tags.

<details>
<summary>Answer</summary>

Use a pattern such as `rg-shopsphere-prod-api`, `vnet-shopsphere-prod-cin`, `aks-shopsphere-prod`, `kv-shopsphere-prod`. Tags: `Environment=Production`, `Application=ShopSphere`, `Owner=PlatformTeam`, `CostCenter=FIN-001`, `ManagedBy=Terraform`.

A stranger should read purpose, environment, and owner from the name plus tags. Follow Azure length and character rules per resource type. Names are operational, not decoration.

</details>

---

## 14. Centralize vs workload-own DNS, hub, logs, Key Vault, ACR, AKS, database, security

**Practice**

Decide which of these should be centralized and which should remain workload-owned:

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

<details>
<summary>Answer</summary>

Centralize the network hub, private DNS, security tooling, and often the log workspace so inspection and audit stay consistent. Workload-own the AKS cluster and the database when teams need independent blast radius and release cadence.

Key Vault and ACR can be either: one platform registry and vault, or one per workload for isolation. Central services reduce duplication and become a delivery dependency. Workload ownership increases isolation and duplicates cost and operational skill.

</details>

---

## 15. Resource lock on a lab resource that must not be deleted by accident

**Practice**

Identify one resource in your lab where accidental deletion would be especially damaging. Explain whether a lock would improve the design and what operational inconvenience it might introduce.

<details>
<summary>Answer</summary>

Lock the production-like Key Vault or the Terraform state storage account with `CanNotDelete`. Accidental `az group delete` or a portal delete then fails. A lock does not replace RBAC, change control, or IaC.

The inconvenience is real: Terraform destroy and legitimate deletes need the lock removed first. Use locks on few high-impact resources. Do not lock every lab VM.

</details>

---

## 16. ShopSphere top five cost drivers and one optimization each

**Practice**

For ShopSphere, identify the top five likely cost drivers and one optimization opportunity for each.

<details>
<summary>Answer</summary>

1. Compute (AKS nodes or App Service plan): right-size SKUs and scale non-prod to zero after hours. 2. Database: pick the SKU that matches load; use reserved capacity only when usage is steady. 3. Monitoring and log ingestion: cap retention and drop noisy debug logs. 4. Data transfer and NAT/firewall: keep private traffic on Private Endpoint instead of hairpinning through the internet. 5. Non-production copies: share SKUs down and shut idle labs.

Do not cut Production HA to save money. Optimize consumption while keeping security and reliability.

</details>

---

## 17. Create in portal, inspect with CLI, name five operational properties

**Practice**

Create an Azure resource in the portal, then inspect the same resource using CLI. Identify at least five properties that matter operationally.

<details>
<summary>Answer</summary>

Create the resource in the portal. Run `az resource show --ids <RESOURCE-ID>`. Record at least: resource ID, location, SKU or kind, tags, provisioning state, and identity or network settings.

Also compare expected configuration with actual ARM properties, then Policy, RBAC, network, and the application. The portal view can hide JSON fields the CLI shows. Those fields matter in incidents.

</details>

---

## 18. Lab policy that audits or restricts a configuration

**Practice**

Create a lab policy that audits or restricts a resource configuration, then observe the deployment behavior.

<details>
<summary>Answer</summary>

Assign a policy at the lab resource group that audits a required tag or denies an unapproved location. Deploy a non-compliant resource. Confirm Audit writes a non-compliant result, or Deny blocks the ARM request.

Then deploy a compliant resource and confirm it succeeds. Read the policy assignment and the deployment error. Policy is not RBAC. The identity can be Contributor and still fail a Deny effect.

</details>

---

## 19. Lab identity with insufficient data-plane permission

**Practice**

Create a lab identity with insufficient data-plane permission. Verify the failure, then grant only the required access.

<details>
<summary>Answer</summary>

Give an identity Reader or control-plane access on a Key Vault resource. Do not grant `Key Vault Secrets User` or the data-plane get action. Have the app or `az keyvault secret show` fail.

Then grant only secret get on that vault, or only on named secrets if the model supports it. Confirm the secret read works. Seeing the vault in `az resource show` never proved data-plane access.

</details>

---

## 20. Difference between an Entra tenant and an Azure subscription

**5-Minute Recall**

What is the difference between an Entra tenant and an Azure subscription?

<details>
<summary>Answer</summary>

The tenant is the identity directory boundary. The subscription is an Azure resource-management and billing boundary. One tenant can associate with many subscriptions.

A user authenticates to the tenant. Access to create VMs still needs Azure RBAC on a subscription, resource group, or resource.

</details>

---

## 21. What is the hierarchy?

**5-Minute Recall**

What is the hierarchy?

<details>
<summary>Answer</summary>

Tenant → Management Groups → Subscriptions → Resource Groups → Resources. Identity, Policy, networking, monitoring, and cost sit around that tree.

Management groups organize subscriptions. They do not contain application resources themselves.

</details>

---

## 22. What do management groups provide?

**5-Minute Recall**

What do management groups provide?

<details>
<summary>Answer</summary>

They provide governance and organization across subscriptions. You assign Policy and RBAC at a group, and child subscriptions inherit that scope.

Use them for environment or platform boundaries, not as a folder per team resource.

</details>

---

## 23. What is a resource group?

**5-Minute Recall**

What is a resource group?

<details>
<summary>Answer</summary>

A logical Azure resource-management boundary inside a subscription. Teams commonly align it with lifecycle, ownership, and access.

Deleting the group can delete the resources it contains. That is a blast-radius property.

</details>

---

## 24. What is Azure RBAC?

**5-Minute Recall**

What is Azure RBAC?

<details>
<summary>Answer</summary>

Scope-based authorization. A security principal plus a role plus a scope produce effective permission on Azure management actions.

Roles include Reader, Contributor, and Owner. Custom roles can be narrower.

</details>

---

## 25. What is Azure Policy?

**5-Minute Recall**

What is Azure Policy?

<details>
<summary>Answer</summary>

Governance that evaluates or controls whether resource configuration complies with organizational rules. Effects include Audit, Deny, and Modify.

Policy does not replace RBAC. It constrains what a permitted identity may create or leave non-compliant.

</details>

---

## 26. RBAC vs Policy

**5-Minute Recall**

RBAC vs Policy?

<details>
<summary>Answer</summary>

RBAC asks whether the identity can perform the action. Policy asks whether the resource configuration is allowed or compliant.

A Contributor can still fail a Deny policy. A user with no RBAC never reaches the Policy question.

</details>

---

## 27. What is the control plane?

**5-Minute Recall**

What is the control plane?

<details>
<summary>Answer</summary>

The management layer used to create, configure, update, authorize, and delete resources. Portal, Azure CLI, Bicep, and Terraform all use it through ARM.

Control-plane success does not prove the application can read data.

</details>

---

## 28. What is the data plane?

**5-Minute Recall**

What is the data plane?

<details>
<summary>Answer</summary>

The interface that consumes the resource’s actual data or service function. Examples: blob read, secret get, SQL query.

Data-plane authorization and networking are separate from “can I manage this resource.”

</details>

---

## 29. Region vs Availability Zone

**5-Minute Recall**

Region vs Availability Zone?

<details>
<summary>Answer</summary>

A region is a geographic Azure area. Availability zones are separate physical locations inside supported regions.

Not every service or region offers the same zone behavior. Same region does not mean zone failure is survivable.

</details>

---

## 30. What is Azure Resource Manager?

**5-Minute Recall**

What is Azure Resource Manager?

<details>
<summary>Answer</summary>

The Azure management layer that organizes and manages resources. Tools call ARM APIs, then resource providers, then resources.

ARM is why the portal and Terraform can manage the same VM.

</details>

---

## 31. Why do subscriptions matter?

**5-Minute Recall**

Why do subscriptions matter?

<details>
<summary>Answer</summary>

They bound resources, billing, access, quotas, and blast radius. Production isolation often starts at subscription scope.

One subscription per environment is a design choice, not a law. Explain why the boundary exists.

</details>

---

## 32. Why do resource groups matter?

**5-Minute Recall**

Why do resource groups matter?

<details>
<summary>Answer</summary>

They organize resources around lifecycle, ownership, permissions, and operations. RBAC and Policy often use them as scope.

Group delete is a real operational risk. Design groups so accidental delete matches intended blast radius.

</details>

---

## 33. Why are tags important?

**5-Minute Recall**

Why are tags important?

<details>
<summary>Answer</summary>

They support ownership, cost attribution, automation, governance, and discovery. A tag such as `CostCenter` or `Environment` makes bills and Policy useful.

Meaningless tags do not help. Require the few tags operators actually query.

</details>

---

## 34. Senior/Lead Azure architecture mindset

**5-Minute Recall**

What is the Senior/Lead Azure architecture mindset?

<details>
<summary>Answer</summary>

Do not begin with “Which Azure service?” Begin with boundary, responsibility, traffic flow, security, reliability, and the operational model.

Azure architecture is the design of those boundaries around resources: identity, governance, subscription, resource group, network, service, workload, and operations.

</details>

---

## 35. Design Azure landing structure for 50 Dev teams, 20 UAT, 10 Prod

**Senior/Lead Architecture Exercise**

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

<details>
<summary>Answer</summary>

Use one Entra tenant. Management groups: Platform, Production, NonProduction. Subscriptions: Network, Security/Logs, Shared Services under Platform; one or few Prod subscriptions with per-workload resource groups; Dev subscriptions per team or per cluster of teams; UAT subscriptions under NonProduction.

RBAC: teams get Contributor on their app resource groups, not Owner on Prod subscriptions. Policy: Deny unapproved regions and public data-plane exposure at Production. Network: hub in the Network subscription, spokes in workload subscriptions. Logs and security tooling in the Security subscription. Cost: tags plus subscription bills. Terraform state: one backend per environment, not one global file. Prod deploys: pipeline identity plus approval, not standing human Contributor.

Each boundary exists to limit blast radius and to keep platform ownership separate from workload ownership.

</details>

---

## 36. Build RG → VNet → Subnet → Storage → Key Vault and answer the post-build questions

**Practice: Build a Small Azure Platform**

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

<details>
<summary>Answer</summary>

Create `rg-azure-architecture-lab` with `az group create`. Deploy a VNet, one subnet, a storage account, and a Key Vault. Tag `Environment=Lab`, `ManagedBy=Terraform`, `Owner=DevOps`. Inspect IDs, locations, RBAC, and Policy with `az account show`, `az resource list`, and `az resource show`.

VNet, subnet, storage, and Key Vault are regional. Some names and Microsoft Entra objects are global. Creating and tagging them is control plane. Blob read and secret get are data plane. ARM RBAC identities manage resources. Data-plane roles or access policies use the data. Assigned Policy at group or subscription applies. Deleting the resource group deletes these lab resources.

Stop the lab afterward. Do not leave billable resources running.

</details>

---

## 37. What each RBAC assignment can affect, smallest blast radius, easiest narrow justification

**Practice**

Ask:

```text
What can each identity potentially affect?
Which has the smallest blast radius?
Which would be easiest to justify for a narrow task?
```

The three assignments are Contributor at subscription, Contributor at resource group, and Reader on one storage account.

<details>
<summary>Answer</summary>

Subscription Contributor can change almost every resource in that subscription, including new resource groups. Resource-group Contributor is limited to that group. Storage Reader can only read that one account.

Smallest blast radius: Reader on one storage account. Easiest to justify for a narrow task: the same Reader assignment. Use broader Contributor only when the job must create or change many resources.

</details>

---

## 38. Developer deploys a production VM in an unapproved region

**Failure Drill: Governance**

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

<details>
<summary>Answer</summary>

Do not blame RBAC first. Trace: was the user authenticated in Entra? Was the user authorized to create VMs at that scope? Did Azure Policy allow the region? Did the subscription have quota? Was the VM size and resource type supported there?

RBAC is permission to act. Policy is the configuration constraint. Quota is platform capacity. A Deny region policy explains this failure even when the developer is Contributor.

</details>
