# Day 11 — Questions and answers

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Then answer each item below before you open the Answer block. After that, do the lab in [03-implementation.md](03-implementation.md).

Write your own answer first. Open the Answer block only after you try. Keep the original numbering.

---

## 1. Boundaries for 50 applications across Dev, UAT, and Production

**Practice**

Think about a company running 50 applications across Dev, UAT, and Production. List the boundaries you would need before deciding where individual VMs, databases, networks, or containers should be created.

<details>
<summary>Answer</summary>

List the boundaries before you place any VM, database, network, or container. You need an identity boundary for the whole company. You need a governance layer that applies shared rules. You need isolation units for billing and access.

You also need environment splits for Dev, UAT, and Production. Add shared-platform boundaries for network and platform services. Then add application ownership so each workload has a clear owner. Each boundary must give a control, not only a tidy portal.

</details>

---

## 2. Production application in the Azure hierarchy

**Practice**

Take a typical production application and identify where its identity, governance, subscription, resource-group, and individual resources would sit in the hierarchy.

<details>
<summary>Answer</summary>

Place identity in the Entra ID tenant. Users, groups, and service principals live there. Place governance in a Production management group. Azure Policy and role assignments apply at that scope.

Place the workload in a Production subscription. That subscription is the billing and access boundary. Place the App Service, database, and related resources in one application resource group. Those resources share a lifecycle. Individual VMs, VNets, and databases sit at the resource level.

</details>

---

## 3. Map the company into an AWS Organization

**Practice**

Map the same fictional company into an AWS Organization with separate accounts for shared services, development, and production.

<details>
<summary>Answer</summary>

Create one AWS Organization for the company. Put shared services in their own account, such as networking, logging, and identity helpers. Put development workloads in a Development account. Put production workloads in a Production account.

Group those accounts with Organizational Units. Apply Service Control Policies at the OU or account. Workloads then use VPCs, EC2, databases, and S3 inside the matching account. Azure uses subscriptions as a major boundary. AWS uses accounts.

</details>

---

## 4. One tenant and three subscriptions: identity versus billing

**Practice**

Draw the relationship between one tenant and three subscriptions: Dev, UAT, and Prod. Then ask which object provides identity and which objects provide infrastructure and billing boundaries.

<details>
<summary>Answer</summary>

Draw one Entra ID tenant at the top. Hang Dev, UAT, and Prod subscriptions under that tenant. The tenant provides identity. It authenticates users, groups, applications, and service principals.

The three subscriptions provide infrastructure and billing boundaries. Each subscription can hold its own resource groups, quotas, and role assignments. One tenant can contain many subscriptions. A subscription is not a tenant.

</details>

---

## 5. One shared subscription versus separate Dev, UAT, and Prod subscriptions

**Practice**

Consider whether Dev, UAT, and Production should share one subscription or use separate subscriptions. Write down the security, billing, and operational consequences of each design.

<details>
<summary>Answer</summary>

Separate subscriptions give stronger security, billing, and operations. A Production compromise does not automatically grant Dev access. Bills split by environment. Quotas and change control can differ.

One shared subscription is weaker. Role assignments mix. A Dev mistake can reach Production resources more easily. Cost reports become harder to split. Use one subscription only at small scale. Prefer separate subscriptions when environments have different risk.

</details>

---

## 6. Three Azure subscriptions mapped to AWS accounts

**Practice**

Take the Azure design of three subscriptions and create an equivalent AWS design using accounts. Identify what is similar and what is different.

<details>
<summary>Answer</summary>

Map the Dev subscription to a Development account. Map UAT to a UAT account. Map Prod to a Production account. Both designs isolate billing, quotas, and access.

The difference is the isolation unit. Azure uses a subscription inside one tenant. AWS uses an account inside an Organization. AWS accounts are a strong blast-radius boundary. Do not call a subscription and an account identical. Call them equivalent enterprise isolation units.

</details>

---

## 7. Resource group for a Spring Boot application

**Practice**

For a Spring Boot application with an App Service, database, storage account, and monitoring resources, decide which resources you would place in the same resource group. Explain the lifecycle relationship.

<details>
<summary>Answer</summary>

Place the App Service, database, storage account, and monitoring resources in the same resource group when they share a lifecycle. You create, update, and delete them together. One team owns that set.

Do not treat the resource group as a subscription-level security boundary. It organizes related resources. The subscription still owns billing and broad access. Resources in that group can sit in different regions if the design needs it.

</details>

---

## 8. Which resources in a group are regional, and which links are logical

**Practice**

Take a resource group containing a frontend, backend, database, and backup resource. Identify which of those resources have a regional location and which relationships are purely logical.

<details>
<summary>Answer</summary>

A resource group is a logical container. It is not a physical location. The frontend, backend, and database each have a regional location. Backup may sit in another region on purpose.

The resource group membership is logical. It does not force those resources to live in one data center. Keep management grouping separate from physical placement.

</details>

---

## 9. Choose a primary region for users in India

**Practice**

For an application serving users primarily in India, list the factors you would evaluate before selecting its primary Azure or AWS region.

<details>
<summary>Answer</summary>

Evaluate latency to users in India first. Then check data residency rules for that workload. Confirm the services you need exist in the candidate region. Review availability-zone support and disaster-recovery pairing.

Also compare cost. Do not pick a region only because it is geographically close. Choose from business and technical requirements.

</details>

---

## 10. Distribute a production application across availability zones

**Practice**

Take a production application with a load balancer, application instances, and database. Identify which components should be distributed across availability zones and why.

<details>
<summary>Answer</summary>

Place the load balancer so it can send traffic to instances in more than one zone. Run application instances in at least two availability zones. Put the database on a zone-redundant or multi-zone design when the service supports it.

A failure in one zone then does not take down the whole workload. Zones do not replace regional disaster recovery. A region-wide failure still needs a multi-region plan.

</details>

---

## 11. Dev, UAT, and Prod structure at subscription and resource-group level

**Practice**

Design a Dev/UAT/Prod structure for one application and decide which boundaries you would use at the subscription/account and resource-group levels.

<details>
<summary>Answer</summary>

Give Production its own subscription or account. Give Non-Production a separate subscription, or split Dev and UAT if risk and billing need it. Production then gets stronger access control and change process.

Inside each environment, use resource groups per application or per shared platform. Naming can help, but naming is not the security boundary. Environment boundaries must support different risk, not exist only as labels.

</details>

---

## 12. Management-group hierarchy for Production, Non-Production, and Security

**Practice**

Design a simple management-group hierarchy for a company with Production, Non-Production, and Security subscriptions.

<details>
<summary>Answer</summary>

Create a root management group for the company. Under it, create Production, Non-Production, and Security branches. Place Production subscriptions under Production. Place Dev and UAT subscriptions under Non-Production.

Place Security and logging subscriptions under Security. Apply stricter Azure Policy on Production. Apply looser but still guarded policy on Non-Production. Subscriptions inherit the controls from their management-group branch.

</details>

---

## 13. Where Azure-to-AWS governance mapping is approximate

**Practice**

Map:

```text
Azure Management Group → AWS Organizational Unit
Azure Subscription → AWS Account
Azure Resource → AWS Resource
```

Then identify where the mapping is approximate rather than exact.

<details>
<summary>Answer</summary>

Map Azure Management Group to an AWS Organizational Unit. Map Azure Subscription to an AWS Account. Map an Azure resource to an AWS resource. The architectural role is similar: governance above the workload.

The mapping is not exact. Azure Policy is not identical to Service Control Policies. A resource group has no equal AWS object in this mapping. Do not tell an interviewer the services are the same. Explain the shared job: guardrails above individual resources.

</details>

---

## 14. Five governance rules, and which stay central

**Practice**

Create five governance rules for a fictional enterprise and decide whether each should be enforced centrally or left to individual application teams.

<details>
<summary>Answer</summary>

Enforce these centrally: allowed regions, required tags, mandatory logging, identity controls such as who may create subscriptions, and a ban on risky public exposure. Those rules must apply to every team.

Leave application-specific instance size, feature flags, and inner workload layout to application teams. Governance sets guardrails. Workload teams operate inside those guardrails. Do not make every team rebuild the same foundation.

</details>

---

## 15. Ownership for Network, Platform, Security, and Application teams

**Practice**

For a company with Network, Platform, Security, and Application teams, assign ownership for the major cloud layers and identify where responsibilities overlap.

<details>
<summary>Answer</summary>

Give the Network team shared networking, including hub connectivity and core routing. Give the Platform team common compute or Kubernetes infrastructure. Give the Security team policy, identity guardrails, and logging. Give Application teams their application resources.

Overlap appears at the edges. Application teams consume the network but do not own it. Platform teams run the cluster, while application teams own the workload on it. Name the owner of each layer so change, incident response, and billing have a clear path.

</details>

---

## 16. Read, write, and administrative access from the ownership model

**Practice**

Take your ownership model and identify where each team should have read, write, or administrative access.

<details>
<summary>Answer</summary>

Grant the Network team administrative access to network infrastructure. Give Application teams permission to consume that network, not to rewrite it. Give developers write access in Development. Do not give them unrestricted Production administration.

Give Security read across environments so they can audit. Give Production write only to the owning team and its pipeline identity. Follow least privilege. Grant what a team needs to operate, not broad access for convenience.

</details>

---

## 17. Blast radius of an accidental resource delete

**Practice**

Imagine an engineer accidentally deletes an application resource. Compare the potential impact when all applications share one broad administrative boundary versus when each workload has appropriate isolation.

<details>
<summary>Answer</summary>

If all applications share one broad administrative boundary, one delete can hit unrelated applications and shared infrastructure. The failure spreads because access and lifecycle sit in one bucket.

If each workload has its own subscription or account, resource group, and Terraform state, the same mistake stays inside that workload. Good architecture does not remove failures. It limits how far they spread.

</details>

---

## 18. Environment factory loop for a per-customer VPC, IAM, and RDS stack

**Practice:** A product gives each customer their own VPC, IAM role, and RDS instance. Write the factory loop (module, pipeline, check). Then say what you refuse to do in the console.

<details>
<summary>Answer</summary>

Write one Terraform module for the stack: network, IAM, compute, and data stores. A pipeline applies that module for each customer. After apply, run a check that the VPC, IAM role, and RDS instance exist and can reach each other.

Refuse to provision that stack in the console. Console clicks break repeatability and least-privilege IAM. A factory stamps the landing zone. It does not hand-build each customer.

</details>

---

## 19. Fictional enterprise on Azure, then the AWS equivalent

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

<details>
<summary>Answer</summary>

On Azure, use a company root management group with Production and Non-Production branches. Under each branch, use subscriptions for Network, Platform, and Applications. Inside those subscriptions, use resource groups that match lifecycle and ownership. Place workloads in chosen regions and availability zones.

On AWS, use an Organization with Production and Non-Production OUs. Use accounts for Network, Platform, and Applications. Place resources inside those accounts. Azure subscriptions and AWS accounts play the isolation role. Management groups and OUs play the governance role.

</details>

---

## 20. Terraform projects and state for each major boundary

**Practice**

Take the enterprise architecture you designed and identify the Terraform project and state that would manage each major boundary.

<details>
<summary>Answer</summary>

Give Network its own Terraform project and state. Give Platform its own project and state. Give each application its own project and state. Split Production state from Non-Production state.

Terraform should follow ownership and lifecycle already set by the cloud design. Do not put the whole enterprise in one project and one state. IaC must reinforce the architecture, not fight it.

</details>

---

## 21. Git commit through application and infrastructure pipelines

**Practice**

For one production application, draw the flow from Git commit through the application pipeline and infrastructure pipeline to the cloud resources. Identify where security checks, approvals, and environment boundaries belong.

<details>
<summary>Answer</summary>

A developer commits to Git. The application pipeline builds and deploys application code. The infrastructure pipeline validates, plans, reviews, and applies infrastructure. Security checks sit in both pipelines before Production.

Approvals sit before Production apply and Production deploy. Environment boundaries keep Dev identities away from Production. Each pipeline uses an identity with only the permissions it needs. Code, infrastructure, identity, state, and delivery then support the same ownership model.

</details>

---

## Part 7 — Integrated Practice

Design a small enterprise cloud from scratch.

The objective is to understand the **reason behind every boundary**, not to memorize a particular company structure.

---

## 22. Integrated Practice — Design a small enterprise cloud

Start with one company containing Dev, UAT, and Production environments. Define the identity boundary, governance hierarchy, subscriptions or accounts, network ownership, platform ownership, and application ownership. Decide where resources should live and which regions and availability zones you need. Decide how to separate access and how Terraform projects and state map to those boundaries.

<details>
<summary>Answer</summary>

Start with one Entra ID tenant or one AWS Organization as the identity boundary. Put governance in management groups or OUs. Use separate subscriptions or accounts for Dev, UAT, and Production. Give Network, Platform, and Application teams their own ownership boundaries.

Place shared networking in the network subscription or account. Place applications in application resource groups inside the matching environment. Choose a primary region from latency, residency, and service needs. Use multiple availability zones in Production. Map Terraform state to those same ownership and environment boundaries.

</details>

---

## 23. Integrated Practice — Present the design to a Lead Architect

Then explain the architecture as if you were presenting it to a Lead Architect:

> "This is our enterprise hierarchy. These are our governance boundaries. These are our environment boundaries. These teams own these resources. These are our Terraform state boundaries. These pipelines are allowed to change these environments."

<details>
<summary>Answer</summary>

Present the reasons, not a copy of another company. Say: this is our enterprise hierarchy, from tenant or Organization down to resource. These are our governance boundaries, where policy and SCPs apply. These are our environment boundaries, so Production stays apart from Non-Production.

These teams own these resources: Network, Platform, Security, and Application. These Terraform states match those ownership lines. These pipelines may change these environments, with stronger approval on Production.

Every boundary answers a question. Who are we? What rules apply? Who owns this? Where does it run? Which resources belong together?

</details>

---

**5-Minute Interview Recall**

Before moving on, you should be able to answer these without looking at the notes:

---

## 24. Interview Recall — Why does an enterprise need a cloud hierarchy?

1. Why does an enterprise need a cloud hierarchy?

<details>
<summary>Answer</summary>

A small project can live in one account or subscription. An enterprise needs stronger boundaries for security, billing, ownership, governance, and operational control.

Providers therefore give higher-level containers. Each boundary should provide a useful control. Do not create a hierarchy only to tidy the portal.

</details>

---

## 25. Interview Recall — Azure tenant, subscription, resource group, and resource

2. What is the difference between an Azure tenant, subscription, resource group, and resource?

<details>
<summary>Answer</summary>

The tenant is the identity boundary in Microsoft Entra ID. A subscription is the billing, quota, and access boundary. A resource group is a logical container for related resources.

A resource is the actual VM, VNet, database, or storage account. One tenant can contain many subscriptions. A resource group is not equal to a subscription.

</details>

---

## 26. Interview Recall — AWS Organization, OU, account, and resource

3. What is the difference between an AWS Organization, OU, account, and resource?

<details>
<summary>Answer</summary>

An AWS Organization is the company container for accounts. An Organizational Unit groups accounts for policy. An account is the isolation, billing, IAM, and quota boundary.

A resource is the VPC, EC2 instance, database, or S3 bucket inside an account. AWS commonly uses accounts as the major enterprise boundary.

</details>

---

## 27. Interview Recall — Why Azure subscriptions are important enterprise boundaries

4. Why are Azure subscriptions important enterprise boundaries?

<details>
<summary>Answer</summary>

A subscription is a major management, billing, quota, and access boundary. You can apply Azure Policy and role assignments at subscription scope.

Separate subscriptions are a stronger boundary than separate resource groups inside one subscription. Enterprises use them to split environments, business units, workloads, or security domains.

</details>

---

## 28. Interview Recall — Why AWS accounts are important enterprise boundaries

5. Why are AWS accounts important enterprise boundaries?

<details>
<summary>Answer</summary>

An AWS account has its own billing context, resource ownership, IAM boundary, quotas, and operational scope. Splitting workloads or environments into accounts reduces blast radius.

This is a key mapping point. Azure often isolates with subscriptions. AWS often isolates with accounts.

</details>

---

## 29. Interview Recall — Is a resource group a region?

6. Is a resource group a region?

<details>
<summary>Answer</summary>

No. A resource group is a logical management container. A region is a physical geographic location.

A resource group can contain resources from different regions. One resource group does not make resources physically reside together.

</details>

---

## 30. Interview Recall — Region versus availability zone

7. What is the difference between a region and an availability zone?

<details>
<summary>Answer</summary>

A region is a geographic area of cloud infrastructure. An availability zone is a physically separate location inside a region.

Zones help with failures inside a region. Multiple regions address larger regional failures. Zones do not replace regional disaster recovery.

</details>

---

## 31. Interview Recall — Why separate Production from Non-Production

8. Why separate Production from Non-Production?

<details>
<summary>Answer</summary>

Production has higher operational risk. It needs stronger access control and change process than Development.

Separation by subscription or account, and by resource group, supports those differences. Environment names alone are not enough.

</details>

---

## 32. Interview Recall — What an Azure Management Group provides

9. What does an Azure Management Group provide?

<details>
<summary>Answer</summary>

A management group sits above subscriptions. It lets you organize subscriptions and apply Azure Policy and role assignments at a broader scope.

Production subscriptions can sit under one branch. Development subscriptions can sit under another. Child subscriptions inherit those controls.

</details>

---

## 33. Interview Recall — Closest AWS equivalent of a management group

10. What is the closest AWS architectural equivalent?

<details>
<summary>Answer</summary>

AWS Organizations and Organizational Units provide similar higher-level governance. You apply Service Control Policies to accounts or OUs as guardrails.

Do not claim the services are identical. Both provide governance above individual workload resources.

</details>

---

## 34. Interview Recall — Why access should follow ownership and least privilege

11. Why should cloud access follow ownership and least privilege?

<details>
<summary>Answer</summary>

Grant access according to what a team needs to operate. The Network team administers the network. An application team only consumes it.

Developers may change Development resources. They should not hold unrestricted Production administration. Least privilege reduces the impact of stolen credentials and operational mistakes.

</details>

---

## 35. Interview Recall — How enterprise boundaries reduce blast radius

12. How do enterprise boundaries reduce blast radius?

<details>
<summary>Answer</summary>

Separating environments, subscriptions or accounts, workloads, and ownership limits how far a mistake can spread. An incorrect deployment then stays inside one application.

The same idea applies to Terraform state, networking, identities, and production pipelines. Good boundaries reduce the resources one change can affect.

</details>

---

## 36. Interview Recall — How Terraform state should map to cloud ownership

13. How should Terraform state map to cloud ownership?

<details>
<summary>Answer</summary>

Terraform projects and state should follow the same ownership and lifecycle as the cloud design. Network state stays with the Network team. Application state stays with the Application team.

Do not put everything in one large state. Align cloud ownership, source code, state, access, and pipelines.

</details>

---

## 37. Interview Recall — Why infrastructure and application pipelines differ

14. Why should infrastructure and application pipelines have different responsibilities?

<details>
<summary>Answer</summary>

An application pipeline builds and deploys application code. An infrastructure pipeline validates, plans, reviews, and applies infrastructure.

Each pipeline uses an identity with only the permissions it needs. Production gets stronger approval. Code, infrastructure, identity, state, and delivery then share one ownership model.

</details>

---

## 38. Interview Recall — Environment factory versus a hand-built landing zone

15. How does an environment factory differ from building one landing zone by hand?

<details>
<summary>Answer</summary>

A landing zone is the ready foundation: identity, governance, networking, and guardrails that workloads deploy into. Building one by hand is acceptable for a single platform.

A factory stamps that foundation many times. One Terraform module describes the stack. A pipeline applies it for each team or customer. IAM stays least-privilege for that stack. A check after apply proves the pieces exist and can reach each other. Nobody provisions in the console.

</details>
