# Day 28 — AWS Overlay 03: AWS Networking

The goal of this day is to build an AWS networking mental model on top of the networking concepts already learned in the core course and Azure overlay. The important part is not memorizing VPC commands. You should be able to look at an AWS architecture, trace a packet from source to destination, identify the routing and security controls involved, and troubleshoot the failure one layer at a time.

The core mental model is:

**Source → DNS → Destination IP → Route Table → Security → Port → Service → Application**

For internet-facing traffic:

**Client → DNS → ALB/NLB → Target → Application**

For private AWS service access:

**Application → DNS → VPC Endpoint → AWS Service**

For private outbound access:

**Private Subnet → NAT Gateway → Internet Gateway → Internet**

---

## Part 1 — AWS VPC and the Network Boundary

A Virtual Private Cloud, or VPC, is the fundamental AWS network boundary for workloads. It provides a private IPv4 and/or IPv6 address space and contains subnets, route tables, security groups, network ACLs, gateways, endpoints, and other networking components. The VPC itself does not make an application private or public. The actual behavior depends on subnet routing, addressing, security controls, and the services inside it.

For example, a production VPC might use:

```text
VPC: 10.20.0.0/16

Public subnets:
10.20.1.0/24
10.20.2.0/24

Private application subnets:
10.20.11.0/24
10.20.12.0/24

Private database subnets:
10.20.21.0/24
10.20.22.0/24
```

This is conceptually similar to an Azure VNet:

```text
Azure VNet ↔ AWS VPC
Azure Subnet ↔ AWS Subnet
```

The important difference is not the name. The underlying responsibility is the same: define the network space and provide the foundation on which routing and security are built.

You can inspect a VPC with:

```bash
aws ec2 describe-vpcs
```

Practice:

Design a VPC for:

```text
Internet-facing frontend
Private backend
Private database
Private AWS service access
Outbound internet access
```

Before you create anything, choose the CIDR ranges. Make sure they will not conflict with networks that may later connect through VPN, Direct Connect, or Transit Gateway.

---

## Part 2 — Subnets and Availability Zones

A subnet is a range of IP addresses inside a VPC and is associated with a single Availability Zone. Production architectures commonly distribute subnets across multiple Availability Zones so that workloads do not depend on one physical failure domain.

A typical structure is:

```text
VPC
│
├── AZ-a
│   ├── Public subnet
│   ├── Private app subnet
│   └── Private data subnet
│
└── AZ-b
    ├── Public subnet
    ├── Private app subnet
    └── Private data subnet
```

The subnet's route table determines where traffic goes. Therefore, the words “public subnet” and “private subnet” describe routing behavior rather than names.

For example:

```text
Public subnet:
0.0.0.0/0 → Internet Gateway

Private subnet:
0.0.0.0/0 → NAT Gateway
```

Inspect subnets:

```bash
aws ec2 describe-subnets
```

Inspect their Availability Zones:

```bash
aws ec2 describe-subnets \
  --query 'Subnets[*].[SubnetId,AvailabilityZone,CidrBlock]' \
  --output table
```

A production application should normally have capacity in more than one AZ where its availability requirements justify it.

Practice:

Design:

```text
2 AZs
2 public subnets
2 private app subnets
2 private database subnets
```

Then explain which workloads belong in each subnet and why.

---

## Part 3 — Route Tables

Route tables determine where packets should go. Every subnet is associated with a route table, either explicitly or through the VPC's main route table.

A route contains:

```text
Destination CIDR
        +
Target
```

For example:

```text
10.20.0.0/16 → local
0.0.0.0/0    → Internet Gateway
```

The `local` route allows communication within the VPC's address space.

A private subnet might instead have:

```text
10.20.0.0/16 → local
0.0.0.0/0    → NAT Gateway
```

Inspect route tables:

```bash
aws ec2 describe-route-tables
```

A useful troubleshooting question is:

> “Which route actually matches the destination IP?”

Do not simply check whether a route table exists. Check whether the correct route exists and whether its target is healthy and appropriate.

Practice:

Suppose an application in `10.20.11.0/24` wants to reach:

```text
10.30.0.10
```

Determine whether the route table has a specific route for `10.30.0.0/16` or whether the default route will be used.

---

## Part 4 — Internet Gateway and Public Connectivity

An Internet Gateway, or IGW, provides a path between a VPC and the internet. A subnet becomes publicly routable when its route table sends internet-bound traffic to an Internet Gateway and the workload has appropriate public addressing.

A simplified path is:

```text
Internet
   ↓
Internet Gateway
   ↓
Public subnet
   ↓
EC2 / Load Balancer
```

The presence of an Internet Gateway alone does not make every resource in the VPC publicly accessible.

You still need:

```text
Correct route
+
Public addressing where required
+
Security Group/NACL rules
+
Application listening
```

Create an Internet Gateway:

```bash
aws ec2 create-internet-gateway
```

Attach it:

```bash
aws ec2 attach-internet-gateway \
  --vpc-id <VPC-ID> \
  --internet-gateway-id <IGW-ID>
```

Practice:

Explain why this architecture is not enough:

```text
VPC
  |
Internet Gateway
```

You must still have the correct subnet route and workload addressing/security.

---

## Part 5 — NAT Gateway and Private Outbound Access

A NAT Gateway lets resources in private subnets start outbound connections to the internet without direct inbound internet connectivity.

The typical architecture is:

```text
Private EC2
    ↓
Private Route Table
    ↓
NAT Gateway
    ↓
Internet Gateway
    ↓
Internet
```

The NAT Gateway itself is normally placed in a public subnet.

A public subnet's route might be:

```text
0.0.0.0/0 → Internet Gateway
```

while the private application's route is:

```text
0.0.0.0/0 → NAT Gateway
```

Create a public IP:

```bash
aws ec2 allocate-address \
  --domain vpc
```

This allocates an Elastic IP — AWS's name for a static public IP address that remains yours until you release it.

Create the NAT Gateway:

```bash
aws ec2 create-nat-gateway \
  --subnet-id <PUBLIC-SUBNET-ID> \
  --allocation-id <EIP-ALLOCATION-ID>
```

Then configure the private route table to use the NAT Gateway.

A production architecture may use a NAT Gateway per AZ to reduce dependency on cross-AZ paths and improve resilience, but this also increases cost.

Practice:

Your private application needs to call:

```text
https://api.example.com
```

but must not accept inbound internet connections.

Design the complete outbound path and identify every component involved.

---

## Part 6 — Security Groups

Security Groups are stateful virtual firewalls associated with resources such as EC2 network interfaces and many AWS managed services. They control inbound and outbound traffic using rules based on protocol, port, source, and destination.

A strong production pattern is to reference Security Groups rather than broad CIDR ranges when the relationship is between application tiers.

For example:

```text
ALB Security Group
       ↓
allows TCP 8080
       ↓
App Security Group
       ↓
allows TCP 5432
       ↓
Database Security Group
```

Instead of:

```text
0.0.0.0/0 → 5432
```

you can allow the application tier's Security Group to access the database tier where the architecture supports it.

Inspect Security Groups:

```bash
aws ec2 describe-security-groups
```

A Security Group is stateful. When it allows an inbound connection, it automatically allows the corresponding response traffic.

Practice:

Design Security Groups for:

```text
Internet → ALB: 443
ALB → App: 8080
App → RDS: 5432
Internet → RDS: denied
```

Then identify which source should be used for each rule.

---

## Part 7 — Network ACLs

Network Access Control Lists, or NACLs, provide subnet-level traffic filtering. Unlike Security Groups, NACLs are stateless, so you must consider both directions of a connection.

A simplified mental model is:

```text
Security Group:
resource-level + stateful

NACL:
subnet-level + stateless
```

NACL rules have rule numbers, and AWS evaluates them in order.

Inspect NACLs:

```bash
aws ec2 describe-network-acls
```

NACLs can be useful as an additional subnet-level control, but they can also make troubleshooting more complicated if the organization uses them extensively.

A common troubleshooting mistake is checking only Security Groups when a NACL is actually blocking traffic.

Practice:

Suppose:

```text
Security Group allows TCP 443
```

but the connection still fails.

Check:

```text
NACL inbound
NACL outbound
Route table
Application
```

Because NACLs are stateless, you must allow return traffic explicitly.

---

## Part 8 — DNS and Route 53

DNS converts names into addresses and is therefore one of the first things to test when an application cannot reach a service.

For example:

```text
api.example.com
      ↓
DNS
      ↓
IP address
```

AWS Route 53 provides DNS services including public hosted zones and private hosted zones. A hosted zone is simply the container that holds the DNS records for one domain.

A private hosted zone can provide internal names such as:

```text
db.internal.example.com
```

for workloads inside associated VPCs.

You can inspect Route 53 hosted zones:

```bash
aws route53 list-hosted-zones
```

Test DNS from Linux:

```bash
dig api.example.com
```

or:

```bash
nslookup api.example.com
```

A DNS result should always be interpreted in the context of the architecture.

If the application should use a private endpoint but DNS returns a public address, the network path may be completely different from what you intended.

Practice:

Create a private DNS name for an internal application and verify resolution from inside the VPC.

Then break the DNS association and observe the failure.

---

## Part 9 — VPC Endpoints

VPC endpoints allow private workloads to access supported AWS services without relying on public internet paths.

There are two important categories to understand:

```text
Gateway endpoint
Interface endpoint
```

Gateway endpoints are commonly used for services such as S3 and DynamoDB. Interface endpoints use private network interfaces, and AWS PrivateLink powers them. PrivateLink is the AWS technology that exposes a service through a private IP in your VPC instead of a public address.

A simplified architecture is:

```text
Private workload
      ↓
VPC Endpoint
      ↓
AWS Service
```

For example, a private EC2 instance can access S3 through an S3 gateway endpoint instead of sending the traffic through a NAT Gateway.

This can improve the network design and may reduce NAT processing costs for eligible traffic.

Inspect endpoints:

```bash
aws ec2 describe-vpc-endpoints
```

Practice:

Compare:

```text
Private EC2 → NAT → Internet → S3
```

with:

```text
Private EC2 → VPC Endpoint → S3
```

Explain the differences in network path, security, availability, and cost.

---

## Part 10 — VPC Peering

VPC Peering creates a private network connection between two VPCs.

For example:

```text
VPC A
10.10.0.0/16
      |
      | Peering
      |
VPC B
10.20.0.0/16
```

The VPCs must have non-overlapping address spaces.

Creating the peering connection is not enough. You also need the correct routes and Security Group/NACL rules.

The traffic path therefore becomes:

```text
Source
 ↓
Source route table
 ↓
VPC Peering
 ↓
Destination route table
 ↓
Security
 ↓
Destination
```

Inspect peerings:

```bash
aws ec2 describe-vpc-peering-connections
```

VPC Peering is useful for direct VPC-to-VPC connectivity, but large organizations often need a more centralized connectivity architecture.

Practice:

Create a conceptual design for:

```text
Shared Services VPC
        ↕
Application VPC
```

Identify the routes required on both sides.

---

## Part 11 — Transit Gateway

AWS Transit Gateway provides a central network hub for connecting multiple VPCs and external networks.

Instead of building many direct peerings:

```text
A ↔ B
A ↔ C
A ↔ D
B ↔ C
B ↔ D
C ↔ D
```

you can use:

```text
          Transit Gateway
          /      |      \
        VPC A   VPC B   VPC C
```

This makes the connectivity model easier to scale and centralize, although it introduces a shared infrastructure dependency that needs appropriate availability, routing design, and governance.

Transit Gateway can also participate in hybrid connectivity architectures involving VPN and Direct Connect.

The key Senior/Lead question is:

> “At what scale does direct connectivity become difficult to manage, and what centralized topology gives us better control?”

Practice:

Imagine 50 application VPCs plus:

```text
On-premises
Security VPC
Shared Services VPC
Central inspection
```

Design how Transit Gateway could connect them.

---

## Part 12 — AWS Network Firewall and Centralized Inspection

AWS Network Firewall provides managed network firewall capabilities for centralized inspection and traffic control.

A common architecture is:

```text
Application VPC
      ↓
Transit Gateway
      ↓
Inspection VPC
      ↓
Network Firewall
      ↓
Internet / destination
```

The important point is that the firewall only helps if routing sends traffic through it.

Therefore:

```text
Firewall policy
+
Correct routing
```

are both required.

This is the same fundamental principle learned with Azure Firewall:

**A security appliance cannot inspect traffic that never reaches it.**

Practice:

Design centralized outbound inspection for:

```text
VPC A
VPC B
VPC C
```

Then identify which route tables must change to force the traffic through the inspection path.

---

## Part 13 — Application Load Balancer

An Application Load Balancer, or ALB, operates at Layer 7 and understands HTTP/HTTPS traffic. It can route requests based on hostnames, URL paths, headers and other application-level information.

For example:

```text
Client
  ↓
ALB
  |
  +-- /api/* → API target group
  |
  +-- /web/* → Web target group
```

The ALB uses target groups and health checks to determine which targets should receive traffic.

Inspect ALBs:

```bash
aws elbv2 describe-load-balancers
```

Inspect target groups:

```bash
aws elbv2 describe-target-groups
```

Inspect target health:

```bash
aws elbv2 describe-target-health \
  --target-group-arn <TARGET-GROUP-ARN>
```

A registered target is not automatically a healthy target. Health checks provide important evidence about whether the backend is ready to receive traffic.

Practice:

Create an ALB architecture for:

```text
api.example.com → API
www.example.com → frontend
```

Then explain how hostname-based routing works.

---

## Part 14 — Network Load Balancer

A Network Load Balancer, or NLB, operates primarily at Layer 4. It serves TCP, UDP and TLS traffic patterns that need connection-level load balancing.

The distinction is:

```text
ALB:
HTTP/HTTPS-aware
Layer 7

NLB:
TCP/UDP/TLS connection-oriented
Layer 4
```

For a normal web API requiring URL-path routing:

```text
ALB
```

may be appropriate.

For a TCP-based service:

```text
NLB
```

may be more appropriate.

Do not choose based only on performance assumptions. Start with the protocol and traffic requirements.

Practice:

Choose a load balancer for:

```text
HTTP path-based routing
Raw TCP application
UDP application
```

Explain the reasoning for each.

---

## Part 15 — Private Connectivity to RDS and AWS Services

RDS databases are commonly deployed into private subnets and accessed through private network paths. Applications typically connect to an RDS DNS endpoint rather than directly using a hard-coded IP address.

A typical architecture is:

```text
Application
   ↓
RDS DNS endpoint
   ↓
Private IP
   ↓
RDS
```

Security Groups then control which application workloads can access the database port.

For PostgreSQL:

```text
TCP 5432
```

For MySQL:

```text
TCP 3306
```

A production application should normally not expose these database ports to the public internet.

Practice:

Design:

```text
ECS/EKS application
        ↓
RDS PostgreSQL
```

with:

```text
Private subnets
Database Security Group
Application Security Group
Port 5432
```

Then explain how DNS, routing and security work together.

---

## Part 16 — Hybrid Networking: VPN and Direct Connect

AWS supports hybrid connectivity between on-premises environments and AWS using services such as Site-to-Site VPN and Direct Connect.

A VPN provides encrypted connectivity over an underlying network path:

```text
On-Premises
    ↓
VPN
    ↓
AWS
```

Direct Connect provides dedicated connectivity through a supported provider:

```text
Enterprise
    ↓
Connectivity Provider
    ↓
Direct Connect
    ↓
AWS
```

The same network fundamentals still apply:

```text
Address spaces
Routing
Security
DNS
Availability
```

Overlapping CIDRs are particularly problematic in hybrid environments.

Practice:

Your company has:

```text
On-premises: 10.0.0.0/16
AWS VPC:     10.0.0.0/16
```

Explain why connecting the networks creates routing ambiguity and why this should be resolved before the connectivity project begins.

---

## Part 17 — EKS Networking

EKS combines Kubernetes networking with AWS VPC networking.

A typical path is:

```text
Internet
   ↓
ALB/NLB
   ↓
Kubernetes Service
   ↓
Pod
   ↓
AWS VPC
   ↓
RDS / AWS Service
```

The AWS VPC CNI commonly gives Pods networking integration with the VPC. The exact behavior depends on the EKS networking configuration, but the important point is that Kubernetes and AWS networking are not separate worlds.

For an EKS Pod connecting to RDS, investigate:

```text
Pod DNS
→ destination IP
→ Kubernetes networking
→ VPC route
→ Security Group
→ RDS Security Group
→ port
→ database
```

For an EKS Pod accessing S3:

```text
Pod
→ DNS
→ VPC endpoint or NAT path
→ S3
```

Practice:

Deploy a small EKS workload and connect it to RDS. Deliberately block database access through the RDS Security Group and troubleshoot from the Pod outward.

---

## Part 18 — AWS Networking for ECS and Fargate

ECS tasks using `awsvpc` networking receive their own network interfaces and private IP addresses. This makes the task a first-class participant in the VPC networking model.

A typical Fargate architecture is:

```text
ALB
 ↓
Private subnet
 ↓
Fargate task
 ↓
RDS
```

The task can have:

```text
Task Security Group
Private IP
Subnet
Route table
```

This means ECS troubleshooting often looks very similar to EC2 networking troubleshooting.

For example:

```text
ECS task → RDS timeout
```

Investigate:

```text
Task subnet
→ route table
→ task Security Group
→ RDS Security Group
→ DNS
→ port 5432
→ database health
```

Practice:

Run a Fargate task in a private subnet and make it connect to a database. Verify that the task does not require a public IP when the architecture provides the necessary private paths.

---

## Part 19 — Outbound vs Inbound Architecture

Treat inbound and outbound traffic separately.

Inbound:

```text
Internet
 ↓
Route 53
 ↓
ALB/NLB
 ↓
Target
 ↓
Application
```

Outbound:

```text
Application
 ↓
Route table
 ↓
NAT / VPC Endpoint / Firewall
 ↓
Destination
```

This distinction dramatically improves troubleshooting.

Suppose:

```text
Users can access the API.
API cannot reach an external payment service.
```

The inbound load balancer is unlikely to be the first place to investigate. Start with:

```text
Application
→ DNS
→ route
→ outbound security
→ NAT/firewall/VPC endpoint
→ external destination
```

Practice:

For each scenario, identify whether the primary path is inbound or outbound:

```text
User cannot open website
API cannot call external API
EC2 cannot access S3
ALB cannot reach target
```

---

## Part 20 — AWS Network Troubleshooting Workflow

Use a fixed sequence.

Start with DNS:

```text
1. Does the hostname resolve?
```

Then determine the destination:

```text
2. What IP address did it resolve to?
```

Then routing:

```text
3. Which route matches the destination?
```

Then security:

```text
4. Security Group?
5. NACL?
6. Firewall?
7. Kubernetes NetworkPolicy?
```

Then connectivity:

```text
8. Is the port reachable?
```

Then the service:

```text
9. Is the target healthy/listening?
```

Then the application:

```text
10. Logs
11. Configuration
12. Authentication
```

Useful commands:

```bash
dig <hostname>
nslookup <hostname>

ip route

nc -vz <ip> <port>

curl -v https://<hostname>
```

For AWS resource inspection:

```bash
aws ec2 describe-route-tables
aws ec2 describe-security-groups
aws ec2 describe-network-acls
aws ec2 describe-vpc-endpoints
```

For load balancer health:

```bash
aws elbv2 describe-target-health \
  --target-group-arn <TARGET-GROUP-ARN>
```

AWS Reachability Analyzer can also analyze whether a network path should be reachable between supported network resources.

The key troubleshooting rule is:

**Do not change multiple networking controls simultaneously. Establish evidence first.**

Practice:

Troubleshoot:

```text
ECS task
  ↓
db.internal.example.com
  ↓
connection timeout
```

Work through:

```text
DNS
→ IP
→ route
→ Security Group
→ NACL
→ port 5432
→ RDS
→ application
```

---

## Part 21 — Senior/Lead Architecture Exercise

Design the AWS network for a production platform with:

```text
Internet users
Frontend
Backend APIs
EKS
RDS
S3
On-premises systems
Central security inspection
Multiple application teams
```

Requirements:

```text
Frontend is internet-facing.
Backend is not directly exposed.
RDS is private.
S3 access should use an appropriate private path.
Outbound internet access needs predictable control.
On-premises connectivity is required.
Multiple VPCs must communicate.
Security inspection should be centralized.
```

A possible architecture direction is:

```text
                         Internet
                            |
                         Route 53
                            |
                           ALB
                            |
                           EKS
                         /     \
                        /       \
                      RDS       S3
                    private    endpoint


Application VPCs
       |
       v
Transit Gateway
       |
       +---- Inspection VPC
       |
       +---- Shared Services
       |
       +---- On-Premises
```

The important part is explaining the design rather than copying the diagram.

Answer:

1. Why is the ALB public while EKS worker capacity remains private?
2. Why is RDS private?
3. Why use a VPC endpoint for S3?
4. Where does outbound internet traffic go?
5. Where should centralized inspection occur?
6. How do multiple VPCs communicate?
7. How does on-premises traffic enter AWS?
8. What prevents Internet users from reaching RDS?
9. How does DNS resolve internal services?
10. Which components create shared blast radius?
11. How would you design high availability?
12. How would you troubleshoot a failed EKS → RDS connection?

---

## Part 22 — Practice: Build an AWS Networking Lab

Create a small dedicated lab environment.

Start with:

```text
VPC: 10.50.0.0/16

AZ-a:
Public subnet
Private app subnet

AZ-b:
Public subnet
Private app subnet
```

Then create:

```text
Internet Gateway
NAT Gateway
Route Tables
Security Groups
EC2 or ECS
S3 VPC Endpoint
ALB
```

Start with the VPC:

```bash
aws ec2 create-vpc \
  --cidr-block 10.50.0.0/16
```

Create subnets:

```bash
aws ec2 create-subnet \
  --vpc-id <VPC-ID> \
  --cidr-block 10.50.1.0/24 \
  --availability-zone ap-south-1a
```

and:

```bash
aws ec2 create-subnet \
  --vpc-id <VPC-ID> \
  --cidr-block 10.50.11.0/24 \
  --availability-zone ap-south-1a
```

Repeat appropriate subnet creation for the second AZ.

Then implement:

```text
Internet Gateway
→ public routing

NAT Gateway
→ private outbound access

Security Groups
→ application filtering

VPC Endpoint
→ private AWS service access

ALB
→ inbound application access
```

Test each path independently.

Then deliberately break:

```text
Route table
Security Group
NACL
DNS
VPC Endpoint
ALB target health
```

For every failure, identify the exact layer responsible.

---

## Part 23 — Failure Drill: Wrong Route

Scenario:

```text
Private application
       ↓
External API
       ↓
Timeout
```

A route-table change was deployed shortly before the failure.

Check:

```text
Destination IP
↓
Matching route
↓
Route target
↓
NAT Gateway / Firewall
↓
Internet Gateway
↓
Security
↓
Destination
```

A route can exist and still be wrong.

For example:

```text
0.0.0.0/0 → NAT-A
```

may technically be valid but architecturally wrong if the expected path is through a centralized inspection VPC.

The key question is:

> “Is this the intended next hop for this destination?”

Practice:

Change a private subnet's default route in a lab and observe the connectivity failure. Restore the correct route and verify recovery.

---

## Part 24 — Failure Drill: Security Group

Scenario:

```text
ECS task
  ↓
RDS PostgreSQL
  ↓
Timeout
```

The database is healthy.

Check:

```text
Task Security Group
RDS Security Group
NACL
Route
DNS
Port 5432
```

Suppose the RDS Security Group contains:

```text
Allowed:
10.50.0.0/16
```

but the architecture expects access only from the application tier.

A better design may use the application Security Group as the source where supported.

This reduces the network trust boundary from:

```text
Entire VPC
```

to:

```text
Application workload
```

Practice:

Remove the database ingress rule, test the application, then restore only the required rule.

---

## Part 25 — Failure Drill: DNS and Private Service Access

Scenario:

```text
Private EC2
    ↓
AWS service
```

The service should be reached privately, but DNS resolves the expected hostname to an address/path that does not match the intended architecture.

Investigate:

```text
DNS
↓
VPC endpoint
↓
Endpoint type
↓
Route
↓
Security
↓
Service
```

For interface endpoints, private DNS configuration is particularly important. Applications can continue to use normal AWS service hostnames while DNS resolves them toward the private endpoint.

Practice:

Break private DNS for a lab interface endpoint and compare the behavior before and after restoring it.

---

## Part 26 — AWS ↔ Azure Networking Mapping

The underlying networking concepts are shared across both clouds.

| Concept | AWS | Azure |
|---|---|---|
| Virtual network | VPC | VNet |
| Subnet | Subnet | Subnet |
| Route table | Route Table | Route Table / UDR |
| Resource firewall | Security Group | NSG |
| Subnet firewall | NACL | NSG/subnet filtering model differs |
| Central firewall | AWS Network Firewall | Azure Firewall |
| Internet connectivity | Internet Gateway | Public IP / Azure internet connectivity model |
| Outbound NAT | NAT Gateway | NAT Gateway |
| Private service access | VPC Endpoint / PrivateLink | Private Endpoint |
| Private DNS | Route 53 Private Hosted Zone | Azure Private DNS |
| VPC/VNet connection | VPC Peering | VNet Peering |
| Central network hub | Transit Gateway | Virtual WAN / Hub-Spoke |
| VPN | Site-to-Site VPN | VPN Gateway |
| Dedicated private connection | Direct Connect | ExpressRoute |
| L4 load balancer | NLB | Azure Load Balancer |
| L7 load balancer | ALB | Application Gateway |
| Managed Kubernetes | EKS | AKS |

The mapping is conceptual rather than perfectly one-to-one. For example, Azure NSGs and AWS Security Groups are both network filtering controls, but their scope, behavior, and surrounding architecture differ. Similarly, AWS VPC Endpoints and Azure Private Endpoints solve related private-service-access problems but use different implementation models.

The interview approach should therefore be:

```text
Requirement
→ Networking capability
→ AWS implementation
→ Azure equivalent
```

---

## Part 27 — 5-Minute Recall

Without looking at the notes, explain:

1. What does a VPC provide?
2. Why are subnets associated with Availability Zones?
3. What makes a subnet public?
4. What does a route table control?
5. What does an Internet Gateway do?
6. Why does a private subnet use a NAT Gateway?
7. Why is the NAT Gateway normally placed in a public subnet?
8. What does a Security Group do?
9. Why are Security Groups considered stateful?
10. How is a NACL different from a Security Group?
11. What role does Route 53 play in networking?
12. What is a VPC endpoint?
13. What is the difference between gateway and interface endpoints?
14. What problem does VPC Peering solve?
15. Why would an enterprise use Transit Gateway?
16. Why does centralized firewalling require routing changes?
17. What is the difference between ALB and NLB?
18. How should an application access a private RDS database?
19. What are the main AWS hybrid connectivity options?
20. Why does EKS require both Kubernetes and VPC networking knowledge?
21. How does ECS Fargate participate in VPC networking?
22. How would you troubleshoot an ECS → RDS timeout?
23. How would you troubleshoot a private EC2 → internet timeout?
24. How would you troubleshoot private AWS service access?
25. What is the Azure equivalent of the major AWS networking concepts?

The sequence worth remembering is:

**DNS → IP → Route → Security → Port → Service → Application**

At Senior/Lead level, you should be able to trace the traffic path, identify the network boundary involved, explain the security model, recognize the blast radius of centralized components, and choose between direct and centralized connectivity based on scale and operational requirements.

---

## Part 28 — Cleanup

Delete only resources created specifically for the lab.

For EC2:

```bash
aws ec2 terminate-instances \
  --instance-ids <INSTANCE-ID>
```

For load balancers, remove the load balancer and associated target groups when they are no longer required.

For NAT Gateway:

```bash
aws ec2 delete-nat-gateway \
  --nat-gateway-id <NAT-GATEWAY-ID>
```

Release the associated Elastic IP only after confirming it is no longer needed.

For VPC endpoints:

```bash
aws ec2 delete-vpc-endpoints \
  --vpc-endpoint-ids <ENDPOINT-ID>
```

Then remove:

```text
Routes
Security Groups
Subnets
Internet Gateway
VPC
```

only after their dependencies are removed.

Inspect before deleting:

```bash
aws ec2 describe-vpcs
aws ec2 describe-subnets
aws ec2 describe-route-tables
aws ec2 describe-nat-gateways
aws ec2 describe-vpc-endpoints
aws elbv2 describe-load-balancers
```

Be particularly careful with NAT Gateways, load balancers and Elastic IPs because they can continue generating charges even when the application itself has been stopped.

The learning lifecycle remains:

**Create → Inspect → Test → Break → Troubleshoot → Recover → Destroy → Verify**

The final Day 28 mental model is:

**VPC → Subnets → Route Tables → Gateways/Endpoints → Security Groups/NACLs → Load Balancers → Workloads**, with DNS controlling service discovery and Transit Gateway/VPN/Direct Connect providing larger-scale connectivity.

The Senior/Lead skill is to take a requirement such as “private application access with controlled outbound connectivity” and translate it into a complete network path, security model, failure model, and operational design rather than simply selecting AWS networking services.

## Answers to practice

### 1. Design a VPC CIDR for frontend, private backend, private DB, endpoints, outbound

<details>
<summary>Answer</summary>

Use a unique range such as `10.20.0.0/16`. Public `10.20.1.0/24` and `10.20.2.0/24` for ALB and NAT. Private app `10.20.11.0/24` and `10.20.12.0/24`. Private data `10.20.21.0/24` and `10.20.22.0/24`. Leave space for endpoints or TGW attachments.

Check on-premises, VPN, Direct Connect, and other VPCs before you lock CIDRs. Overlap is a later outage.

</details>

### 2. Two AZs: public, private app, and private database subnets

<details>
<summary>Answer</summary>

Each AZ gets a public subnet (ALB, NAT, IGW route), a private app subnet (ECS/EKS/EC2, NAT default route), and a private data subnet (RDS, no IGW). Multi-AZ so one AZ failure does not take the app.

Public vs private is routing, not the subnet name. Workloads that must not have public IPs stay in private subnets.

</details>

### 3. App in `10.20.11.0/24` reaching `10.30.0.10`

<details>
<summary>Answer</summary>

If the route table has `10.30.0.0/16` to peering, TGW, or VPN, that more-specific route wins. If not, `0.0.0.0/0` sends the packet to NAT or IGW and the private destination never arrives.

Ask which route matches the destination IP, not whether a route table exists.

</details>

### 4. Why VPC plus Internet Gateway is not enough for public access

<details>
<summary>Answer</summary>

You still need a subnet route to the IGW, a public IP on the workload or load balancer, Security Group/NACL allows, and a listening process.

An attached IGW does not publish every resource on the internet.

</details>

### 5. Private app calls `https://api.example.com` with no inbound internet

<details>
<summary>Answer</summary>

Private instance → private route `0.0.0.0/0` → NAT Gateway in a public subnet → IGW → internet. Return traffic comes back to NAT, then the private IP. Security Groups allow egress 443. No public IP on the app.

NAT is outbound only. Users still enter through an ALB if needed.

</details>

### 6. Security Groups: Internet→ALB 443, ALB→App 8080, App→RDS 5432, deny Internet→RDS

<details>
<summary>Answer</summary>

ALB SG: inbound 443 from `0.0.0.0/0` (or known CDNs). App SG: inbound 8080 from the ALB SG. RDS SG: inbound 5432 from the App SG. RDS has no inbound from the internet.

Prefer SG references as sources, not the whole VPC CIDR.

</details>

### 7. SG allows 443 but the connection still fails — check NACL

<details>
<summary>Answer</summary>

NACLs are stateless. Allow inbound 443 and the ephemeral outbound return range. Also check the route and the application.

Do not stop at Security Groups. A subnet NACL can drop the same flow.

</details>

### 8. Private DNS name, then break the VPC association

<details>
<summary>Answer</summary>

Create a Route 53 private hosted zone, associate the VPC, and `nslookup` from inside. Disassociate the VPC. Resolution fails or falls through to public DNS.

If you expected a private IP and get a public one, the path is wrong even when routes look fine.

</details>

### 9. Private EC2 → S3 via NAT vs VPC endpoint

<details>
<summary>Answer</summary>

NAT path: private route → NAT → IGW → public S3. Costs NAT processing and uses the internet path. Gateway endpoint: prefix list route in the table → S3 on the AWS network, no NAT for that traffic.

Endpoint changes path, security, and often cost. IAM and bucket policy still apply.

</details>

### 10. Shared Services VPC peered with Application VPC — routes both ways

<details>
<summary>Answer</summary>

Peer non-overlapping CIDRs. Application VPC needs a route to `10.10.0.0/16` (shared) via the peering ID. Shared VPC needs a route to the app CIDR via the same peering. SGs and NACLs must allow the ports.

Peering without routes is a disconnected cable.

</details>

### 11. Transit Gateway for 50 app VPCs, on-prem, security, shared, inspection

<details>
<summary>Answer</summary>

Attach every VPC and the VPN/Direct Connect gateway to Transit Gateway. Use route tables so app VPCs send east-west and egress through an inspection VPC. Shared Services and Security VPCs attach once.

Avoid a 50×50 peering mesh. TGW is a shared blast radius: design HA and change control.

</details>

### 12. Central outbound inspection for VPC A, B, and C

<details>
<summary>Answer</summary>

Send `0.0.0.0/0` from each app VPC to Transit Gateway, then to an inspection VPC with AWS Network Firewall, then to IGW/NAT. Change app VPC route tables, TGW route tables, and the inspection VPC routes.

Firewall policy without those routes inspects nothing.

</details>

### 13. ALB hostname routing for `api.example.com` and `www.example.com`

<details>
<summary>Answer</summary>

One HTTPS listener. Host header `api.example.com` → API target group. Host `www.example.com` → frontend target group. Health checks decide which targets receive traffic.

A registered target is not automatically healthy. Inspect `aws elbv2 describe-target-health`.

</details>

### 14. ALB vs NLB for HTTP paths, raw TCP, and UDP

<details>
<summary>Answer</summary>

HTTP path routing: ALB (Layer 7). Raw TCP: NLB (Layer 4). UDP: NLB.

Start from protocol. Do not pick NLB for an HTTP API only because of a performance rumor.

</details>

### 15. ECS/EKS to private RDS PostgreSQL

<details>
<summary>Answer</summary>

App in private subnets uses the RDS DNS name, which resolves to a private IP. Local VPC route delivers the packet. App SG → RDS SG on TCP 5432. No public RDS.

DNS, routing, and Security Groups must all agree. Hard-coded IPs break when RDS fails over.

</details>

### 16. On-premises `10.0.0.0/16` and AWS VPC `10.0.0.0/16`

<details>
<summary>Answer</summary>

VPN or Direct Connect cannot uniquely route a destination in that prefix. Return traffic is equally ambiguous.

Pick unique CIDRs before the connectivity project. Overlap is not a tunnel-PSK problem.

</details>

### 17. EKS to RDS: block the RDS Security Group and troubleshoot from the Pod

<details>
<summary>Answer</summary>

Remove the worker/Pod SG from RDS 5432. From the Pod, `nslookup` the RDS endpoint, then `nc -vz` 5432. Restore only the app SG.

Walk Pod DNS → CNI → VPC route → SGs → port → database. Kubernetes and VPC are one path.

</details>

### 18. Fargate in a private subnet to the database, no public IP

<details>
<summary>Answer</summary>

`awsvpc` gives the task an ENI and private IP. Private subnet route, task SG, and RDS SG on 5432 are enough. NAT or endpoints cover other AWS APIs.

The task must not need a public IP if private paths exist.

</details>

### 19. Inbound vs outbound for four failure scenarios

<details>
<summary>Answer</summary>

User cannot open the website: inbound (DNS, ALB, target health). API cannot call an external API: outbound (route, NAT/firewall, egress SG). EC2 cannot access S3: outbound or endpoint path. ALB cannot reach target: inbound data path after the load balancer (SG, health, app).

Users working does not prove egress works.

</details>

### 20. Troubleshoot ECS → `db.internal.example.com` timeout

<details>
<summary>Answer</summary>

`dig` the name, note the IP, match the route, check task SG and RDS SG, NACL, `nc` 5432, then RDS health and app credentials.

Change one control at a time. DNS → IP → route → security → port → service → application.

</details>

### 21. Lab: change a private subnet default route, observe timeout, restore

<details>
<summary>Answer</summary>

Point `0.0.0.0/0` at a blackhole or the wrong NAT. HTTPS to an external API times out. Restore the NAT (or inspection) next hop and retest.

A route can exist and still be the wrong next hop.

</details>

### 22. Remove the database ingress rule, test, restore only the required rule

<details>
<summary>Answer</summary>

Delete RDS inbound 5432. The app times out while RDS stays healthy. Restore inbound 5432 from the application Security Group only, not from `10.50.0.0/16`.

Narrow source from “entire VPC” to the workload SG.

</details>

### 23. Break private DNS on a lab interface endpoint, then restore

<details>
<summary>Answer</summary>

Disable private DNS on the interface endpoint. The AWS hostname resolves publicly and the path may NAT or fail. Restore private DNS and confirm the private endpoint IP.

Applications keep using the normal hostname. DNS must aim at PrivateLink.

</details>

### 24. Why the ALB is public while EKS workers stay private

<details>
<summary>Answer</summary>

Users need a public entry. Nodes and Pods do not. ALB in public subnets, targets in private subnets.

Exposing workers puts the data plane on the internet.

</details>

### 25. Why is RDS private?

<details>
<summary>Answer</summary>

The database holds customer data. Only the app SG should reach 5432.

A public RDS endpoint is an unnecessary attack surface.

</details>

### 26. Why use a VPC endpoint for S3?

<details>
<summary>Answer</summary>

Private subnets reach S3 without NAT or the public S3 path. Traffic stays on the AWS network.

IAM still authorizes. The endpoint is path, not permission.

</details>

### 27. Where does outbound internet traffic go?

<details>
<summary>Answer</summary>

Private default route to NAT, or to Transit Gateway then inspection then NAT/IGW. Use known Elastic IPs when partners allowlist you.

Do not give app tasks public IPs “for convenience.”

</details>

### 28. Where should centralized inspection occur?

<details>
<summary>Answer</summary>

In an inspection VPC on Transit Gateway, with AWS Network Firewall on the forced path.

Routing must send the traffic there. Policy alone is not a path.

</details>

### 29. How do multiple VPCs communicate?

<details>
<summary>Answer</summary>

At this scale, Transit Gateway, not a peering mesh. Routes on both the VPC and TGW tables. SGs still filter.

Peering is fine for two VPCs. Fifty VPCs need a hub.

</details>

### 30. How does on-premises traffic enter AWS?

<details>
<summary>Answer</summary>

Site-to-Site VPN or Direct Connect into Transit Gateway or a VPN gateway, then to app VPCs.

Unique CIDRs, routes both ways, and SGs that allow the on-premises prefix or hub.

</details>

### 31. What prevents Internet users from reaching RDS?

<details>
<summary>Answer</summary>

Private subnets, no IGW route on data subnets, RDS SG with no public inbound, and no public RDS flag.

Defense in layers. One mis-opened 5432 is enough to fail the design.

</details>

### 32. How does DNS resolve internal services?

<details>
<summary>Answer</summary>

Route 53 private hosted zones associated to the VPCs, plus RDS and endpoint private DNS.

Wrong zone association sends clients to public IPs.

</details>

### 33. Which components create shared blast radius?

<details>
<summary>Answer</summary>

Transit Gateway, inspection firewall, shared NAT, shared private hosted zones, and a shared ALB.

A bad TGW route can isolate many teams. Change-control those hubs.

</details>

### 34. How would you design high availability?

<details>
<summary>Answer</summary>

Subnets and NAT (if used) in at least two AZs. Multi-AZ ALB, EKS nodes, and RDS. TGW and firewall in a resilient design.

Single-AZ NAT is a quiet single point of failure for all private egress.

</details>

### 35. Troubleshoot a failed EKS → RDS connection

<details>
<summary>Answer</summary>

From the Pod: DNS, destination IP, CNI, VPC route, node/Pod SG, RDS SG, port 5432, RDS health, credentials.

Do not stop at `kubectl get pods`.

</details>

### 36. What does a VPC provide?

<details>
<summary>Answer</summary>

The private IP space and the foundation for subnets, routes, SGs, gateways, and endpoints.

The VPC name alone does not make an app private.

</details>

### 37. Why are subnets associated with Availability Zones?

<details>
<summary>Answer</summary>

A subnet lives in one AZ. Spread subnets so workloads survive AZ failure.

Capacity in one AZ is not Multi-AZ.

</details>

### 38. What makes a subnet public?

<details>
<summary>Answer</summary>

Default route to an Internet Gateway plus public addressing on the workload or load balancer.

Routing defines public, not the label.

</details>

### 39. What does a route table control?

<details>
<summary>Answer</summary>

Where packets matching a destination CIDR go next: local, IGW, NAT, TGW, peering, or endpoint.

The matching route matters more than the table’s existence.

</details>

### 40. What does an Internet Gateway do?

<details>
<summary>Answer</summary>

It provides a path between the VPC and the public internet.

It is necessary for public subnets and for NAT, not sufficient by itself.

</details>

### 41. Why does a private subnet use a NAT Gateway?

<details>
<summary>Answer</summary>

So instances without public IPs can start outbound internet connections.

Inbound internet still cannot initiate to those instances.

</details>

### 42. Why is the NAT Gateway normally placed in a public subnet?

<details>
<summary>Answer</summary>

NAT needs a route to the Internet Gateway and a public Elastic IP.

A NAT in a private subnet cannot reach the internet.

</details>

### 43. What does a Security Group do?

<details>
<summary>Answer</summary>

Stateful allow rules on ENIs and many managed services, by protocol, port, and source.

It is the primary workload firewall in most designs.

</details>

### 44. Why are Security Groups considered stateful?

<details>
<summary>Answer</summary>

Allowed inbound automatically permits the matching return traffic.

You do not write a separate ephemeral-port allow for that flow.

</details>

### 45. How is a NACL different from a Security Group?

<details>
<summary>Answer</summary>

NACL is subnet-level and stateless. You must allow both directions. Rules number in order.

SGs are resource-level and stateful. Check both when traffic dies.

</details>

### 46. What role does Route 53 play in networking?

<details>
<summary>Answer</summary>

DNS: public and private hosted zones that map names to IPs or aliases.

Wrong DNS sends packets down the wrong path.

</details>

### 47. What is a VPC endpoint?

<details>
<summary>Answer</summary>

Private access to a supported AWS service without the public internet path.

Gateway endpoints for S3/DynamoDB. Interface endpoints (PrivateLink) for many APIs.

</details>

### 48. Difference between gateway and interface endpoints

<details>
<summary>Answer</summary>

Gateway: prefix-list route in the route table (S3, DynamoDB). Interface: ENI with a private IP, often with private DNS, powered by PrivateLink.

Pick the type the service supports.

</details>

### 49. What problem does VPC Peering solve?

<details>
<summary>Answer</summary>

Private connectivity between two VPCs with non-overlapping CIDRs, plus routes and SGs on both sides.

It does not scale well to dozens of VPCs.

</details>

### 50. Why would an enterprise use Transit Gateway?

<details>
<summary>Answer</summary>

To hub many VPCs and hybrid links instead of a peering mesh.

You gain control and accept a shared dependency.

</details>

### 51. Why does centralized firewalling require routing changes?

<details>
<summary>Answer</summary>

The firewall only sees packets that routes send to it.

Policy without a UDR or TGW route is unused.

</details>

### 52. Difference between ALB and NLB

<details>
<summary>Answer</summary>

ALB: Layer 7 HTTP/HTTPS, host and path. NLB: Layer 4 TCP/UDP/TLS.

Choose from traffic type.

</details>

### 53. How should an application access a private RDS database?

<details>
<summary>Answer</summary>

RDS DNS → private IP → VPC local route → App SG to RDS SG on 5432.

No public endpoint. Credentials stay in Secrets Manager.

</details>

### 54. Main AWS hybrid connectivity options

<details>
<summary>Answer</summary>

Site-to-Site VPN (encrypted over the internet) and Direct Connect (provider private path).

Both still need unique CIDRs, routes, security, and DNS.

</details>

### 55. Why EKS needs Kubernetes and VPC networking knowledge

<details>
<summary>Answer</summary>

Pods use CNI IPs in the VPC. Failures span Services, NetworkPolicy, routes, and SGs.

A ready Pod can still miss RDS.

</details>

### 56. How does ECS Fargate participate in VPC networking?

<details>
<summary>Answer</summary>

`awsvpc` gives each task an ENI, private IP, subnet, route table, and Security Group.

Troubleshoot it like EC2 networking.

</details>

### 57. Troubleshoot an ECS → RDS timeout

<details>
<summary>Answer</summary>

Task subnet, route, task SG, RDS SG, DNS, port 5432, database health.

Do not rebuild the cluster first.

</details>

### 58. Troubleshoot a private EC2 → internet timeout

<details>
<summary>Answer</summary>

DNS, default route to NAT, NAT health and public subnet, IGW, egress SG/NACL, then the external site.

Common miss: default route still points at IGW on a private instance with no public IP.

</details>

### 59. Troubleshoot private AWS service access

<details>
<summary>Answer</summary>

DNS (private vs public), endpoint type and state, route or ENI, SG on the interface endpoint, then IAM.

If DNS is public, you never hit the endpoint.

</details>

### 60. Azure equivalents of major AWS networking concepts

<details>
<summary>Answer</summary>

VPC ↔ VNet. SG ↔ NSG (not identical). Route table ↔ UDR. NAT ↔ NAT. Endpoint/PrivateLink ↔ Private Endpoint. Route 53 private zone ↔ Azure Private DNS. Peering ↔ peering. TGW ↔ hub/Virtual WAN. VPN ↔ VPN Gateway. Direct Connect ↔ ExpressRoute. ALB ↔ Application Gateway. NLB ↔ Azure Load Balancer.

Map the capability, then the product.

</details>

### 61. Design the production AWS network per Part 21 requirements

<details>
<summary>Answer</summary>

Internet users hit Route 53 then a public ALB. EKS workers stay private. RDS is private with SG-to-SG 5432. S3 uses a gateway endpoint. Egress goes NAT or TGW inspection with known IPs. Hybrid lands on TGW. Teams get spoke VPCs, not one flat network.

Explain each hop. The diagram is a consequence of the requirements, not decoration.

</details>

### 62. Build VPC `10.50.0.0/16` across two AZs and break each layer

<details>
<summary>Answer</summary>

Create public and private app subnets in two AZs, IGW, NAT, routes, SGs, EC2/ECS, S3 endpoint, and ALB. Test inbound, outbound, and S3 privately.

Then break route, SG, NACL, DNS, endpoint, and ALB health one at a time. Name the layer from evidence. Destroy NAT, ALB, and EIPs when done; they keep billing.

</details>
