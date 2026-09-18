# Day 11 — Cloud Architecture & Enterprise Structure

## What you will learn

Cloud infrastructure becomes difficult to manage when an organization grows from a few resources to many teams, applications, environments, and subscriptions or accounts. A Senior/Lead DevOps engineer needs to understand how the cloud is structured above the individual resource level and why organizations create management groups, subscriptions/accounts, resource groups, regions, environments, and ownership boundaries. The goal of this lesson is to understand the architecture behind the resources you deploy, not just how to create the resources themselves.

---

## Part 1 — The Enterprise Cloud Hierarchy

1. Why does an enterprise need a cloud hierarchy?

A small project can put its resources into a single cloud account or subscription, but an enterprise needs stronger boundaries for security, billing, ownership, governance, and operational control. Cloud providers therefore give organizations higher-level containers that allow resources to be grouped and controlled at different levels. The important idea is that a hierarchy is not created simply to make the portal look organized; each boundary should provide a useful control such as access management, policy, cost separation, or workload isolation.

**Practice**

Think about a company running 50 applications across Dev, UAT, and Production. List the boundaries you would need before deciding where individual VMs, databases, networks, or containers should be created.

2. What is the basic Azure hierarchy?

In Azure, the broad hierarchy is **Tenant → Management Groups → Subscriptions → Resource Groups → Resources**. The Microsoft Entra tenant represents the organization's identity boundary, management groups provide governance across subscriptions, subscriptions provide important billing and access boundaries, resource groups organize related resources, and the resources are the actual services such as VMs, VNets, databases, and storage accounts. Not every organization needs every management-group level, but the hierarchy gives you a way to apply control at the appropriate scope.

**Practice**

Take a typical production application and identify where its identity, governance, subscription, resource-group, and individual resources would sit in the hierarchy.

3. How does AWS structure an enterprise?

AWS uses a different terminology and hierarchy. An organization can contain multiple AWS accounts, with Organizational Units used to group accounts and policies applied through AWS Organizations. Individual workloads then use resources inside those accounts, such as VPCs, EC2 instances, databases, and S3 buckets. A useful mental model is **AWS Organization → Organizational Units → Accounts → Resources**. AWS accounts are therefore a major isolation and governance boundary in enterprise architecture.

**Practice**

Map the same fictional company into an AWS Organization with separate accounts for shared services, development, and production.

**Remember:** Azure commonly uses subscriptions as a major enterprise boundary; AWS commonly uses accounts.

---

## Part 2 — Tenant, Subscription, Account, and Resource Group

4. What is an Entra ID tenant?

An Azure tenant is the organization's identity boundary in Microsoft Entra ID. It contains identities such as users, groups, applications, and service principals and provides the identity system used to authenticate and authorize access to Azure and other connected services. A tenant is not the same thing as a subscription: one tenant can contain multiple Azure subscriptions, while the subscriptions use the tenant's identity system for access control.

**Practice**

Draw the relationship between one tenant and three subscriptions: Dev, UAT, and Prod. Then ask which object provides identity and which objects provide infrastructure and billing boundaries.

5. What is an Azure Subscription?

An Azure subscription is a major management, billing, quota, and access boundary for Azure resources. Organizations often create multiple subscriptions to separate environments, business units, workloads, or security boundaries. A subscription can contain many resource groups and resources, and Azure policies and role assignments can be applied at subscription scope. Separating subscriptions is therefore much stronger than simply creating separate resource groups inside one subscription.

**Practice**

Consider whether Dev, UAT, and Production should share one subscription or use separate subscriptions. Write down the security, billing, and operational consequences of each design.

6. What is an AWS Account?

An AWS account is a strong isolation and governance boundary inside an AWS Organization. Accounts have their own billing context, resource ownership, IAM boundaries, service quotas, and operational scope. Enterprises commonly use multiple accounts because separating workloads or environments into accounts can reduce blast radius and make security and governance easier to enforce. This is one of the most important differences to remember when mapping Azure architecture to AWS.

**Practice**

Take the Azure design of three subscriptions and create an equivalent AWS design using accounts. Identify what is similar and what is different.

7. What is a Resource Group?

An Azure Resource Group is a logical container for related Azure resources. It is useful for organizing resources that share a lifecycle, ownership model, or operational purpose. A resource group is not the same as a region and is not a security boundary equivalent to a subscription. Resources in a resource group can be located in different Azure regions, although many resources are region-specific themselves.

**Practice**

For a Spring Boot application with an App Service, database, storage account, and monitoring resources, decide which resources you would place in the same resource group and explain the lifecycle relationship.

**Remember:** Resource groups organize resources; subscriptions provide a broader management boundary.

---

## Part 3 — Regions, Availability Zones, and Environments

8. Is a Resource Group the same as a Region?

No. A resource group is a logical management container, while a region is a physical geographic location where cloud infrastructure is deployed. A resource group can contain resources associated with different regions, although individual Azure resources may have regional placement requirements. Keeping this distinction clear prevents a common architectural mistake: assuming that putting resources into one resource group makes them physically reside together.

**Practice**

Take a resource group containing a frontend, backend, database, and backup resource. Identify which of those resources have a regional location and which relationships are purely logical.

9. What is a Cloud Region?

A region is a geographic area containing cloud infrastructure operated by the provider. Choosing a region affects latency, data residency, service availability, disaster-recovery design, and sometimes cost. A production architecture should therefore choose regions based on business and technical requirements rather than simply choosing the geographically closest location.

**Practice**

For an application serving users primarily in India, list the factors you would evaluate before selecting its primary Azure or AWS region.

10. What is an Availability Zone?

Availability Zones are physically separate locations within a cloud region that are designed to reduce the impact of failures affecting one location. Deploying supported workloads across multiple zones can improve availability because a failure in one zone does not necessarily take down the entire workload. Zones do not replace regional disaster recovery: a region-wide failure requires a multi-region strategy.

**Practice**

Take a production application with a load balancer, application instances, and database. Identify which components should be distributed across availability zones and why.

**Remember:** Zones help with failures inside a region; multiple regions address larger regional failures.

11. How are environments represented in cloud architecture?

Dev, UAT, and Production are logical environments representing different stages of the application lifecycle and different levels of operational risk. They can be separated using subscriptions or accounts, resource groups, naming conventions, or a combination of these depending on the organization's scale and governance requirements. Production normally deserves stronger access controls and change processes than development, so environment boundaries should support those differences rather than exist only as labels.

**Practice**

Design a Dev/UAT/Prod structure for one application and decide which boundaries you would use at the subscription/account and resource-group levels.

---

## Part 4 — Management Groups, Organizational Units, and Governance

12. What is an Azure Management Group?

An Azure Management Group is a governance container above subscriptions. It allows organizations to organize subscriptions into a hierarchy and apply Azure Policy, role assignments, and other governance controls at a broader scope. For example, a company might place Production subscriptions under one management-group branch and Development subscriptions under another, allowing different policies and access requirements to be inherited by the subscriptions below them.

**Practice**

Design a simple management-group hierarchy for a company with Production, Non-Production, and Security subscriptions.

13. What is the AWS equivalent of an Azure Management Group?

AWS does not have an exact one-to-one equivalent, but AWS Organizations and Organizational Units provide a similar higher-level governance capability. Organizational Units group AWS accounts, while Service Control Policies can be applied to accounts or organizational units to establish guardrails. The important interview point is not to claim that the services are identical; instead, understand the architectural role they play: both provide governance above individual workload resources.

**Practice**

Map:

```text
Azure Management Group → AWS Organizational Unit
Azure Subscription → AWS Account
Azure Resource → AWS Resource
```

Then identify where the mapping is approximate rather than exact.

14. What belongs at the governance layer?

The governance layer should contain controls that need to apply consistently across multiple subscriptions or accounts, such as allowed regions, security requirements, required tags, identity controls, logging requirements, and restrictions on risky services or configurations. The purpose is to establish organizational guardrails without requiring every application team to implement the same foundational controls independently.

**Practice**

Create five governance rules for a fictional enterprise and decide whether each should be enforced centrally or left to individual application teams.

**Remember:** Governance defines the guardrails; workload teams operate within those guardrails.

---

## Part 5 — Ownership and Enterprise Boundaries

15. Why are cloud boundaries also ownership boundaries?

Cloud architecture becomes easier to operate when each major boundary has a clear owner. For example, a Network team may own shared networking, a Platform team may own common compute or Kubernetes infrastructure, and Application teams may own their application resources. Clear ownership makes it easier to determine who can change something, who responds when it fails, and who pays for or reviews the associated resources. This is why enterprise structure should be designed around organizational responsibility as well as technical grouping.

**Practice**

For a company with Network, Platform, Security, and Application teams, assign ownership for the major cloud layers and identify where responsibilities overlap.

16. Why should access follow ownership?

Access should be granted according to what a team needs to operate, rather than giving everyone broad access because it is convenient. The Network team may need administrative access to network infrastructure while an application team may only need permission to consume that network. Similarly, developers may need access to development resources but not unrestricted production administration. This follows the least-privilege principle and reduces the impact of compromised credentials or operational mistakes.

**Practice**

Take your ownership model and identify where each team should have read, write, or administrative access.

17. How does enterprise structure reduce blast radius?

Separating environments, accounts or subscriptions, workloads, and ownership boundaries limits how far a mistake can spread. If one application team has access only to its own resources, an incorrect deployment is less likely to affect unrelated applications or shared infrastructure. The same principle applies to Terraform state, networking, identities, and production pipelines: good boundaries reduce the number of resources that one change can affect.

**Practice**

Imagine an engineer accidentally deletes an application resource. Compare the potential impact when all applications share one broad administrative boundary versus when each workload has appropriate isolation.

**Remember:** Good architecture does not eliminate failures; it limits how far failures can spread.

---

## Part 6 — Putting the Enterprise Architecture Together

18. How does a typical enterprise cloud structure fit together?

A practical enterprise design starts with the identity and governance layer, then creates strong boundaries for subscriptions or accounts, environments, shared platforms, and workloads. Inside those boundaries, resource groups or similar logical containers organize resources according to lifecycle and ownership. Individual resources are then deployed into appropriate regions and availability zones. The important point is that each layer answers a different question: **Who are we? What rules apply? Who owns this environment? Where does it run? Which resources belong together?**

**Practice**

Design the following fictional enterprise:

```text
Company
├── Production
│   ├── Network
│   ├── Platform
│   └── Applications
└── Non-Production
    ├── Network
    ├── Platform
    └── Applications
```

Now decide how you would represent this using Azure Management Groups, Subscriptions, Resource Groups, Regions, and resources. Then create the equivalent AWS design using Organizations, OUs, Accounts, and resources.

19. How should Terraform fit into this architecture?

Terraform should normally follow the ownership and lifecycle boundaries already established by the cloud architecture. If the Network team owns network infrastructure and the Application team owns application infrastructure, their Terraform configurations and states should normally reflect those boundaries rather than putting everything into one large project and state. This creates a consistent relationship between cloud ownership, source code, state, access permissions, and deployment pipelines.

**Practice**

Take the enterprise architecture you designed and identify the Terraform project and state that would manage each major boundary.

**Remember:** A good IaC structure should reinforce the cloud architecture, not fight against it.

20. How should CI/CD fit into this architecture?

Application and infrastructure changes should have controlled delivery paths appropriate to their ownership and risk. An application pipeline may build and deploy application code, while an infrastructure pipeline validates, plans, reviews, and applies infrastructure changes. These pipelines should use identities with only the permissions they require and should apply stronger approval and protection mechanisms to Production. The result is a system where code, infrastructure, identity, state, and deployment controls all support the same ownership model.

**Practice**

For one production application, draw the flow from Git commit through the application pipeline and infrastructure pipeline to the cloud resources. Identify where security checks, approvals, and environment boundaries belong.

---

## Part 7 — Integrated Practice

Design a small enterprise cloud from scratch.

Start with one company containing Dev, UAT, and Production environments. Define the identity boundary, governance hierarchy, subscriptions or accounts, network ownership, platform ownership, and application ownership. Decide where resources should live, which regions and availability zones are required, how access should be separated, and how Terraform projects and state should map to those boundaries.

Then explain the architecture as if you were presenting it to a Lead Architect:

> "This is our enterprise hierarchy. These are our governance boundaries. These are our environment boundaries. These teams own these resources. These are our Terraform state boundaries. These pipelines are allowed to change these environments."

The objective is to understand the **reason behind every boundary**, not to memorize a particular company structure.

---

**5-Minute Interview Recall**

Before moving on, you should be able to answer these without looking at the notes:

1. Why does an enterprise need a cloud hierarchy?
2. What is the difference between an Azure tenant, subscription, resource group, and resource?
3. What is the difference between an AWS Organization, OU, account, and resource?
4. Why are Azure subscriptions important enterprise boundaries?
5. Why are AWS accounts important enterprise boundaries?
6. Is a resource group a region?
7. What is the difference between a region and an availability zone?
8. Why separate Production from Non-Production?
9. What does an Azure Management Group provide?
10. What is the closest AWS architectural equivalent?
11. Why should cloud access follow ownership and least privilege?
12. How do enterprise boundaries reduce blast radius?
13. How should Terraform state map to cloud ownership?
14. Why should infrastructure and application pipelines have different responsibilities?

**Core Mental Model**

**Tenant/Organization → Governance → Subscription/Account → Environment/Workload → Resource Group or logical container → Resource**

The exact hierarchy differs between Azure and AWS, but the architectural goals are the same: **identity, governance, isolation, ownership, security, cost control, and reduced blast radius.**

**Cleanup**

If you created cloud resources during this lesson, destroy or remove them using the appropriate Terraform/Bicep workflow. Verify that no test resources, public endpoints, or unnecessary networking components remain.
