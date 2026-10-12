# Day 11 — Cloud Architecture & Enterprise Structure

**Goal:** Understand the structure above individual resources (tenant, governance, subscriptions or accounts, resource groups) and why each boundary exists. Then you can explain an enterprise cloud design instead of only building inside one.

**Core mental model:** Hold this one picture before any detail. Every numbered question in this lesson explains one level of it, so if you get lost, come back here.

```text
Tenant / Organization         → Who are we?
        ↓
Governance layer              → What rules apply to everyone?
        ↓
Subscription / Account        → Who owns and pays for this?
        ↓
Resource group / container    → Which resources live and die together?
        ↓
Resource                      → The actual VM, VNet, database
```

| Concept | Azure | AWS |
|:--|:--|:--|
| Isolation unit | Subscription | Account |
| Grouping for governance | Management groups | Organizations / OUs |
| Guardrails | Azure Policy | SCPs |

> **JD note:** Lead cloud roles grade exactly this design thinking. See the [landing zone pattern card](jd-insights/patterns/landing-zone-multi-account.md).

## What you will learn

A few cloud resources are easy to manage. Hundreds of resources across many teams, applications, and environments are not. The thing that keeps them manageable is structure: management groups, subscriptions or accounts, resource groups, regions, and clear ownership. This lesson is about why each of those boundaries exists and what control it gives you, not about how to click resources into existence.

---

## Part 1 — The Enterprise Cloud Hierarchy

1. Why does an enterprise need a cloud hierarchy?

A small project can put its resources into a single cloud account or subscription. An enterprise needs stronger boundaries for security, billing, ownership, governance, and operational control. Cloud providers therefore give organizations higher-level containers, so you can group and control resources at different levels. You do not create a hierarchy simply to make the portal look organized. Each boundary should provide a useful control, such as access management, policy, cost separation, or workload isolation.

**Practice**

Think about a company running 50 applications across Dev, UAT, and Production. List the boundaries you would need before deciding where individual VMs, databases, networks, or containers should be created.

2. What is the basic Azure hierarchy?

In Azure, the broad hierarchy is **Tenant → Management Groups → Subscriptions → Resource Groups → Resources**. Each level has one job:

```text
Tenant           → the organization's identity boundary (Microsoft Entra)
Management group → governance applied across subscriptions
Subscription     → billing and access boundary
Resource group   → organizes resources that belong together
Resource         → the actual VM, VNet, database, storage account
```

Not every organization needs every management-group level, but the hierarchy gives you a way to apply control at the appropriate scope.

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

An Azure tenant is the organization's identity boundary in Microsoft Entra ID. It contains identities such as users, groups, applications, and service principals. It provides the identity system that authenticates and authorizes access to Azure and other connected services. A tenant is not the same thing as a subscription: one tenant can contain multiple Azure subscriptions, while the subscriptions use the tenant's identity system for access control.

**Practice**

Draw the relationship between one tenant and three subscriptions: Dev, UAT, and Prod. Then ask which object provides identity and which objects provide infrastructure and billing boundaries.

5. What is an Azure Subscription?

An Azure subscription is a major management, billing, quota, and access boundary for Azure resources. Organizations often create multiple subscriptions to separate environments, business units, workloads, or security boundaries. A subscription can contain many resource groups and resources, and you can apply Azure policies and role assignments at subscription scope. Separate subscriptions are therefore a much stronger boundary than separate resource groups inside one subscription.

**Practice**

Consider whether Dev, UAT, and Production should share one subscription or use separate subscriptions. Write down the security, billing, and operational consequences of each design.

6. What is an AWS Account?

An AWS account is a strong isolation and governance boundary inside an AWS Organization. Accounts have their own billing context, resource ownership, IAM boundaries, service quotas, and operational scope. Enterprises commonly use multiple accounts because separating workloads or environments into accounts can reduce blast radius and make security and governance easier to enforce. This is one of the most important differences to remember when mapping Azure architecture to AWS.

**Practice**

Take the Azure design of three subscriptions and create an equivalent AWS design using accounts. Identify what is similar and what is different.

7. What is a Resource Group?

An Azure Resource Group is a logical container for related Azure resources. It is useful for organizing resources that share a lifecycle, ownership model, or operational purpose. A resource group is not the same as a region and is not a security boundary equivalent to a subscription. Resources in a resource group can be located in different Azure regions, although many resources are region-specific themselves.

**Practice**

For a Spring Boot application with an App Service, database, storage account, and monitoring resources, decide which resources you would place in the same resource group. Explain the lifecycle relationship.

**Remember:** Resource groups organize resources; subscriptions provide a broader management boundary.

---

## Part 3 — Regions, Availability Zones, and Environments

8. Is a Resource Group the same as a Region?

No. A resource group is a logical management container, while a region is a physical geographic location where the provider operates cloud infrastructure. A resource group can contain resources associated with different regions, although individual Azure resources may have regional placement requirements. Keep this distinction clear to avoid a common architectural mistake: one resource group does not make resources physically reside together.

**Practice**

Take a resource group containing a frontend, backend, database, and backup resource. Identify which of those resources have a regional location and which relationships are purely logical.

9. What is a Cloud Region?

A region is a geographic area containing cloud infrastructure operated by the provider. Choosing a region affects latency, data residency, service availability, disaster-recovery design, and sometimes cost. A production architecture should therefore choose regions based on business and technical requirements rather than simply choosing the geographically closest location.

**Practice**

For an application serving users primarily in India, list the factors you would evaluate before selecting its primary Azure or AWS region.

10. What is an Availability Zone?

Availability Zones are physically separate locations within a cloud region. They reduce the impact of a failure in one location. Deploy supported workloads across multiple zones to improve availability: a failure in one zone does not necessarily take down the entire workload. Zones do not replace regional disaster recovery: a region-wide failure requires a multi-region strategy.

**Practice**

Take a production application with a load balancer, application instances, and database. Identify which components should be distributed across availability zones and why.

**Remember:** Zones help with failures inside a region; multiple regions address larger regional failures.

11. How are environments represented in cloud architecture?

Dev, UAT, and Production are logical environments representing different stages of the application lifecycle and different levels of operational risk. You can separate them with subscriptions or accounts, resource groups, naming conventions, or a combination of these, depending on the organization's scale and governance requirements. Production normally deserves stronger access controls and change processes than development, so environment boundaries should support those differences rather than exist only as labels.

**Practice**

Design a Dev/UAT/Prod structure for one application and decide which boundaries you would use at the subscription/account and resource-group levels.

---

## Part 4 — Management Groups, Organizational Units, and Governance

12. What is an Azure Management Group?

An Azure Management Group is a governance container above subscriptions. It allows organizations to organize subscriptions into a hierarchy and apply Azure Policy, role assignments, and other governance controls at a broader scope. For example, a company might place Production subscriptions under one management-group branch and Development subscriptions under another. The subscriptions below each branch then inherit different policies and access requirements.

**Practice**

Design a simple management-group hierarchy for a company with Production, Non-Production, and Security subscriptions.

13. What is the AWS equivalent of an Azure Management Group?

AWS does not have an exact one-to-one equivalent, but AWS Organizations and Organizational Units provide a similar higher-level governance capability. Organizational Units group AWS accounts, and you can apply Service Control Policies to accounts or organizational units as guardrails. Do not claim in an interview that the services are identical. Instead, understand their architectural role: both provide governance above individual workload resources.

**Practice**

Map:

```text
Azure Management Group → AWS Organizational Unit
Azure Subscription → AWS Account
Azure Resource → AWS Resource
```

Then identify where the mapping is approximate rather than exact.

14. What belongs at the governance layer?

The governance layer should contain controls that must apply consistently across multiple subscriptions or accounts. Examples: allowed regions, security requirements, required tags, identity controls, logging requirements, and restrictions on risky services or configurations. The purpose is to establish organizational guardrails, so that application teams do not each build the same foundational controls independently.

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

Grant access according to what a team needs to operate, not broad access for everyone because it is convenient. The Network team may need administrative access to network infrastructure while an application team may only need permission to consume that network. Similarly, developers may need access to development resources but not unrestricted production administration. This follows the least-privilege principle and reduces the impact of compromised credentials or operational mistakes.

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

A practical enterprise design starts with the identity and governance layer, then creates strong boundaries for subscriptions or accounts, environments, shared platforms, and workloads. Inside those boundaries, resource groups or similar logical containers organize resources according to lifecycle and ownership. Teams then deploy individual resources into appropriate regions and availability zones. The important point is that each layer answers a different question: **Who are we? What rules apply? Who owns this environment? Where does it run? Which resources belong together?**

> **Remember:** This ready-to-use foundation is what JDs call a **landing zone**. Think of it as a paved parking lot: each workload parks in its own numbered spot, and the lights, gates, and cameras are already there.

The landing zone becomes a factory when many teams or customers need the same foundation. One Terraform module describes the stack (network, IAM, compute, and data stores), and a pipeline applies that module for each team or customer. Nobody provisions in the console. IAM stays least-privilege for that stack, and a check after apply proves the pieces exist and can reach each other.

Some product JDs call each customer stack a tenant. That is a product tenant, not the Entra ID tenant you met earlier in this lesson. Day 16 calls the self-service version of this a paved road. Day 36 shows the plan, apply, and validate pipeline.

**Practice:** A product gives each customer their own VPC, IAM role, and RDS instance. Write the factory loop (module, pipeline, check). Then say what you refuse to do in the console.

> **Remember:** A factory stamps a landing zone: one module, a pipeline, least-privilege IAM, then a check that it worked. No console clicks.

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

Terraform should normally follow the ownership and lifecycle boundaries already established by the cloud architecture. If the Network team owns network infrastructure and the Application team owns application infrastructure, their Terraform configurations and states should normally reflect those boundaries. Do not put everything into one large project and state. This creates a consistent relationship between cloud ownership, source code, state, access permissions, and deployment pipelines.

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

Start with one company containing Dev, UAT, and Production environments. Define the identity boundary, governance hierarchy, subscriptions or accounts, network ownership, platform ownership, and application ownership. Decide where resources should live and which regions and availability zones you need. Decide how to separate access and how Terraform projects and state map to those boundaries.

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
15. How does an environment factory differ from building one landing zone by hand?

**Core Mental Model**

**Tenant/Organization → Governance → Subscription/Account → Environment/Workload → Resource Group or logical container → Resource**

The exact hierarchy differs between Azure and AWS, but the architectural goals are the same: **identity, governance, isolation, ownership, security, cost control, and reduced blast radius.**

**Cleanup**

If you created cloud resources during this lesson, destroy or remove them using the appropriate Terraform/Bicep workflow. Verify that no test resources, public endpoints, or unnecessary networking components remain.

## Answers to practice

### 1. Boundaries for 50 applications across Dev, UAT, and Production

<details>
<summary>Answer</summary>

List the boundaries before you place any VM, database, network, or container. You need an identity boundary for the whole company. You need a governance layer that applies shared rules. You need isolation units for billing and access.

You also need environment splits for Dev, UAT, and Production. Add shared-platform boundaries for network and platform services. Then add application ownership so each workload has a clear owner. Each boundary must give a control, not only a tidy portal.

</details>

### 2. Production application in the Azure hierarchy

<details>
<summary>Answer</summary>

Place identity in the Entra ID tenant. Users, groups, and service principals live there. Place governance in a Production management group. Azure Policy and role assignments apply at that scope.

Place the workload in a Production subscription. That subscription is the billing and access boundary. Place the App Service, database, and related resources in one application resource group. Those resources share a lifecycle. Individual VMs, VNets, and databases sit at the resource level.

</details>

### 3. Map the company into an AWS Organization

<details>
<summary>Answer</summary>

Create one AWS Organization for the company. Put shared services in their own account, such as networking, logging, and identity helpers. Put development workloads in a Development account. Put production workloads in a Production account.

Group those accounts with Organizational Units. Apply Service Control Policies at the OU or account. Workloads then use VPCs, EC2, databases, and S3 inside the matching account. Azure uses subscriptions as a major boundary. AWS uses accounts.

</details>

### 4. One tenant and three subscriptions: identity versus billing

<details>
<summary>Answer</summary>

Draw one Entra ID tenant at the top. Hang Dev, UAT, and Prod subscriptions under that tenant. The tenant provides identity. It authenticates users, groups, applications, and service principals.

The three subscriptions provide infrastructure and billing boundaries. Each subscription can hold its own resource groups, quotas, and role assignments. One tenant can contain many subscriptions. A subscription is not a tenant.

</details>

### 5. One shared subscription versus separate Dev, UAT, and Prod subscriptions

<details>
<summary>Answer</summary>

Separate subscriptions give stronger security, billing, and operations. A Production compromise does not automatically grant Dev access. Bills split by environment. Quotas and change control can differ.

One shared subscription is weaker. Role assignments mix. A Dev mistake can reach Production resources more easily. Cost reports become harder to split. Use one subscription only at small scale. Prefer separate subscriptions when environments have different risk.

</details>

### 6. Three Azure subscriptions mapped to AWS accounts

<details>
<summary>Answer</summary>

Map the Dev subscription to a Development account. Map UAT to a UAT account. Map Prod to a Production account. Both designs isolate billing, quotas, and access.

The difference is the isolation unit. Azure uses a subscription inside one tenant. AWS uses an account inside an Organization. AWS accounts are a strong blast-radius boundary. Do not call a subscription and an account identical. Call them equivalent enterprise isolation units.

</details>

### 7. Resource group for a Spring Boot application

<details>
<summary>Answer</summary>

Place the App Service, database, storage account, and monitoring resources in the same resource group when they share a lifecycle. You create, update, and delete them together. One team owns that set.

Do not treat the resource group as a subscription-level security boundary. It organizes related resources. The subscription still owns billing and broad access. Resources in that group can sit in different regions if the design needs it.

</details>

### 8. Which resources in a group are regional, and which links are logical

<details>
<summary>Answer</summary>

A resource group is a logical container. It is not a physical location. The frontend, backend, and database each have a regional location. Backup may sit in another region on purpose.

The resource group membership is logical. It does not force those resources to live in one data center. Keep management grouping separate from physical placement.

</details>

### 9. Choose a primary region for users in India

<details>
<summary>Answer</summary>

Evaluate latency to users in India first. Then check data residency rules for that workload. Confirm the services you need exist in the candidate region. Review availability-zone support and disaster-recovery pairing.

Also compare cost. Do not pick a region only because it is geographically close. Choose from business and technical requirements.

</details>

### 10. Distribute a production application across availability zones

<details>
<summary>Answer</summary>

Place the load balancer so it can send traffic to instances in more than one zone. Run application instances in at least two availability zones. Put the database on a zone-redundant or multi-zone design when the service supports it.

A failure in one zone then does not take down the whole workload. Zones do not replace regional disaster recovery. A region-wide failure still needs a multi-region plan.

</details>

### 11. Dev, UAT, and Prod structure at subscription and resource-group level

<details>
<summary>Answer</summary>

Give Production its own subscription or account. Give Non-Production a separate subscription, or split Dev and UAT if risk and billing need it. Production then gets stronger access control and change process.

Inside each environment, use resource groups per application or per shared platform. Naming can help, but naming is not the security boundary. Environment boundaries must support different risk, not exist only as labels.

</details>

### 12. Management-group hierarchy for Production, Non-Production, and Security

<details>
<summary>Answer</summary>

Create a root management group for the company. Under it, create Production, Non-Production, and Security branches. Place Production subscriptions under Production. Place Dev and UAT subscriptions under Non-Production.

Place Security and logging subscriptions under Security. Apply stricter Azure Policy on Production. Apply looser but still guarded policy on Non-Production. Subscriptions inherit the controls from their management-group branch.

</details>

### 13. Where Azure-to-AWS governance mapping is approximate

<details>
<summary>Answer</summary>

Map Azure Management Group to an AWS Organizational Unit. Map Azure Subscription to an AWS Account. Map an Azure resource to an AWS resource. The architectural role is similar: governance above the workload.

The mapping is not exact. Azure Policy is not identical to Service Control Policies. A resource group has no equal AWS object in this mapping. Do not tell an interviewer the services are the same. Explain the shared job: guardrails above individual resources.

</details>

### 14. Five governance rules, and which stay central

<details>
<summary>Answer</summary>

Enforce these centrally: allowed regions, required tags, mandatory logging, identity controls such as who may create subscriptions, and a ban on risky public exposure. Those rules must apply to every team.

Leave application-specific instance size, feature flags, and inner workload layout to application teams. Governance sets guardrails. Workload teams operate inside those guardrails. Do not make every team rebuild the same foundation.

</details>

### 15. Ownership for Network, Platform, Security, and Application teams

<details>
<summary>Answer</summary>

Give the Network team shared networking, including hub connectivity and core routing. Give the Platform team common compute or Kubernetes infrastructure. Give the Security team policy, identity guardrails, and logging. Give Application teams their application resources.

Overlap appears at the edges. Application teams consume the network but do not own it. Platform teams run the cluster, while application teams own the workload on it. Name the owner of each layer so change, incident response, and billing have a clear path.

</details>

### 16. Read, write, and administrative access from the ownership model

<details>
<summary>Answer</summary>

Grant the Network team administrative access to network infrastructure. Give Application teams permission to consume that network, not to rewrite it. Give developers write access in Development. Do not give them unrestricted Production administration.

Give Security read across environments so they can audit. Give Production write only to the owning team and its pipeline identity. Follow least privilege. Grant what a team needs to operate, not broad access for convenience.

</details>

### 17. Blast radius of an accidental resource delete

<details>
<summary>Answer</summary>

If all applications share one broad administrative boundary, one delete can hit unrelated applications and shared infrastructure. The failure spreads because access and lifecycle sit in one bucket.

If each workload has its own subscription or account, resource group, and Terraform state, the same mistake stays inside that workload. Good architecture does not remove failures. It limits how far they spread.

</details>

### 18. Environment factory loop for a per-customer VPC, IAM, and RDS stack

<details>
<summary>Answer</summary>

Write one Terraform module for the stack: network, IAM, compute, and data stores. A pipeline applies that module for each customer. After apply, run a check that the VPC, IAM role, and RDS instance exist and can reach each other.

Refuse to provision that stack in the console. Console clicks break repeatability and least-privilege IAM. A factory stamps the landing zone. It does not hand-build each customer.

</details>

### 19. Fictional enterprise on Azure, then the AWS equivalent

<details>
<summary>Answer</summary>

On Azure, use a company root management group with Production and Non-Production branches. Under each branch, use subscriptions for Network, Platform, and Applications. Inside those subscriptions, use resource groups that match lifecycle and ownership. Place workloads in chosen regions and availability zones.

On AWS, use an Organization with Production and Non-Production OUs. Use accounts for Network, Platform, and Applications. Place resources inside those accounts. Azure subscriptions and AWS accounts play the isolation role. Management groups and OUs play the governance role.

</details>

### 20. Terraform projects and state for each major boundary

<details>
<summary>Answer</summary>

Give Network its own Terraform project and state. Give Platform its own project and state. Give each application its own project and state. Split Production state from Non-Production state.

Terraform should follow ownership and lifecycle already set by the cloud design. Do not put the whole enterprise in one project and one state. IaC must reinforce the architecture, not fight it.

</details>

### 21. Git commit through application and infrastructure pipelines

<details>
<summary>Answer</summary>

A developer commits to Git. The application pipeline builds and deploys application code. The infrastructure pipeline validates, plans, reviews, and applies infrastructure. Security checks sit in both pipelines before Production.

Approvals sit before Production apply and Production deploy. Environment boundaries keep Dev identities away from Production. Each pipeline uses an identity with only the permissions it needs. Code, infrastructure, identity, state, and delivery then support the same ownership model.

</details>

### 22. Integrated Practice — Design a small enterprise cloud

<details>
<summary>Answer</summary>

Start with one Entra ID tenant or one AWS Organization as the identity boundary. Put governance in management groups or OUs. Use separate subscriptions or accounts for Dev, UAT, and Production. Give Network, Platform, and Application teams their own ownership boundaries.

Place shared networking in the network subscription or account. Place applications in application resource groups inside the matching environment. Choose a primary region from latency, residency, and service needs. Use multiple availability zones in Production. Map Terraform state to those same ownership and environment boundaries.

</details>

### 23. Integrated Practice — Present the design to a Lead Architect

<details>
<summary>Answer</summary>

Present the reasons, not a copy of another company. Say: this is our enterprise hierarchy, from tenant or Organization down to resource. These are our governance boundaries, where policy and SCPs apply. These are our environment boundaries, so Production stays apart from Non-Production.

These teams own these resources: Network, Platform, Security, and Application. These Terraform states match those ownership lines. These pipelines may change these environments, with stronger approval on Production.

Every boundary answers a question. Who are we? What rules apply? Who owns this? Where does it run? Which resources belong together?

</details>

### 24. Interview Recall — Why does an enterprise need a cloud hierarchy?

<details>
<summary>Answer</summary>

A small project can live in one account or subscription. An enterprise needs stronger boundaries for security, billing, ownership, governance, and operational control.

Providers therefore give higher-level containers. Each boundary should provide a useful control. Do not create a hierarchy only to tidy the portal.

</details>

### 25. Interview Recall — Azure tenant, subscription, resource group, and resource

<details>
<summary>Answer</summary>

The tenant is the identity boundary in Microsoft Entra ID. A subscription is the billing, quota, and access boundary. A resource group is a logical container for related resources.

A resource is the actual VM, VNet, database, or storage account. One tenant can contain many subscriptions. A resource group is not equal to a subscription.

</details>

### 26. Interview Recall — AWS Organization, OU, account, and resource

<details>
<summary>Answer</summary>

An AWS Organization is the company container for accounts. An Organizational Unit groups accounts for policy. An account is the isolation, billing, IAM, and quota boundary.

A resource is the VPC, EC2 instance, database, or S3 bucket inside an account. AWS commonly uses accounts as the major enterprise boundary.

</details>

### 27. Interview Recall — Why Azure subscriptions are important enterprise boundaries

<details>
<summary>Answer</summary>

A subscription is a major management, billing, quota, and access boundary. You can apply Azure Policy and role assignments at subscription scope.

Separate subscriptions are a stronger boundary than separate resource groups inside one subscription. Enterprises use them to split environments, business units, workloads, or security domains.

</details>

### 28. Interview Recall — Why AWS accounts are important enterprise boundaries

<details>
<summary>Answer</summary>

An AWS account has its own billing context, resource ownership, IAM boundary, quotas, and operational scope. Splitting workloads or environments into accounts reduces blast radius.

This is a key mapping point. Azure often isolates with subscriptions. AWS often isolates with accounts.

</details>

### 29. Interview Recall — Is a resource group a region?

<details>
<summary>Answer</summary>

No. A resource group is a logical management container. A region is a physical geographic location.

A resource group can contain resources from different regions. One resource group does not make resources physically reside together.

</details>

### 30. Interview Recall — Region versus availability zone

<details>
<summary>Answer</summary>

A region is a geographic area of cloud infrastructure. An availability zone is a physically separate location inside a region.

Zones help with failures inside a region. Multiple regions address larger regional failures. Zones do not replace regional disaster recovery.

</details>

### 31. Interview Recall — Why separate Production from Non-Production

<details>
<summary>Answer</summary>

Production has higher operational risk. It needs stronger access control and change process than Development.

Separation by subscription or account, and by resource group, supports those differences. Environment names alone are not enough.

</details>

### 32. Interview Recall — What an Azure Management Group provides

<details>
<summary>Answer</summary>

A management group sits above subscriptions. It lets you organize subscriptions and apply Azure Policy and role assignments at a broader scope.

Production subscriptions can sit under one branch. Development subscriptions can sit under another. Child subscriptions inherit those controls.

</details>

### 33. Interview Recall — Closest AWS equivalent of a management group

<details>
<summary>Answer</summary>

AWS Organizations and Organizational Units provide similar higher-level governance. You apply Service Control Policies to accounts or OUs as guardrails.

Do not claim the services are identical. Both provide governance above individual workload resources.

</details>

### 34. Interview Recall — Why access should follow ownership and least privilege

<details>
<summary>Answer</summary>

Grant access according to what a team needs to operate. The Network team administers the network. An application team only consumes it.

Developers may change Development resources. They should not hold unrestricted Production administration. Least privilege reduces the impact of stolen credentials and operational mistakes.

</details>

### 35. Interview Recall — How enterprise boundaries reduce blast radius

<details>
<summary>Answer</summary>

Separating environments, subscriptions or accounts, workloads, and ownership limits how far a mistake can spread. An incorrect deployment then stays inside one application.

The same idea applies to Terraform state, networking, identities, and production pipelines. Good boundaries reduce the resources one change can affect.

</details>

### 36. Interview Recall — How Terraform state should map to cloud ownership

<details>
<summary>Answer</summary>

Terraform projects and state should follow the same ownership and lifecycle as the cloud design. Network state stays with the Network team. Application state stays with the Application team.

Do not put everything in one large state. Align cloud ownership, source code, state, access, and pipelines.

</details>

### 37. Interview Recall — Why infrastructure and application pipelines differ

<details>
<summary>Answer</summary>

An application pipeline builds and deploys application code. An infrastructure pipeline validates, plans, reviews, and applies infrastructure.

Each pipeline uses an identity with only the permissions it needs. Production gets stronger approval. Code, infrastructure, identity, state, and delivery then share one ownership model.

</details>

### 38. Interview Recall — Environment factory versus a hand-built landing zone

<details>
<summary>Answer</summary>

A landing zone is the ready foundation: identity, governance, networking, and guardrails that workloads deploy into. Building one by hand is acceptable for a single platform.

A factory stamps that foundation many times. One Terraform module describes the stack. A pipeline applies it for each team or customer. IAM stays least-privilege for that stack. A check after apply proves the pieces exist and can reach each other. Nobody provisions in the console.

</details>
