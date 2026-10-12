# Day 24 — Questions and answers

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Then answer each item below before you open the Answer block. After that, do the lab in [03-implementation.md](03-implementation.md).

Write your own answer first. Open the Answer block only after you try. Keep the original numbering.

---

## 1. Packet path for AKS Pod → PostgreSQL

**Practice**

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

<details>
<summary>Answer</summary>

Write the hostname (for example `orders-db.postgres.database.azure.com`), the IP `nslookup` returns, the subnet route to that IP, NSG and firewall on the path, TCP 5432, then the database listener and credentials.

Do not start with the firewall. Walk DNS → IP → route → security → port → service → application. If DNS returns a public IP, you are not on the private endpoint path.

</details>

---

## 2. VNet design for web, app, database, private endpoints, and management

**Practice**

Design a VNet for:

```text
Web
Application
Database
Private Endpoints
Management
```

Choose CIDRs that leave room for growth.

<details>
<summary>Answer</summary>

Use a non-overlapping space such as `10.20.0.0/16`. Example: `snet-web 10.20.1.0/24`, `snet-app 10.20.2.0/24`, `snet-data 10.20.3.0/24`, `snet-private-endpoints 10.20.4.0/24`, `snet-management 10.20.5.0/24`. Leave spare `/24`s for growth.

Check on-premises and other VNets before you pick CIDRs. Overlap breaks peering, VPN, and ExpressRoute later. IP planning is architecture, not a later config tweak.

</details>

---

## 3. NSG rules for Internet→Web 443, Web→App 8080, App→DB 5432, deny Internet→DB

**Practice**

Design rules for:

```text
Internet → Web: 443
Web → App: 8080
App → Database: 5432
Internet → Database: Deny
```

Then ask whether each rule is required and whether the source can be narrowed further.

<details>
<summary>Answer</summary>

Allow inbound TCP 443 to the web subnet from the internet (or from Application Gateway only, which is narrower). Allow TCP 8080 from the web subnet to the app subnet. Allow TCP 5432 from the app subnet to the data subnet. Do not allow internet sources to 5432.

Each allow should name the real source, not `*`. Internet→Web 443 is required only if users hit the web tier directly. If Application Gateway is the front door, source that subnet or its private IPs instead.

</details>

---

## 4. Intentional NSG failure on TCP 5432, then restore

**Practice**

Create an intentional NSG failure. Block TCP 5432 from the application subnet and test the application-to-database connection. Then identify the blocking rule and restore the intended access.

<details>
<summary>Answer</summary>

Add a Deny on inbound TCP 5432 from the app subnet with a lower priority number than the Allow, or remove the Allow so a default deny wins. Test with `nc -vz <db-ip> 5432` from the app. List rules with `az network nsg rule list` and find the first matching deny.

Restore the intended Allow from `10.20.1.0/24` to 5432. Recheck subnet NSG, NIC NSG, route, and firewall. The first matching priority wins. A later deny does not override an earlier allow.

</details>

---

## 5. App cannot reach on-premises after a route-table change

**Practice**

Imagine an application suddenly cannot reach an on-premises network after a route-table change. Determine whether the route to the on-premises CIDR still points toward the correct VPN/ExpressRoute path.

<details>
<summary>Answer</summary>

Find the on-premises CIDR. Check which route matches it in the subnet route table. The next hop must be the VPN or ExpressRoute gateway, not `Internet` or a wrong appliance IP.

A UDR can be valid JSON and still steal that prefix. Wrong path is routing. Correct path but blocked is NSG or firewall. Do not edit NSGs first.

</details>

---

## 6. Hub-and-spoke egress through Azure Firewall, and why the route table is required

**Practice**

Design a hub-and-spoke environment where:

```text
Spoke application
       ↓
Azure Firewall
       ↓
Internet
```

Explain why the route table is required in addition to the firewall. The firewall cannot inspect traffic that routing never sends through it.

<details>
<summary>Answer</summary>

Place Azure Firewall in the hub. In each spoke app subnet, add a UDR `0.0.0.0/0` next hop `VirtualAppliance` to the firewall private IP. Spokes peer to the hub. NSGs still filter local subnet traffic.

The firewall never sees packets that routing sends elsewhere. Deploying Firewall without the UDR leaves default internet paths in place. Routing steers. Firewall inspects.

</details>

---

## 7. Outbound path to a payment API that allowlists source IPs

**Practice**

Your application must call a third-party payment API that allowlists source IPs. Design the outbound path and identify which Azure public IP the third party should allowlist.

<details>
<summary>Answer</summary>

Put a NAT Gateway (or Azure Firewall SNAT) on the app subnet. Associate a static Standard public IP such as `pip-nat`. The third party allowlists that public IP, not the private `10.20.1.10`.

NAT Gateway is outbound only. Users still enter through Application Gateway or a load balancer. Do not confuse NAT with inbound load balancing.

</details>

---

## 8. Private endpoint for Storage: confirm `nslookup` returns a private IP

**Practice**

Create a private endpoint for a test Storage Account. From a workload inside the VNet, verify:

```bash
nslookup mystorage.blob.core.windows.net
```

Then determine whether the returned IP is public or private.

<details>
<summary>Answer</summary>

Create the private endpoint in `snet-private-endpoints` for the blob group. From a VNet workload run `nslookup mystorage.blob.core.windows.net`. A private IP such as `10.20.3.10` means Private DNS is working.

A public `20.x.x.x` address means the hostname still uses the public endpoint. The private endpoint NIC can be healthy while DNS is wrong. Fix the zone and VNet link, then retest.

</details>

---

## 9. Break private DNS, observe public resolution, restore private resolution

**Practice**

Break the private DNS configuration and observe what changes:

```bash
nslookup mystorage.blob.core.windows.net
```

Then restore the DNS configuration and verify that the application resolves the intended private address.

<details>
<summary>Answer</summary>

Remove the VNet link on `privatelink.blob.core.windows.net`. Run `nslookup mystorage.blob.core.windows.net` again. Expect a public IP. Restore the link with `az network private-dns link vnet create` and confirm the private endpoint IP returns.

Private Endpoint supplies the NIC. Private DNS makes the usual hostname resolve to that NIC. You need both.

</details>

---

## 10. Peer Hub, Spoke A, and Spoke B, then decide spoke-to-spoke

**Practice**

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

<details>
<summary>Answer</summary>

Peer Hub `10.0.0.0/16` with Spoke A `10.10.0.0/16` and Spoke B `10.20.0.0/16` in both directions. Spoke → Hub should be allowed for shared firewall, DNS, and gateways.

Spoke A → Spoke B should not be open by default. If required, use hub inspection (firewall) plus routes, or carefully controlled spoke peering. NSGs still must allow the ports. Peering is not a free pass.

</details>

---

## 11. Production hub-and-spoke for 50 teams, 3 environments, on-prem, inspection, private PaaS

**Practice**

Design a production hub-and-spoke architecture for:

```text
50 application teams
3 environments
on-premises connectivity
central outbound inspection
private PaaS access
```

Identify what belongs in the hub and what belongs in spokes.

<details>
<summary>Answer</summary>

Hub holds Azure Firewall, VPN or ExpressRoute gateway, private DNS, and shared management. Spokes hold application VNets per team or per environment. Production spokes get stricter NSGs and no public databases.

On-premises lands on the hub gateway. Outbound from spokes uses a UDR to the firewall. Private Endpoints live in spoke or shared PE subnets with Private DNS in the hub. The hub is a shared dependency: make it highly available and tightly change-controlled.

</details>

---

## 12. Load Balancer backend pool of three instances

**Practice**

Design a backend pool with three application instances and explain:

```text
What is the frontend IP?
What is the backend pool?
What does the health probe test?
What happens when one instance fails?
```

<details>
<summary>Answer</summary>

Frontend IP is the public or private address clients hit. The backend pool is the three instance NICs or IPs. The health probe checks a TCP port or HTTP path on each instance.

When one instance fails the probe, the load balancer stops sending new flows there. Remaining healthy instances take traffic. This is Layer 4. It does not read HTTP paths.

</details>

---

## 13. Application Gateway routing for API, www, and /images

**Practice**

Design routing for:

```text
api.example.com → Spring Boot API

www.example.com → Frontend

example.com/images/* → Static/content backend
```

Then decide whether the requirement is primarily Layer 4 or Layer 7.

<details>
<summary>Answer</summary>

Create listeners for `api.example.com` → Spring Boot backend, `www.example.com` → frontend, and a path map `example.com/images/*` → static backend. Use HTTP/HTTPS host and path rules.

This is Layer 7. A Layer 4 load balancer cannot route on hostname or URL path. Use Application Gateway (with WAF if required) as the internet front door.

</details>

---

## 14. On-premises `10.0.0.0/16` and Azure `10.0.0.0/16`

**Practice**

Imagine:

```text
On-premises: 10.0.0.0/16
Azure:       10.0.0.0/16
```

Explain why connecting these networks creates routing problems and why IP planning should happen before deployment.

<details>
<summary>Answer</summary>

Both sides own the same prefix. After VPN or ExpressRoute, routers cannot tell which `10.0.1.10` is on-premises and which is Azure. Return traffic is equally ambiguous.

Plan unique CIDRs before you deploy gateways. Overlap is a routing design failure, not a tunnel-setting bug.

</details>

---

## 15. Site-to-Site VPN vs ExpressRoute for continuous on-premises database access

**Practice**

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

<details>
<summary>Answer</summary>

VPN encrypts over the public internet. It is faster to stand up, cheaper, and depends on internet quality. ExpressRoute is private connectivity through a provider, with a different routing and operations model, usually higher cost and lead time.

Choose from reliability, bandwidth, routing, operations, cost, and security evidence. Do not pick ExpressRoute only because the slide says “enterprise.” A well-built VPN can be enough; a poorly routed ExpressRoute still fails.

</details>

---

## 16. AKS to Azure database through a private endpoint — draw the packet path first

**Practice**

Deploy a simple application to AKS and connect it to an Azure database through a private endpoint. Draw the complete packet path before troubleshooting.

<details>
<summary>Answer</summary>

User → Application Gateway or load balancer → AKS Service → Pod → Kubernetes DNS / Azure DNS → private endpoint IP → VNet route → NSG/firewall → private endpoint → PostgreSQL.

If the Pod times out, walk Pod DNS → destination IP → CNI → Azure route → NSG → firewall → 5432 → database health → credentials. Do not stop at `kubectl get pods`. Kubernetes and Azure networking both own this path.

</details>

---

## 17. Users work, payment API fails — start outbound, not the public load balancer

**Practice**

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

<details>
<summary>Answer</summary>

Inbound is healthy. Inspect application DNS for the payment hostname, the matching route, NSG/firewall egress, NAT or firewall SNAT IP, then the destination allowlist and API.

Do not start at the public load balancer. Inbound and outbound are different problems. A new UDR to a firewall that lacks an allow rule is a typical cause.

</details>

---

## 18. Break the VNet link to a private DNS zone, then restore

**Practice**

Break the VNet link to a private DNS zone and test name resolution from a workload. Restore the link and confirm that the expected private address is returned.

<details>
<summary>Answer</summary>

Delete the VNet link. From a workload, `nslookup` the PaaS hostname and record the public IP. Recreate the link and confirm the private endpoint IP.

This is the same failure as a missing `privatelink` zone. Connectivity errors then look like “timeout to storage” while the NIC was never in the path.

</details>

---

## 19. Troubleshoot AKS Pod → orders-db.internal connection timeout

**Practice**

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

<details>
<summary>Answer</summary>

From a debug Pod run `nslookup orders-db.internal`, then `nc -vz` the returned IP on 5432. Check Kubernetes NetworkPolicy, Azure route, NSG, and firewall. Confirm PostgreSQL is listening and credentials work.

Change one control at a time. Record evidence. DNS → IP → route → security → port → service → application. Do not edit five NSGs at once.

</details>

---

**Failure drill — Private Endpoint DNS**

## 20. Failure drill: private endpoint DNS broken (lab)

**Failure drill**

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

<details>
<summary>Answer</summary>

Break the zone or VNet link. Confirm `nslookup` returns a public address while the private endpoint IP stays healthy. Restore DNS and confirm private resolution.

A private endpoint does not automatically make every client resolve the hostname privately. DNS is part of the design.

</details>

---

**Senior/Lead Architecture Exercise — walkthrough questions**

## 21. Why is the database private?

**Senior/Lead Architecture Exercise**

1. Why is the database private?

<details>
<summary>Answer</summary>

The database holds customer data. It must not have a public listener on the internet. Application Gateway fronts users. Pods reach PostgreSQL through a private endpoint and NSG-limited sources.

Private connectivity shrinks the attack surface. It does not replace credentials, encryption, or backups.

</details>

---

## 22. Why Application Gateway instead of exposing the backend directly?

**Senior/Lead Architecture Exercise**

2. Why use Application Gateway instead of exposing the backend directly?

<details>
<summary>Answer</summary>

Application Gateway terminates TLS, routes on host and path, probes backends, and can run WAF. AKS node IPs and API Pods stay private.

Exposing the backend public IP skips Layer 7 control and puts Kubernetes nodes on the internet. The front door is the inbound control point.

</details>

---

## 23. Where should outbound traffic leave Azure?

**Senior/Lead Architecture Exercise**

3. Where should outbound traffic leave Azure?

<details>
<summary>Answer</summary>

Leave through a hub Azure Firewall SNAT or a NAT Gateway with a known public IP, depending on whether you need inspection.

Predictable egress IPs let partners allowlist you. Random instance IPs do not.

</details>

---

## 24. Where should centralized inspection happen?

**Senior/Lead Architecture Exercise**

4. Where should centralized inspection happen?

<details>
<summary>Answer</summary>

In the hub Azure Firewall, fed by spoke UDRs for internet and optionally for spoke-to-spoke and hybrid traffic.

NSGs still do local allow/deny. Inspection without routing to the firewall is a drawing, not a control.

</details>

---

## 25. How does AKS reach the database?

**Senior/Lead Architecture Exercise**

5. How does AKS reach the database?

<details>
<summary>Answer</summary>

The Pod resolves the database hostname to the private endpoint IP, routes inside the VNet/peering, passes NSG/firewall, and connects to TCP 5432 on PostgreSQL.

If DNS returns a public IP, the Pod tries the public endpoint and may time out when public access is off.

</details>

---

## 26. How does DNS know to use the private endpoint?

**Senior/Lead Architecture Exercise**

6. How does DNS know to use the private endpoint?

<details>
<summary>Answer</summary>

A Private DNS zone such as `privatelink.postgres.database.azure.com` is linked to the VNet. The zone maps the service hostname to the private endpoint IP.

Without the link, public DNS wins. The private NIC exists and is unused.

</details>

---

## 27. How does on-premises traffic reach the application?

**Senior/Lead Architecture Exercise**

7. How does on-premises traffic reach the application?

<details>
<summary>Answer</summary>

On-premises → VPN Gateway or ExpressRoute → hub VNet → peering to the spoke → Application Gateway private frontend or internal load balancer → AKS.

Routes both ways must exist. NSGs must allow the on-premises CIDR to the intended port. Overlapping CIDRs break this path.

</details>

---

## 28. What happens if a route is wrong?

**Senior/Lead Architecture Exercise**

8. What happens if a route is wrong?

<details>
<summary>Answer</summary>

Packets go to the wrong next hop: internet, a blackhole, or a firewall that never expected them. The app times out even when NSGs look correct.

Ask whether the selected route is the intended route for that destination, not only whether a route exists.

</details>

---

## 29. What happens if DNS is wrong?

**Senior/Lead Architecture Exercise**

9. What happens if DNS is wrong?

<details>
<summary>Answer</summary>

The client connects to the wrong IP: public PaaS, an old record, or NXDOMAIN. Private Endpoint and NSGs never see the traffic.

`nslookup` is the first tool. Fix resolution before you rewrite firewall rules.

</details>

---

## 30. What happens if NSG is wrong?

**Senior/Lead Architecture Exercise**

10. What happens if NSG is wrong?

<details>
<summary>Answer</summary>

The route is correct and the packet is dropped. Symptoms look like a timeout, same as a bad route.

Use Network Watcher IP flow verify and list NSG rules by priority. Restore the narrow Allow. Do not open `*` to “make it work.”

</details>

---

## 31. Which components create the largest blast radius?

**Senior/Lead Architecture Exercise**

11. Which components create the largest blast radius?

<details>
<summary>Answer</summary>

Hub firewall, hub gateway, shared Private DNS, and a shared Application Gateway affect every spoke. A bad UDR on a shared hub route can isolate many teams.

Spoke NSGs and one workload’s private endpoint have smaller blast radius. Treat hub changes as production changes.

</details>

---

## 32. Which components need high availability?

**Senior/Lead Architecture Exercise**

12. Which components need high availability?

<details>
<summary>Answer</summary>

Application Gateway, Azure Firewall, VPN/ExpressRoute gateway, NAT Gateway (where SKU allows), and zone-redundant database and AKS node pools.

A single-zone hub firewall takes down egress and inspection for every spoke when that zone fails.

</details>

---

**5-Minute Interview Recall**

Without looking at the notes, explain these in your own words.

The sequence worth memorizing is:

**DNS → IP → Route → Security → Port → Service → Application**

## 33. What problem does a VNet solve?

**5-Minute Recall**

Without looking at the notes, explain:

1. What problem does a VNet solve?

<details>
<summary>Answer</summary>

It provides the private IP space and boundary for routing, security, connectivity, and workload placement.

It is not only a bag of addresses.

</details>

---

## 34. Why does subnet design matter?

**5-Minute Recall**

Without looking at the notes, explain:

2. Why does subnet design matter?

<details>
<summary>Answer</summary>

Subnets place workloads, attach NSGs, NAT, and route tables, and some services need dedicated subnets. Changing CIDR later is hard.

Overlap with on-premises or peers blocks hybrid connectivity.

</details>

---

## 35. What does an NSG do?

**5-Minute Recall**

Without looking at the notes, explain:

3. What does an NSG do?

<details>
<summary>Answer</summary>

It filters traffic by source, destination, protocol, port, and direction.

It does not choose the next hop. That is routing.

</details>

---

## 36. How is an NSG different from a route table?

**5-Minute Recall**

Without looking at the notes, explain:

4. How is an NSG different from a route table?

<details>
<summary>Answer</summary>

A route table answers where traffic goes. An NSG answers whether that traffic is allowed.

Wrong path: routing. Correct path but blocked: NSG or firewall.

</details>

---

## 37. How are NSG priorities evaluated?

**5-Minute Recall**

Without looking at the notes, explain:

5. How are NSG priorities evaluated?

<details>
<summary>Answer</summary>

Lower numerical priority is evaluated first. The first match wins. Default rules still exist if you add no custom rule.

An Allow at 100 beats a Deny at 110 for the same traffic.

</details>

---

## 38. What does a UDR change?

**5-Minute Recall**

Without looking at the notes, explain:

6. What does a UDR change?

<details>
<summary>Answer</summary>

It overrides system routes for matching prefixes so you can send traffic to a firewall, gateway, or other next hop.

A default `0.0.0.0/0` to a virtual appliance is the usual forced-tunnel pattern.

</details>

---

## 39. Why would an organization use Azure Firewall?

**5-Minute Recall**

Without looking at the notes, explain:

7. Why would an organization use Azure Firewall?

<details>
<summary>Answer</summary>

For centralized, stateful inspection and egress control across many spokes.

NSGs stay for local subnet filtering. The two controls solve different problems.

</details>

---

## 40. What problem does NAT Gateway solve?

**5-Minute Recall**

Without looking at the notes, explain:

8. What problem does NAT Gateway solve?

<details>
<summary>Answer</summary>

Predictable outbound internet connectivity for private subnets using SNAT to a static public IP.

It is not an inbound load balancer.

</details>

---

## 41. Why would an application need a predictable outbound IP?

**5-Minute Recall**

Without looking at the notes, explain:

9. Why would an application need a predictable outbound IP?

<details>
<summary>Answer</summary>

Third parties allowlist source IPs for payment, partner, or SaaS APIs.

Without NAT or firewall SNAT, instance IPs change and the partner blocks you.

</details>

---

## 42. What does a Private Endpoint provide?

**5-Minute Recall**

Without looking at the notes, explain:

10. What does a Private Endpoint provide?

<details>
<summary>Answer</summary>

A private IP in your VNet for a supported Azure PaaS resource, so the app uses private connectivity instead of the public endpoint.

Security architecture can then control and monitor that path.

</details>

---

## 43. Why is Private DNS important with Private Endpoint?

**5-Minute Recall**

Without looking at the notes, explain:

11. Why is Private DNS important with Private Endpoint?

<details>
<summary>Answer</summary>

Applications still use the public hostname. Private DNS must return the private endpoint IP.

Without it, clients keep using the public address even if the NIC exists.

</details>

---

## 44. What does VNet Peering provide?

**5-Minute Recall**

Without looking at the notes, explain:

12. What does VNet Peering provide?

<details>
<summary>Answer</summary>

Private IP connectivity between VNets over Azure’s backbone.

Address spaces must not overlap. Routes and NSGs still apply.

</details>

---

## 45. Why are overlapping CIDRs dangerous?

**5-Minute Recall**

Without looking at the notes, explain:

13. Why are overlapping CIDRs dangerous?

<details>
<summary>Answer</summary>

Routers cannot uniquely identify a destination across VPN, ExpressRoute, or peering.

Fix address plans before you connect networks.

</details>

---

## 46. Difference between Load Balancer and Application Gateway

**5-Minute Recall**

Without looking at the notes, explain:

14. What is the difference between Load Balancer and Application Gateway?

<details>
<summary>Answer</summary>

Azure Load Balancer distributes TCP/UDP at Layer 4. Application Gateway routes HTTP/HTTPS at Layer 7 using host and path, and can add WAF.

Pick from protocol need, not from which name is more familiar.

</details>

---

## 47. When would VPN Gateway be used?

**5-Minute Recall**

Without looking at the notes, explain:

15. When would VPN Gateway be used?

<details>
<summary>Answer</summary>

For encrypted Site-to-Site (or similar) connectivity between on-premises and Azure over VPN.

Use it when private provider connectivity is not required or not ready.

</details>

---

## 48. How is ExpressRoute different conceptually from VPN?

**5-Minute Recall**

Without looking at the notes, explain:

16. How is ExpressRoute different conceptually from VPN?

<details>
<summary>Answer</summary>

VPN is encrypted over shared public infrastructure. ExpressRoute is private connectivity through a supported provider.

Routing, operations, lead time, and cost differ. It is not “VPN but faster” as a slogan.

</details>

---

## 49. Why does AKS networking need both Kubernetes and Azure knowledge?

**5-Minute Recall**

Without looking at the notes, explain:

17. Why does AKS networking require both Kubernetes and Azure networking knowledge?

<details>
<summary>Answer</summary>

A request crosses kube-proxy/CNI, Services, NetworkPolicy, then VNet routes, NSGs, load balancers, and private endpoints.

A healthy Pod can still time out on Azure routing or DNS.

</details>

---

## 50. Difference between inbound and outbound connectivity

**5-Minute Recall**

Without looking at the notes, explain:

18. What is the difference between inbound and outbound connectivity?

<details>
<summary>Answer</summary>

Inbound is client → public IP → Application Gateway or load balancer → backend. Outbound is backend → NAT or firewall → public destination.

Users working does not prove egress works.

</details>

---

## 51. Standard network troubleshooting sequence

**5-Minute Recall**

Without looking at the notes, explain:

19. What is your standard network troubleshooting sequence?

<details>
<summary>Answer</summary>

DNS → IP → route → security (NSG, firewall, NetworkPolicy) → port → service → application.

Use `nslookup`, `ip route`, `nc -vz`, then Azure Network Watcher. Change one thing at a time.

</details>

---

## 52. Troubleshoot a private Azure PaaS connection that times out

**5-Minute Recall**

Without looking at the notes, explain:

20. How would you troubleshoot a private Azure PaaS connection that times out?

<details>
<summary>Answer</summary>

Resolve the hostname. If it is public, fix Private DNS and the VNet link. If it is private, check route to that IP, NSG, firewall, private endpoint NIC, then the service port and credentials.

The private endpoint can be healthy while DNS still aims at the public endpoint.

</details>

---

**Senior/Lead Architecture Exercise — full design**

## 53. Design the production network for frontend, API, AKS, DB, Storage, on-prem, internet users

**Senior/Lead Architecture Exercise**

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

<details>
<summary>Answer</summary>

Internet users hit Application Gateway. AKS in a spoke stays private. Database and Storage use private endpoints plus Private DNS. Outbound uses hub firewall or NAT with known IPs. On-premises uses VPN or ExpressRoute into the hub. Teams get spokes, not a shared flat VNet.

Explain each choice with traffic path and blast radius. There is not one universal diagram. The requirements in Part 20 are the score.

</details>

---

## 54. Build the Azure networking lab and validate each layer

**Practice: Build an Azure Networking Lab**

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

<details>
<summary>Answer</summary>

Build `rg-network-lab` with VNet `10.50.0.0/16`, app `10.50.1.0/24`, data `10.50.2.0/24`, PE `10.50.3.0/24`. Add NSG, route table, NAT Gateway, Storage, private endpoint, and Private DNS. Test DNS, route, security, port, and service separately.

Then break an NSG rule, the DNS link, a route, and the application destination. Troubleshoot each with the standard sequence. Destroy the lab resource group when done.

</details>

---

**Failure drill — Wrong route**

## 55. Failure drill: wrong route after a new route table — HTTPS API timeout

**Failure drill**

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

<details>
<summary>Answer</summary>

Find the destination IP. See which route matches. Read the next hop. Check whether the new table sends traffic to a firewall or NVA. Confirm that device allows HTTPS and that return routing exists.

The route can exist and still be the wrong route. Do not assume “a default route is present, so internet works.”

</details>
