# Day 12 — Cloud Networking: Azure & AWS

## What you will learn

Cloud networking is the foundation that allows applications, databases, users, and cloud services to communicate securely. For a Senior/Lead DevOps engineer, knowing how to create a VNet or VPC is not enough; you need to understand how traffic moves, where it is allowed, how private resources reach other services, and how enterprise networks are structured. This lesson builds one networking model and then maps it between Azure and AWS.

---

## Part 1 — The Cloud Network Mental Model

1. What happens when an application communicates with another service?

A network request usually passes through several decisions before it reaches its destination: the application resolves a name to an IP address, the source decides where to send the packet, routing determines the next hop, and network security controls whether the traffic is allowed. The destination may then be reached directly, through a load balancer, through a private endpoint, or through another network. When troubleshooting cloud connectivity, think about the complete path rather than checking only one firewall rule.

**Practice**

For a Spring Boot application connecting to a database, write the expected path:

```text
Application → DNS → Route → Security → Database
```

Then identify what could fail at each step.

2. What is a VNet or VPC?

An Azure VNet and an AWS VPC are the logical private networks in which many cloud resources communicate. They provide an IP address space and allow you to divide that space into subnets, define routes, and control traffic. A VNet or VPC is therefore more than a container for resources: it establishes the network boundary within which connectivity and security decisions are made.

**Remember:** VNet in Azure and VPC in AWS are the primary logical network boundaries.

3. Why do we divide a network into subnets?

Subnets divide a VNet or VPC address space into smaller network segments. This allows different workloads to have different routing, security, and operational requirements. For example, a production design might place application servers in one subnet and databases in another so that database access can be restricted to the application tier instead of allowing broad communication across the entire network.

**Practice**

Design three subnets for a simple application:

```text
Web
Application
Database
```

For each subnet, decide which other subnet should be allowed to communicate with it.

---

## Part 2 — IP Addressing, Routing, and Traffic Flow

4. Why is IP addressing important in cloud networking?

Every network interface needs an address that allows traffic to be delivered to the correct destination. Cloud networks use private IP ranges for internal communication, while public IP addresses provide internet-reachable endpoints where required. Good address planning matters because overlapping address spaces can make VNet/VPC peering, VPN connectivity, and hybrid networking difficult or impossible without redesign.

**Practice**

Create an address plan such as:

```text
VNet/VPC: 10.20.0.0/16
Web:      10.20.1.0/24
App:      10.20.2.0/24
DB:       10.20.3.0/24
```

Identify the network and usable address range for each subnet.

5. What does a Route Table do?

A route table tells the network where traffic destined for a particular address range should go. Cloud platforms provide default routes, but custom routes can direct traffic through appliances, gateways, peering connections, or other network paths. A security rule saying that traffic is allowed does not guarantee connectivity; the traffic also needs a valid route to its destination.

**Practice**

For an application subnet that needs to reach a database subnet, identify the route required and then identify the security rule required. Notice that routing and security solve different problems.

**Remember:** Routing answers **"Where should the traffic go?"** Security answers **"Is the traffic allowed?"**

6. What is a Network Security Group or Security Group?

Azure Network Security Groups and AWS Security Groups control network traffic to resources or network interfaces according to rules such as source, destination, port, and protocol. They are not substitutes for routing: traffic still needs a valid path before a security rule can allow it. A common enterprise pattern is to allow only the minimum required flows, such as application-to-database traffic on the database port, rather than allowing an entire subnet to communicate freely.

**Practice**

For a database listening on port 5432, define the intended rule:

```text
Source: Application subnet
Destination: Database
Port: 5432
Protocol: TCP
Action: Allow
```

Then consider why an internet-wide source would be inappropriate for a private database.

7. What is the difference between Routing and Security?

Routing determines the path a packet can take, while security controls determine whether the packet is permitted to pass. Both must work together. If a route is missing, an allowed packet may still fail; if the route exists but a security rule blocks the traffic, the packet still fails. This distinction is one of the most useful troubleshooting concepts in cloud networking.

**Practice**

When an application cannot connect to a database, check these separately:

```text
DNS → IP → Route → Security Rule → Port → Database
```

Do not assume a successful DNS lookup means the network path is working.

---

## Part 3 — Internet and Private Connectivity

8. How does a private subnet reach the Internet?

A private subnet normally does not give its resources directly reachable public addresses. If those resources need outbound internet access, traffic can be routed through a NAT service or equivalent outbound gateway. This allows resources such as application servers to download updates or call external APIs without making the resources directly reachable from the internet. The exact service differs between Azure and AWS, but the architectural purpose is similar.

**Practice**

For a private application subnet, answer:

> "How can this application call an external API without receiving an inbound internet connection?"

Identify the route and NAT component required by the cloud platform.

9. What allows traffic from the Internet into a cloud workload?

Inbound internet connectivity normally requires a public-facing endpoint and an appropriate network path. A load balancer, application gateway, or similar service can receive public traffic and forward it to private application resources. Security rules should then restrict which traffic reaches the backend. A strong architecture avoids giving every application server its own public IP when a controlled public entry point can provide the required access.

**Practice**

Design the path for a public web application:

```text
Internet → Public Load Balancer → Private Application
```

Identify where DNS, TLS, routing, and security controls belong.

10. What is a NAT Gateway?

A NAT Gateway provides outbound internet connectivity for private resources without requiring those resources to have public IP addresses. The source address is translated so that the external service sees the NAT's public address rather than the private address of the workload. NAT is primarily about outbound connectivity; it does not make a private workload directly reachable from the internet.

**Remember:** NAT provides controlled outbound internet access; it is not an inbound publishing mechanism.

11. What is a Private Endpoint?

A private endpoint provides private connectivity from a virtual network to a supported managed service by giving the service a private IP address within the network. This allows an application to access services such as storage or databases without sending the service traffic over a public endpoint. Private endpoints are especially useful when organizations require tighter network isolation and want to reduce public exposure.

**Practice**

Consider an application in a private subnet accessing object storage. Compare:

```text
Application → Public Service Endpoint

Application → Private Endpoint → Managed Service
```

Identify the security and network differences.

12. Why is Private DNS important?

Private connectivity often depends on DNS returning a private address instead of a public address. A private endpoint can therefore work correctly at the network level but still cause problems if the application resolves the service name to an unexpected public address. Enterprise private networking frequently combines private endpoints with private DNS zones and appropriate DNS forwarding so applications can use normal service names while resolving them to private addresses.

**Practice**

For a private database endpoint, verify:

```bash
nslookup <database-hostname>
```

Then determine whether the returned address is public or private.

---

## Part 4 — Load Balancing and Application Connectivity

13. Why do we use a Load Balancer?

A load balancer provides a controlled entry point for traffic and distributes requests across multiple backend instances or services. This can improve availability and scalability while hiding the individual backend addresses from clients. Depending on the service, a cloud load balancer may operate at the network or application layer, so the correct service depends on whether you need TCP/UDP forwarding, HTTP-aware routing, TLS termination, path-based routing, or other application features.

**Practice**

For two application instances, design:

```text
Client
   ↓
Load Balancer
  ↙   ↘
App 1  App 2
```

Then ask what happens when App 1 becomes unhealthy.

14. What is the difference between Network and Application Load Balancing?

Network-level load balancing generally works with transport-level traffic such as TCP or UDP and is useful when the load balancer does not need to understand the application protocol. Application-level load balancing understands protocols such as HTTP and HTTPS and can make routing decisions based on information such as hostnames or URL paths. Azure and AWS provide several load-balancing services, so the architectural decision should be based on the traffic and behavior you need rather than simply choosing the most familiar service.

**Practice**

Decide which type you would use for:

- TCP traffic to a database proxy
- HTTPS traffic to `/api`
- HTTPS traffic to `/payments`

Explain what information the load balancer needs to make each decision.

---

## Part 5 — Connecting Networks

15. Why connect two VNets or VPCs?

Organizations often have separate networks for different environments, applications, business units, or shared services. Those networks may still need controlled communication, such as an application network accessing a central monitoring or identity service. Network peering or transit architectures can provide private connectivity while keeping the networks logically separate.

**Practice**

Consider:

```text
Application Network → Shared Services Network
```

List the routes and security controls that would be required before traffic can flow.

16. What is VNet/VPC Peering?

Peering creates private connectivity between two cloud networks so resources can communicate using private IP addresses. Azure VNet Peering and AWS VPC Peering are useful for relatively direct network-to-network connectivity, but large enterprises may prefer centralized transit designs when many networks need to communicate. Peering also requires careful address planning because overlapping CIDR ranges can prevent straightforward routing.

**Remember:** Peering connects networks privately, but it does not automatically mean every resource should be allowed to communicate.

17. What is a Hub-and-Spoke network?

A hub-and-spoke architecture places shared networking and security services in a central hub while application or workload networks operate as spokes. The hub can provide connectivity to shared services, on-premises networks, firewalls, DNS, and other centralized capabilities. This creates a repeatable enterprise pattern where workload teams can operate their own networks without independently rebuilding every shared networking service.

**Practice**

Design:

```text
             Hub
          /   |   \
       Dev   UAT  Prod
```

Decide which services belong in the hub and which belong in the spokes.

18. How does AWS provide centralized network connectivity?

AWS can use centralized networking services such as Transit Gateway to connect multiple VPCs and external networks through a shared transit architecture. This serves a similar architectural purpose to Azure hub-and-spoke designs using centralized connectivity, although the individual services and implementation details differ. The important concept is centralized routing and connectivity without creating an unmanageable mesh of direct connections between every network.

**Practice**

Imagine 20 VPCs that need access to shared services. Compare a full mesh of direct connections with a centralized transit design and identify which design is easier to operate as the number of networks grows.

---

## Part 6 — Hybrid and Enterprise Networking

19. How does a cloud network connect to an on-premises network?

Hybrid connectivity allows cloud resources to communicate with an organization's data center or corporate network using private or controlled connections. VPN connections commonly use encrypted tunnels over the internet, while dedicated connectivity services such as Azure ExpressRoute and AWS Direct Connect provide private connectivity through supported providers. The choice depends on requirements such as reliability, bandwidth, latency, security, and cost.

**Practice**

For a company moving an application database from on-premises to Azure or AWS, identify which traffic still needs to travel between the cloud and data center during the migration.

20. Why is centralized network security useful?

Large organizations often centralize controls such as firewalls, inspection, DNS, and connectivity to on-premises networks so that security requirements are applied consistently. This can reduce duplication and provide a common inspection point, but it also introduces dependencies on shared infrastructure. A Senior/Lead engineer therefore needs to balance centralized control with availability and operational simplicity.

**Practice**

Identify three services that you might centralize in an enterprise hub and one risk created by making each service a shared dependency.

21. How should cloud networking be separated by environment?

Production, UAT, and Dev should have network boundaries appropriate to their risk and connectivity requirements. Production often requires stricter inbound and outbound controls, while development may need more flexibility. Environment separation can be implemented through separate subscriptions/accounts, VNets/VPCs, subnets, security rules, and routing boundaries depending on the organization's architecture.

**Practice**

Design separate network boundaries for Dev, UAT, and Prod and identify which shared services they are allowed to access.

---

## Part 7 — Troubleshooting Cloud Connectivity

22. How should you troubleshoot when an application cannot reach a database?

Start from the application and follow the actual network path rather than changing random security rules. Confirm that the hostname resolves to the expected IP, verify that a route exists, check network security rules, confirm the destination port is listening, and then investigate the database or application itself. This approach narrows the problem layer by layer and prevents the common mistake of assuming every connectivity problem is a firewall problem.

**Practice**

Use the following sequence:

```text
DNS
 ↓
IP
 ↓
Route
 ↓
Security
 ↓
Port
 ↓
Application/Database
```

Useful commands include:

```bash
nslookup <hostname>
ip route
nc -vz <host> <port>
traceroute <host>
```

Use cloud-native network diagnostics where available to inspect routes, security decisions, and connectivity.

**Remember:** Troubleshoot the path in order. Do not start by opening the firewall.

23. What happens when DNS works but the connection still fails?

A successful DNS lookup proves only that the hostname was resolved; it does not prove that traffic can reach the destination. The route may be missing, a security rule may block the port, a network firewall may deny the traffic, the service may not be listening, or the destination may be unhealthy. This is why DNS should be treated as the first layer of connectivity testing rather than proof that the network is working.

**Practice**

If:

```text
nslookup database.example.com → succeeds
nc -vz database.example.com 5432 → fails
```

List the next checks you would perform in order.

---

## Part 8 — Azure and AWS Mapping

24. How do the core Azure and AWS networking concepts map?

The underlying networking ideas are largely the same even though the service names differ. Azure VNet maps conceptually to AWS VPC, Azure subnet to AWS subnet, Azure NSG to AWS Security Group, Azure Route Table to AWS Route Table, Azure NAT Gateway to AWS NAT Gateway, and Azure VNet Peering to AWS VPC Peering. Azure ExpressRoute and AWS Direct Connect provide comparable dedicated connectivity patterns, while Azure hub-and-spoke architectures can be mapped conceptually to AWS centralized transit designs such as Transit Gateway.

**Practice**

Memorize the concepts rather than the names:

```text
VNet        ↔ VPC
Subnet      ↔ Subnet
NSG         ↔ Security Group
Route Table ↔ Route Table
NAT Gateway ↔ NAT Gateway
Peering     ↔ Peering
```

Then explain where the mapping is approximate rather than identical.

---

## Part 9 — Integrated Practice

Design the network for a production Spring Boot application with a web frontend, application tier, database, private storage, and access to an external API.

The application should have no direct public access to the database, application workloads should use private addresses, outbound internet access should be controlled, managed services should use private connectivity where required, and users should enter through a controlled public endpoint.

Start with the network and subnet design, then define routes, security rules, DNS, load balancing, private endpoints, and outbound connectivity. Finally, create the same architecture conceptually in both Azure and AWS and explain which services perform each role.

The objective is to be able to answer:

> "A user sends an HTTPS request to the application. Explain exactly how that request travels through the cloud network and how the response returns."

---

**5-Minute Interview Recall**

Before moving on, you should be able to answer these without looking at the notes:

1. What is a VNet/VPC?
2. Why do we create subnets?
3. Why is IP address planning important?
4. What does a route table do?
5. What is the difference between routing and security?
6. What does an NSG/Security Group control?
7. How does a private subnet access the internet?
8. What does a NAT Gateway do?
9. Why use a private endpoint?
10. Why is private DNS important with private endpoints?
11. Why use a load balancer?
12. What is the difference between network and application load balancing?
13. What is VNet/VPC peering?
14. What is a hub-and-spoke architecture?
15. Why use centralized transit networking at enterprise scale?
16. How does cloud connect to an on-premises network?
17. How would you troubleshoot application-to-database connectivity?
18. Why does successful DNS resolution not prove connectivity?
19. How would you separate Dev, UAT, and Prod networks?
20. Map the major Azure networking concepts to AWS.

**Core Mental Model**

**Name → IP → Route → Security → Port → Service**

At enterprise scale:

**Internet / Users → Public Entry Point → Load Balancer → Private Workload → Private Service**

and:

**Workload Networks → Central Connectivity → Shared Services / On-Premises**

The service names differ between Azure and AWS, but the underlying networking decisions remain the same: **addressing, segmentation, routing, security, connectivity, DNS, availability, and controlled access.**

**Cleanup**

If you created networking resources for the lab, remove them using Terraform or the appropriate cloud deployment workflow. Verify that temporary public IPs, NAT resources, load balancers, private endpoints, gateways, and test resources are no longer running so that the lab does not continue generating charges.
