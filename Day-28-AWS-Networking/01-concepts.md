# Day 28 — AWS Overlay 03 AWS Networking

This Day uses three files. Read them in this order.

1. [01-concepts.md](01-concepts.md) — lesson content (this file)
2. [02-questions-and-answers.md](02-questions-and-answers.md) — practice items, each with a model answer
3. [03-implementation.md](03-implementation.md) — hands-on lab

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
