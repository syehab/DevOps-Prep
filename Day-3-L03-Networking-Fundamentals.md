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

> **Key idea:** Networking troubleshooting is mostly about finding **where the request stopped**.

---

## 02 · IP Address · 9 min

An **IP address identifies a network interface or endpoint** so that machines know where to send traffic. For example, an application server might have `10.0.1.10` and a database might have `10.0.1.20`. An IP address is therefore similar to a network location: it tells the sender which endpoint it is trying to reach.

Private IP addresses are used inside private networks and are not directly routable across the public internet. Public IP addresses provide internet-reachable addressing when routing and firewall rules also permit the traffic. In cloud environments, resources such as VMs, load balancers and database services commonly have private addresses for internal communication, while only selected components are given public access.

```text
Private network

10.0.1.10  →  Application
10.0.1.20  →  Database
```

IP addresses also belong to different networks and subnets. The subnet tells a machine which destinations are considered local and which require a router or gateway. This becomes important when you design cloud networks because placing two resources in different subnets does not automatically guarantee that they can communicate.

The important point is that an IP tells you **where the destination is**, but it does not tell you which application should receive the traffic. The port and protocol provide that additional information.

> **DevOps view:** When connectivity fails, identify the source IP, destination IP and network they belong to before investigating the application itself.

---

## 03 · DNS · 9 min

**DNS (Domain Name System)** translates human-friendly names such as `api.example.com` into IP addresses. This lets users and applications work with stable names instead of having to remember or hard-code changing IP addresses. When a user enters a URL, DNS is one of the first steps involved in discovering where that service should be reached.

```text
api.example.com
       ↓
    DNS lookup
       ↓
   10.0.1.10
```

DNS supports different record types for different purposes. An **A record** maps a name to an IPv4 address, while a **CNAME** maps one name to another name. A service can also have multiple IP addresses returned by DNS, which can support distribution or failover.

DNS responses are often cached by clients, operating systems and DNS resolvers. This is why changing a DNS record does not necessarily become visible everywhere immediately; the old answer may remain cached until its TTL expires.

If DNS returns the wrong address, the application can be perfectly healthy while users are sent to the wrong destination. A useful first test is:

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

An IP address tells the network **which endpoint** to reach, while a **port identifies the service** on that endpoint. A server can run several services on the same IP because each service can listen on a different port, such as an application on `8080`, HTTPS on `443` and SSH on `22`.

```text
10.0.1.10:8080
     │      │
     │      └── Port
     └───────── IP
```

A protocol defines how the communication behaves. **TCP** establishes a connection and provides reliable, ordered delivery, which is why HTTP/HTTPS commonly runs over TCP. **UDP** sends datagrams without establishing the same kind of connection and is used by protocols such as DNS and many real-time workloads.

Ports are also important from a security perspective. You generally want only the required ports exposed; an application that listens on `8080` does not need that port to be publicly reachable if a load balancer or reverse proxy is the intended entry point.

For troubleshooting, separate **“is anything listening?”** from **“can I connect to it?”**:

```bash
ss -lntp
nc -vz 10.0.1.10 8080
```

A listening port only proves that a process has opened the port. It does not prove that the application is healthy or that the complete request path works.

> **Key idea:** Correct IP + correct port does not automatically mean the application will respond.

---

## 05 · Routing · 9 min

**Routing determines where traffic should go next.** A machine maintains a routing table containing destination networks and the path or interface to use for reaching them. If the destination is on the local network, the machine can communicate directly; if it is on another network, traffic is normally sent through a router or gateway.

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

Cloud networking uses the same idea. Azure VNets and AWS VPCs contain subnets, and route tables determine how traffic moves between those subnets, toward other networks, or toward gateways such as an internet gateway, NAT gateway or VPN connection.

Inspect routes on Linux with:

```bash
ip route
```

> **Senior question:** **“Does a valid path to the destination exist?”** before assuming the firewall or application is responsible.

---

## 06 · Firewalls & Security Groups · 9 min

A **firewall controls whether network traffic is allowed or denied**. Rules commonly evaluate information such as source, destination, port and protocol. This lets you expose only the traffic a service actually needs; for example, HTTPS may be allowed from the internet while database port `3306` is allowed only from application servers.

```text
Internet → TCP 443 → ALLOWED
App      → TCP 3306 → ALLOWED
Internet → TCP 3306 → DENIED
```

In the cloud, there can be multiple layers of network filtering. Azure commonly uses **Network Security Groups (NSGs)** and AWS uses **Security Groups**, while the operating system can have its own firewall as well. The important distinction is that a network security rule normally controls **network access**, while application authentication and authorization decide what an already-connected user or service is allowed to do.

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

This creates an important troubleshooting distinction: the VM can be healthy, the application process can be running, and the application can be listening on its port, while the load balancer still considers the instance unhealthy.

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

### Exit criteria

You should be able to trace:

```text
Name
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
