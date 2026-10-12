# Day 12 — Cloud Networking: Azure & AWS

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

**Practice**

For a Spring Boot application connecting to a database, write out the expected path ending at the database. Then identify what could fail at each step.

2. What is a VNet or VPC?

An Azure VNet and an AWS VPC are the logical private networks in which many cloud resources communicate. They provide an IP address space and allow you to divide that space into subnets, define routes, and control traffic. A VNet or VPC is therefore more than a container for resources: it establishes the network boundary where you make connectivity and security decisions.

**Remember:** VNet in Azure and VPC in AWS are the primary logical network boundaries.

3. Why do we divide a network into subnets?

Subnets divide a VNet or VPC address space into smaller network segments. This allows different workloads to have different routing, security, and operational requirements. For example, a production design might place application servers in one subnet and databases in another. You can then restrict database access to the application tier instead of allowing broad communication across the entire network.

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

A route table tells the network where traffic for a particular address range should go. Cloud platforms provide default routes, but custom routes can direct traffic through appliances, gateways, peering connections, or other network paths. A security rule that allows traffic does not guarantee connectivity; the traffic also needs a valid route to its destination.

**Practice**

For an application subnet that needs to reach a database subnet, identify the route required and then identify the security rule required. Notice that routing and security solve different problems.

**Remember:** Routing answers **"Where should the traffic go?"** Security answers **"Is the traffic allowed?"**

6. What is a Network Security Group or Security Group?

Azure Network Security Groups and AWS Security Groups control network traffic to resources or network interfaces according to rules such as source, destination, port, and protocol. They are not substitutes for routing: traffic still needs a valid path before a security rule can allow it. A common enterprise pattern is to allow only the minimum required flows. For example, allow application-to-database traffic on the database port instead of free communication across an entire subnet.

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

Routing determines the path a packet can take, while security controls determine whether the packet can pass. Both must work together. If a route is missing, an allowed packet may still fail. If the route exists but a security rule blocks the traffic, the packet still fails. This distinction is one of the most useful troubleshooting concepts in cloud networking.

**Practice**

When an application cannot connect to a database, check these separately:

```text
DNS → IP → Route → Security Rule → Port → Database
```

Do not assume a successful DNS lookup means the network path is working.

---

## Part 3 — Internet and Private Connectivity

8. How does a private subnet reach the Internet?

A private subnet normally does not give its resources directly reachable public addresses. If those resources need outbound internet access, you can route traffic through a NAT service or an equivalent outbound gateway. This allows resources such as application servers to download updates or call external APIs without making the resources directly reachable from the internet. The exact service differs between Azure and AWS, but the architectural purpose is similar.

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

A NAT Gateway provides outbound internet connectivity for private resources without requiring those resources to have public IP addresses. NAT translates the source address, so the external service sees the NAT's public address rather than the private address of the workload. NAT is primarily about outbound connectivity; it does not make a private workload directly reachable from the internet.

**Remember:** NAT provides controlled outbound internet access; it is not an inbound publishing mechanism.

11. What is a Private Endpoint?

A private endpoint provides private connectivity from a virtual network to a supported managed service. It gives the service a private IP address within the network. This allows an application to access services such as storage or databases without sending the service traffic over a public endpoint. Private endpoints are especially useful when organizations require tighter network isolation and want to reduce public exposure.

**Practice**

Consider an application in a private subnet accessing object storage. Compare:

```text
Application → Public Service Endpoint

Application → Private Endpoint → Managed Service
```

Identify the security and network differences.

12. Why is Private DNS important?

Private connectivity often depends on DNS returning a private address instead of a public address. A private endpoint can therefore work correctly at the network level but still cause problems if the application resolves the service name to an unexpected public address. Enterprise private networking frequently combines private endpoints with private DNS zones and appropriate DNS forwarding. Applications can then use normal service names and still resolve them to private addresses.

**Practice**

For a private database endpoint, verify:

```bash
nslookup <database-hostname>
```

Then determine whether the returned address is public or private.

---

## Part 4 — Load Balancing and Application Connectivity

13. Why do we use a Load Balancer?

A load balancer provides a controlled entry point for traffic and distributes requests across multiple backend instances or services. This can improve availability and scalability while hiding the individual backend addresses from clients. A cloud load balancer may operate at the network layer or the application layer. The correct service depends on what you need: TCP/UDP forwarding, HTTP-aware routing, TLS termination, path-based routing, or other application features.

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

Network-level load balancing generally works with transport-level traffic such as TCP or UDP. It is useful when the load balancer does not need to understand the application protocol. Application-level load balancing understands protocols such as HTTP and HTTPS and can make routing decisions based on information such as hostnames or URL paths. Azure and AWS provide several load-balancing services. Base the architectural decision on the traffic and behavior you need, not on the most familiar service.

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

Peering creates private connectivity between two cloud networks so resources can communicate using private IP addresses. Azure VNet Peering and AWS VPC Peering are useful for relatively direct network-to-network connectivity. Large enterprises may prefer centralized transit designs when many networks need to communicate. Peering also requires careful address planning because overlapping CIDR ranges can prevent straightforward routing.

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

AWS can use centralized networking services such as Transit Gateway to connect multiple VPCs and external networks through a shared transit architecture. This serves a similar architectural purpose to an Azure hub-and-spoke design with centralized connectivity, although the individual services and implementation details differ. The important concept is centralized routing and connectivity without creating an unmanageable mesh of direct connections between every network.

**Practice**

Imagine 20 VPCs that need access to shared services. Compare a full mesh of direct connections with a centralized transit design. Identify which design is easier to operate as the number of networks grows.

---

## Part 6 — Hybrid and Enterprise Networking

19. How does a cloud network connect to an on-premises network?

Hybrid connectivity allows cloud resources to communicate with an organization's data center or corporate network using private or controlled connections. VPN connections commonly use encrypted tunnels over the internet. Dedicated connectivity services such as Azure ExpressRoute and AWS Direct Connect provide private connectivity through supported providers. The choice depends on requirements such as reliability, bandwidth, latency, security, and cost.

**Practice**

For a company moving an application database from on-premises to Azure or AWS, identify which traffic still needs to travel between the cloud and data center during the migration.

20. Why is centralized network security useful?

Large organizations often centralize controls such as firewalls, inspection, DNS, and connectivity to on-premises networks so that security requirements apply consistently. This can reduce duplication and provide a common inspection point, but it also introduces dependencies on shared infrastructure. A Senior/Lead engineer therefore needs to balance centralized control with availability and operational simplicity.

**Practice**

Identify three services that you might centralize in an enterprise hub and one risk created by making each service a shared dependency.

21. How should cloud networking be separated by environment?

Production, UAT, and Dev should have network boundaries appropriate to their risk and connectivity requirements. Production often requires stricter inbound and outbound controls, while development may need more flexibility. You can separate environments through separate subscriptions/accounts, VNets/VPCs, subnets, security rules, and routing boundaries, depending on the organization's architecture.

**Practice**

Design separate network boundaries for Dev, UAT, and Prod and identify which shared services they are allowed to access.

---

## Part 7 — Troubleshooting Cloud Connectivity

22. How should you troubleshoot when an application cannot reach a database?

Start from the application and follow the actual network path rather than changing random security rules. Confirm that the hostname resolves to the expected IP. Verify that a route exists and check the network security rules. Confirm that the destination port is listening, and then investigate the database or application itself. This approach narrows the problem layer by layer and prevents the common mistake of assuming every connectivity problem is a firewall problem.

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

A successful DNS lookup proves only that the hostname was resolved; it does not prove that traffic can reach the destination. The route may be missing, a security rule may block the port, a network firewall may deny the traffic, the service may not be listening, or the destination may be unhealthy. Treat DNS as the first layer of connectivity testing, not as proof that the network works.

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

**Practice**

Memorize the concepts in the left column rather than the service names. Then explain where the mapping is approximate rather than identical — the last two rows are patterns, not one-to-one products.

---

## Part 9 — Integrated Practice

Design the network for a production Spring Boot application with a web frontend, application tier, database, private storage, and access to an external API.

The database must have no direct public access. Application workloads should use private addresses, and outbound internet access should be controlled. Managed services should use private connectivity where required, and users should enter through a controlled public endpoint.

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

If you created networking resources for the lab, remove them using Terraform or the appropriate cloud deployment workflow. Verify that temporary public IPs, NAT resources, load balancers, private endpoints, gateways, and test resources no longer run. Otherwise the lab continues to generate charges.

## Answers to practice

### 1. Path from a Spring Boot application to a database, and what can fail

<details>
<summary>Answer</summary>

Write the path as Application → DNS → Route → Security → Destination. The application resolves the database name to an IP. Routing sends the packet toward that IP. A Network Security Group or Security Group then allows or denies the flow. The packet reaches the database if the port is listening.

Failures match those steps. DNS can return the wrong address or no address. A missing route drops the packet. A deny rule blocks the port. The database process can be down. Walk the full path. Do not check only one firewall rule.

</details>

### 2. Three-tier subnets and allowed communication

<details>
<summary>Answer</summary>

Create Web, Application, and Database subnets. Allow the internet or load balancer only into Web. Allow Web to reach Application on the application port. Allow Application to reach Database on the database port.

Do not allow Web to talk to Database. Do not allow Database to start connections to Web. Segment the address space so each tier has its own routing and security. Restrict database access to the application tier.

</details>

### 3. Address plan for `10.20.0.0/16` and three `/24` subnets

<details>
<summary>Answer</summary>

The VNet or VPC is `10.20.0.0/16`. That is the whole private network. Web `10.20.1.0/24`, App `10.20.2.0/24`, and DB `10.20.3.0/24` are segments inside it.

Cloud platforms reserve some addresses in each subnet, so usable host counts sit below 256. Plan non-overlapping ranges before peering or hybrid links. Overlapping CIDR blocks make later connectivity hard or impossible without redesign.

</details>

### 4. Route versus security rule from application subnet to database subnet

<details>
<summary>Answer</summary>

The application subnet needs a route to the database subnet address range. In a simple VNet or VPC that is often the local virtual-network route. Security then needs an allow rule from the application subnet to the database on the database port.

Routing answers where the traffic should go. Security answers whether the traffic is allowed. An allow rule does not help if no route exists.

</details>

### 5. Allow TCP 5432 from the application subnet only

<details>
<summary>Answer</summary>

Write the intended rule as source Application subnet, destination Database, port `5432`, protocol TCP, action Allow. That is the minimum flow the application needs.

An internet-wide source is wrong for a private database. It would accept connections from anywhere that can reach the path. Allow only the application tier.

</details>

### 6. Check DNS, IP, route, security, port, and database separately

<details>
<summary>Answer</summary>

When the application cannot connect, do not assume DNS success means the network works. Confirm the name resolves to the expected IP. Then confirm a route exists. Then check the security rule. Then test the port. Then inspect the database.

Each layer can fail on its own. A good lookup only proves name resolution. It does not prove the packet can arrive.

</details>

### 7. Private application subnet calling an external API

<details>
<summary>Answer</summary>

Give the subnet a default route toward a NAT Gateway or equivalent outbound gateway. The application then starts outbound connections. The internet cannot start inbound connections to those private addresses.

NAT translates the source address. The external API sees the NAT public address, not the private workload address. This is outbound access, not inbound publishing.

</details>

### 8. Path for a public web application through a load balancer

<details>
<summary>Answer</summary>

Design Internet → Public Load Balancer → Private Application. Put DNS on the public name so it resolves to the load balancer. Terminate TLS at the load balancer or application gateway if that is the chosen design.

Route public traffic only to that entry point. Security rules then allow the load balancer to reach the private application. Do not give every application server its own public IP when one controlled entry point is enough.

</details>

### 9. Public service endpoint versus a private endpoint to object storage

<details>
<summary>Answer</summary>

`Application → Public Service Endpoint` sends storage traffic to a public address. You must then lock that public path with identity and service firewalls. `Application → Private Endpoint → Managed Service` places a private IP in the VNet or VPC.

The private path keeps service traffic on the private network. It reduces public exposure. Use it when the organization requires tighter isolation for storage or databases.

</details>

### 10. Confirm a private database name with `nslookup`

<details>
<summary>Answer</summary>

Run `nslookup <database-hostname>`. Read the returned address. A private endpoint should resolve to a private IP in your network, not to a public service IP.

Private connectivity can work at the network layer and still fail if DNS returns the public address. Pair private endpoints with private DNS zones and forwarding so applications keep using normal names.

</details>

### 11. Two application instances behind a load balancer, and an unhealthy App 1

<details>
<summary>Answer</summary>

Place the client behind one load balancer. The load balancer distributes requests to App 1 and App 2. Health checks watch each instance.

When App 1 becomes unhealthy, the load balancer stops sending new traffic to it. App 2 continues to serve. The client still uses the same entry point. That is why a load balancer hides backend addresses and improves availability.

</details>

### 12. Network versus application load balancing for TCP, `/api`, and `/payments`

<details>
<summary>Answer</summary>

Use network-level load balancing for TCP traffic to a database proxy. The balancer forwards transport traffic and does not need HTTP paths. Use application-level load balancing for HTTPS to `/api` and `/payments`.

The application load balancer needs hostname or URL path information to split those routes. Choose the service from the traffic and behavior you need, not from the most familiar name.

</details>

### 13. Routes and security for Application Network to Shared Services Network

<details>
<summary>Answer</summary>

Each network needs a route to the other network’s CIDR, usually through peering or a hub. Security rules must then allow only the required ports from the application network to the shared service.

Peering or transit creates the path. It does not mean every resource may talk. Overlapping address ranges can block this design, so plan CIDR first.

</details>

### 14. Hub-and-spoke: what belongs in the hub, and what belongs in the spokes

<details>
<summary>Answer</summary>

Put shared connectivity in the hub: firewalls, DNS, on-premises links, and shared inspection. Put Dev, UAT, and Prod workloads in spokes. Each spoke keeps its own application subnets and security rules.

The hub is the repeatable center. Spoke teams do not rebuild every shared networking service. Workload networks stay logically separate while they use the hub for common paths.

</details>

### 15. Full mesh of 20 VPCs versus centralized transit

<details>
<summary>Answer</summary>

A full mesh needs a connection between many pairs of VPCs. That mesh grows fast and becomes hard to change. Centralized transit, such as Transit Gateway, connects each VPC to one hub.

New networks then attach once, not to every peer. Centralized routing is easier to operate as the number of networks grows. The idea matches Azure hub-and-spoke, even though the product names differ.

</details>

### 16. Traffic that still crosses cloud and data center during a database migration

<details>
<summary>Answer</summary>

The application in the cloud still needs a private path to the on-premises database until cutover. Management, replication, and identity traffic may also cross that link.

Use a VPN tunnel or a dedicated link such as ExpressRoute or Direct Connect. Choose from reliability, bandwidth, latency, security, and cost. Hybrid connectivity exists so that path is controlled, not public.

</details>

### 17. Three hub services to centralize, and one risk each

<details>
<summary>Answer</summary>

Centralize firewalls, DNS, and on-premises connectivity in the hub. Each one then applies consistently. The risk is shared dependency.

If the hub firewall fails, many spokes lose inspected paths. If hub DNS fails, name resolution fails across environments. If the hybrid gateway fails, cloud-to-data-center traffic stops. Balance control with availability.

</details>

### 18. Separate Dev, UAT, and Prod networks, and allowed shared services

<details>
<summary>Answer</summary>

Give each environment its own VNet or VPC. Keep Production routes and security rules stricter than Development. Allow all three to reach approved shared services such as identity, logging, and DNS through the hub.

Do not let Dev route freely into Production. Separate subscriptions or accounts can hold these networks. Environment risk should drive inbound and outbound controls.

</details>

### 19. Troubleshoot application-to-database connectivity in path order

<details>
<summary>Answer</summary>

Start from the application and follow the path. Run `nslookup <hostname>` to confirm DNS. Check `ip route` for a valid route. Test the port with `nc -vz <host> <port>`. Use `traceroute <host>` when you need the path.

Then inspect cloud routes, NSG or Security Group decisions, and the database listener. Troubleshoot in order: DNS → IP → Route → Security → Port → Application/Database. Do not start by opening the firewall.

</details>

### 20. Next checks when `nslookup` succeeds and `nc -vz` to port 5432 fails

<details>
<summary>Answer</summary>

DNS worked, so do not stop there. Check that the resolved IP is the expected private address. Check that a route to that IP exists. Check NSG or Security Group rules for TCP `5432`.

Then confirm nothing else denies the flow, that the database listens on `5432`, and that the instance is healthy. A successful lookup is the first layer. It is not proof the network works.

</details>

### 21. Memorize concepts, and where Azure-to-AWS mapping is approximate

<details>
<summary>Answer</summary>

Memorize the left-column ideas: private network, subnet, traffic filtering, routes, outbound NAT, network-to-network link, dedicated on-premises link, and centralized hub. Azure and AWS names differ. The decisions stay the same.

The last two rows are patterns, not one-to-one products. ExpressRoute maps in role to Direct Connect. Hub-and-spoke VNets map in role to a Transit Gateway design. Do not say the products are identical.

</details>

### 22. Integrated Practice — Production Spring Boot network design

<details>
<summary>Answer</summary>

Create a VNet or VPC with Web, Application, and Database subnets, plus a subnet for private endpoints. Users enter through a public load balancer. Application workloads use private addresses. The database has no public IP.

Route outbound internet from the application subnet through a NAT Gateway so the app can call the external API. Connect object storage through a private endpoint. Use NSG or Security Group rules that allow only required flows. Use private DNS so service names resolve to private IPs.

On Azure the boundary is a VNet with NSGs, a NAT Gateway, Private Endpoints, and hub-spoke peering. On AWS the boundary is a VPC with Security Groups, a NAT Gateway, private endpoints, and Transit Gateway or peering.

A user HTTPS request travels User → DNS → Public Load Balancer → Private Application. The application then uses the private database or storage. The response returns on the same controlled path.

</details>

### 23. Interview Recall — What is a VNet/VPC?

<details>
<summary>Answer</summary>

An Azure VNet and an AWS VPC are the logical private networks where many cloud resources communicate. They provide an IP address space.

You divide that space into subnets, define routes, and control traffic. This is the primary logical network boundary.

</details>

### 24. Interview Recall — Why do we create subnets?

<details>
<summary>Answer</summary>

Subnets split a VNet or VPC into smaller segments. Different workloads can then use different routing and security.

A common pattern is application servers in one subnet and databases in another. You then allow only the required flows.

</details>

### 25. Interview Recall — Why IP address planning matters

<details>
<summary>Answer</summary>

Every network interface needs an address so traffic can reach the right destination. Private ranges serve internal traffic. Public IPs serve internet endpoints where required.

Overlapping address spaces make peering, VPN, and hybrid networking hard. Plan CIDR before you connect networks.

</details>

### 26. Interview Recall — What a route table does

<details>
<summary>Answer</summary>

A route table tells the network where traffic for an address range should go. Cloud platforms provide default routes. Custom routes can send traffic through appliances, gateways, or peering.

A security allow rule is not enough. The packet also needs a valid route.

</details>

### 27. Interview Recall — Routing versus security

<details>
<summary>Answer</summary>

Routing decides the path a packet can take. Security controls decide whether the packet may pass.

If the route is missing, an allowed packet still fails. If the route exists but a rule blocks the port, the packet still fails. Check both.

</details>

### 28. Interview Recall — What an NSG or Security Group controls

<details>
<summary>Answer</summary>

Azure Network Security Groups and AWS Security Groups filter traffic to resources or interfaces. Rules use source, destination, port, and protocol.

They are not a substitute for routing. Allow only the minimum required flows, such as application-to-database on the database port.

</details>

### 29. Interview Recall — How a private subnet accesses the internet

<details>
<summary>Answer</summary>

A private subnet does not give resources public inbound addresses. For outbound access, route traffic through a NAT Gateway or equivalent outbound gateway.

The workload can call external APIs or download updates. The internet cannot start a connection to that private resource.

</details>

### 30. Interview Recall — What a NAT Gateway does

<details>
<summary>Answer</summary>

A NAT Gateway provides outbound internet connectivity for private resources. It translates the source address so the external service sees the NAT public address.

NAT is outbound connectivity. It does not publish a private workload for inbound internet traffic.

</details>

### 31. Interview Recall — Why use a private endpoint

<details>
<summary>Answer</summary>

A private endpoint gives a managed service a private IP inside the virtual network. The application then reaches storage or a database without a public service endpoint.

Use it when you need tighter isolation and less public exposure.

</details>

### 32. Interview Recall — Why private DNS matters with private endpoints

<details>
<summary>Answer</summary>

The application must resolve the service name to the private IP. If DNS returns the public address, the private path is unused.

Enterprise designs combine private endpoints with private DNS zones and forwarding. Applications keep normal names and still reach private addresses.

</details>

### 33. Interview Recall — Why use a load balancer

<details>
<summary>Answer</summary>

A load balancer is a controlled entry point. It distributes requests across backends and hides individual addresses.

It can improve availability and scale. Choose network-level or application-level balancing from the traffic you need.

</details>

### 34. Interview Recall — Network versus application load balancing

<details>
<summary>Answer</summary>

Network-level balancing works with TCP or UDP. It does not need to understand HTTP. Application-level balancing understands HTTP and HTTPS.

It can route on hostname or URL path. Pick the service from required behavior, not from habit.

</details>

### 35. Interview Recall — What VNet/VPC peering is

<details>
<summary>Answer</summary>

Peering creates private connectivity between two cloud networks. Resources then use private IPs. Azure VNet Peering and AWS VPC Peering serve this role.

Peering does not mean every resource should communicate. Overlapping CIDR ranges can block it.

</details>

### 36. Interview Recall — What hub-and-spoke architecture is

<details>
<summary>Answer</summary>

The hub holds shared networking and security services. Spokes hold application or workload networks.

The hub can provide firewalls, DNS, shared services, and on-premises connectivity. Spoke teams reuse that center instead of rebuilding it.

</details>

### 37. Interview Recall — Why use centralized transit at enterprise scale

<details>
<summary>Answer</summary>

Connecting every network to every other network creates a mesh that is hard to operate. Transit Gateway and hub-spoke designs attach each network to a center.

You get centralized routing without an unmanageable web of direct links.

</details>

### 38. Interview Recall — How cloud connects to an on-premises network

<details>
<summary>Answer</summary>

A VPN uses an encrypted tunnel over the internet. Dedicated links such as ExpressRoute and Direct Connect provide private connectivity through supported providers.

Choose from reliability, bandwidth, latency, security, and cost.

</details>

### 39. Interview Recall — How to troubleshoot application-to-database connectivity

<details>
<summary>Answer</summary>

Follow the path: DNS → IP → Route → Security → Port → Database. Use `nslookup`, `ip route`, `nc -vz`, and `traceroute`. Use cloud diagnostics for routes and security decisions.

Do not start by opening the firewall. Narrow the failed layer with evidence.

</details>

### 40. Interview Recall — Why successful DNS does not prove connectivity

<details>
<summary>Answer</summary>

A lookup only proves the name resolved. The route may be missing. A security rule may block the port. The service may not listen.

Treat DNS as the first test, not as proof the network works.

</details>

### 41. Interview Recall — How to separate Dev, UAT, and Prod networks

<details>
<summary>Answer</summary>

Use separate subscriptions or accounts, VNets or VPCs, subnets, security rules, and routes as the risk requires. Keep Production stricter than Development.

Allow only approved shared services through the hub. Do not let Dev reach Production freely.

</details>

### 42. Interview Recall — Map major Azure networking concepts to AWS

<details>
<summary>Answer</summary>

VNet maps to VPC. Subnet maps to subnet. NSG maps to Security Group. Route Table maps to Route Table. NAT Gateway maps to NAT Gateway. VNet Peering maps to VPC Peering.

ExpressRoute maps in role to Direct Connect. Hub-and-spoke maps in role to a Transit Gateway design. Learn the concepts first. Learn the product names second.

</details>
