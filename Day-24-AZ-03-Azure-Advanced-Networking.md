# Day 24 — Azure Overlay 03: Azure Advanced Networking

## Part 1 — The Azure Networking Mental Model

You already learned the underlying networking model in Day 3 and the cloud/Kubernetes networking model in Day 12 and Day 15. Azure networking is now a concrete implementation of those ideas. The goal is not to memorize Azure networking products; it is to understand how a packet moves through an Azure architecture and which component controls each decision.

Start with:

```text
Source
  ↓
DNS
  ↓
Destination IP
  ↓
Route
  ↓
Security
  ↓
Port
  ↓
Service
  ↓
Application
```

Azure gives you several controls around this path:

```text
VNet
Subnets
Route Tables / UDRs
NSGs
Azure Firewall
NAT Gateway
Private Endpoint
Private DNS
Load Balancer
Application Gateway
VNet Peering
VPN Gateway
ExpressRoute
```

Each exists for a different reason. A common Senior/Lead mistake is treating all networking services as interchangeable “security” or “connectivity” components.

For example:

```text
NSG          → subnet/NIC traffic filtering
UDR          → route selection
NAT Gateway  → controlled outbound translation
Firewall     → centralized network security/inspection
Private Endpoint → private access to supported PaaS service
Private DNS  → name resolution
Load Balancer → Layer 4 traffic distribution
Application Gateway → Layer 7 HTTP(S) traffic handling
VPN Gateway  → encrypted connectivity
ExpressRoute → private connectivity through provider connectivity
```

**Remember:** First identify the networking problem; then choose the Azure service that solves that problem.

Practice: Draw the network path for a private AKS application connecting to Azure Database for PostgreSQL and identify where DNS, routing, and security are handled.

---

## Part 2 — VNet and Subnet Design

An Azure Virtual Network (VNet) is the fundamental private network boundary for Azure resources that participate in virtual networking. You define an address space using CIDR ranges and divide it into subnets for different workloads or network functions.

Example:

```text
VNet: 10.20.0.0/16

├── snet-aks       10.20.1.0/24
├── snet-app       10.20.2.0/24
├── snet-private   10.20.3.0/24
└── snet-firewall  10.20.4.0/24
```

The exact subnet structure depends on the architecture. Do not create many tiny subnets simply to make a diagram look sophisticated.

Address planning matters because overlapping CIDRs can make future connectivity difficult or impossible without translation or redesign.

Think about:

```text
Current workloads
Future workloads
Peering
VPN
ExpressRoute
On-premises networks
AKS IP consumption
Private endpoints
```

A VNet is also not the same thing as a subnet. A subnet is a subdivision of a VNet and is an important boundary for routing and security configuration.

Practice:

```bash
az network vnet create \
  --resource-group rg-network-lab \
  --name vnet-lab \
  --address-prefix 10.20.0.0/16 \
  --subnet-name snet-app \
  --subnet-prefix 10.20.1.0/24
```

Then inspect:

```bash
az network vnet show \
  --resource-group rg-network-lab \
  --name vnet-lab
```

Ask: How many usable addresses does the subnet provide, and what happens if your future architecture needs substantially more addresses?

---

## Part 3 — NSGs: Filtering Traffic

A Network Security Group (NSG) provides network traffic filtering for supported Azure network interfaces and subnets. It contains security rules that evaluate traffic using characteristics such as source, destination, port, and protocol. NSGs are primarily about **allowing or denying network traffic**, not about choosing where the traffic should be routed.

Conceptually:

```text
Packet
  ↓
NSG
  ├── Allow
  └── Deny
```

A rule might conceptually say:

```text
Source: API subnet
Destination: DB subnet
Port: 5432
Protocol: TCP
Action: Allow
```

A different rule might deny unwanted inbound traffic.

The critical distinction is:

```text
Routing:
"Where should the packet go?"

NSG:
"Is this traffic allowed?"
```

NSGs can be associated with subnets and network interfaces, and effective behavior depends on the complete rule set and association points.

Practice: Create an NSG and add a controlled rule:

```bash
az network nsg create \
  --resource-group rg-network-lab \
  --name nsg-app
```

Then inspect rules:

```bash
az network nsg rule list \
  --resource-group rg-network-lab \
  --nsg-name nsg-app \
  --output table
```

Do not open broad access such as `0.0.0.0/0` to sensitive ports in a production-style lab.

---

## Part 4 — NSG Rule Evaluation and Troubleshooting

NSG rules have priorities. A lower numeric priority is evaluated before a higher numeric priority, and the effective rule set determines whether traffic is allowed or denied. Azure also provides default rules, so absence of a custom allow rule does not necessarily mean “nothing happens”; you must understand the effective rule set.

A useful troubleshooting question is:

```text
Is there an explicit deny?
Is the required allow rule present?
Which NSG is attached?
What is its priority?
Is another security control blocking the traffic?
```

For example:

```text
Rule 100:
Allow TCP 5432 from app subnet

Rule 200:
Deny TCP 5432 from all sources
```

The specific allow rule has higher evaluation precedence because its priority number is lower.

Practice: Create two conflicting rules in a lab and inspect the effective behavior. Then remove the conflict and retest.

When troubleshooting, do not simply add:

```text
Allow Any Any
```

That may prove that a security rule was involved, but it creates a dangerous configuration and does not identify the correct least-privilege rule.

**Senior habit:** Use a temporary narrow diagnostic change, test, and then restore the intended security model.

---

## Part 5 — Route Tables and User Defined Routes

Routing determines the next hop for traffic. Azure has system routes, but you can add custom routes through route tables containing **User Defined Routes (UDRs)**.

The mental model is:

```text
Destination IP
      ↓
Route table
      ↓
Next hop
```

A route might conceptually say:

```text
10.30.0.0/16 → Virtual network peering

0.0.0.0/0 → Virtual appliance
```

The second example is often used when traffic should pass through a centralized network security appliance or firewall.

A route table is therefore not a firewall.

```text
UDR:
Where does traffic go?

NSG:
Is traffic allowed?
```

Practice:

```bash
az network route-table create \
  --resource-group rg-network-lab \
  --name rt-app
```

Create a route:

```bash
az network route-table route create \
  --resource-group rg-network-lab \
  --route-table-name rt-app \
  --name to-shared-network \
  --address-prefix 10.30.0.0/16 \
  --next-hop-type VirtualAppliance \
  --next-hop-ip-address 10.20.4.4
```

The IP above is illustrative. Do not configure a nonexistent next hop in a real workload.

Senior scenario: Application traffic suddenly stops after a route-table change. Your first question should be “What destination is now using which next hop?” rather than immediately modifying NSGs.

---

## Part 6 — Azure Firewall

Azure Firewall is a managed, stateful network security service designed for centralized traffic control and inspection. It can provide network and application-level filtering capabilities depending on configuration and SKU/features, and it is commonly placed in a hub network so multiple workload networks can use centralized security controls.

A conceptual hub-spoke design:

```text
                 Hub VNet
              ┌─────────────┐
              │   Firewall  │
              └──────┬──────┘
                     │
            ┌────────┴────────┐
            │                 │
        Spoke A            Spoke B
        App VNet           App VNet
```

Traffic can be routed through the firewall using UDRs.

The distinction is:

```text
NSG:
Distributed subnet/NIC-level filtering.

Azure Firewall:
Centralized network security and traffic inspection.
```

They can coexist.

Do not assume that deploying a firewall automatically forces traffic through it. Routing must actually direct the traffic to the firewall.

Practice: Draw:

```text
AKS subnet → Firewall → Internet
```

and identify the route required for the traffic to reach the firewall.

---

## Part 7 — NAT Gateway and Outbound Connectivity

NAT Gateway provides scalable outbound internet connectivity for supported Azure resources in a subnet while keeping the workload's private addresses hidden behind the NAT public IP configuration. It is useful when applications need predictable outbound source IPs or controlled outbound internet connectivity.

Conceptually:

```text
Private workload
10.20.1.10
      ↓
NAT Gateway
      ↓
Public IP
      ↓
Internet
```

The important distinction is:

```text
Inbound:
NAT Gateway is not a general inbound publishing mechanism.

Outbound:
NAT Gateway provides source network address translation.
```

This can be important when an external payment provider requires an allowlist:

```text
ShopSphere
   ↓
NAT Gateway
   ↓
Fixed public IP
   ↓
Payment Provider
```

Practice: Design outbound access for an application that must call an external API whose firewall allows only approved public IP addresses.

Ask:

```text
What source IP does the external service see?
How do we make it predictable?
What happens if the public IP changes?
```

---

## Part 8 — Private Endpoint

A private endpoint provides a private IP address in your VNet for accessing a supported Azure service through Azure Private Link. The key idea is that the client connects to a private address associated with the service rather than requiring a public network path to that service.

Conceptually:

```text
Application subnet
      ↓
Private IP
10.20.3.10
      ↓
Private Endpoint
      ↓
Azure PaaS service
```

This is particularly useful for services such as supported Storage, Key Vault, databases, and other Private Link-enabled services.

A private endpoint does not simply mean:

```text
"Put the entire Azure service inside my VNet."
```

Instead, it creates a private connectivity interface from your VNet to the supported service.

This distinction matters because the service remains an Azure managed service while access can use a private endpoint.

Practice: Identify where you could use private endpoints in ShopSphere:

```text
Key Vault
Storage
Container registry
Database
```

For each, explain why private access may be useful and what DNS changes are required.

---

## Part 9 — Private DNS

Private connectivity is incomplete if clients cannot resolve the service name to the private endpoint address.

Suppose the application uses:

```text
myvault.vault.azure.net
```

The architecture needs DNS behavior that directs the application toward the appropriate private endpoint address when private access is configured.

Conceptually:

```text
Application
     ↓
DNS query
     ↓
Private DNS
     ↓
Private IP
     ↓
Private Endpoint
     ↓
Azure Service
```

This is why Private Endpoint and Private DNS are commonly discussed together.

A network can be perfectly configured while the application still fails because:

```text
DNS resolves to public IP
```

when the application architecture expects private connectivity.

Practice: From a VM or container with access to the VNet, test:

```bash
nslookup <service-name>
```

Then verify whether the returned address matches the intended private path.

**Remember:** Private connectivity without correct DNS often looks like a networking failure even though the private endpoint itself is healthy.

---

## Part 10 — VNet Peering

VNet peering provides private connectivity between Azure VNets over Microsoft's backbone network. Once peered and correctly configured, resources in the VNets can communicate using private IP addresses subject to routing and security controls.

Conceptually:

```text
VNet A
10.20.0.0/16
    │
    │ Peering
    │
VNet B
10.30.0.0/16
```

Address planning matters because overlapping address spaces create connectivity problems.

Peering is useful for relatively direct connectivity, but enterprise environments with many networks often need a more scalable topology.

A hub-and-spoke model can centralize shared services:

```text
             Hub
        ┌──────┼──────┐
        │      │      │
     Spoke A Spoke B Spoke C
```

The hub may contain:

```text
Firewall
VPN Gateway
ExpressRoute Gateway
DNS
Shared services
```

Practice: Explain why ten directly peered VNets can become difficult to manage and how hub-and-spoke can simplify the architecture.

---

## Part 11 — Hub-and-Spoke Architecture

Hub-and-spoke separates shared network capabilities from workload networks.

A simplified design:

```text
                         Hub VNet
                ┌─────────────────────┐
                │ Firewall             │
                │ VPN Gateway          │
                │ ExpressRoute Gateway │
                │ Shared DNS           │
                └──────────┬──────────┘
                           │
             ┌─────────────┼─────────────┐
             │             │             │
          Spoke A       Spoke B       Spoke C
          App A         App B         App C
```

The benefit is centralized networking and security while workload teams retain ownership of their application networks.

But centralization creates dependencies.

If:

```text
All traffic
   ↓
Central Firewall
```

then a firewall problem can affect many workloads.

Therefore a Senior/Lead architecture must consider:

```text
Centralization benefits
vs
Centralized failure/blast radius
```

Practice: Identify three shared services you would place in the hub and three things you would keep in workload spokes.

---

## Part 12 — Azure Load Balancer

Azure Load Balancer operates primarily at Layer 4 and distributes TCP/UDP traffic across backend instances according to its configuration and health probes. It is useful when you need high-performance network-level load balancing rather than HTTP-aware routing.

Conceptually:

```text
Client
  ↓
Azure Load Balancer
  ↓
Backend Pool
 ├── VM1
 ├── VM2
 └── VM3
```

The load balancer can use health probes to avoid sending traffic to unhealthy backend instances.

It does not inherently understand application concepts such as:

```text
URL path
Host header
HTTP headers
```

For HTTP-aware routing, another layer may be more appropriate.

Practice: Compare:

```text
TCP connection
vs
HTTP request
```

and decide which load-balancing layer needs to understand each.

---

## Part 13 — Application Gateway

Azure Application Gateway is a Layer 7 web traffic service that can provide HTTP(S) load balancing, TLS termination, host/path-based routing, and integration with web application firewall capabilities depending on configuration.

Conceptually:

```text
Client
  ↓
Application Gateway
  ├── /orders → Orders backend
  ├── /users  → Users backend
  └── /admin  → Admin backend
```

Because it understands HTTP(S), it can make decisions that a Layer 4 load balancer cannot.

This creates a useful comparison:

```text
Azure Load Balancer
→ Layer 4
→ TCP/UDP
→ Network-level distribution

Application Gateway
→ Layer 7
→ HTTP/HTTPS
→ Application-aware routing
```

Do not treat these as universally interchangeable. The correct choice depends on protocol and routing requirements.

Practice: Design an architecture where:

```text
shop.example.com/orders → Orders service
shop.example.com/catalog → Catalog service
```

Explain why an HTTP-aware component is useful.

---

## Part 14 — VPN Gateway

Azure VPN Gateway provides encrypted connectivity between Azure VNets and external networks over VPN technologies.

Common patterns include:

```text
On-premises
     │
     │ IPsec VPN
     ↓
Azure VPN Gateway
     ↓
Azure VNet
```

and:

```text
VNet A
  ↓
VPN Gateway
  ↓
VNet / external network
```

VPN connectivity commonly travels over the public internet while using encryption to protect traffic.

When troubleshooting VPN connectivity, think about:

```text
Local network
 ↓
Public reachability
 ↓
VPN gateway
 ↓
Tunnel status
 ↓
Routes
 ↓
NSGs / firewall
 ↓
Destination
```

A tunnel being “up” does not guarantee that application traffic can reach its destination. Routing and security must still permit the traffic.

Practice: Draw the complete path from an on-premises application to a private Azure database over VPN.

---

## Part 15 — ExpressRoute

ExpressRoute provides private connectivity between an organization's network and Azure through an ExpressRoute connectivity provider or supported exchange model. Unlike a typical site-to-site VPN, the traffic path does not rely on the public internet in the same way.

Conceptually:

```text
Corporate Network
       ↓
Connectivity Provider
       ↓
ExpressRoute
       ↓
Azure
       ↓
VNet
```

ExpressRoute is generally considered for enterprise connectivity requirements involving predictable private connectivity, bandwidth, compliance, or network architecture.

However, “private connectivity” does not mean every security requirement disappears. You still need:

```text
Routing
NSGs
Firewalls
Identity
Application authorization
```

Practice: Compare VPN and ExpressRoute for:

```text
Encryption
Connectivity path
Operational complexity
Cost
Bandwidth
Use case
```

Do not reduce the comparison to “VPN is insecure and ExpressRoute is secure.” Security depends on the complete architecture and controls.

---

## Part 16 — Azure Networking for AKS

AKS adds another networking layer to the Azure architecture.

A simplified view:

```text
Azure VNet
     ↓
AKS networking
     ↓
Nodes
     ↓
Pods
     ↓
Services
     ↓
Ingress / Load Balancer
```

Now combine the Day 15 Kubernetes model with Azure:

```text
Internet
  ↓
Azure Load Balancer / Application Gateway
  ↓
Ingress
  ↓
Kubernetes Service
  ↓
Pod
  ↓
Private dependency
  ↓
Database / Azure service
```

A troubleshooting failure could happen at any layer.

For example:

```text
Application cannot reach database
```

could involve:

```text
Pod DNS
Service/DNS
VNet routing
UDR
NSG
Azure Firewall
Private Endpoint
Private DNS
Database firewall
Database listener
Application credentials
```

This is why AKS networking often feels complicated: Kubernetes networking and Azure networking interact.

Practice: Draw the complete path from an AKS Pod to an Azure database through a private endpoint.

---

## Part 17 — Outbound vs Inbound Traffic

Always classify a networking problem as inbound or outbound first.

Inbound:

```text
Internet
 ↓
Public entry
 ↓
Application
```

Outbound:

```text
Application
 ↓
NAT / Firewall / public path
 ↓
External service
```

The controls can differ.

For example:

```text
Inbound:
Application Gateway / Load Balancer
NSG
WAF
Ingress

Outbound:
UDR
Azure Firewall
NAT Gateway
NSG
```

For an external payment provider, the application may need:

```text
Predictable outbound IP
```

For a public API, the application may need:

```text
Controlled inbound HTTPS
```

Practice: Create two diagrams for ShopSphere:

```text
Inbound customer request
Outbound payment request
```

Identify every Azure networking component involved in each.

---

## Part 18 — DNS Troubleshooting in Azure

DNS failures are often misdiagnosed as network failures.

For a private Azure service, investigate:

```text
Application hostname
       ↓
DNS resolver
       ↓
Private DNS zone
       ↓
Private endpoint record
       ↓
Private IP
```

Use:

```bash
nslookup <hostname>
```

or, from Linux:

```bash
dig <hostname>
```

Then compare the result with the expected private IP.

If DNS returns the wrong address:

```text
Do not start changing NSGs.
```

Fix the name-resolution path first.

A useful troubleshooting distinction is:

```text
DNS failure:
Hostname cannot resolve or resolves incorrectly.

Routing failure:
Correct IP exists but traffic has no valid path.

Security failure:
Path exists but traffic is denied.

Port/service failure:
Traffic reaches the destination but the service is not accepting it.
```

Practice: Create a private endpoint lab and deliberately test name resolution before and after the private DNS configuration.

---

## Part 19 — Complete Azure Network Troubleshooting Workflow

Use this sequence during incidents:

```text
1. What is the source?
2. What is the destination?
3. What hostname is being used?
4. What IP does DNS return?
5. What route should traffic follow?
6. What route does Azure actually use?
7. Which NSG/security control applies?
8. Is Azure Firewall involved?
9. Is the required port open?
10. Is the destination service listening?
11. Is authentication succeeding?
12. Is the application itself healthy?
```

For a private database:

```text
Pod
 ↓
DNS
 ↓
Private IP
 ↓
Route
 ↓
NSG / Firewall
 ↓
Private Endpoint
 ↓
Database
 ↓
Authentication
```

Useful commands include:

```bash
az network vnet show ...
az network nsg rule list ...
az network route-table route list ...
nslookup <hostname>
```

Azure also provides network diagnostic capabilities that can help analyze connectivity depending on the resource and architecture.

Practice: Take this failure:

```text
AKS → PostgreSQL timeout
```

Do not make any change until you can state which layer you are testing.

---

## Part 20 — Senior/Lead Architecture Exercise

Design the ShopSphere production network.

Requirements:

- Public users access the application over HTTPS.
- AKS hosts the backend.
- PostgreSQL should use private connectivity.
- Key Vault should be accessed privately where appropriate.
- Application outbound traffic to the payment provider must use predictable public IPs.
- Central security inspection is required.
- Dev and Prod networks must be isolated.
- On-premises systems must reach selected private Azure services.
- Network ownership is centralized, while application teams own workload resources.

Your architecture could conceptually contain:

```text
                         Internet
                            │
                      Application Gateway
                            │
                           AKS
                            │
                  ┌─────────┴─────────┐
                  │                   │
             Private Endpoint      Egress
                  │                   │
             PostgreSQL          Firewall/NAT
                                      │
                                Payment API

On-Prem
   │
VPN / ExpressRoute
   │
  Hub VNet
   │
 ┌─┴───────────────┐
 │                 │
Dev Spoke       Prod Spoke
```

You must now answer:

```text
Where is DNS managed?
Where are routes managed?
Where are security rules applied?
Where does outbound traffic exit?
What source IP does the payment provider see?
How does on-premises reach PostgreSQL?
What happens if the firewall fails?
What happens if DNS fails?
What happens if the payment provider is unavailable?
```

Do not simply reproduce the diagram. Explain the traffic flow.

---

## Part 21 — Practice: Build an Azure Networking Lab

Create a dedicated lab resource group:

```bash
az group create \
  --name rg-network-lab \
  --location centralindia
```

Create a VNet:

```bash
az network vnet create \
  --resource-group rg-network-lab \
  --name vnet-lab \
  --address-prefix 10.20.0.0/16 \
  --subnet-name snet-app \
  --subnet-prefix 10.20.1.0/24
```

Create another subnet:

```bash
az network vnet subnet create \
  --resource-group rg-network-lab \
  --vnet-name vnet-lab \
  --name snet-private \
  --address-prefix 10.20.2.0/24
```

Create an NSG:

```bash
az network nsg create \
  --resource-group rg-network-lab \
  --name nsg-app
```

Then practice the following in sequence:

```text
1. Inspect VNet and subnet configuration.
2. Create an NSG rule.
3. Associate the NSG.
4. Create a route table.
5. Inspect effective routing.
6. Test DNS.
7. Create two VNets.
8. Peer them.
9. Test private connectivity.
10. Create a private endpoint for a supported lab service.
11. Configure/inspect private DNS.
12. Test name resolution.
```

Do not create expensive networking services unless required for the exercise. In particular, managed firewall and ExpressRoute scenarios can introduce significant cost and complexity; use conceptual design or carefully controlled labs when practical.

---

## Part 22 — Failure Drill: Wrong Route

A VM can resolve:

```text
database.internal
→ 10.30.1.10
```

But:

```bash
nc -vz 10.30.1.10 5432
```

times out.

You inspect the route table and discover:

```text
10.30.0.0/16 → Virtual Appliance
```

but the configured appliance is not reachable.

Your reasoning should be:

```text
DNS works
 ↓
Destination IP is correct
 ↓
Route exists
 ↓
Next hop is wrong/unreachable
 ↓
Traffic never reaches database
```

Do not modify the database firewall because the evidence points to routing.

Practice: Describe exactly which evidence would distinguish this from an NSG problem.

---

## Part 23 — Failure Drill: Private Endpoint DNS

An application connects to:

```text
myvault.vault.azure.net
```

The private endpoint exists, but the application still reaches the public address and cannot access the service under the intended network restrictions.

Investigate:

```text
Does DNS resolve?
        ↓
What IP is returned?
        ↓
Is the private DNS zone configured?
        ↓
Is the VNet linked?
        ↓
Does the private endpoint have the expected private IP?
        ↓
Can the application route to that IP?
```

The important insight is:

```text
Private Endpoint
+
Correct DNS
+
Correct routing
+
Correct authorization
=
Working private access
```

All four matter.

---

## Part 24 — Azure ↔ AWS Networking Mapping

| Concept | Azure | AWS |
|---|---|---|
| Virtual network | VNet | VPC |
| Subnet | Subnet | Subnet |
| Security filtering | NSG | Security Group / NACL depending on layer |
| Custom routing | UDR / Route Table | Route Table |
| Central firewall | Azure Firewall | AWS Network Firewall / other firewall architectures |
| Outbound NAT | NAT Gateway | NAT Gateway |
| Private PaaS access | Private Endpoint / Private Link | VPC Endpoint / PrivateLink |
| Private DNS | Private DNS | Route 53 private hosted zones |
| Network peering | VNet Peering | VPC Peering |
| Central connectivity | Hub-Spoke | Transit Gateway-centered architectures |
| Site-to-site VPN | VPN Gateway | Site-to-Site VPN |
| Private dedicated connectivity | ExpressRoute | Direct Connect |
| L4 load balancing | Azure Load Balancer | Network Load Balancer |
| L7 web routing | Application Gateway | Application Load Balancer |

The mapping is conceptual rather than exact.

For example, AWS Security Groups and Azure NSGs both participate in traffic filtering, but their behavior and scope models are not identical. Learn each provider's actual semantics when implementing it.

---

## Part 25 — 5-Minute Recall

What is the difference between VNet and subnet?

**A VNet is the virtual network boundary; a subnet is a segmented address range within that VNet.**

What does an NSG do?

**Filters network traffic according to security rules.**

What does a UDR do?

**Controls routing by defining custom routes and next hops.**

NSG vs UDR?

**NSG = Is traffic allowed? UDR = Where does traffic go?**

What does Azure Firewall provide?

**Centralized, stateful network security and traffic inspection capabilities.**

What does NAT Gateway do?

**Provides scalable outbound source NAT and predictable outbound public IP behavior for supported subnet traffic.**

What does a Private Endpoint do?

**Provides a private IP interface in a VNet for accessing a supported Azure service through Private Link.**

Why is Private DNS important?

**It allows service names to resolve to the intended private endpoint addresses.**

What is VNet Peering?

**Private connectivity between Azure VNets over the Azure backbone, subject to routing and security.**

Why use hub-and-spoke?

**To centralize shared network capabilities while separating workload networks.**

What is Azure Load Balancer?

**Primarily Layer 4 TCP/UDP load balancing.**

What is Application Gateway?

**Layer 7 HTTP(S)-aware traffic management with capabilities such as TLS termination and path/host-based routing.**

VPN vs ExpressRoute?

**VPN provides encrypted connectivity typically over the internet; ExpressRoute provides private connectivity through supported connectivity providers/exchange models.**

What is the most important Azure networking troubleshooting path?

**DNS → IP → Route → Security → Port → Service → Application**

What is the Senior/Lead networking mindset?

**Do not say “network issue.” Identify the exact traffic flow, layer, control point, evidence, and failure boundary.**

**Final mental model:**

> **Azure networking is the combination of address space, routing, security, private connectivity, traffic distribution, DNS, and external connectivity. When something breaks, follow the packet instead of guessing the service.**

---

## Part 26 — Cleanup

Delete the dedicated lab resource group after verifying it contains only resources created for this lesson:

```bash
az group delete \
  --name rg-network-lab \
  --yes \
  --no-wait
```

Verify:

```bash
az group exists \
  --name rg-network-lab
```

Also check for resources that may have been created outside the lab resource group:

```bash
az resource list \
  --output table
```

Review especially:

```text
VNets
Public IPs
Network interfaces
NSGs
Route tables
NAT gateways
Private endpoints
Private DNS zones
Load balancers
Application Gateways
Firewall resources
VPN gateways
```

Some advanced networking services can continue generating charges even when the application workload is no longer running. Confirm that expensive lab resources are removed.

Do not delete shared, production, or centrally managed networking resources.

---

## Next

**Day 25 — Azure Overlay 04: Azure DevOps + IaC Architecture**

This lesson will connect the core CI/CD and Terraform/Bicep lessons to a real Azure enterprise delivery platform:

```text
Azure Repos
     ↓
Azure Pipelines
     ↓
Security
     ↓
Artifacts / ACR
     ↓
Terraform / Bicep
     ↓
Azure Environments
     ↓
AKS / App Service / Container Apps
```

The focus will be on **pipeline architecture, service connections, environments, approvals, variable groups, Key Vault integration, Terraform state, application-vs-infrastructure pipelines, reusable templates, deployment governance, and Senior/Lead CI/CD architecture decisions**.
