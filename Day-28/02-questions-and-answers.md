# Day 28 — Questions and answers

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Then answer each item below before you open the Answer block. After that, do the lab in [03-implementation.md](03-implementation.md).

Write your own answer first. Open the Answer block only after you try. Keep the original numbering.

---

## 1. Design a VPC CIDR for frontend, private backend, private DB, endpoints, outbound

**Practice**

Design a VPC for:

```text
Internet-facing frontend
Private backend
Private database
Private AWS service access
Outbound internet access
```

Before you create anything, choose the CIDR ranges. Make sure they will not conflict with networks that may later connect through VPN, Direct Connect, or Transit Gateway.

<details>
<summary>Answer</summary>

Use a unique range such as `10.20.0.0/16`. Public `10.20.1.0/24` and `10.20.2.0/24` for ALB and NAT. Private app `10.20.11.0/24` and `10.20.12.0/24`. Private data `10.20.21.0/24` and `10.20.22.0/24`. Leave space for endpoints or TGW attachments.

Check on-premises, VPN, Direct Connect, and other VPCs before you lock CIDRs. Overlap is a later outage.

</details>

---

## 2. Two AZs: public, private app, and private database subnets

**Practice**

Design:

```text
2 AZs
2 public subnets
2 private app subnets
2 private database subnets
```

Then explain which workloads belong in each subnet and why.

<details>
<summary>Answer</summary>

Each AZ gets a public subnet (ALB, NAT, IGW route), a private app subnet (ECS/EKS/EC2, NAT default route), and a private data subnet (RDS, no IGW). Multi-AZ so one AZ failure does not take the app.

Public vs private is routing, not the subnet name. Workloads that must not have public IPs stay in private subnets.

</details>

---

## 3. App in `10.20.11.0/24` reaching `10.30.0.10`

**Practice**

Suppose an application in `10.20.11.0/24` wants to reach:

```text
10.30.0.10
```

Determine whether the route table has a specific route for `10.30.0.0/16` or whether the default route will be used.

<details>
<summary>Answer</summary>

If the route table has `10.30.0.0/16` to peering, TGW, or VPN, that more-specific route wins. If not, `0.0.0.0/0` sends the packet to NAT or IGW and the private destination never arrives.

Ask which route matches the destination IP, not whether a route table exists.

</details>

---

## 4. Why VPC plus Internet Gateway is not enough for public access

**Practice**

Explain why this architecture is not enough:

```text
VPC
  |
Internet Gateway
```

You must still have the correct subnet route and workload addressing/security.

<details>
<summary>Answer</summary>

You still need a subnet route to the IGW, a public IP on the workload or load balancer, Security Group/NACL allows, and a listening process.

An attached IGW does not publish every resource on the internet.

</details>

---

## 5. Private app calls `https://api.example.com` with no inbound internet

**Practice**

Your private application needs to call:

```text
https://api.example.com
```

but must not accept inbound internet connections.

Design the complete outbound path and identify every component involved.

<details>
<summary>Answer</summary>

Private instance → private route `0.0.0.0/0` → NAT Gateway in a public subnet → IGW → internet. Return traffic comes back to NAT, then the private IP. Security Groups allow egress 443. No public IP on the app.

NAT is outbound only. Users still enter through an ALB if needed.

</details>

---

## 6. Security Groups: Internet→ALB 443, ALB→App 8080, App→RDS 5432, deny Internet→RDS

**Practice**

Design Security Groups for:

```text
Internet → ALB: 443
ALB → App: 8080
App → RDS: 5432
Internet → RDS: denied
```

Then identify which source should be used for each rule.

<details>
<summary>Answer</summary>

ALB SG: inbound 443 from `0.0.0.0/0` (or known CDNs). App SG: inbound 8080 from the ALB SG. RDS SG: inbound 5432 from the App SG. RDS has no inbound from the internet.

Prefer SG references as sources, not the whole VPC CIDR.

</details>

---

## 7. SG allows 443 but the connection still fails — check NACL

**Practice**

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

<details>
<summary>Answer</summary>

NACLs are stateless. Allow inbound 443 and the ephemeral outbound return range. Also check the route and the application.

Do not stop at Security Groups. A subnet NACL can drop the same flow.

</details>

---

## 8. Private DNS name, then break the VPC association

**Practice**

Create a private DNS name for an internal application and verify resolution from inside the VPC.

Then break the DNS association and observe the failure.

<details>
<summary>Answer</summary>

Create a Route 53 private hosted zone, associate the VPC, and `nslookup` from inside. Disassociate the VPC. Resolution fails or falls through to public DNS.

If you expected a private IP and get a public one, the path is wrong even when routes look fine.

</details>

---

## 9. Private EC2 → S3 via NAT vs VPC endpoint

**Practice**

Compare:

```text
Private EC2 → NAT → Internet → S3
```

with:

```text
Private EC2 → VPC Endpoint → S3
```

Explain the differences in network path, security, availability, and cost.

<details>
<summary>Answer</summary>

NAT path: private route → NAT → IGW → public S3. Costs NAT processing and uses the internet path. Gateway endpoint: prefix list route in the table → S3 on the AWS network, no NAT for that traffic.

Endpoint changes path, security, and often cost. IAM and bucket policy still apply.

</details>

---

## 10. Shared Services VPC peered with Application VPC — routes both ways

**Practice**

Create a conceptual design for:

```text
Shared Services VPC
        ↕
Application VPC
```

Identify the routes required on both sides.

<details>
<summary>Answer</summary>

Peer non-overlapping CIDRs. Application VPC needs a route to `10.10.0.0/16` (shared) via the peering ID. Shared VPC needs a route to the app CIDR via the same peering. SGs and NACLs must allow the ports.

Peering without routes is a disconnected cable.

</details>

---

## 11. Transit Gateway for 50 app VPCs, on-prem, security, shared, inspection

**Practice**

Imagine 50 application VPCs plus:

```text
On-premises
Security VPC
Shared Services VPC
Central inspection
```

Design how Transit Gateway could connect them.

<details>
<summary>Answer</summary>

Attach every VPC and the VPN/Direct Connect gateway to Transit Gateway. Use route tables so app VPCs send east-west and egress through an inspection VPC. Shared Services and Security VPCs attach once.

Avoid a 50×50 peering mesh. TGW is a shared blast radius: design HA and change control.

</details>

---

## 12. Central outbound inspection for VPC A, B, and C

**Practice**

Design centralized outbound inspection for:

```text
VPC A
VPC B
VPC C
```

Then identify which route tables must change to force the traffic through the inspection path.

<details>
<summary>Answer</summary>

Send `0.0.0.0/0` from each app VPC to Transit Gateway, then to an inspection VPC with AWS Network Firewall, then to IGW/NAT. Change app VPC route tables, TGW route tables, and the inspection VPC routes.

Firewall policy without those routes inspects nothing.

</details>

---

## 13. ALB hostname routing for `api.example.com` and `www.example.com`

**Practice**

Create an ALB architecture for:

```text
api.example.com → API
www.example.com → frontend
```

Then explain how hostname-based routing works.

<details>
<summary>Answer</summary>

One HTTPS listener. Host header `api.example.com` → API target group. Host `www.example.com` → frontend target group. Health checks decide which targets receive traffic.

A registered target is not automatically healthy. Inspect `aws elbv2 describe-target-health`.

</details>

---

## 14. ALB vs NLB for HTTP paths, raw TCP, and UDP

**Practice**

Choose a load balancer for:

```text
HTTP path-based routing
Raw TCP application
UDP application
```

Explain the reasoning for each.

<details>
<summary>Answer</summary>

HTTP path routing: ALB (Layer 7). Raw TCP: NLB (Layer 4). UDP: NLB.

Start from protocol. Do not pick NLB for an HTTP API only because of a performance rumor.

</details>

---

## 15. ECS/EKS to private RDS PostgreSQL

**Practice**

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

<details>
<summary>Answer</summary>

App in private subnets uses the RDS DNS name, which resolves to a private IP. Local VPC route delivers the packet. App SG → RDS SG on TCP 5432. No public RDS.

DNS, routing, and Security Groups must all agree. Hard-coded IPs break when RDS fails over.

</details>

---

## 16. On-premises `10.0.0.0/16` and AWS VPC `10.0.0.0/16`

**Practice**

Your company has:

```text
On-premises: 10.0.0.0/16
AWS VPC:     10.0.0.0/16
```

Explain why connecting the networks creates routing ambiguity and why this should be resolved before the connectivity project begins.

<details>
<summary>Answer</summary>

VPN or Direct Connect cannot uniquely route a destination in that prefix. Return traffic is equally ambiguous.

Pick unique CIDRs before the connectivity project. Overlap is not a tunnel-PSK problem.

</details>

---

## 17. EKS to RDS: block the RDS Security Group and troubleshoot from the Pod

**Practice**

Deploy a small EKS workload and connect it to RDS. Deliberately block database access through the RDS Security Group and troubleshoot from the Pod outward.

<details>
<summary>Answer</summary>

Remove the worker/Pod SG from RDS 5432. From the Pod, `nslookup` the RDS endpoint, then `nc -vz` 5432. Restore only the app SG.

Walk Pod DNS → CNI → VPC route → SGs → port → database. Kubernetes and VPC are one path.

</details>

---

## 18. Fargate in a private subnet to the database, no public IP

**Practice**

Run a Fargate task in a private subnet and make it connect to a database. Verify that the task does not require a public IP when the architecture provides the necessary private paths.

<details>
<summary>Answer</summary>

`awsvpc` gives the task an ENI and private IP. Private subnet route, task SG, and RDS SG on 5432 are enough. NAT or endpoints cover other AWS APIs.

The task must not need a public IP if private paths exist.

</details>

---

## 19. Inbound vs outbound for four failure scenarios

**Practice**

For each scenario, identify whether the primary path is inbound or outbound:

```text
User cannot open website
API cannot call external API
EC2 cannot access S3
ALB cannot reach target
```

<details>
<summary>Answer</summary>

User cannot open the website: inbound (DNS, ALB, target health). API cannot call an external API: outbound (route, NAT/firewall, egress SG). EC2 cannot access S3: outbound or endpoint path. ALB cannot reach target: inbound data path after the load balancer (SG, health, app).

Users working does not prove egress works.

</details>

---

## 20. Troubleshoot ECS → `db.internal.example.com` timeout

**Practice**

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

<details>
<summary>Answer</summary>

`dig` the name, note the IP, match the route, check task SG and RDS SG, NACL, `nc` 5432, then RDS health and app credentials.

Change one control at a time. DNS → IP → route → security → port → service → application.

</details>

---

**Failure drills**

## 21. Lab: change a private subnet default route, observe timeout, restore

**Failure drill**

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

Change a private subnet's default route in a lab and observe the connectivity failure. Restore the correct route and verify recovery.

<details>
<summary>Answer</summary>

Point `0.0.0.0/0` at a blackhole or the wrong NAT. HTTPS to an external API times out. Restore the NAT (or inspection) next hop and retest.

A route can exist and still be the wrong next hop.

</details>

---

## 22. Remove the database ingress rule, test, restore only the required rule

**Failure drill**

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

Remove the database ingress rule, test the application, then restore only the required rule.

<details>
<summary>Answer</summary>

Delete RDS inbound 5432. The app times out while RDS stays healthy. Restore inbound 5432 from the application Security Group only, not from `10.50.0.0/16`.

Narrow source from “entire VPC” to the workload SG.

</details>

---

## 23. Break private DNS on a lab interface endpoint, then restore

**Failure drill**

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

Break private DNS for a lab interface endpoint and compare the behavior before and after restoring it.

<details>
<summary>Answer</summary>

Disable private DNS on the interface endpoint. The AWS hostname resolves publicly and the path may NAT or fail. Restore private DNS and confirm the private endpoint IP.

Applications keep using the normal hostname. DNS must aim at PrivateLink.

</details>

---

**Senior/Lead Architecture Exercise — walkthrough questions**

## 24. Why the ALB is public while EKS workers stay private

**Senior/Lead Architecture Exercise**

1. Why is the ALB public while EKS worker capacity remains private?

<details>
<summary>Answer</summary>

Users need a public entry. Nodes and Pods do not. ALB in public subnets, targets in private subnets.

Exposing workers puts the data plane on the internet.

</details>

---

## 25. Why is RDS private?

**Senior/Lead Architecture Exercise**

2. Why is RDS private?

<details>
<summary>Answer</summary>

The database holds customer data. Only the app SG should reach 5432.

A public RDS endpoint is an unnecessary attack surface.

</details>

---

## 26. Why use a VPC endpoint for S3?

**Senior/Lead Architecture Exercise**

3. Why use a VPC endpoint for S3?

<details>
<summary>Answer</summary>

Private subnets reach S3 without NAT or the public S3 path. Traffic stays on the AWS network.

IAM still authorizes. The endpoint is path, not permission.

</details>

---

## 27. Where does outbound internet traffic go?

**Senior/Lead Architecture Exercise**

4. Where does outbound internet traffic go?

<details>
<summary>Answer</summary>

Private default route to NAT, or to Transit Gateway then inspection then NAT/IGW. Use known Elastic IPs when partners allowlist you.

Do not give app tasks public IPs “for convenience.”

</details>

---

## 28. Where should centralized inspection occur?

**Senior/Lead Architecture Exercise**

5. Where should centralized inspection occur?

<details>
<summary>Answer</summary>

In an inspection VPC on Transit Gateway, with AWS Network Firewall on the forced path.

Routing must send the traffic there. Policy alone is not a path.

</details>

---

## 29. How do multiple VPCs communicate?

**Senior/Lead Architecture Exercise**

6. How do multiple VPCs communicate?

<details>
<summary>Answer</summary>

At this scale, Transit Gateway, not a peering mesh. Routes on both the VPC and TGW tables. SGs still filter.

Peering is fine for two VPCs. Fifty VPCs need a hub.

</details>

---

## 30. How does on-premises traffic enter AWS?

**Senior/Lead Architecture Exercise**

7. How does on-premises traffic enter AWS?

<details>
<summary>Answer</summary>

Site-to-Site VPN or Direct Connect into Transit Gateway or a VPN gateway, then to app VPCs.

Unique CIDRs, routes both ways, and SGs that allow the on-premises prefix or hub.

</details>

---

## 31. What prevents Internet users from reaching RDS?

**Senior/Lead Architecture Exercise**

8. What prevents Internet users from reaching RDS?

<details>
<summary>Answer</summary>

Private subnets, no IGW route on data subnets, RDS SG with no public inbound, and no public RDS flag.

Defense in layers. One mis-opened 5432 is enough to fail the design.

</details>

---

## 32. How does DNS resolve internal services?

**Senior/Lead Architecture Exercise**

9. How does DNS resolve internal services?

<details>
<summary>Answer</summary>

Route 53 private hosted zones associated to the VPCs, plus RDS and endpoint private DNS.

Wrong zone association sends clients to public IPs.

</details>

---

## 33. Which components create shared blast radius?

**Senior/Lead Architecture Exercise**

10. Which components create shared blast radius?

<details>
<summary>Answer</summary>

Transit Gateway, inspection firewall, shared NAT, shared private hosted zones, and a shared ALB.

A bad TGW route can isolate many teams. Change-control those hubs.

</details>

---

## 34. How would you design high availability?

**Senior/Lead Architecture Exercise**

11. How would you design high availability?

<details>
<summary>Answer</summary>

Subnets and NAT (if used) in at least two AZs. Multi-AZ ALB, EKS nodes, and RDS. TGW and firewall in a resilient design.

Single-AZ NAT is a quiet single point of failure for all private egress.

</details>

---

## 35. Troubleshoot a failed EKS → RDS connection

**Senior/Lead Architecture Exercise**

12. How would you troubleshoot a failed EKS → RDS connection?

<details>
<summary>Answer</summary>

From the Pod: DNS, destination IP, CNI, VPC route, node/Pod SG, RDS SG, port 5432, RDS health, credentials.

Do not stop at `kubectl get pods`.

</details>

---

**5-Minute Interview Recall**

Without looking at the notes, explain these in your own words.

The sequence worth remembering is:

**DNS → IP → Route → Security → Port → Service → Application**

At Senior/Lead level, you should be able to trace the traffic path, identify the network boundary involved, explain the security model, recognize the blast radius of centralized components, and choose between direct and centralized connectivity based on scale and operational requirements.

## 36. What does a VPC provide?

**5-Minute Recall**

Without looking at the notes, explain:

1. What does a VPC provide?

<details>
<summary>Answer</summary>

The private IP space and the foundation for subnets, routes, SGs, gateways, and endpoints.

The VPC name alone does not make an app private.

</details>

---

## 37. Why are subnets associated with Availability Zones?

**5-Minute Recall**

Without looking at the notes, explain:

2. Why are subnets associated with Availability Zones?

<details>
<summary>Answer</summary>

A subnet lives in one AZ. Spread subnets so workloads survive AZ failure.

Capacity in one AZ is not Multi-AZ.

</details>

---

## 38. What makes a subnet public?

**5-Minute Recall**

Without looking at the notes, explain:

3. What makes a subnet public?

<details>
<summary>Answer</summary>

Default route to an Internet Gateway plus public addressing on the workload or load balancer.

Routing defines public, not the label.

</details>

---

## 39. What does a route table control?

**5-Minute Recall**

Without looking at the notes, explain:

4. What does a route table control?

<details>
<summary>Answer</summary>

Where packets matching a destination CIDR go next: local, IGW, NAT, TGW, peering, or endpoint.

The matching route matters more than the table’s existence.

</details>

---

## 40. What does an Internet Gateway do?

**5-Minute Recall**

Without looking at the notes, explain:

5. What does an Internet Gateway do?

<details>
<summary>Answer</summary>

It provides a path between the VPC and the public internet.

It is necessary for public subnets and for NAT, not sufficient by itself.

</details>

---

## 41. Why does a private subnet use a NAT Gateway?

**5-Minute Recall**

Without looking at the notes, explain:

6. Why does a private subnet use a NAT Gateway?

<details>
<summary>Answer</summary>

So instances without public IPs can start outbound internet connections.

Inbound internet still cannot initiate to those instances.

</details>

---

## 42. Why is the NAT Gateway normally placed in a public subnet?

**5-Minute Recall**

Without looking at the notes, explain:

7. Why is the NAT Gateway normally placed in a public subnet?

<details>
<summary>Answer</summary>

NAT needs a route to the Internet Gateway and a public Elastic IP.

A NAT in a private subnet cannot reach the internet.

</details>

---

## 43. What does a Security Group do?

**5-Minute Recall**

Without looking at the notes, explain:

8. What does a Security Group do?

<details>
<summary>Answer</summary>

Stateful allow rules on ENIs and many managed services, by protocol, port, and source.

It is the primary workload firewall in most designs.

</details>

---

## 44. Why are Security Groups considered stateful?

**5-Minute Recall**

Without looking at the notes, explain:

9. Why are Security Groups considered stateful?

<details>
<summary>Answer</summary>

Allowed inbound automatically permits the matching return traffic.

You do not write a separate ephemeral-port allow for that flow.

</details>

---

## 45. How is a NACL different from a Security Group?

**5-Minute Recall**

Without looking at the notes, explain:

10. How is a NACL different from a Security Group?

<details>
<summary>Answer</summary>

NACL is subnet-level and stateless. You must allow both directions. Rules number in order.

SGs are resource-level and stateful. Check both when traffic dies.

</details>

---

## 46. What role does Route 53 play in networking?

**5-Minute Recall**

Without looking at the notes, explain:

11. What role does Route 53 play in networking?

<details>
<summary>Answer</summary>

DNS: public and private hosted zones that map names to IPs or aliases.

Wrong DNS sends packets down the wrong path.

</details>

---

## 47. What is a VPC endpoint?

**5-Minute Recall**

Without looking at the notes, explain:

12. What is a VPC endpoint?

<details>
<summary>Answer</summary>

Private access to a supported AWS service without the public internet path.

Gateway endpoints for S3/DynamoDB. Interface endpoints (PrivateLink) for many APIs.

</details>

---

## 48. Difference between gateway and interface endpoints

**5-Minute Recall**

Without looking at the notes, explain:

13. What is the difference between gateway and interface endpoints?

<details>
<summary>Answer</summary>

Gateway: prefix-list route in the route table (S3, DynamoDB). Interface: ENI with a private IP, often with private DNS, powered by PrivateLink.

Pick the type the service supports.

</details>

---

## 49. What problem does VPC Peering solve?

**5-Minute Recall**

Without looking at the notes, explain:

14. What problem does VPC Peering solve?

<details>
<summary>Answer</summary>

Private connectivity between two VPCs with non-overlapping CIDRs, plus routes and SGs on both sides.

It does not scale well to dozens of VPCs.

</details>

---

## 50. Why would an enterprise use Transit Gateway?

**5-Minute Recall**

Without looking at the notes, explain:

15. Why would an enterprise use Transit Gateway?

<details>
<summary>Answer</summary>

To hub many VPCs and hybrid links instead of a peering mesh.

You gain control and accept a shared dependency.

</details>

---

## 51. Why does centralized firewalling require routing changes?

**5-Minute Recall**

Without looking at the notes, explain:

16. Why does centralized firewalling require routing changes?

<details>
<summary>Answer</summary>

The firewall only sees packets that routes send to it.

Policy without a UDR or TGW route is unused.

</details>

---

## 52. Difference between ALB and NLB

**5-Minute Recall**

Without looking at the notes, explain:

17. What is the difference between ALB and NLB?

<details>
<summary>Answer</summary>

ALB: Layer 7 HTTP/HTTPS, host and path. NLB: Layer 4 TCP/UDP/TLS.

Choose from traffic type.

</details>

---

## 53. How should an application access a private RDS database?

**5-Minute Recall**

Without looking at the notes, explain:

18. How should an application access a private RDS database?

<details>
<summary>Answer</summary>

RDS DNS → private IP → VPC local route → App SG to RDS SG on 5432.

No public endpoint. Credentials stay in Secrets Manager.

</details>

---

## 54. Main AWS hybrid connectivity options

**5-Minute Recall**

Without looking at the notes, explain:

19. What are the main AWS hybrid connectivity options?

<details>
<summary>Answer</summary>

Site-to-Site VPN (encrypted over the internet) and Direct Connect (provider private path).

Both still need unique CIDRs, routes, security, and DNS.

</details>

---

## 55. Why EKS needs Kubernetes and VPC networking knowledge

**5-Minute Recall**

Without looking at the notes, explain:

20. Why does EKS require both Kubernetes and VPC networking knowledge?

<details>
<summary>Answer</summary>

Pods use CNI IPs in the VPC. Failures span Services, NetworkPolicy, routes, and SGs.

A ready Pod can still miss RDS.

</details>

---

## 56. How does ECS Fargate participate in VPC networking?

**5-Minute Recall**

Without looking at the notes, explain:

21. How does ECS Fargate participate in VPC networking?

<details>
<summary>Answer</summary>

`awsvpc` gives each task an ENI, private IP, subnet, route table, and Security Group.

Troubleshoot it like EC2 networking.

</details>

---

## 57. Troubleshoot an ECS → RDS timeout

**5-Minute Recall**

Without looking at the notes, explain:

22. How would you troubleshoot an ECS → RDS timeout?

<details>
<summary>Answer</summary>

Task subnet, route, task SG, RDS SG, DNS, port 5432, database health.

Do not rebuild the cluster first.

</details>

---

## 58. Troubleshoot a private EC2 → internet timeout

**5-Minute Recall**

Without looking at the notes, explain:

23. How would you troubleshoot a private EC2 → internet timeout?

<details>
<summary>Answer</summary>

DNS, default route to NAT, NAT health and public subnet, IGW, egress SG/NACL, then the external site.

Common miss: default route still points at IGW on a private instance with no public IP.

</details>

---

## 59. Troubleshoot private AWS service access

**5-Minute Recall**

Without looking at the notes, explain:

24. How would you troubleshoot private AWS service access?

<details>
<summary>Answer</summary>

DNS (private vs public), endpoint type and state, route or ENI, SG on the interface endpoint, then IAM.

If DNS is public, you never hit the endpoint.

</details>

---

## 60. Azure equivalents of major AWS networking concepts

**5-Minute Recall**

Without looking at the notes, explain:

25. What is the Azure equivalent of the major AWS networking concepts?

<details>
<summary>Answer</summary>

VPC ↔ VNet. SG ↔ NSG (not identical). Route table ↔ UDR. NAT ↔ NAT. Endpoint/PrivateLink ↔ Private Endpoint. Route 53 private zone ↔ Azure Private DNS. Peering ↔ peering. TGW ↔ hub/Virtual WAN. VPN ↔ VPN Gateway. Direct Connect ↔ ExpressRoute. ALB ↔ Application Gateway. NLB ↔ Azure Load Balancer.

Map the capability, then the product.

</details>

---

**Senior/Lead Architecture Exercise — full design**

## 61. Design the production AWS network per Part 21 requirements

**Senior/Lead Architecture Exercise**

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

<details>
<summary>Answer</summary>

Internet users hit Route 53 then a public ALB. EKS workers stay private. RDS is private with SG-to-SG 5432. S3 uses a gateway endpoint. Egress goes NAT or TGW inspection with known IPs. Hybrid lands on TGW. Teams get spoke VPCs, not one flat network.

Explain each hop. The diagram is a consequence of the requirements, not decoration.

</details>

---

**Practice: Build an AWS Networking Lab**

## 62. Build VPC `10.50.0.0/16` across two AZs and break each layer

**Practice: Build an AWS Networking Lab**

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

<details>
<summary>Answer</summary>

Create public and private app subnets in two AZs, IGW, NAT, routes, SGs, EC2/ECS, S3 endpoint, and ALB. Test inbound, outbound, and S3 privately.

Then break route, SG, NACL, DNS, endpoint, and ALB health one at a time. Name the layer from evidence. Destroy NAT, ALB, and EIPs when done; they keep billing.

</details>
