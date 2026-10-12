# Day 24 — Azure Overlay 03: Azure Advanced Networking

The goal of this day is to move from basic cloud networking into the Azure networking decisions you are expected to understand as a Senior/Lead DevOps Engineer. The focus is not memorizing Azure networking services. It is understanding how traffic moves, where it can be blocked, how Azure provides private connectivity, and how to troubleshoot failures systematically.

The core mental model is:

**Source → DNS → Destination IP → Route → Security → Port → Service → Application**

For external access, extend it to:

**Client → DNS → Public IP → Load Balancer/Application Gateway → Backend → Service → Application**

For private Azure PaaS access:

**Application → DNS → Private IP → Route → NSG/Firewall → Private Endpoint → Azure PaaS**

---

## Part 1 — The Azure Networking Mental Model

Azure networking starts with the Virtual Network, or VNet. A VNet provides the private IP space in which Azure workloads communicate, while subnets divide that address space into smaller logical network segments. A Senior/Lead engineer should not think about a VNet merely as a container for IP addresses. It is a boundary around routing, security, connectivity, and workload placement.

For example:

```text
VNet: 10.20.0.0/16

10.20.1.0/24   App subnet
10.20.2.0/24   Data subnet
10.20.3.0/24   Private Endpoint subnet
10.20.4.0/24   Management subnet
```

A request from an application to a database does not magically reach the database. The packet needs an IP destination, a route, an allowed path, the correct port, and a healthy service on the other side.

Think through every network problem in this order:

```text
Can I resolve the name?
        ↓
What IP did it resolve to?
        ↓
Do I have a route?
        ↓
Is traffic allowed?
        ↓
Can I reach the port?
        ↓
Is the service listening?
        ↓
Is the application accepting the request?
```

Useful commands from a Linux workload include:

```bash
nslookup db.example.internal
ip route
ping 10.20.2.10
nc -vz 10.20.2.10 5432
```

For Azure itself:

```bash
az network vnet show \
  --resource-group rg-network \
  --name vnet-prod
```

Practice:

Pick one hypothetical flow:

```text
AKS Pod → PostgreSQL
```

Write down:

```text
DNS name
Destination IP
Route
Security controls
Destination port
Database service
```

Do not start with the firewall. Start with the complete traffic path.

---

## Part 2 — VNet and Subnet Design

A VNet defines an IP address space using CIDR notation. CIDR is simply a compact way to write an IP range: in `10.20.0.0/16`, the number after the slash says how much of the address is fixed, so a smaller number means a bigger range (`/16` holds 65,536 addresses, `/24` holds 256). Subnets divide that address space into smaller ranges and provide logical placement boundaries. Subnet design matters because changing the address space later can be difficult, while overlapping networks create serious problems for peering and hybrid connectivity.

Example:

```text
VNet
10.20.0.0/16
│
├── snet-app
│   10.20.1.0/24
│
├── snet-data
│   10.20.2.0/24
│
├── snet-private-endpoints
│   10.20.3.0/24
│
└── snet-management
    10.20.4.0/24
```

A common mistake is to choose address ranges without thought for future connectivity. If an enterprise already has an on-premises network on `10.20.0.0/16`, an Azure VNet with the same range can make routing ambiguous or impossible across VPN/ExpressRoute.

Implementation example:

```bash
az network vnet create \
  --resource-group rg-network \
  --name vnet-prod \
  --address-prefix 10.20.0.0/16 \
  --subnet-name snet-app \
  --subnet-prefix 10.20.1.0/24
```

Add another subnet:

```bash
az network vnet subnet create \
  --resource-group rg-network \
  --vnet-name vnet-prod \
  --name snet-data \
  --address-prefix 10.20.2.0/24
```

The subnet is also an important security and platform boundary. Some Azure services require dedicated subnet configurations, and services such as private endpoints, Application Gateway, and AKS can have specific subnet design requirements.

Practice:

Design a VNet for:

```text
Web
Application
Database
Private Endpoints
Management
```

Choose CIDRs that leave room for growth.

**Remember:** good IP planning is a long-term architecture decision, not merely a configuration detail.

---

## Part 3 — NSGs: Filtering Traffic

A Network Security Group, or NSG, controls network traffic using rules based on characteristics such as source, destination, protocol, port, and direction. It is a traffic-filtering control, not a routing mechanism.

A simple model is:

```text
Route decides:
"Where should this traffic go?"

NSG decides:
"Is this traffic allowed?"
```

For example, suppose an application subnet must access PostgreSQL:

```text
App subnet
10.20.1.0/24
       |
       | TCP 5432
       v
Data subnet
10.20.2.0/24
```

An NSG could allow TCP 5432 from the application subnet while denying unnecessary traffic.

Implementation example:

```bash
az network nsg create \
  --resource-group rg-network \
  --name nsg-data
```

Create a rule:

```bash
az network nsg rule create \
  --resource-group rg-network \
  --nsg-name nsg-data \
  --name Allow-App-Postgres \
  --priority 100 \
  --source-address-prefixes 10.20.1.0/24 \
  --destination-port-ranges 5432 \
  --protocol Tcp \
  --access Allow \
  --direction Inbound
```

Then associate the NSG with the data subnet:

```bash
az network vnet subnet update \
  --resource-group rg-network \
  --vnet-name vnet-prod \
  --name snet-data \
  --network-security-group nsg-data
```

The important operational point is that an NSG should express the intended communication pattern rather than becoming a large collection of broad allow rules.

Practice:

Design rules for:

```text
Internet → Web: 443
Web → App: 8080
App → Database: 5432
Internet → Database: Deny
```

Then ask whether each rule is required and whether the source can be narrowed further.

---

## Part 4 — NSG Rule Evaluation and Troubleshooting

Azure evaluates NSG rules according to priority: lower numerical priority runs before higher numerical priority. Azure also has default NSG rules, so the absence of a custom rule does not mean that no rules exist.

Suppose you create:

```text
Priority 100:
Allow TCP 443 from Internet

Priority 110:
Deny TCP 443 from Internet
```

The first matching rule determines the result, so the deny at priority 110 does not override the earlier allow.

Implementation example:

```bash
az network nsg rule list \
  --resource-group rg-network \
  --nsg-name nsg-web \
  --output table
```

When troubleshooting an unexpected block, inspect:

```text
Subnet NSG
    +
NIC-level NSG if applicable
    +
Route
    +
Azure Firewall / other security controls
```

Do not assume that “the NSG looks correct” proves that traffic is allowed. A central firewall, UDR, private endpoint configuration, or destination service can still cause failure.

For deeper investigation, Azure Network Watcher provides network diagnostic capabilities such as IP flow verification and next-hop analysis.

Example:

```bash
az network watcher test-ip-flow \
  --resource-group rg-network \
  --vm vm-app \
  --direction Inbound \
  --protocol TCP \
  --local 10.20.2.10:5432 \
  --remote 10.20.1.10:50000 \
  --vm-ip 10.20.2.10
```

Practice:

Create an intentional NSG failure. Block TCP 5432 from the application subnet and test the application-to-database connection. Then identify the blocking rule and restore the intended access.

---

## Part 5 — Route Tables and User Defined Routes

Routing determines where packets go. Azure automatically provides system routes, but User Defined Routes, or UDRs, let you explicitly control paths for certain traffic.

For example:

```text
Application subnet
       |
       | 0.0.0.0/0
       v
Azure Firewall
       |
       v
Internet
```

Instead of allowing workloads to send outbound traffic directly, an organization may force traffic through a centralized inspection device.

A route table can contain:

```text
Address prefix       Next hop
10.30.0.0/16         Virtual network
0.0.0.0/0            Virtual appliance
```

Implementation example:

```bash
az network route-table create \
  --resource-group rg-network \
  --name rt-app
```

Create a route:

```bash
az network route-table route create \
  --resource-group rg-network \
  --route-table-name rt-app \
  --name Default-To-Firewall \
  --address-prefix 0.0.0.0/0 \
  --next-hop-type VirtualAppliance \
  --next-hop-ip-address 10.20.10.4
```

Then associate the route table with a subnet:

```bash
az network vnet subnet update \
  --resource-group rg-network \
  --vnet-name vnet-prod \
  --name snet-app \
  --route-table rt-app
```

A common troubleshooting mistake is changing an NSG when the actual problem is routing.

Use the distinction:

```text
Wrong destination path → routing problem
Correct path but blocked → security problem
Correct path and allowed → inspect port/service/application
```

Practice:

Imagine an application suddenly cannot reach an on-premises network after a route-table change. Determine whether the route to the on-premises CIDR still points toward the correct VPN/ExpressRoute path.

---

## Part 6 — Azure Firewall

Azure Firewall provides centralized, stateful network security and traffic inspection. Stateful means the firewall remembers each connection it allows, so it permits the reply traffic for an allowed connection automatically, without a rule of its own. It is different from an NSG because it is designed as a centralized security service rather than simply filtering traffic at a subnet/NIC boundary.

A common architecture is:

```text
Internet
   |
   v
Azure Firewall
   |
   v
Hub VNet
   |
   +---- Spoke 1
   |
   +---- Spoke 2
   |
   +---- Spoke 3
```

Firewall policies can control network traffic and, depending on the configuration and SKU/features used, provide additional application-level filtering and threat-intelligence capabilities.

The important architectural question is:

> “Do I need local subnet filtering, centralized inspection, or both?”

A mature architecture may use:

```text
NSG:
local workload/subnet filtering

Azure Firewall:
centralized inspection and egress control
```

The two controls solve different problems.

Practice:

Design a hub-and-spoke environment where:

```text
Spoke application
       ↓
Azure Firewall
       ↓
Internet
```

Explain why the route table is required in addition to the firewall. The firewall cannot inspect traffic that routing never sends through it.

---

## Part 7 — NAT Gateway and Outbound Connectivity

NAT Gateway provides predictable outbound internet connectivity for supported Azure resources in a subnet. It performs source network address translation so private workload addresses can communicate with public destinations.

Conceptually:

```text
Private workload
10.20.1.10
     |
     v
NAT Gateway
Public IP
     |
     v
Internet
```

This is particularly useful when external systems need to allowlist a stable outbound public IP.

Implementation example:

```bash
az network public-ip create \
  --resource-group rg-network \
  --name pip-nat \
  --sku Standard \
  --allocation-method Static
```

Create the NAT Gateway:

```bash
az network nat gateway create \
  --resource-group rg-network \
  --name nat-prod \
  --public-ip-addresses pip-nat \
  --idle-timeout 10
```

Associate it with the application subnet:

```bash
az network vnet subnet update \
  --resource-group rg-network \
  --vnet-name vnet-prod \
  --name snet-app \
  --nat-gateway nat-prod
```

NAT Gateway is about **outbound** connectivity. It is not a general inbound load balancer and should not be confused with Azure Load Balancer.

Practice:

Your application must call a third-party payment API that allowlists source IPs. Design the outbound path and identify which Azure public IP the third party should allowlist.

---

## Part 8 — Private Endpoint

A Private Endpoint provides a private IP interface in your VNet for supported Azure PaaS resources. Instead of reaching a service through its public endpoint, traffic can use a private IP in your network.

Conceptually:

```text
Application
10.20.1.10
    |
    v
Private DNS
    |
    v
10.20.3.10
    |
    v
Private Endpoint
    |
    v
Azure PaaS Service
```

For example, an Azure Storage account can have a private endpoint.

The key benefit is not simply “the service is private.” The important benefit: the application reaches the PaaS service through private network connectivity, and the organization's security architecture can control and monitor that path.

Implementation example:

```bash
az network private-endpoint create \
  --resource-group rg-network \
  --name pe-storage \
  --vnet-name vnet-prod \
  --subnet snet-private-endpoints \
  --private-connection-resource-id <STORAGE-RESOURCE-ID> \
  --group-id blob \
  --connection-name storage-private-connection
```

Private Endpoint introduces an important troubleshooting requirement: **DNS**.

The application may still use a familiar public service hostname such as:

```text
mystorage.blob.core.windows.net
```

The goal is for DNS resolution from the private network to return the private endpoint IP where appropriate.

Practice:

Create a private endpoint for a test Storage Account. From a workload inside the VNet, verify:

```bash
nslookup mystorage.blob.core.windows.net
```

Then determine whether the returned IP is public or private.

---

## Part 9 — Private DNS

Private DNS provides name resolution for private resources and is often the missing piece in Private Endpoint architectures.

The flow is:

```text
Application
   |
   | mystorage.blob.core.windows.net
   v
DNS
   |
   v
Private IP
   |
   v
Private Endpoint
```

Without correct DNS, the network may be perfectly configured while the application still connects to the wrong destination.

For a private endpoint, Azure commonly uses a private DNS zone appropriate to the service, such as:

```text
privatelink.blob.core.windows.net
```

The exact zone depends on the Azure service.

Implementation example:

```bash
az network private-dns zone create \
  --resource-group rg-network \
  --name privatelink.blob.core.windows.net
```

Link the zone to the VNet:

```bash
az network private-dns link vnet create \
  --resource-group rg-network \
  --zone-name privatelink.blob.core.windows.net \
  --name link-prod \
  --virtual-network vnet-prod \
  --registration-enabled false
```

The important distinction is:

```text
Private Endpoint:
provides private network interface/IP

Private DNS:
makes the expected hostname resolve to that private path
```

You usually need both for a clean private-access experience.

Practice:

Break the private DNS configuration and observe what changes:

```bash
nslookup mystorage.blob.core.windows.net
```

Then restore the DNS configuration and verify that the application resolves the intended private address.

---

## Part 10 — VNet Peering

VNet Peering connects VNets using Azure's network infrastructure so resources in the connected VNets can communicate using private IP addresses.

Example:

```text
Hub VNet
10.0.0.0/16
     |
     | Peering
     |
     +----------------+
                      |
                Spoke VNet
                10.10.0.0/16
```

The VNets must have non-overlapping address spaces. Peering does not automatically allow every traffic flow; routing and security controls still matter.

Implementation example:

```bash
az network vnet peering create \
  --resource-group rg-network \
  --vnet-name vnet-hub \
  --name hub-to-spoke \
  --remote-vnet vnet-spoke \
  --allow-vnet-access
```

You also need to configure the reverse peering direction for normal bidirectional connectivity.

Hub-and-spoke architectures commonly use VNet Peering. As the number of networks grows, a central connectivity architecture may use services such as Azure Virtual WAN.

Practice:

Connect:

```text
Hub: 10.0.0.0/16
Spoke A: 10.10.0.0/16
Spoke B: 10.20.0.0/16
```

Then determine whether:

```text
Spoke A → Hub
Spoke B → Hub
Spoke A → Spoke B
```

should be allowed by your architecture and what routing/security controls are required.

---

## Part 11 — Hub-and-Spoke Architecture

Hub-and-spoke separates shared network services from workload networks.

The hub may contain:

```text
Azure Firewall
VPN Gateway
ExpressRoute Gateway
DNS infrastructure
Shared management services
```

Spokes contain workload resources:

```text
Spoke A → Application A
Spoke B → Application B
Spoke C → Application C
```

Conceptually:

```text
                 Hub
          +----------------+
          | Firewall       |
          | VPN Gateway    |
          | Shared DNS     |
          +----------------+
            /      |      \
           /       |       \
       Spoke A  Spoke B  Spoke C
       App A    App B    App C
```

The architectural advantage is centralization of shared connectivity and security services. The trade-off is that the hub can become a dependency and potentially a blast-radius concern if badly designed.

A Senior/Lead engineer should therefore ask:

```text
Is the hub highly available?
What happens if Firewall is unavailable?
How are routes propagated?
Can one spoke reach another?
Who owns the hub?
How are changes governed?
```

Practice:

Design a production hub-and-spoke architecture for:

```text
50 application teams
3 environments
on-premises connectivity
central outbound inspection
private PaaS access
```

Identify what belongs in the hub and what belongs in spokes.

---

## Part 12 — Azure Load Balancer

Azure Load Balancer operates at Layer 4 and distributes TCP/UDP traffic across backend resources. Layer 4 means it only sees IP addresses and ports; it cannot read the HTTP request inside the traffic.

Conceptually:

```text
Client
  |
  v
Public Load Balancer
  |
  +---- VM 1
  |
  +---- VM 2
  |
  +---- VM 3
```

It uses frontend IPs, backend pools, health probes, and load-balancing rules.

A health probe is important because the load balancer should avoid sending traffic to an unhealthy backend.

Implementation example:

```bash
az network lb create \
  --resource-group rg-network \
  --name lb-app \
  --sku Standard \
  --frontend-ip-name frontend \
  --backend-pool-name backend \
  --public-ip-address pip-lb
```

The Load Balancer is not an application-aware reverse proxy. It does not provide the same Layer 7 capabilities as Application Gateway.

Think:

```text
Load Balancer:
TCP/UDP traffic distribution

Application Gateway:
HTTP/HTTPS-aware routing
```

Practice:

Design a backend pool with three application instances and explain:

```text
What is the frontend IP?
What is the backend pool?
What does the health probe test?
What happens when one instance fails?
```

---

## Part 13 — Application Gateway

Application Gateway is an Azure Layer 7 load balancer/reverse proxy designed for HTTP/HTTPS traffic. It can make routing decisions using application-level information such as hostname and URL path.

Example:

```text
Client
  |
  v
Application Gateway
  |
  +---- /api/*  → API backend
  |
  +---- /web/*  → Web backend
```

This is different from a Layer 4 Load Balancer because Application Gateway understands HTTP-level traffic.

A simplified architecture:

```text
Internet
   |
   v
Application Gateway
   |
   +--> Backend Pool
   |
   +--> Health Probes
   |
   +--> Routing Rules
```

Application Gateway can also integrate with Web Application Firewall capabilities for HTTP-layer protection.

Practice:

Design routing for:

```text
api.example.com → Spring Boot API

www.example.com → Frontend

example.com/images/* → Static/content backend
```

Then decide whether the requirement is primarily Layer 4 or Layer 7.

---

## Part 14 — VPN Gateway

VPN Gateway provides encrypted connectivity between Azure and external networks using VPN technologies.

A common architecture is:

```text
On-Premises
    |
    | IPsec VPN
    |
    v
VPN Gateway
    |
    v
Azure VNet
```

For Site-to-Site VPN, the external network has a VPN device and Azure has a VPN Gateway.

The important troubleshooting areas are:

```text
Address spaces
↓
Gateway configuration
↓
Shared authentication parameters
↓
Tunnel state
↓
Routes
↓
NSG/firewall
↓
Application
```

Overlapping CIDRs can cause serious problems because the network does not have a clean way to distinguish destinations.

Practice:

Imagine:

```text
On-premises: 10.0.0.0/16
Azure:       10.0.0.0/16
```

Explain why connecting these networks creates routing problems and why IP planning should happen before deployment.

---

## Part 15 — ExpressRoute

ExpressRoute provides private connectivity between on-premises environments and Microsoft cloud services through a connectivity provider. It is commonly considered when organizations need predictable private connectivity, higher reliability requirements, or enterprise hybrid connectivity.

Conceptually:

```text
Enterprise Network
       |
       v
Connectivity Provider
       |
       v
ExpressRoute
       |
       v
Azure
```

A Senior/Lead engineer should understand that ExpressRoute is not simply “VPN but faster.” The connectivity architecture, routing, provider relationship, and operational model are different.

A simplified comparison:

```text
VPN:
encrypted connection over shared/public infrastructure

ExpressRoute:
private connectivity through supported provider architecture
```

Practice:

For an enterprise application that must communicate continuously with on-premises databases, compare:

```text
Site-to-Site VPN
ExpressRoute
```

Consider:

```text
Connectivity model
Reliability requirements
Routing
Operational complexity
Cost
Security requirements
```

Do not select purely on the label “enterprise.”

---

## Part 16 — Azure Networking for AKS

AKS networking combines Azure networking and Kubernetes networking. This is where the networking concepts from earlier days become especially important.

A simplified path is:

```text
User
 |
 v
Azure Load Balancer / Application Gateway
 |
 v
AKS
 |
 v
Kubernetes Service
 |
 v
Pod
 |
 v
Application
```

For an application calling an Azure database:

```text
Pod
 |
 v
DNS
 |
 v
Private Endpoint / Private IP
 |
 v
Route
 |
 v
NSG / Firewall
 |
 v
Database
```

AKS introduces additional concepts such as:

```text
Pod IP
Service IP
Ingress
NetworkPolicy
Kubernetes DNS
Azure VNet
NSG
UDR
Load Balancer
```

This means troubleshooting cannot stop at Kubernetes.

For example, if a Pod cannot reach an Azure database, investigate:

```text
Pod DNS
→ destination IP
→ Kubernetes network
→ Azure route
→ NSG
→ Firewall
→ database port
→ database health
→ credentials
```

Practice:

Deploy a simple application to AKS and connect it to an Azure database through a private endpoint. Draw the complete packet path before troubleshooting.

---

## Part 17 — Outbound vs Inbound Traffic

Inbound and outbound traffic are separate architectural problems.

Inbound:

```text
Internet
  ↓
Public IP
  ↓
Load Balancer / Application Gateway
  ↓
Backend
```

Outbound:

```text
Backend
  ↓
NAT Gateway / Firewall
  ↓
Public destination
```

This distinction is extremely useful during troubleshooting.

Suppose users can access your application but the application cannot call an external API. The inbound path may be completely healthy. You should investigate outbound routing, NAT, firewall policy, DNS, and external connectivity.

Conversely, if the application can call external services but users cannot reach it, investigate the inbound path.

Practice:

For this scenario:

```text
Users → Application works
Application → Payment API fails
```

Do not inspect the public load balancer first. Start with:

```text
Application
→ DNS
→ route
→ outbound security
→ NAT/firewall
→ destination
```

---

## Part 18 — DNS Troubleshooting in Azure

DNS problems frequently appear as application connectivity problems. A hostname may resolve to the wrong IP, resolve to a public address when a private address is expected, or fail to resolve completely.

The first diagnostic step is:

```bash
nslookup api.example.com
```

or:

```bash
dig api.example.com
```

Then compare the result with the architecture you intended.

For a private service:

```text
Expected:
10.20.3.10

Actual:
20.x.x.x
```

That immediately tells you that the application may be taking the public path instead of the private path.

For Azure Private Endpoint troubleshooting, check:

```text
Private DNS zone
      ↓
VNet link
      ↓
DNS resolution
      ↓
Private endpoint IP
```

Implementation example:

```bash
az network private-dns zone list \
  --resource-group rg-network

az network private-dns link vnet list \
  --resource-group rg-network \
  --zone-name privatelink.blob.core.windows.net
```

Practice:

Break the VNet link to a private DNS zone and test name resolution from a workload. Restore the link and confirm that the expected private address is returned.

---

## Part 19 — Complete Azure Network Troubleshooting Workflow

Use a fixed sequence instead of randomly changing networking resources.

Start with the hostname:

```text
1. DNS
```

Determine the destination IP:

```text
2. IP
```

Check routing:

```text
3. Route
```

Check filtering:

```text
4. NSG
5. Azure Firewall
6. NetworkPolicy if Kubernetes is involved
```

Check the port:

```text
7. TCP/UDP connectivity
```

Check the service:

```text
8. Is the destination actually listening?
```

Check the application:

```text
9. Logs
10. Configuration
11. Authentication
```

Useful commands:

```bash
nslookup <hostname>

ip route

nc -vz <ip> <port>

curl -v https://<hostname>
```

From Kubernetes:

```bash
kubectl run net-debug \
  --rm -it \
  --image=busybox:1.36 \
  -- sh
```

Then:

```bash
nslookup <service>
wget -qO- http://<service>
```

For Azure routing investigation:

```bash
az network watcher show-topology \
  --resource-group rg-network
```

For a VM, Network Watcher can also help inspect the effective route and connectivity.

The key rule is:

**Do not change five networking controls at once. Make one evidence-based change, test again, and record what changed.**

Practice:

Troubleshoot:

```text
AKS Pod
  ↓
orders-db.internal
  ↓
connection timeout
```

Work through:

```text
DNS
→ IP
→ Kubernetes route
→ Azure route
→ NSG
→ Firewall
→ port 5432
→ PostgreSQL
```

---

## Part 20 — Senior/Lead Architecture Exercise

Design the network architecture for a production application with:

```text
Frontend
Backend API
AKS
Azure Database
Azure Storage
On-premises integration
Internet users
```

Requirements:

```text
Frontend is internet-facing
Backend is not directly exposed to the internet
Database uses private connectivity
Storage should use private access
Outbound traffic should use predictable IPs
On-premises connectivity is required
Central security inspection is required
Multiple application teams share the platform
```

A possible conceptual architecture is:

```text
                         Internet
                            |
                            v
                    Application Gateway
                            |
                            v
                           AKS
                         /     \
                        /       \
                       v         v
              Private Endpoint  Outbound
                   |             |
                   v             v
                Database     NAT / Firewall
                   |
                   v
             Private Storage


On-Premises
     |
     v
VPN / ExpressRoute
     |
     v
Hub VNet
     |
     +------ Spoke VNet → AKS
```

The exercise is not about producing one universally correct diagram. Explain the reasoning behind your choices.

Answer:

1. Why is the database private?
2. Why use Application Gateway instead of exposing the backend directly?
3. Where should outbound traffic leave Azure?
4. Where should centralized inspection happen?
5. How does AKS reach the database?
6. How does DNS know to use the private endpoint?
7. How does on-premises traffic reach the application?
8. What happens if a route is wrong?
9. What happens if DNS is wrong?
10. What happens if NSG is wrong?
11. Which components create the largest blast radius?
12. Which components need high availability?

---

## Part 21 — Practice: Build an Azure Networking Lab

Build a small network:

```text
Resource Group
    |
    v
VNet 10.50.0.0/16
    |
    +-- App subnet 10.50.1.0/24
    |
    +-- Data subnet 10.50.2.0/24
    |
    +-- Private Endpoint subnet 10.50.3.0/24
```

Create:

```text
NSG
Route table
NAT Gateway
Storage Account
Private Endpoint
Private DNS Zone
```

Example commands:

```bash
az group create \
  --name rg-network-lab \
  --location centralindia
```

Create VNet:

```bash
az network vnet create \
  --resource-group rg-network-lab \
  --name vnet-network-lab \
  --address-prefix 10.50.0.0/16 \
  --subnet-name snet-app \
  --subnet-prefix 10.50.1.0/24
```

Create the data subnet:

```bash
az network vnet subnet create \
  --resource-group rg-network-lab \
  --vnet-name vnet-network-lab \
  --name snet-data \
  --address-prefix 10.50.2.0/24
```

Create the private endpoint subnet:

```bash
az network vnet subnet create \
  --resource-group rg-network-lab \
  --vnet-name vnet-network-lab \
  --name snet-private-endpoints \
  --address-prefix 10.50.3.0/24
```

Then implement:

```text
NSG filtering
Private Endpoint
Private DNS
NAT Gateway
```

Validate each layer separately.

Do not simply create everything and assume it works. Test:

```text
DNS
Route
Security
Port
Service
```

Then deliberately break:

```text
NSG rule
Private DNS link
Route
Application destination
```

and troubleshoot each failure.

---

## Part 22 — Failure Drill: Wrong Route

Scenario:

```text
Application
   |
   | HTTPS
   v
External API
```

The application worked yesterday. Today it times out.

You discover that a new route table was associated with the application subnet.

Investigate:

```text
1. What is the destination IP?
2. Which route matches it?
3. What is the next hop?
4. Was the route table recently changed?
5. Is traffic now being sent to a firewall/NVA (network virtual appliance)?
6. Does that device allow the traffic?
7. Is return traffic also routed correctly?
```

The lesson is that a route can be syntactically valid but architecturally wrong.

A common Senior/Lead failure mode is assuming:

> “The route exists, therefore routing works.”

Instead ask:

> “Is the selected route the intended route for this destination?”

---

## Part 23 — Failure Drill: Private Endpoint DNS

Scenario:

```text
Application → Storage Account
```

The private endpoint exists and its private IP is healthy, but the application still reaches the public endpoint.

Test:

```bash
nslookup mystorage.blob.core.windows.net
```

Suppose the result is a public address.

Investigate:

```text
Private DNS zone exists?
        ↓
Correct zone name?
        ↓
VNet linked?
        ↓
DNS resolution path correct?
        ↓
Private endpoint associated?
```

The key insight is:

**A private endpoint does not automatically mean every application will correctly resolve the service hostname to the private IP.**

Practice:

Intentionally break the DNS configuration, verify the wrong resolution, then restore it and verify private resolution.

---

## Part 24 — Azure ↔ AWS Networking Mapping

The underlying networking concepts are shared across clouds.

| Concept | Azure | AWS |
|---|---|---|
| Virtual network | VNet | VPC |
| Subnet | Subnet | Subnet |
| Security filtering | NSG | Security Groups / NACLs depending use case |
| Route table | Route Table / UDR | Route Table |
| Central firewall | Azure Firewall | AWS Network Firewall |
| NAT | NAT Gateway | NAT Gateway |
| Private PaaS access | Private Endpoint | VPC Endpoint / PrivateLink |
| Private DNS | Azure Private DNS | Route 53 Private Hosted Zone |
| VNet/VPC connection | VNet Peering | VPC Peering |
| Central connectivity | Virtual WAN / Hub-Spoke | Transit Gateway |
| VPN | VPN Gateway | Site-to-Site VPN |
| Dedicated private connectivity | ExpressRoute | Direct Connect |
| L4 load balancing | Azure Load Balancer | Network Load Balancer |
| L7 load balancing | Application Gateway | Application Load Balancer |

The important interview approach is to describe the capability before naming the service.

For example:

> “I need private connectivity from an application network to a managed database without exposing the service through the public internet.”

Then map it:

```text
Azure → Private Endpoint
AWS   → PrivateLink/VPC Endpoint where supported
```

This demonstrates that you understand cloud networking rather than only Azure terminology.

---

## Part 25 — 5-Minute Recall

Without looking at the notes, explain:

1. What problem does a VNet solve?
2. Why does subnet design matter?
3. What does an NSG do?
4. How is an NSG different from a route table?
5. How are NSG priorities evaluated?
6. What does a UDR change?
7. Why would an organization use Azure Firewall?
8. What problem does NAT Gateway solve?
9. Why would an application need a predictable outbound IP?
10. What does a Private Endpoint provide?
11. Why is Private DNS important with Private Endpoint?
12. What does VNet Peering provide?
13. Why are overlapping CIDRs dangerous?
14. What is the difference between Load Balancer and Application Gateway?
15. When would VPN Gateway be used?
16. How is ExpressRoute different conceptually from VPN?
17. Why does AKS networking require both Kubernetes and Azure networking knowledge?
18. What is the difference between inbound and outbound connectivity?
19. What is your standard network troubleshooting sequence?
20. How would you troubleshoot a private Azure PaaS connection that times out?

The sequence worth memorizing is:

**DNS → IP → Route → Security → Port → Service → Application**

---

## Part 26 — Cleanup

Delete only the resources created specifically for this lab.

If everything is inside the dedicated lab resource group:

```bash
az group delete \
  --name rg-network-lab \
  --yes \
  --no-wait
```

Then verify:

```bash
az group show \
  --name rg-network-lab
```

If the lab uses shared networking, do not delete the shared VNet, hub, firewall, DNS infrastructure, or other shared resources.

Before cleanup, inspect what you created:

```bash
az resource list \
  --resource-group rg-network-lab \
  --output table
```

A good learning habit is:

```text
Create
  ↓
Inspect
  ↓
Test
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

**Final mental model for Day 24:**

```text
                    Azure Networking
                          |
       +------------------+------------------+
       |                  |                  |
    Routing            Security             DNS
       |                  |                  |
     UDR             NSG/Firewall       Private DNS
       |                  |
       +---------+--------+
                 |
              Traffic
                 |
       +---------+---------+
       |                   |
    Inbound             Outbound
       |                   |
 App Gateway/LB       NAT/Firewall
       |                   |
       v                   v
   Workload            Internet/API
       |
       v
 Private Endpoint
       |
       v
    Azure PaaS
```

At Senior/Lead level, the objective is not to memorize Azure networking commands. It is to look at a connectivity failure and identify **which layer owns the failure, what evidence proves it, what the safest correction is, and what architectural control prevents the same problem from recurring.**

## Answers to practice

### 1. Packet path for AKS Pod → PostgreSQL

<details>
<summary>Answer</summary>

Write the hostname (for example `orders-db.postgres.database.azure.com`), the IP `nslookup` returns, the subnet route to that IP, NSG and firewall on the path, TCP 5432, then the database listener and credentials.

Do not start with the firewall. Walk DNS → IP → route → security → port → service → application. If DNS returns a public IP, you are not on the private endpoint path.

</details>

### 2. VNet design for web, app, database, private endpoints, and management

<details>
<summary>Answer</summary>

Use a non-overlapping space such as `10.20.0.0/16`. Example: `snet-web 10.20.1.0/24`, `snet-app 10.20.2.0/24`, `snet-data 10.20.3.0/24`, `snet-private-endpoints 10.20.4.0/24`, `snet-management 10.20.5.0/24`. Leave spare `/24`s for growth.

Check on-premises and other VNets before you pick CIDRs. Overlap breaks peering, VPN, and ExpressRoute later. IP planning is architecture, not a later config tweak.

</details>

### 3. NSG rules for Internet→Web 443, Web→App 8080, App→DB 5432, deny Internet→DB

<details>
<summary>Answer</summary>

Allow inbound TCP 443 to the web subnet from the internet (or from Application Gateway only, which is narrower). Allow TCP 8080 from the web subnet to the app subnet. Allow TCP 5432 from the app subnet to the data subnet. Do not allow internet sources to 5432.

Each allow should name the real source, not `*`. Internet→Web 443 is required only if users hit the web tier directly. If Application Gateway is the front door, source that subnet or its private IPs instead.

</details>

### 4. Intentional NSG failure on TCP 5432, then restore

<details>
<summary>Answer</summary>

Add a Deny on inbound TCP 5432 from the app subnet with a lower priority number than the Allow, or remove the Allow so a default deny wins. Test with `nc -vz <db-ip> 5432` from the app. List rules with `az network nsg rule list` and find the first matching deny.

Restore the intended Allow from `10.20.1.0/24` to 5432. Recheck subnet NSG, NIC NSG, route, and firewall. The first matching priority wins. A later deny does not override an earlier allow.

</details>

### 5. App cannot reach on-premises after a route-table change

<details>
<summary>Answer</summary>

Find the on-premises CIDR. Check which route matches it in the subnet route table. The next hop must be the VPN or ExpressRoute gateway, not `Internet` or a wrong appliance IP.

A UDR can be valid JSON and still steal that prefix. Wrong path is routing. Correct path but blocked is NSG or firewall. Do not edit NSGs first.

</details>

### 6. Hub-and-spoke egress through Azure Firewall, and why the route table is required

<details>
<summary>Answer</summary>

Place Azure Firewall in the hub. In each spoke app subnet, add a UDR `0.0.0.0/0` next hop `VirtualAppliance` to the firewall private IP. Spokes peer to the hub. NSGs still filter local subnet traffic.

The firewall never sees packets that routing sends elsewhere. Deploying Firewall without the UDR leaves default internet paths in place. Routing steers. Firewall inspects.

</details>

### 7. Outbound path to a payment API that allowlists source IPs

<details>
<summary>Answer</summary>

Put a NAT Gateway (or Azure Firewall SNAT) on the app subnet. Associate a static Standard public IP such as `pip-nat`. The third party allowlists that public IP, not the private `10.20.1.10`.

NAT Gateway is outbound only. Users still enter through Application Gateway or a load balancer. Do not confuse NAT with inbound load balancing.

</details>

### 8. Private endpoint for Storage: confirm `nslookup` returns a private IP

<details>
<summary>Answer</summary>

Create the private endpoint in `snet-private-endpoints` for the blob group. From a VNet workload run `nslookup mystorage.blob.core.windows.net`. A private IP such as `10.20.3.10` means Private DNS is working.

A public `20.x.x.x` address means the hostname still uses the public endpoint. The private endpoint NIC can be healthy while DNS is wrong. Fix the zone and VNet link, then retest.

</details>

### 9. Break private DNS, observe public resolution, restore private resolution

<details>
<summary>Answer</summary>

Remove the VNet link on `privatelink.blob.core.windows.net`. Run `nslookup mystorage.blob.core.windows.net` again. Expect a public IP. Restore the link with `az network private-dns link vnet create` and confirm the private endpoint IP returns.

Private Endpoint supplies the NIC. Private DNS makes the usual hostname resolve to that NIC. You need both.

</details>

### 10. Peer Hub, Spoke A, and Spoke B, then decide spoke-to-spoke

<details>
<summary>Answer</summary>

Peer Hub `10.0.0.0/16` with Spoke A `10.10.0.0/16` and Spoke B `10.20.0.0/16` in both directions. Spoke → Hub should be allowed for shared firewall, DNS, and gateways.

Spoke A → Spoke B should not be open by default. If required, use hub inspection (firewall) plus routes, or carefully controlled spoke peering. NSGs still must allow the ports. Peering is not a free pass.

</details>

### 11. Production hub-and-spoke for 50 teams, 3 environments, on-prem, inspection, private PaaS

<details>
<summary>Answer</summary>

Hub holds Azure Firewall, VPN or ExpressRoute gateway, private DNS, and shared management. Spokes hold application VNets per team or per environment. Production spokes get stricter NSGs and no public databases.

On-premises lands on the hub gateway. Outbound from spokes uses a UDR to the firewall. Private Endpoints live in spoke or shared PE subnets with Private DNS in the hub. The hub is a shared dependency: make it highly available and tightly change-controlled.

</details>

### 12. Load Balancer backend pool of three instances

<details>
<summary>Answer</summary>

Frontend IP is the public or private address clients hit. The backend pool is the three instance NICs or IPs. The health probe checks a TCP port or HTTP path on each instance.

When one instance fails the probe, the load balancer stops sending new flows there. Remaining healthy instances take traffic. This is Layer 4. It does not read HTTP paths.

</details>

### 13. Application Gateway routing for API, www, and /images

<details>
<summary>Answer</summary>

Create listeners for `api.example.com` → Spring Boot backend, `www.example.com` → frontend, and a path map `example.com/images/*` → static backend. Use HTTP/HTTPS host and path rules.

This is Layer 7. A Layer 4 load balancer cannot route on hostname or URL path. Use Application Gateway (with WAF if required) as the internet front door.

</details>

### 14. On-premises `10.0.0.0/16` and Azure `10.0.0.0/16`

<details>
<summary>Answer</summary>

Both sides own the same prefix. After VPN or ExpressRoute, routers cannot tell which `10.0.1.10` is on-premises and which is Azure. Return traffic is equally ambiguous.

Plan unique CIDRs before you deploy gateways. Overlap is a routing design failure, not a tunnel-setting bug.

</details>

### 15. Site-to-Site VPN vs ExpressRoute for continuous on-premises database access

<details>
<summary>Answer</summary>

VPN encrypts over the public internet. It is faster to stand up, cheaper, and depends on internet quality. ExpressRoute is private connectivity through a provider, with a different routing and operations model, usually higher cost and lead time.

Choose from reliability, bandwidth, routing, operations, cost, and security evidence. Do not pick ExpressRoute only because the slide says “enterprise.” A well-built VPN can be enough; a poorly routed ExpressRoute still fails.

</details>

### 16. AKS to Azure database through a private endpoint — draw the packet path first

<details>
<summary>Answer</summary>

User → Application Gateway or load balancer → AKS Service → Pod → Kubernetes DNS / Azure DNS → private endpoint IP → VNet route → NSG/firewall → private endpoint → PostgreSQL.

If the Pod times out, walk Pod DNS → destination IP → CNI → Azure route → NSG → firewall → 5432 → database health → credentials. Do not stop at `kubectl get pods`. Kubernetes and Azure networking both own this path.

</details>

### 17. Users work, payment API fails — start outbound, not the public load balancer

<details>
<summary>Answer</summary>

Inbound is healthy. Inspect application DNS for the payment hostname, the matching route, NSG/firewall egress, NAT or firewall SNAT IP, then the destination allowlist and API.

Do not start at the public load balancer. Inbound and outbound are different problems. A new UDR to a firewall that lacks an allow rule is a typical cause.

</details>

### 18. Break the VNet link to a private DNS zone, then restore

<details>
<summary>Answer</summary>

Delete the VNet link. From a workload, `nslookup` the PaaS hostname and record the public IP. Recreate the link and confirm the private endpoint IP.

This is the same failure as a missing `privatelink` zone. Connectivity errors then look like “timeout to storage” while the NIC was never in the path.

</details>

### 19. Troubleshoot AKS Pod → orders-db.internal connection timeout

<details>
<summary>Answer</summary>

From a debug Pod run `nslookup orders-db.internal`, then `nc -vz` the returned IP on 5432. Check Kubernetes NetworkPolicy, Azure route, NSG, and firewall. Confirm PostgreSQL is listening and credentials work.

Change one control at a time. Record evidence. DNS → IP → route → security → port → service → application. Do not edit five NSGs at once.

</details>

### 20. Failure drill: private endpoint DNS broken (lab)

<details>
<summary>Answer</summary>

Break the zone or VNet link. Confirm `nslookup` returns a public address while the private endpoint IP stays healthy. Restore DNS and confirm private resolution.

A private endpoint does not automatically make every client resolve the hostname privately. DNS is part of the design.

</details>

### 21. Why is the database private?

<details>
<summary>Answer</summary>

The database holds customer data. It must not have a public listener on the internet. Application Gateway fronts users. Pods reach PostgreSQL through a private endpoint and NSG-limited sources.

Private connectivity shrinks the attack surface. It does not replace credentials, encryption, or backups.

</details>

### 22. Why Application Gateway instead of exposing the backend directly?

<details>
<summary>Answer</summary>

Application Gateway terminates TLS, routes on host and path, probes backends, and can run WAF. AKS node IPs and API Pods stay private.

Exposing the backend public IP skips Layer 7 control and puts Kubernetes nodes on the internet. The front door is the inbound control point.

</details>

### 23. Where should outbound traffic leave Azure?

<details>
<summary>Answer</summary>

Leave through a hub Azure Firewall SNAT or a NAT Gateway with a known public IP, depending on whether you need inspection.

Predictable egress IPs let partners allowlist you. Random instance IPs do not.

</details>

### 24. Where should centralized inspection happen?

<details>
<summary>Answer</summary>

In the hub Azure Firewall, fed by spoke UDRs for internet and optionally for spoke-to-spoke and hybrid traffic.

NSGs still do local allow/deny. Inspection without routing to the firewall is a drawing, not a control.

</details>

### 25. How does AKS reach the database?

<details>
<summary>Answer</summary>

The Pod resolves the database hostname to the private endpoint IP, routes inside the VNet/peering, passes NSG/firewall, and connects to TCP 5432 on PostgreSQL.

If DNS returns a public IP, the Pod tries the public endpoint and may time out when public access is off.

</details>

### 26. How does DNS know to use the private endpoint?

<details>
<summary>Answer</summary>

A Private DNS zone such as `privatelink.postgres.database.azure.com` is linked to the VNet. The zone maps the service hostname to the private endpoint IP.

Without the link, public DNS wins. The private NIC exists and is unused.

</details>

### 27. How does on-premises traffic reach the application?

<details>
<summary>Answer</summary>

On-premises → VPN Gateway or ExpressRoute → hub VNet → peering to the spoke → Application Gateway private frontend or internal load balancer → AKS.

Routes both ways must exist. NSGs must allow the on-premises CIDR to the intended port. Overlapping CIDRs break this path.

</details>

### 28. What happens if a route is wrong?

<details>
<summary>Answer</summary>

Packets go to the wrong next hop: internet, a blackhole, or a firewall that never expected them. The app times out even when NSGs look correct.

Ask whether the selected route is the intended route for that destination, not only whether a route exists.

</details>

### 29. What happens if DNS is wrong?

<details>
<summary>Answer</summary>

The client connects to the wrong IP: public PaaS, an old record, or NXDOMAIN. Private Endpoint and NSGs never see the traffic.

`nslookup` is the first tool. Fix resolution before you rewrite firewall rules.

</details>

### 30. What happens if NSG is wrong?

<details>
<summary>Answer</summary>

The route is correct and the packet is dropped. Symptoms look like a timeout, same as a bad route.

Use Network Watcher IP flow verify and list NSG rules by priority. Restore the narrow Allow. Do not open `*` to “make it work.”

</details>

### 31. Which components create the largest blast radius?

<details>
<summary>Answer</summary>

Hub firewall, hub gateway, shared Private DNS, and a shared Application Gateway affect every spoke. A bad UDR on a shared hub route can isolate many teams.

Spoke NSGs and one workload’s private endpoint have smaller blast radius. Treat hub changes as production changes.

</details>

### 32. Which components need high availability?

<details>
<summary>Answer</summary>

Application Gateway, Azure Firewall, VPN/ExpressRoute gateway, NAT Gateway (where SKU allows), and zone-redundant database and AKS node pools.

A single-zone hub firewall takes down egress and inspection for every spoke when that zone fails.

</details>

### 33. What problem does a VNet solve?

<details>
<summary>Answer</summary>

It provides the private IP space and boundary for routing, security, connectivity, and workload placement.

It is not only a bag of addresses.

</details>

### 34. Why does subnet design matter?

<details>
<summary>Answer</summary>

Subnets place workloads, attach NSGs, NAT, and route tables, and some services need dedicated subnets. Changing CIDR later is hard.

Overlap with on-premises or peers blocks hybrid connectivity.

</details>

### 35. What does an NSG do?

<details>
<summary>Answer</summary>

It filters traffic by source, destination, protocol, port, and direction.

It does not choose the next hop. That is routing.

</details>

### 36. How is an NSG different from a route table?

<details>
<summary>Answer</summary>

A route table answers where traffic goes. An NSG answers whether that traffic is allowed.

Wrong path: routing. Correct path but blocked: NSG or firewall.

</details>

### 37. How are NSG priorities evaluated?

<details>
<summary>Answer</summary>

Lower numerical priority is evaluated first. The first match wins. Default rules still exist if you add no custom rule.

An Allow at 100 beats a Deny at 110 for the same traffic.

</details>

### 38. What does a UDR change?

<details>
<summary>Answer</summary>

It overrides system routes for matching prefixes so you can send traffic to a firewall, gateway, or other next hop.

A default `0.0.0.0/0` to a virtual appliance is the usual forced-tunnel pattern.

</details>

### 39. Why would an organization use Azure Firewall?

<details>
<summary>Answer</summary>

For centralized, stateful inspection and egress control across many spokes.

NSGs stay for local subnet filtering. The two controls solve different problems.

</details>

### 40. What problem does NAT Gateway solve?

<details>
<summary>Answer</summary>

Predictable outbound internet connectivity for private subnets using SNAT to a static public IP.

It is not an inbound load balancer.

</details>

### 41. Why would an application need a predictable outbound IP?

<details>
<summary>Answer</summary>

Third parties allowlist source IPs for payment, partner, or SaaS APIs.

Without NAT or firewall SNAT, instance IPs change and the partner blocks you.

</details>

### 42. What does a Private Endpoint provide?

<details>
<summary>Answer</summary>

A private IP in your VNet for a supported Azure PaaS resource, so the app uses private connectivity instead of the public endpoint.

Security architecture can then control and monitor that path.

</details>

### 43. Why is Private DNS important with Private Endpoint?

<details>
<summary>Answer</summary>

Applications still use the public hostname. Private DNS must return the private endpoint IP.

Without it, clients keep using the public address even if the NIC exists.

</details>

### 44. What does VNet Peering provide?

<details>
<summary>Answer</summary>

Private IP connectivity between VNets over Azure’s backbone.

Address spaces must not overlap. Routes and NSGs still apply.

</details>

### 45. Why are overlapping CIDRs dangerous?

<details>
<summary>Answer</summary>

Routers cannot uniquely identify a destination across VPN, ExpressRoute, or peering.

Fix address plans before you connect networks.

</details>

### 46. Difference between Load Balancer and Application Gateway

<details>
<summary>Answer</summary>

Azure Load Balancer distributes TCP/UDP at Layer 4. Application Gateway routes HTTP/HTTPS at Layer 7 using host and path, and can add WAF.

Pick from protocol need, not from which name is more familiar.

</details>

### 47. When would VPN Gateway be used?

<details>
<summary>Answer</summary>

For encrypted Site-to-Site (or similar) connectivity between on-premises and Azure over VPN.

Use it when private provider connectivity is not required or not ready.

</details>

### 48. How is ExpressRoute different conceptually from VPN?

<details>
<summary>Answer</summary>

VPN is encrypted over shared public infrastructure. ExpressRoute is private connectivity through a supported provider.

Routing, operations, lead time, and cost differ. It is not “VPN but faster” as a slogan.

</details>

### 49. Why does AKS networking need both Kubernetes and Azure knowledge?

<details>
<summary>Answer</summary>

A request crosses kube-proxy/CNI, Services, NetworkPolicy, then VNet routes, NSGs, load balancers, and private endpoints.

A healthy Pod can still time out on Azure routing or DNS.

</details>

### 50. Difference between inbound and outbound connectivity

<details>
<summary>Answer</summary>

Inbound is client → public IP → Application Gateway or load balancer → backend. Outbound is backend → NAT or firewall → public destination.

Users working does not prove egress works.

</details>

### 51. Standard network troubleshooting sequence

<details>
<summary>Answer</summary>

DNS → IP → route → security (NSG, firewall, NetworkPolicy) → port → service → application.

Use `nslookup`, `ip route`, `nc -vz`, then Azure Network Watcher. Change one thing at a time.

</details>

### 52. Troubleshoot a private Azure PaaS connection that times out

<details>
<summary>Answer</summary>

Resolve the hostname. If it is public, fix Private DNS and the VNet link. If it is private, check route to that IP, NSG, firewall, private endpoint NIC, then the service port and credentials.

The private endpoint can be healthy while DNS still aims at the public endpoint.

</details>

### 53. Design the production network for frontend, API, AKS, DB, Storage, on-prem, internet users

<details>
<summary>Answer</summary>

Internet users hit Application Gateway. AKS in a spoke stays private. Database and Storage use private endpoints plus Private DNS. Outbound uses hub firewall or NAT with known IPs. On-premises uses VPN or ExpressRoute into the hub. Teams get spokes, not a shared flat VNet.

Explain each choice with traffic path and blast radius. There is not one universal diagram. The requirements in Part 20 are the score.

</details>

### 54. Build the Azure networking lab and validate each layer

<details>
<summary>Answer</summary>

Build `rg-network-lab` with VNet `10.50.0.0/16`, app `10.50.1.0/24`, data `10.50.2.0/24`, PE `10.50.3.0/24`. Add NSG, route table, NAT Gateway, Storage, private endpoint, and Private DNS. Test DNS, route, security, port, and service separately.

Then break an NSG rule, the DNS link, a route, and the application destination. Troubleshoot each with the standard sequence. Destroy the lab resource group when done.

</details>

### 55. Failure drill: wrong route after a new route table — HTTPS API timeout

<details>
<summary>Answer</summary>

Find the destination IP. See which route matches. Read the next hop. Check whether the new table sends traffic to a firewall or NVA. Confirm that device allows HTTPS and that return routing exists.

The route can exist and still be the wrong route. Do not assume “a default route is present, so internet works.”

</details>
