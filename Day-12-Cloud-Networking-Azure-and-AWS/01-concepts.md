# Day 12 — Cloud Networking: Azure & AWS

This Day uses three files. Read them in this order.

1. [01-concepts.md](01-concepts.md) — lesson content (this file)
2. [02-questions-and-answers.md](02-questions-and-answers.md) — practice items, each with a model answer
3. [03-implementation.md](03-implementation.md) — hands-on lab

**Goal:** Build one cloud networking model — how traffic moves, where it is allowed, and how private resources reach other services — and then map that same model between Azure and AWS.

## What you will learn

Cloud networking is the foundation that allows applications, databases, users, and cloud services to communicate securely. For a Senior/Lead DevOps engineer, knowing how to create a VNet or VPC is not enough. You need to understand the path a request takes, which component makes each decision along that path, and how enterprise networks are structured. This lesson builds that model once, then shows that Azure and AWS are two vocabularies for the same ideas.

---

## Part 1 — The Cloud Network Mental Model

1. What happens when an application communicates with another service?

Every request walks the same path, and this path is the model for the whole lesson:

```text
Application → DNS → Route → Security → Destination
```

The application resolves a name to an IP address, routing decides where the packet goes next, and network security decides whether the traffic is allowed. The destination may then be reached directly, through a load balancer, through a private endpoint, or through another network. When troubleshooting cloud connectivity, walk this complete path instead of checking only one firewall rule.

2. What is a VNet or VPC?

An Azure VNet and an AWS VPC are the logical private networks in which many cloud resources communicate. They provide an IP address space and allow you to divide that space into subnets, define routes, and control traffic. A VNet or VPC is therefore more than a container for resources: it establishes the network boundary where you make connectivity and security decisions.

**Remember:** VNet in Azure and VPC in AWS are the primary logical network boundaries.

3. Why do we divide a network into subnets?

Subnets divide a VNet or VPC address space into smaller network segments. This allows different workloads to have different routing, security, and operational requirements. For example, a production design might place application servers in one subnet and databases in another. You can then restrict database access to the application tier instead of allowing broad communication across the entire network.

---

## Part 2 — IP Addressing, Routing, and Traffic Flow

4. Why is IP addressing important in cloud networking?

Every network interface needs an address that allows traffic to be delivered to the correct destination. Cloud networks use private IP ranges for internal communication, while public IP addresses provide internet-reachable endpoints where required. Good address planning matters because overlapping address spaces can make VNet/VPC peering, VPN connectivity, and hybrid networking difficult or impossible without redesign.

5. What does a Route Table do?

A route table tells the network where traffic for a particular address range should go. Cloud platforms provide default routes, but custom routes can direct traffic through appliances, gateways, peering connections, or other network paths. A security rule that allows traffic does not guarantee connectivity; the traffic also needs a valid route to its destination.

**Remember:** Routing answers **"Where should the traffic go?"** Security answers **"Is the traffic allowed?"**

6. What is a Network Security Group or Security Group?

Azure Network Security Groups and AWS Security Groups control network traffic to resources or network interfaces according to rules such as source, destination, port, and protocol. They are not substitutes for routing: traffic still needs a valid path before a security rule can allow it. A common enterprise pattern is to allow only the minimum required flows. For example, allow application-to-database traffic on the database port instead of free communication across an entire subnet.

7. What is the difference between Routing and Security?

Routing determines the path a packet can take, while security controls determine whether the packet can pass. Both must work together. If a route is missing, an allowed packet may still fail. If the route exists but a security rule blocks the traffic, the packet still fails. This distinction is one of the most useful troubleshooting concepts in cloud networking.

---

## Part 3 — Internet and Private Connectivity

8. How does a private subnet reach the Internet?

A private subnet normally does not give its resources directly reachable public addresses. If those resources need outbound internet access, you can route traffic through a NAT service or an equivalent outbound gateway. This allows resources such as application servers to download updates or call external APIs without making the resources directly reachable from the internet. The exact service differs between Azure and AWS, but the architectural purpose is similar.

9. What allows traffic from the Internet into a cloud workload?

Inbound internet connectivity normally requires a public-facing endpoint and an appropriate network path. A load balancer, application gateway, or similar service can receive public traffic and forward it to private application resources. Security rules should then restrict which traffic reaches the backend. A strong architecture avoids giving every application server its own public IP when a controlled public entry point can provide the required access.

10. What is a NAT Gateway?

A NAT Gateway provides outbound internet connectivity for private resources without requiring those resources to have public IP addresses. NAT translates the source address, so the external service sees the NAT's public address rather than the private address of the workload. NAT is primarily about outbound connectivity; it does not make a private workload directly reachable from the internet.

**Remember:** NAT provides controlled outbound internet access; it is not an inbound publishing mechanism.

11. What is a Private Endpoint?

A private endpoint provides private connectivity from a virtual network to a supported managed service. It gives the service a private IP address within the network. This allows an application to access services such as storage or databases without sending the service traffic over a public endpoint. Private endpoints are especially useful when organizations require tighter network isolation and want to reduce public exposure.

12. Why is Private DNS important?

Private connectivity often depends on DNS returning a private address instead of a public address. A private endpoint can therefore work correctly at the network level but still cause problems if the application resolves the service name to an unexpected public address. Enterprise private networking frequently combines private endpoints with private DNS zones and appropriate DNS forwarding. Applications can then use normal service names and still resolve them to private addresses.

---

## Part 4 — Load Balancing and Application Connectivity

13. Why do we use a Load Balancer?

A load balancer provides a controlled entry point for traffic and distributes requests across multiple backend instances or services. This can improve availability and scalability while hiding the individual backend addresses from clients. A cloud load balancer may operate at the network layer or the application layer. The correct service depends on what you need: TCP/UDP forwarding, HTTP-aware routing, TLS termination, path-based routing, or other application features.

14. What is the difference between Network and Application Load Balancing?

Network-level load balancing generally works with transport-level traffic such as TCP or UDP. It is useful when the load balancer does not need to understand the application protocol. Application-level load balancing understands protocols such as HTTP and HTTPS and can make routing decisions based on information such as hostnames or URL paths. Azure and AWS provide several load-balancing services. Base the architectural decision on the traffic and behavior you need, not on the most familiar service.

---

## Part 5 — Connecting Networks

15. Why connect two VNets or VPCs?

Organizations often have separate networks for different environments, applications, business units, or shared services. Those networks may still need controlled communication, such as an application network accessing a central monitoring or identity service. Network peering or transit architectures can provide private connectivity while keeping the networks logically separate.

16. What is VNet/VPC Peering?

Peering creates private connectivity between two cloud networks so resources can communicate using private IP addresses. Azure VNet Peering and AWS VPC Peering are useful for relatively direct network-to-network connectivity. Large enterprises may prefer centralized transit designs when many networks need to communicate. Peering also requires careful address planning because overlapping CIDR ranges can prevent straightforward routing.

**Remember:** Peering connects networks privately, but it does not automatically mean every resource should be allowed to communicate.

17. What is a Hub-and-Spoke network?

A hub-and-spoke architecture places shared networking and security services in a central hub while application or workload networks operate as spokes. The hub can provide connectivity to shared services, on-premises networks, firewalls, DNS, and other centralized capabilities. This creates a repeatable enterprise pattern where workload teams can operate their own networks without independently rebuilding every shared networking service.

18. How does AWS provide centralized network connectivity?

AWS can use centralized networking services such as Transit Gateway to connect multiple VPCs and external networks through a shared transit architecture. This serves a similar architectural purpose to an Azure hub-and-spoke design with centralized connectivity, although the individual services and implementation details differ. The important concept is centralized routing and connectivity without creating an unmanageable mesh of direct connections between every network.

---

## Part 6 — Hybrid and Enterprise Networking

19. How does a cloud network connect to an on-premises network?

Hybrid connectivity allows cloud resources to communicate with an organization's data center or corporate network using private or controlled connections. VPN connections commonly use encrypted tunnels over the internet. Dedicated connectivity services such as Azure ExpressRoute and AWS Direct Connect provide private connectivity through supported providers. The choice depends on requirements such as reliability, bandwidth, latency, security, and cost.

20. Why is centralized network security useful?

Large organizations often centralize controls such as firewalls, inspection, DNS, and connectivity to on-premises networks so that security requirements apply consistently. This can reduce duplication and provide a common inspection point, but it also introduces dependencies on shared infrastructure. A Senior/Lead engineer therefore needs to balance centralized control with availability and operational simplicity.

21. How should cloud networking be separated by environment?

Production, UAT, and Dev should have network boundaries appropriate to their risk and connectivity requirements. Production often requires stricter inbound and outbound controls, while development may need more flexibility. You can separate environments through separate subscriptions/accounts, VNets/VPCs, subnets, security rules, and routing boundaries, depending on the organization's architecture.

---

## Part 7 — Troubleshooting Cloud Connectivity

22. How should you troubleshoot when an application cannot reach a database?

Start from the application and follow the actual network path rather than changing random security rules. Confirm that the hostname resolves to the expected IP. Verify that a route exists and check the network security rules. Confirm that the destination port is listening, and then investigate the database or application itself. This approach narrows the problem layer by layer and prevents the common mistake of assuming every connectivity problem is a firewall problem.

**Remember:** Troubleshoot the path in order. Do not start by opening the firewall.

23. What happens when DNS works but the connection still fails?

A successful DNS lookup proves only that the hostname was resolved; it does not prove that traffic can reach the destination. The route may be missing, a security rule may block the port, a network firewall may deny the traffic, the service may not be listening, or the destination may be unhealthy. Treat DNS as the first layer of connectivity testing, not as proof that the network works.

---

## Part 8 — Azure and AWS Mapping

24. How do the core Azure and AWS networking concepts map?

The underlying networking ideas are the same even though the service names differ.

| Concept | Azure | AWS |
|:--|:--|:--|
| Private network boundary | VNet | VPC |
| Network segment | Subnet | Subnet |
| Traffic filtering | NSG | Security Group |
| Traffic direction | Route Table | Route Table |
| Private outbound internet | NAT Gateway | NAT Gateway |
| Network-to-network link | VNet Peering | VPC Peering |
| Dedicated on-premises link | ExpressRoute | Direct Connect |
| Centralized network hub | Hub-and-spoke VNet | Transit Gateway design |

**Core Mental Model**

**Name → IP → Route → Security → Port → Service**

At enterprise scale:

**Internet / Users → Public Entry Point → Load Balancer → Private Workload → Private Service**

and:

**Workload Networks → Central Connectivity → Shared Services / On-Premises**

The service names differ between Azure and AWS, but the underlying networking decisions remain the same: **addressing, segmentation, routing, security, connectivity, DNS, availability, and controlled access.**

**Cleanup**

If you created networking resources for the lab, remove them using Terraform or the appropriate cloud deployment workflow. Verify that temporary public IPs, NAT resources, load balancers, private endpoints, gateways, and test resources no longer run. Otherwise the lab continues to generate charges.
