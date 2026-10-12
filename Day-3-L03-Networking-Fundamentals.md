---
title: "Day 3 · L03 — Networking Fundamentals"
description: "Understand how a request travels from a user to an application and where networking failures occur."
---

# Day 3 · L03 · Networking Fundamentals

> **Goal:** Build a simple mental model of how traffic moves through a network and learn where to investigate when connectivity fails.

| | |
|---|---|
| ⏱️ Time | 50–65 min |
| 🎯 Level | Senior DevOps |
| ☁️ Cost | ₹0 |
| 🧪 Hands-on | Local machine / Linux VM |

---

## 01 · The Request Journey · 7 min

When a user opens an application, the request travels through several networking layers before reaching the application. You don't need to memorize networking theory first; start by understanding the journey.

```text
User
 ↓
DNS
 ↓
Edge (CDN / WAF / TLS)
 ↓
IP address
 ↓
Route
 ↓
Firewall
 ↓
Load Balancer
 ↓
Application
```

Each step answers a different question: **Who is the destination? Where is it? Can traffic get there? Is it allowed? Which application should receive it?**

The path often starts one hop earlier than your load balancer. Many production sites put a CDN or a WAF at the **edge**. That edge answers DNS, finishes the TLS handshake, rate-limits floods and bots, then forwards only the requests that pass. When users say the site is down, prove this hop first.

Ask three questions: does the name resolve, does TLS complete, and what HTTP status does the edge return? Then walk inward to the firewall, the load balancer, and the application. DNS often lives on the same edge product as the CDN and the WAF, but you still test it as its own question. A wrong name sends users to the wrong place even when the application is healthy.

**Zero Trust** means you verify every request by identity, not by network location. A VPN trusts anyone who joined the network. ZTNA (Zero Trust Network Access) checks who the caller is on each request, whether they sit in the office or at home. Product names such as Cloudflare One (Access, Tunnel, WARP, Secure Web Gateway) and Akamai CDN, WAF, and Edge DNS are Look-up items. Remember the idea. Look up the product when a JD names it.

**Practice:** Draw the path for a user who opens `api.example.com` behind a CDN. Mark the first hop you prove when they report an outage.

> **Remember:** The edge is the first hop of the request path. Zero Trust verifies the caller, not the network they came from.

> **Key idea:** Networking troubleshooting is mostly about finding **where the request stopped**.

---

## 02 · IP Address · 9 min

An **IP address identifies a network interface or endpoint** so that machines know where to send traffic. For example, an application server might have `10.0.1.10` and a database might have `10.0.1.20`. An IP address is therefore similar to a network location: it tells the sender which endpoint it is trying to reach.

Private IP addresses work inside private networks, and the public internet cannot route to them directly. A public IP address can be reached from the internet when routing and firewall rules also allow the traffic. In cloud environments, resources such as VMs, load balancers and database services commonly have private addresses for internal communication. Only selected components get public access.

```text
Private network

10.0.1.10  →  Application
10.0.1.20  →  Database
```

IP addresses also belong to different networks and subnets. The subnet tells a machine which destinations are considered local and which require a router or gateway. This becomes important when you design cloud networks, because two resources in different subnets cannot always reach each other.

The important point is that an IP tells you **where the destination is**, but it does not tell you which application should receive the traffic. The port and protocol provide that additional information.

> **DevOps view:** When connectivity fails, identify the source IP, destination IP and network they belong to before investigating the application itself.

---

## 03 · DNS · 9 min

**DNS (Domain Name System)** translates human-friendly names such as `api.example.com` into IP addresses. This lets users and applications work with stable names instead of having to remember or hard-code changing IP addresses. When a user enters a URL, DNS is one of the first steps: it finds where to reach that service.

```text
api.example.com
       ↓
    DNS lookup
       ↓
   10.0.1.10
```

DNS supports different record types for different purposes. An **A record** maps a name to an IPv4 address, while a **CNAME** maps one name to another name. DNS can also return multiple IP addresses for one service, which can support distribution or failover.

Clients, operating systems and DNS resolvers often cache DNS responses. This is why a DNS record change does not show up everywhere at once; the old answer can stay cached until its TTL expires.

If DNS returns the wrong address, the application can be perfectly healthy while users go to the wrong destination. A useful first test is:

```bash
nslookup api.example.com
```

or:

```bash
dig api.example.com
```

> **Senior habit:** First prove **name → IP resolution**, then investigate whether traffic can actually reach that IP.

---

## 04 · Ports & Protocols · 9 min

An IP address tells the network **which endpoint** to reach, while a **port identifies the service** on that endpoint. A server can run several services on the same IP because each service listens on a different port. For example: an application on `8080`, HTTPS on `443` and SSH on `22`.

```text
10.0.1.10:8080
     │      │
     │      └── Port
     └───────── IP
```

A protocol defines how the communication behaves. **TCP** establishes a connection and provides reliable, ordered delivery, which is why HTTP/HTTPS commonly runs over TCP. **UDP** sends datagrams without establishing the same kind of connection and is used by protocols such as DNS and many real-time workloads.

Ports are also important from a security perspective. Expose only the required ports, because every open port is a possible entry point for an attacker. An application that listens on `8080` does not need a public port when a load balancer or reverse proxy is the intended entry point.

For troubleshooting, separate **“is anything listening?”** from **“can I connect to it?”**:

```bash
ss -lntp
nc -vz 10.0.1.10 8080
```

A listening port only proves that a process has opened the port. It does not prove that the application is healthy or that the complete request path works.

> **Key idea:** Correct IP + correct port does not automatically mean the application will respond.

---

## 05 · Routing · 9 min

**Routing determines where traffic should go next.** A machine keeps a routing table with destination networks and the path or interface to use for each. If the destination is on the local network, the machine can communicate directly. If it is on another network, the machine normally sends traffic through a router or gateway.

```text
Application
    ↓
Route table
    ↓
Gateway
    ↓
Destination network
```

A route is based on the **destination network**, not on the application name. This is why an application can have the correct database IP and still fail to connect: the server may simply have no valid route to the database network.

Cloud networking uses the same idea. Azure VNets and AWS VPCs contain subnets. Route tables determine how traffic moves between those subnets, toward other networks, or toward gateways such as an internet gateway, NAT gateway or VPN connection.

Inspect routes on Linux with:

```bash
ip route
```

> **Senior question:** **“Does a valid path to the destination exist?”** before assuming the firewall or application is responsible.

---

## 06 · Firewalls & Security Groups · 9 min

A **firewall controls whether network traffic is allowed or denied**. Rules commonly evaluate information such as source, destination, port and protocol. This lets you expose only the traffic a service actually needs. For example, you may allow HTTPS from the internet and allow database port `3306` only from application servers.

```text
Internet → TCP 443 → ALLOWED
App      → TCP 3306 → ALLOWED
Internet → TCP 3306 → DENIED
```

In the cloud, there can be multiple layers of network filtering. Azure commonly uses **Network Security Groups (NSGs)** and AWS uses **Security Groups**, while the operating system can have its own firewall as well. The important distinction is that a network security rule normally controls **network access**. Application authentication and authorization decide what an already-connected user or service can do.

A secure design usually follows **least privilege**: allow only the required source, destination, port and protocol instead of broadly opening an entire network. For example, a database should normally accept traffic from the application tier rather than from the public internet.

> **Senior habit:** When traffic fails, identify **which firewall layer** could be blocking it instead of treating “firewall” as one single control.

---

## 07 · Load Balancer · 7 min

A **load balancer provides a single entry point for clients and distributes traffic across multiple application instances**. This reduces the need for clients to know individual server addresses and allows the application tier to scale horizontally. It can also terminate TLS, route traffic based on rules and sometimes provide features such as connection management.

```text
             ┌─ App 1
User → LB ───┼─ App 2
             └─ App 3
```

Most production load balancers also perform health checks. A health check might verify that an instance is reachable and that a specific application endpoint returns an expected response. If the check fails, the load balancer can stop sending new requests to that instance even though the underlying VM is still running.

This creates an important troubleshooting distinction. The VM can be healthy, the process can run, and the port can listen, while the load balancer still considers the instance unhealthy.

This is why these are different states:

**Server healthy ≠ application healthy ≠ traffic path healthy.**

---

## 08 · Mini Exercise · 10–15 min

Use your Linux environment.

### Step A — Resolve a name

```bash
nslookup google.com
```

Identify the returned IP address.

### Step B — Inspect your routes

```bash
ip route
```

Find the default route.

### Step C — Test connectivity

```bash
ping google.com
```

Then test a TCP port:

```bash
nc -vz google.com 443
```

Notice that these tests answer different questions.

### Step D — Trace the path

If available:

```bash
traceroute google.com
```

or:

```bash
tracepath google.com
```

Look at the network hops between your machine and the destination.

> **Exercise goal:** Don't just run commands. Identify **which networking question each command answers**.

---

## 09 · Break & Reason · 5 min

### Scenario

Users report that your API is unavailable.

The application process is running and port `8080` is listening.

Start from the outside and move inward:

```text
Does DNS resolve?
      ↓
Does the edge complete TLS and return a status?
      ↓
Does the client have a route?
      ↓
Can traffic reach the load balancer?
      ↓
Does the firewall allow it?
      ↓
Does the load balancer reach the app?
      ↓
Is the app responding?
```

If DNS resolves correctly but TCP connection fails, don't keep investigating DNS. Move to the next layer.

> **Senior habit:** Use the **first failed layer** to narrow the problem.

---

## 10 · Azure ↔ AWS · 4 min

The networking concepts are the same even though cloud services use different names.

| Concept | Azure | AWS |
|---|---|---|
| Virtual network | VNet | VPC |
| Subnet | Subnet | Subnet |
| Network routing | Route table | Route table |
| Network firewall | NSG | Security Group |
| Public entry point | Public IP / Load Balancer | Public IP / Load Balancer |
| DNS | Azure DNS | Route 53 |

The service names change, but the questions remain the same:

**Where is the destination? Is there a route? Is traffic allowed? Is something listening?**

---

## 11 · Cost Check · 1 min

No cloud resources are required.

**AWS:** ₹0  
**Azure:** ₹0

---

## 12 · Cleanup · <1 min

Nothing to clean up if you used your local machine.

---

## 13 · Exit Check · 3–5 min

Answer without looking:

1. What problem does DNS solve?
2. What is the difference between an IP address and a port?
3. What does routing determine?
4. Where can a network request be blocked?
5. Why can a server be healthy while the application is unreachable?
6. What is the first failed layer in a network troubleshooting path?
7. What sits at the edge of the request path, and how is Zero Trust different from a VPN?

### Exit criteria

You should be able to trace:

```text
Name
 ↓
Edge (CDN / WAF / TLS)
 ↓
IP
 ↓
Route
 ↓
Firewall
 ↓
Load Balancer
 ↓
Port
 ↓
Application
```

> **Takeaway:** Don't think of “the network” as one thing. Think of it as a **path made of several independently testable layers**.

---

## Next

### Day 4 · L04 — CI/CD Mental Model

We'll connect application runtime and networking to:

**Code → Build → Test → Artifact → Deploy → Verify → Rollback**

## Answers to practice

### 1. Practice — Path for `api.example.com` behind a CDN, and the first hop to prove

<details>
<summary>Answer</summary>

Draw the path as: User → DNS → Edge (CDN / WAF / TLS) → IP address → Route → Firewall → Load Balancer → Application. For `api.example.com` behind a CDN, DNS often lives on the same edge product as the CDN and the WAF. You still test DNS as its own question.

When users report an outage, prove the edge first. Ask three questions: does the name resolve, does TLS complete, and what HTTP status does the edge return? Then walk inward to the firewall, the load balancer, and the application. A wrong name sends users to the wrong place even when the application is healthy.

</details>

### 2. Step A — Resolve a name with `nslookup`

<details>
<summary>Answer</summary>

`nslookup google.com` asks DNS to translate the name into IP addresses. Read the returned A records (IPv4 addresses). That answer is the destination the client will try to reach. `dig google.com` answers the same question.

This command proves **name → IP resolution**. It does not prove that traffic can reach that IP. If DNS returns the wrong address, the application can be healthy while users go to the wrong destination. Clients and resolvers cache answers until TTL expires, so an old IP can linger after a DNS change.

</details>

### 3. Step B — Inspect routes with `ip route`

<details>
<summary>Answer</summary>

`ip route` shows the routing table: destination networks and the path or interface to use for each. Find the default route, often `default via <gateway>`. That gateway is where the machine sends traffic that is not on a local network.

This command answers: **does a valid path to the destination exist?** An application can have the correct destination IP and still fail if the server has no route to that network. Check the route before you assume the firewall or the application is responsible.

</details>

### 4. Step C — Test connectivity with `ping` versus `nc`

<details>
<summary>Answer</summary>

`ping google.com` tests whether ICMP echo to that host gets a reply. It answers “is this host reachable with ping?” It does not prove that a TCP service is open. Firewalls often block ICMP while they still allow HTTPS.

`nc -vz google.com 443` tests a TCP connect to port 443. It answers “can I open a TCP session to this IP and port?” These tests answer different questions. A successful ping does not mean port 443 works, and a failed ping does not always mean the service is down.

</details>

### 5. Step D — Trace the path with `traceroute` or `tracepath`

<details>
<summary>Answer</summary>

`traceroute google.com` (or `tracepath google.com`) shows the network hops between your machine and the destination. Read the hop list in order: each line is a router or hop on the path. A hop that times out or stops is a clue that traffic failed at that layer of the path.

This command answers: **where along the path did the request stop?** Use it after DNS and a local route look correct. It does not prove the application is healthy. It only shows how far packets get toward the destination.

</details>

### 6. Exercise goal — Which networking question each command answers

<details>
<summary>Answer</summary>

Do not only run the commands. Map each one to a question. `nslookup` / `dig` answer “who is the destination?” (name → IP). `ip route` answers “does a valid path exist?” `ping` answers “does this host reply to ICMP?” `nc -vz host port` answers “can I connect to this TCP port?” `traceroute` / `tracepath` answer “where did the path stop?”

`ss -lntp` answers “is anything listening on this machine?” Listening is not the same as “can a remote client connect.” Keep IP, port, route, firewall, and application as separate questions. Networking troubleshooting is finding where the request stopped.

</details>

### 7. Scenario — API unavailable, process running, port 8080 listening

<details>
<summary>Answer</summary>

The process and the listen port are healthy on the server, so do not stay inside Java. Start outside and move inward. Use the first failed layer to narrow the problem.

1. Check DNS. Run `nslookup` (or `dig`) for the API name and confirm the IP.
2. Check the edge. Confirm TLS completes and note the HTTP status the CDN or WAF returns.
3. Check the client route. Confirm the client has a path to that IP.
4. Test reachability to the load balancer. Use `nc -vz` against the entry IP and port.
5. Check the firewall. Identify which layer could deny the traffic (NSG, Security Group, or OS firewall).
6. Check whether the load balancer reaches the app and whether health checks pass.
7. Then check whether the app responds correctly.

If DNS resolves and TCP fails, stop investigating DNS. Move to the next layer.

</details>

### 8. What problem does DNS solve?

<details>
<summary>Answer</summary>

DNS translates a human-friendly name such as `api.example.com` into an IP address. Users and applications can use a stable name instead of a changing IP. When a user enters a URL, DNS is one of the first steps: it finds where to reach that service.

Prove **name → IP resolution** first with `nslookup` or `dig`. Then investigate whether traffic can reach that IP. A wrong DNS answer sends users to the wrong place even when the application is healthy.

</details>

### 9. What is the difference between an IP address and a port?

<details>
<summary>Answer</summary>

An IP address identifies the network endpoint: where to send traffic. A port identifies the service on that endpoint. One server can run several services on the same IP because each service listens on a different port. Examples: `8080` for the app, `443` for HTTPS, and `22` for SSH.

Write it as `10.0.1.10:8080`. The IP is the location. The port is the service. Correct IP plus correct port still does not mean the application will respond.

</details>

### 10. What does routing determine?

<details>
<summary>Answer</summary>

Routing determines where traffic should go next. A machine keeps a routing table with destination networks and the path or interface for each. If the destination is local, the machine can send directly. If it is on another network, the machine sends traffic through a router or gateway.

A route is based on the destination network, not the application name. Inspect it with `ip route`. Ask “does a valid path to the destination exist?” before you blame the firewall or the application.

</details>

### 11. Where can a network request be blocked?

<details>
<summary>Answer</summary>

A request can stop at several independent layers. DNS can return a wrong name. The edge (CDN, WAF, TLS) can fail. A missing route, a firewall deny, a failed load-balancer health check, a closed port, or the application itself can also stop the request. In the cloud, Azure NSGs, AWS Security Groups, and the OS firewall are separate filter layers.

When traffic fails, identify **which firewall layer** could block it. Do not treat “firewall” as one control. Also check least privilege rules: source, destination, port, and protocol.

</details>

### 12. Why can a server be healthy while the application is unreachable?

<details>
<summary>Answer</summary>

The VM can run, the process can exist, and the port can listen, while users still cannot use the application. DNS can point to the wrong IP. The edge can fail TLS or return an error. A firewall can deny the path. The load balancer can mark the instance unhealthy and stop sending new requests.

These are different states: **server healthy ≠ application healthy ≠ traffic path healthy.** A health check can fail even though the underlying VM is still running.

</details>

### 13. What is the first failed layer in a network troubleshooting path?

<details>
<summary>Answer</summary>

The first failed layer is the first hop that does not work when you test the path from the outside inward. Walk: DNS → edge (TLS and HTTP status) → client route → load balancer reachability → firewall → load balancer to app → application response. Stop at the first failure and investigate that layer.

If DNS works and TCP fails, do not keep investigating DNS. Use that first failed layer to narrow the problem. Networking troubleshooting is finding where the request stopped, not treating “the network” as one thing.

</details>

### 14. What sits at the edge, and how is Zero Trust different from a VPN?

<details>
<summary>Answer</summary>

The edge is the first hop of the request path: a CDN, WAF, and TLS termination. That hop answers DNS, finishes the TLS handshake, rate-limits floods and bots, then forwards only the requests that pass. When users say the site is down, prove this hop first: name resolution, TLS, and the HTTP status the edge returns.

Zero Trust verifies every request by identity, not by network location. A VPN trusts anyone who joined the network. ZTNA (Zero Trust Network Access) checks who the caller is on each request, whether they sit in the office or at home. Remember the idea. Look up product names such as Cloudflare One or Akamai when a JD names them.

</details>
