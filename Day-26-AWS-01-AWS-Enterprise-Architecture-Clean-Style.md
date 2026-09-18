# Day 26 — AWS Overlay 01: AWS Enterprise Architecture

The goal of this day is to understand how AWS organizes enterprise environments and how services fit together into a governed cloud platform. The important shift from the Azure lessons is not learning a completely new cloud architecture. The underlying ideas are the same: identity, organizational boundaries, isolation, networking, governance, security, cost, and workload ownership. AWS simply implements many of those ideas using Organizations, OUs, Accounts, IAM, VPCs, Regions, Availability Zones, and AWS resource-level controls.

The core mental model is **AWS Organization → Organizational Units → Accounts → Regions/AZs → VPCs → Subnets → Resources**, with identity, governance, security, networking, logging, monitoring, cost and automation supporting the hierarchy.

---

## Part 1 — Why AWS Enterprise Architecture Exists

A small AWS account can be managed by one person, but enterprise environments quickly become difficult if every application, environment, and team shares the same account. AWS Organizations provides a higher-level structure in which multiple AWS accounts can be centrally governed. Accounts become important isolation boundaries for security, billing, ownership, and operational blast radius.

A common enterprise model separates security, infrastructure, workloads and sandbox accounts into appropriate OUs. For example, Security may contain dedicated security and log-archive accounts, Infrastructure may contain networking and shared services, and Workloads may contain separate Production, UAT and Development accounts.

This is conceptually similar to the Azure hierarchy you learned earlier:

```text
Azure:
Tenant → Management Groups → Subscriptions → Resource Groups

AWS:
Organization → OUs → Accounts → Resources
```

The exact structure depends on organizational needs. The important architectural principle is to use boundaries intentionally rather than putting everything into one account.

Imagine an organization with:

```text
50 application teams
3 environments
central security team
central networking team
shared DevOps platform
```

Decide how you would divide accounts and why.

---

## Part 2 — AWS Organizations and the Management Account

AWS Organizations allows an organization to centrally manage multiple AWS accounts. The organization has a management account that owns the organization-level control plane and can apply organization-wide governance mechanisms.

The management account is highly privileged and should not be treated as a normal workload account. Production applications should not run there simply because it is convenient.

A healthy conceptual separation is:

```text
Management Account
    |
    +--> Organization governance
    |
    +--> Account management
    |
    +--> Billing / organization controls
```

while workloads run elsewhere:

```text
Production Account
    |
    +--> VPC
    +--> ECS / EKS / EC2
    +--> RDS
    +--> S3
```

This separation reduces blast radius. If an application account is compromised, organization-level administration does not automatically need to be exposed to the workload.

AWS CLI example:

```bash
aws organizations describe-organization
```

List accounts:

```bash
aws organizations list-accounts
```

Explain why an enterprise should avoid deploying an Internet-facing production application directly into the AWS Organizations management account.

---

## Part 3 — Organizational Units

Organizational Units, or OUs, group AWS accounts so that governance can be applied to groups of accounts rather than individually.

For example:

```text
Organization
│
├── Production OU
│   ├── E-Commerce Prod
│   └── Payments Prod
│
├── NonProduction OU
│   ├── E-Commerce Dev
│   └── E-Commerce UAT
│
└── Security OU
    ├── Audit
    └── Log Archive
```

An OU is not a network boundary and it is not the same thing as a VPC. It is primarily an organizational and governance structure.

This distinction is important:

```text
OU:
governance grouping

Account:
strong isolation / billing / ownership boundary

VPC:
network boundary

Subnet:
network segmentation
```

Service Control Policies, or SCPs, can be attached to OUs and accounts to restrict what identities can do within those accounts.

Implementation example:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Deny",
      "Action": "*",
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {
          "aws:RequestedRegion": [
            "ap-south-1",
            "us-east-1"
          ]
        }
      }
    }
  ]
}
```

This is a governance restriction, not an IAM permission grant. An SCP can limit the maximum permissions available in an account, even when an IAM principal otherwise has permission.

Design:

```text
Prod OU
NonProd OU
Security OU
Sandbox OU
```

Then decide which governance controls should apply to each OU.

---

## Part 4 — AWS Accounts as Isolation Boundaries

An AWS account is one of the most important enterprise boundaries in AWS. Accounts provide separation for billing, IAM administration, quotas, service configuration, security controls, and operational blast radius.

For example:

```text
dev-account
uat-account
prod-account
```

This is often stronger isolation than putting:

```text
dev
uat
prod
```

into three VPCs inside one account.

Neither approach is automatically correct for every organization, but separate accounts are powerful when environments have different risk levels or ownership.

A production account might contain:

```text
prod VPC
prod EKS
prod RDS
prod S3
prod CloudWatch
```

while the development account contains its own resources.

The application may use the same Terraform module in both accounts:

```text
Terraform module
       |
       +--> Dev account
       |
       +--> UAT account
       |
       +--> Prod account
```

Only environment-specific inputs and credentials change.

For a critical financial application, explain why Production might be placed in a separate AWS account rather than simply a separate VPC.

---

## Part 5 — IAM: Authentication and Authorization

AWS Identity and Access Management, or IAM, controls authentication and authorization for AWS resources. The concepts are the same as those learned in Azure: authentication answers who or what is making the request, while authorization determines what that identity is allowed to do.

Important AWS IAM concepts include:

```text
User
Group
Role
Policy
Permission
Trust policy
```

Modern workload architectures generally prefer IAM roles over long-lived access keys for applications and automation.


Example policy allowing an application to read objects from a specific S3 path:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject"
      ],
      "Resource": "arn:aws:s3:::my-app-bucket/config/*"
    }
  ]
}
```

This is much narrower than:

```json
"Action": "s3:*",
"Resource": "*"
```

Create a mental IAM role for:

```text
Application → read S3 objects
```

Then ask what it should be able to do:

```text
GetObject? Yes
PutObject? No
DeleteObject? No
CreateBucket? No
```

This is least privilege in practice.

---

## Part 6 — IAM Roles and Trust Policies

An IAM policy says what an identity can do. A trust policy says **who is allowed to assume a role**.

This is a very important AWS distinction.


For example, an EC2 instance can assume an IAM role through an instance profile, and the role can then allow access to S3.

The application does not need an access key embedded in its configuration.

A simplified trust relationship looks conceptually like:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

The role's permissions policy separately determines what the EC2 workload can access.

If an EC2 application receives:

```text
AccessDenied
```

ask two different questions:

```text
Can EC2 assume the role?
        ↓
Does the role have the required permission?
```

This avoids treating every IAM failure as the same problem.

---

## Part 7 — IAM Identity Center and Human Access

Enterprise users should generally not receive permanent access keys simply to log into AWS. AWS IAM Identity Center provides centralized workforce access to AWS accounts and applications and can integrate with an organization's identity provider.

A conceptual model is:

```text
Employee
   |
   v
Corporate Identity Provider
   |
   v
IAM Identity Center
   |
   +--> Dev Account
   +--> UAT Account
   +--> Prod Account
```

The same person can receive different permission sets depending on the account.

For example:

```text
Developer:
Dev → Developer access
UAT → limited access
Prod → read-only

Platform Engineer:
Dev → Admin-like platform access
Prod → controlled platform access
```

This is much more manageable than creating individual IAM users in every account.

Design access for:

```text
Developer
DevOps Engineer
Security Engineer
Auditor
Application Support
```

across:

```text
Dev
UAT
Prod
```

Think in terms of roles and permission sets rather than individual permissions.

---

## Part 8 — Regions and Availability Zones

AWS Regions are geographically separate infrastructure locations, and Availability Zones are isolated locations within a Region designed to provide failure isolation.

For example:

```text
Region: ap-south-1
│
├── AZ-a
├── AZ-b
└── AZ-c
```

A production application should not assume that one Availability Zone will always be available. Workloads can be distributed across multiple AZs to improve availability.

For example:

```text
Application Load Balancer
       |
       +---- AZ-a → App
       |
       +---- AZ-b → App
       |
       +---- AZ-c → App
```

This is a different concept from deploying the application in multiple Regions. Multi-AZ generally addresses failures within a Region, while multi-Region architecture addresses larger regional failure scenarios and geographic requirements.

For a production application, decide whether it needs:

```text
Single AZ
Multi-AZ
Multi-Region
```

Then justify the decision using:

```text
Availability requirement
Recovery objective
Latency
Cost
Operational complexity
Data architecture
```

---

## Part 9 — VPC as the AWS Network Boundary

A Virtual Private Cloud, or VPC, is the fundamental AWS networking boundary. It provides the private IP address space and networking components used by workloads.

Example:

```text
VPC
10.20.0.0/16
│
├── Public subnet
│
├── Private application subnet
│
└── Private database subnet
```

This is conceptually similar to Azure VNet.

AWS VPC networking then adds:

```text
Subnets
Route Tables
Internet Gateway
NAT Gateway
Security Groups
Network ACLs
VPC Endpoints
Load Balancers
```

A common production architecture is:

```text
Internet
   |
   v
Application Load Balancer
   |
   v
Private Application Subnets
   |
   v
Private Database Subnets
```

The application servers do not need public IP addresses simply because users access the application.

Design a VPC for:

```text
Internet-facing web application
Private backend
Private database
Outbound internet access
```

Draw the public and private subnets before creating resources.

---

## Part 10 — Public and Private Subnets

An AWS subnet is commonly described as public or private based on its routing.

A subnet is effectively public when its route table provides a path through an Internet Gateway and resources have the required public addressing.

A private subnet does not have a direct route to the Internet Gateway for outbound internet access. It can use a NAT Gateway for outbound connectivity.

Example:

```text
Public subnet
10.20.1.0/24
     |
     v
Internet Gateway
     |
  Internet


Private subnet
10.20.2.0/24
     |
     v
NAT Gateway
     |
     v
Internet
```

This distinction is based on routing, not simply the subnet name.

A subnet called:

```text
private-subnet
```

is not private merely because someone named it that way.

Inspect a subnet's route table and determine whether it is truly public or private.

Ask:

```text
Where does 0.0.0.0/0 point?
Does the subnet have direct Internet Gateway routing?
Does the workload have a public IP?
```

---

## Part 11 — Security Groups and Network ACLs

AWS Security Groups are stateful virtual firewalls associated with resources such as network interfaces. They control inbound and outbound traffic using rules.

Network ACLs operate at the subnet level and are stateless, meaning return traffic must also be explicitly allowed.

A useful mental model is:

```text
Security Group:
resource-level, stateful

Network ACL:
subnet-level, stateless
```

For many application architectures, Security Groups are the primary workload-level network control.

Example:

```text
ALB Security Group
   ↓ allows TCP 443
App Security Group
   ↓ allows TCP 8080
Database Security Group
   ↓ allows TCP 5432
```

Instead of allowing the entire VPC to access PostgreSQL:

```text
0.0.0.0/0 → 5432
```

allow the application security group as the source where appropriate.

This creates an identity-like network relationship:

```text
App SG → DB SG
```

rather than relying only on IP addresses.

Design:

```text
ALB → App
App → RDS
Internet → RDS
```

The intended rules should be:

```text
ALB → App: allowed
App → RDS: allowed
Internet → RDS: denied
```

---

## Part 12 — Route Tables, Internet Gateway and NAT Gateway

AWS route tables determine where traffic is sent. An Internet Gateway provides a path between a VPC and the public internet, while a NAT Gateway allows resources in private subnets to initiate outbound internet connections without being directly reachable from the internet.

Typical architecture:

```text
                 Internet
                    |
             Internet Gateway
                    |
             Public Subnet
                    |
               NAT Gateway
                    |
             Private Subnet
                    |
                 App
```

The NAT Gateway itself is placed in a public subnet because it needs connectivity toward the Internet Gateway.

A private application's default route can therefore point to the NAT Gateway.


Implementation example:

```bash
aws ec2 describe-route-tables
```

Inspect the NAT gateway:

```bash
aws ec2 describe-nat-gateways
```

Explain why this does not work:

```text
Private App
   ↓
Internet Gateway
```

and why this does:

```text
Private App
   ↓
NAT Gateway
   ↓
Internet Gateway
   ↓
Internet
```

---

## Part 13 — VPC Endpoints and Private AWS Service Access

VPC endpoints allow workloads to access supported AWS services without necessarily traversing the public internet.

This is especially useful for private workloads accessing services such as S3 or DynamoDB and for many AWS APIs through interface endpoints.


There are different endpoint models, including gateway endpoints and interface endpoints. The implementation depends on the AWS service.

For example, an S3 gateway endpoint can allow private subnet workloads to access S3 without requiring NAT for that traffic.

Compare:

```text
Private EC2 → S3 through NAT
Private EC2 → S3 through VPC endpoint
```

Consider:

```text
Network path
Security
Cost
Availability
Architecture simplicity
```

This is the AWS equivalent of the broader private-service-access concept you learned with Azure Private Endpoint, although the exact AWS implementation and service behavior differ.

---

## Part 14 — Load Balancing in AWS

AWS provides several load-balancing options through Elastic Load Balancing.

The two most important for this course are:

```text
Application Load Balancer
Network Load Balancer
```

An Application Load Balancer operates at Layer 7 and understands HTTP/HTTPS traffic. It can route based on hostnames and URL paths.

Example:

```text
Client
  |
  v
ALB
  |
  +--> /api/* → API
  |
  +--> /web/* → Web
```

A Network Load Balancer operates at Layer 4 and is designed for high-performance TCP/UDP/TLS traffic patterns.

The same underlying reasoning applies as with Azure:

```text
Layer 4:
connection-level traffic

Layer 7:
application-aware HTTP routing
```

Choose between ALB and NLB for:

```text
HTTP path-based routing
TCP service
```

Explain the protocol-level requirement rather than choosing based only on service familiarity.

---

## Part 15 — Centralized Logging, Security and Audit

Enterprise AWS architecture needs centralized visibility. CloudTrail records AWS API activity, while services such as CloudWatch provide monitoring, metrics, logs, and alarms.

A common architecture separates security logging from workload accounts:

```text
Workload Accounts
       |
       +---- CloudTrail
       |
       +---- Logs
       |
       v
Central Log Archive / Security Account
```

This is useful because a compromised workload account should not automatically be able to erase the organization's audit history.

CloudTrail can be inspected with:

```bash
aws cloudtrail describe-trails
```

CloudWatch resources can be inspected using:

```bash
aws cloudwatch list-metrics
```

The broader enterprise principle is:

```text
Workload ownership
      ≠
Security evidence ownership
```

Design centralized audit logging for:

```text
Dev Account
UAT Account
Prod Account
```

Explain where logs should live and who should have permission to modify them.

---

## Part 16 — AWS Config, Guardrails and Governance

AWS Config records resource configuration and can evaluate resources against desired rules. Combined with Organizations, SCPs, IAM, CloudTrail, and security services, it can form a layered governance architecture.

Think of the controls as different layers:

```text
SCP
 ↓
IAM
 ↓
Network Controls
 ↓
Resource Policies
 ↓
Workload Configuration
 ↓
Monitoring / Detection
```

These controls are not interchangeable.

For example:

```text
SCP:
"Accounts in this OU cannot use this capability."

IAM:
"This role can perform these actions."

Security Group:
"This network traffic is allowed."

S3 Bucket Policy:
"This principal/network condition can access this bucket."
```

For the requirement:

> “Production resources must not be deployed outside approved Regions.”

Identify which controls could enforce or detect the requirement and distinguish preventive controls from detective controls.

---

## Part 17 — AWS Cost and Billing Architecture

AWS billing is closely connected to account architecture. Separate accounts can make ownership and cost attribution clearer.

For example:

```text
Production Account
    → Production spend

Development Account
    → Development spend

Sandbox Accounts
    → Experimentation spend
```

AWS Organizations can consolidate billing while preserving account-level visibility.

Tags can also support cost allocation:

```text
Environment=Production
Application=ShopSphere
Owner=Payments
CostCenter=FIN-001
```

But tags should not be treated as the only cost-control mechanism. Account boundaries, budgets, service quotas, architecture choices, and monitoring are also important.

Design cost ownership for:

```text
50 teams
3 environments
shared networking
shared security services
shared CI/CD platform
```

Decide which costs should be:

```text
team-owned
platform-owned
centrally allocated
```

---

## Part 18 — Multi-Account Enterprise Architecture

Now combine the concepts.

A realistic AWS enterprise might look like:

```text
AWS Organization
│
├── Security OU
│   ├── Security Account
│   └── Log Archive Account
│
├── Infrastructure OU
│   ├── Network Account
│   └── Shared Services Account
│
├── Production OU
│   ├── Application A Prod
│   ├── Application B Prod
│   └── Application C Prod
│
└── NonProduction OU
    ├── Application A Dev
    ├── Application A UAT
    └── Sandbox
```

Networking can then be organized independently:

```text
Network Account
      |
      v
Transit Gateway
      |
      +---- Prod Account VPC
      |
      +---- UAT Account VPC
      |
      +---- Shared Services VPC
      |
      +---- Security VPC
```

Identity can be centralized:

```text
Corporate IdP
      |
      v
IAM Identity Center
      |
      +---- Account access
      +---- Permission sets
```

Logging can be centralized:

```text
All accounts
    |
    v
Central logging/security account
```

This is the type of architecture a Senior/Lead DevOps engineer should be able to explain at a high level.

Draw the complete architecture and label:

```text
Identity boundary
Governance boundary
Account boundary
Network boundary
Workload boundary
Logging boundary
Cost boundary
```

---

## Part 19 — Infrastructure as Code Across AWS Accounts

Terraform can manage resources across multiple AWS accounts using provider configurations and IAM role assumption.

A common enterprise model is:

```text
CI/CD Identity
      |
      +---- AssumeRole → Dev Account
      |
      +---- AssumeRole → UAT Account
      |
      +---- AssumeRole → Prod Account
```

Terraform can define provider aliases:

```hcl
provider "aws" {
  alias  = "dev"
  region = "ap-south-1"

  assume_role {
    role_arn = "arn:aws:iam::<DEV-ACCOUNT-ID>:role/TerraformDeployRole"
  }
}

provider "aws" {
  alias  = "prod"
  region = "ap-south-1"

  assume_role {
    role_arn = "arn:aws:iam::<PROD-ACCOUNT-ID>:role/TerraformDeployRole"
  }
}
```

Resources can then use the appropriate provider:

```hcl
resource "aws_s3_bucket" "app" {
  provider = aws.prod
  bucket   = "shopsphere-prod-example"
}
```

In a real enterprise, you would normally structure this more carefully using modules, separate state, environment directories/workspaces where appropriate, and tightly scoped deployment roles.

The important architecture is:

```text
One central CI/CD system
        |
        v
Controlled role assumption
        |
        +--> Dev
        +--> UAT
        +--> Prod
```

Design separate Terraform state and deployment roles for:

```text
dev
uat
prod
```

Then explain why one shared highly privileged role is undesirable.

---

## Part 20 — Senior/Lead Architecture Exercise

Design AWS infrastructure for ShopSphere with:

```text
50 application teams
Dev / UAT / Production
Central security
Central networking
Centralized audit logs
Private workloads
Internet-facing applications
Terraform-based infrastructure
CI/CD through Azure DevOps
```

Your architecture should include:

```text
AWS Organization
        |
        +--> Security OU
        +--> Infrastructure OU
        +--> Production OU
        +--> NonProduction OU
```

Inside the accounts, consider:

```text
VPCs
Subnets
Transit Gateway
Security Groups
NAT Gateway
VPC Endpoints
ALB
EKS/ECS/EC2
RDS
S3
CloudTrail
CloudWatch
IAM Roles
```

Then answer:

1. Why separate Production and NonProduction accounts?
2. Why have a dedicated security/logging account?
3. Why centralize network connectivity?
4. How does a CI/CD pipeline deploy without storing AWS access keys?
5. How does an application access S3 privately?
6. How does an application access RDS?
7. Where should internet-facing traffic enter?
8. Where should private application traffic run?
9. What controls prevent a team from creating resources in an unapproved Region?
10. How do you investigate an unauthorized AWS API call?
11. How do you separate Terraform state between environments?
12. What happens if the production deployment role is compromised?
13. What is the blast radius of one compromised application account?
14. Which controls are preventive and which are detective?

---

## Part 21 — Practice: Build a Small AWS Enterprise Lab

Create a deliberately small multi-account simulation if you have access to multiple AWS accounts. If you only have one account, simulate the organizational model conceptually and build the network/workload portions inside a dedicated lab account.

Start with:

```text
AWS Organization
  |
  +--> Lab-Security
  +--> Lab-NonProd
  +--> Lab-Prod
```

Within a workload account, create:

```text
VPC
├── Public subnet
├── Private app subnet
└── Private data subnet
```

Then implement:

```text
Internet Gateway
NAT Gateway
Route Tables
Security Groups
ALB
EC2 or ECS
S3
VPC Endpoint
CloudWatch
CloudTrail
IAM Role
```

A useful sequence is:

```text
1. Create VPC
2. Create subnets
3. Create route tables
4. Configure Internet Gateway
5. Configure NAT
6. Configure Security Groups
7. Deploy workload
8. Add S3 access through IAM role
9. Add private S3 access if appropriate
10. Inspect logs
```

Do not create everything at once. Build the network first, then security, then workload, then identity.

---

## Part 22 — Failure Drill: IAM AccessDenied

Scenario:

```text
EC2 application
      |
      v
S3
      |
      v
AccessDenied
```

Work through:

```text
1. Does EC2 have an IAM role?
2. Can EC2 obtain credentials for that role?
3. Does the role policy allow s3:GetObject?
4. Is the resource ARN correct?
5. Is the bucket policy denying access?
6. Is an SCP restricting the action?
7. Are there other policy conditions?
```

Do not immediately add:

```json
"Action": "*",
"Resource": "*"
```

That may hide the real problem while creating excessive privilege.

The Senior/Lead approach is:

```text
Identify caller
→ evaluate identity permissions
→ evaluate resource policies
→ evaluate organization restrictions
→ identify explicit deny
→ make smallest safe change
```

---

## Part 23 — Failure Drill: Private Subnet Cannot Reach Internet

Scenario:

```text
Private EC2
   |
   | HTTPS
   v
External API
```

Connection times out.

Use:

```text
DNS
 ↓
Route table
 ↓
NAT Gateway
 ↓
Internet Gateway
 ↓
Security Group / NACL
 ↓
External service
```

Check:

```bash
aws ec2 describe-route-tables
aws ec2 describe-nat-gateways
aws ec2 describe-security-groups
```

Common failure possibilities:

```text
No default route
Wrong NAT Gateway
NAT Gateway in wrong subnet
NAT Gateway unavailable
Security Group blocks egress
NACL blocks traffic
DNS failure
External service failure
```

The important lesson is the same as Azure:

**A connectivity problem should be investigated layer by layer instead of randomly changing security rules.**

---

## Part 24 — Failure Drill: Multi-Account Deployment Failure

Scenario:

```text
Azure DevOps
    |
    v
AWS Production Account
    |
    v
Terraform
    |
    v
AccessDenied
```

Investigate:

```text
Pipeline identity
       ↓
Federation/OIDC
       ↓
AWS role assumption
       ↓
Trust policy
       ↓
Role permissions
       ↓
Resource policy
       ↓
SCP
```

This is particularly important in enterprise environments because permissions can exist at multiple layers.

A role can have an apparently correct IAM policy and still be unable to perform an action because an organization-level SCP denies it.

Draw the complete authentication and authorization chain and identify where each decision is made.

---

## Part 25 — Azure ↔ AWS Enterprise Architecture Mapping

The underlying concepts should now feel familiar.

| Concept | Azure | AWS |
|---|---|---|
| Cloud identity | Microsoft Entra ID | IAM / IAM Identity Center |
| Organization boundary | Tenant | AWS Organization |
| Governance grouping | Management Group | OU |
| Account-like isolation | Subscription | AWS Account |
| Resource grouping | Resource Group | No direct equivalent |
| Regional infrastructure | Region | Region |
| Failure-isolated location | Availability Zone | Availability Zone |
| Virtual network | VNet | VPC |
| Subnet | Subnet | Subnet |
| Network security | NSG | Security Group / NACL |
| Routing | UDR / Route Table | Route Table |
| Central connectivity | Hub-Spoke / Virtual WAN | Transit Gateway |
| Private PaaS access | Private Endpoint | VPC Endpoint / PrivateLink |
| Outbound NAT | NAT Gateway | NAT Gateway |
| L4 load balancing | Azure Load Balancer | NLB |
| L7 load balancing | Application Gateway | ALB |
| Audit API activity | Activity Log | CloudTrail |
| Monitoring | Azure Monitor | CloudWatch |
| Policy | Azure Policy | SCP / Config / other controls |
| Secret management | Key Vault | Secrets Manager |
| Container registry | ACR | ECR |
| Kubernetes | AKS | EKS |
| IaC | Terraform / Bicep | Terraform / CloudFormation / CDK |

One important difference to remember is the organizational hierarchy:

```text
Azure:
Tenant
  → Management Group
  → Subscription
  → Resource Group
  → Resource

AWS:
Organization
  → OU
  → Account
  → Region/VPC
  → Resource
```

Do not force the mapping to be perfectly one-to-one. The purpose is to understand the equivalent architectural responsibility.

---

## Part 26 — 5-Minute Recall

Without looking at the notes, explain:

1. Why does AWS provide Organizations?
2. What is an AWS OU?
3. Why are AWS accounts important isolation boundaries?
4. Why should production workloads not run in the management account?
5. What does an SCP do?
6. How is an SCP different from an IAM policy?
7. What is an IAM role?
8. What is a role trust policy?
9. Why are roles preferable to long-lived access keys for workloads?
10. What is IAM Identity Center used for?
11. What is the difference between Region and Availability Zone?
12. What makes an AWS subnet public?
13. What is the difference between Security Group and NACL?
14. What does a NAT Gateway do?
15. What does an Internet Gateway do?
16. What problem does a VPC endpoint solve?
17. What is the difference between ALB and NLB?
18. Why centralize CloudTrail/security logs?
19. How would you enforce an approved-Region requirement?
20. How would Azure DevOps deploy to AWS without storing permanent AWS access keys?
21. How would you troubleshoot `AccessDenied`?
22. How would you troubleshoot a private subnet internet timeout?
23. Why separate Terraform state by environment/account?
24. What is the blast radius of an AWS account?
25. What is the AWS equivalent architectural idea for Azure Management Groups and Subscriptions?

The most important mental model is:

**Organization → OU → Account → Network → Workload**

with:

**Identity + Governance + Security + Logging + Cost**

around it.

At Senior/Lead level, you should be able to explain not just what an AWS service does, but **why an enterprise would place it at a particular organizational boundary, what failure it prevents, what blast radius it creates, and how it is operated through IaC and CI/CD.**

---

## Part 27 — Cleanup

Delete only resources created specifically for the lab.

For Terraform-managed resources:

```bash
terraform destroy
```

Inspect the account before deleting:

```bash
aws resourcegroupstaggingapi get-resources
```

For specific networking resources, verify dependencies before deletion:

```text
Load Balancer
↓
Target Group
↓
EC2/ECS
↓
NAT
↓
Subnets
↓
VPC
```

Do not delete shared enterprise resources or organization-level infrastructure simply because it was involved in the exercise.

If you created a dedicated lab account, account-level cleanup may be preferable to manually deleting dozens of resources, depending on how the lab environment is managed.

The learning lifecycle should remain:

```text
Create
  ↓
Inspect
  ↓
Use
  ↓
Break
  ↓
Troubleshoot
  ↓
Recover
  ↓
Destroy
  ↓
Verify
```

The final Day 26 mental model is: **Organization → OU → Account → Region/AZ → VPC → Subnet → Workload**, with IAM controlling identity and authorization, SCPs and other governance controls defining boundaries, networking controlling traffic paths, CloudTrail/CloudWatch providing visibility, and Terraform plus CI/CD making the platform repeatable. At Senior/Lead level, the goal is to explain why each boundary exists, what blast radius it creates, how access is controlled, and how the platform is operated safely at scale.
