# Day 3 — Questions and answers

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Then answer each item below before you open the Answer block. After that, do the lab in [03-implementation.md](03-implementation.md).

Write your own answer first. Open the Answer block only after you try. Keep the original numbering.

---

## 1. Practice — Path for `api.example.com` behind a CDN, and the first hop to prove

**Practice:** Draw the path for a user who opens `api.example.com` behind a CDN. Mark the first hop you prove when they report an outage.

<details>
<summary>Answer</summary>

Draw the path as: User → DNS → Edge (CDN / WAF / TLS) → IP address → Route → Firewall → Load Balancer → Application. For `api.example.com` behind a CDN, DNS often lives on the same edge product as the CDN and the WAF. You still test DNS as its own question.

When users report an outage, prove the edge first. Ask three questions: does the name resolve, does TLS complete, and what HTTP status does the edge return? Then walk inward to the firewall, the load balancer, and the application. A wrong name sends users to the wrong place even when the application is healthy.

</details>

---

## 2. Step A — Resolve a name with `nslookup`

## 08 · Mini Exercise · 10–15 min

Use your Linux environment.

### Step A — Resolve a name

```bash
nslookup google.com
```

Identify the returned IP address.

<details>
<summary>Answer</summary>

`nslookup google.com` asks DNS to translate the name into IP addresses. Read the returned A records (IPv4 addresses). That answer is the destination the client will try to reach. `dig google.com` answers the same question.

This command proves **name → IP resolution**. It does not prove that traffic can reach that IP. If DNS returns the wrong address, the application can be healthy while users go to the wrong destination. Clients and resolvers cache answers until TTL expires, so an old IP can linger after a DNS change.

</details>

---

## 3. Step B — Inspect routes with `ip route`

### Step B — Inspect your routes

```bash
ip route
```

Find the default route.

<details>
<summary>Answer</summary>

`ip route` shows the routing table: destination networks and the path or interface to use for each. Find the default route, often `default via <gateway>`. That gateway is where the machine sends traffic that is not on a local network.

This command answers: **does a valid path to the destination exist?** An application can have the correct destination IP and still fail if the server has no route to that network. Check the route before you assume the firewall or the application is responsible.

</details>

---

## 4. Step C — Test connectivity with `ping` versus `nc`

### Step C — Test connectivity

```bash
ping google.com
```

Then test a TCP port:

```bash
nc -vz google.com 443
```

Notice that these tests answer different questions.

<details>
<summary>Answer</summary>

`ping google.com` tests whether ICMP echo to that host gets a reply. It answers “is this host reachable with ping?” It does not prove that a TCP service is open. Firewalls often block ICMP while they still allow HTTPS.

`nc -vz google.com 443` tests a TCP connect to port 443. It answers “can I open a TCP session to this IP and port?” These tests answer different questions. A successful ping does not mean port 443 works, and a failed ping does not always mean the service is down.

</details>

---

## 5. Step D — Trace the path with `traceroute` or `tracepath`

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

<details>
<summary>Answer</summary>

`traceroute google.com` (or `tracepath google.com`) shows the network hops between your machine and the destination. Read the hop list in order: each line is a router or hop on the path. A hop that times out or stops is a clue that traffic failed at that layer of the path.

This command answers: **where along the path did the request stop?** Use it after DNS and a local route look correct. It does not prove the application is healthy. It only shows how far packets get toward the destination.

</details>

---

## 6. Exercise goal — Which networking question each command answers

> **Exercise goal:** Don't just run commands. Identify **which networking question each command answers**.

<details>
<summary>Answer</summary>

Do not only run the commands. Map each one to a question. `nslookup` / `dig` answer “who is the destination?” (name → IP). `ip route` answers “does a valid path exist?” `ping` answers “does this host reply to ICMP?” `nc -vz host port` answers “can I connect to this TCP port?” `traceroute` / `tracepath` answer “where did the path stop?”

`ss -lntp` answers “is anything listening on this machine?” Listening is not the same as “can a remote client connect.” Keep IP, port, route, firewall, and application as separate questions. Networking troubleshooting is finding where the request stopped.

</details>

---

## 7. Scenario — API unavailable, process running, port 8080 listening

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

---

## 8. What problem does DNS solve?

## 13 · Exit Check · 3–5 min

Answer without looking:

1. What problem does DNS solve?

<details>
<summary>Answer</summary>

DNS translates a human-friendly name such as `api.example.com` into an IP address. Users and applications can use a stable name instead of a changing IP. When a user enters a URL, DNS is one of the first steps: it finds where to reach that service.

Prove **name → IP resolution** first with `nslookup` or `dig`. Then investigate whether traffic can reach that IP. A wrong DNS answer sends users to the wrong place even when the application is healthy.

</details>

---

## 9. What is the difference between an IP address and a port?

2. What is the difference between an IP address and a port?

<details>
<summary>Answer</summary>

An IP address identifies the network endpoint: where to send traffic. A port identifies the service on that endpoint. One server can run several services on the same IP because each service listens on a different port. Examples: `8080` for the app, `443` for HTTPS, and `22` for SSH.

Write it as `10.0.1.10:8080`. The IP is the location. The port is the service. Correct IP plus correct port still does not mean the application will respond.

</details>

---

## 10. What does routing determine?

3. What does routing determine?

<details>
<summary>Answer</summary>

Routing determines where traffic should go next. A machine keeps a routing table with destination networks and the path or interface for each. If the destination is local, the machine can send directly. If it is on another network, the machine sends traffic through a router or gateway.

A route is based on the destination network, not the application name. Inspect it with `ip route`. Ask “does a valid path to the destination exist?” before you blame the firewall or the application.

</details>

---

## 11. Where can a network request be blocked?

4. Where can a network request be blocked?

<details>
<summary>Answer</summary>

A request can stop at several independent layers. DNS can return a wrong name. The edge (CDN, WAF, TLS) can fail. A missing route, a firewall deny, a failed load-balancer health check, a closed port, or the application itself can also stop the request. In the cloud, Azure NSGs, AWS Security Groups, and the OS firewall are separate filter layers.

When traffic fails, identify **which firewall layer** could block it. Do not treat “firewall” as one control. Also check least privilege rules: source, destination, port, and protocol.

</details>

---

## 12. Why can a server be healthy while the application is unreachable?

5. Why can a server be healthy while the application is unreachable?

<details>
<summary>Answer</summary>

The VM can run, the process can exist, and the port can listen, while users still cannot use the application. DNS can point to the wrong IP. The edge can fail TLS or return an error. A firewall can deny the path. The load balancer can mark the instance unhealthy and stop sending new requests.

These are different states: **server healthy ≠ application healthy ≠ traffic path healthy.** A health check can fail even though the underlying VM is still running.

</details>

---

## 13. What is the first failed layer in a network troubleshooting path?

6. What is the first failed layer in a network troubleshooting path?

<details>
<summary>Answer</summary>

The first failed layer is the first hop that does not work when you test the path from the outside inward. Walk: DNS → edge (TLS and HTTP status) → client route → load balancer reachability → firewall → load balancer to app → application response. Stop at the first failure and investigate that layer.

If DNS works and TCP fails, do not keep investigating DNS. Use that first failed layer to narrow the problem. Networking troubleshooting is finding where the request stopped, not treating “the network” as one thing.

</details>

---

## 14. What sits at the edge, and how is Zero Trust different from a VPN?

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

<details>
<summary>Answer</summary>

The edge is the first hop of the request path: a CDN, WAF, and TLS termination. That hop answers DNS, finishes the TLS handshake, rate-limits floods and bots, then forwards only the requests that pass. When users say the site is down, prove this hop first: name resolution, TLS, and the HTTP status the edge returns.

Zero Trust verifies every request by identity, not by network location. A VPN trusts anyone who joined the network. ZTNA (Zero Trust Network Access) checks who the caller is on each request, whether they sit in the office or at home. Remember the idea. Look up product names such as Cloudflare One or Akamai when a JD names them.

</details>
