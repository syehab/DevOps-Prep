# Day 24 — Azure Overlay 03 Azure Advanced Networking

This Day uses three files. Read them in this order.

1. [01-concepts.md](01-concepts.md) — lesson content (this file)
2. [02-questions-and-answers.md](02-questions-and-answers.md) — practice items, each with a model answer
3. [03-implementation.md](03-implementation.md) — hands-on lab

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
