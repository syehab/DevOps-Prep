# Day 32 — Questions and answers

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Then answer each item below before you open the Answer block. After that, do the lab in [03-implementation.md](03-implementation.md).

Write your own answer first. Open the Answer block only after you try. Keep the original numbering.

---

## Senior/Lead Interview Recall

Answer these without looking at the lesson or your Terraform code. If you cannot answer one, reread only that part, then try again.

---

## 1. Why is the database in a private subnet?

1. Why is the database in a private subnet?

<details>
<summary>Answer</summary>

PostgreSQL holds orders and customer data. Internet users must not reach TCP 5432. Place the database in private subnets with no Internet Gateway route.

The app reaches it on the VPC private path. A public database IP is out of scope for ShopSphere security.

</details>

---

## 2. What makes a subnet public?

2. What makes a subnet public?

<details>
<summary>Answer</summary>

Routing, not the name. A public subnet has a `0.0.0.0/0` route to an Internet Gateway. Resources also need public addressing and security rules.

A “public” label with only a local VPC route is still private.

</details>

---

## 3. What is the difference between a route table and a security group?

3. What is the difference between a route table and a security group?

<details>
<summary>Answer</summary>

A route table answers where traffic goes next. A security group answers whether that traffic is allowed.

A missing route will not heal if you open a security group. Diagnose route first, then allow rules.

</details>

---

## 4. Why is NAT needed?

4. Why is NAT needed?

<details>
<summary>Answer</summary>

NAT lets a private workload start outbound internet connections without a public IP. Typical needs are package pulls or a third-party API.

The instance stays unreachable from the internet. NAT is a path, not a default.

</details>

---

## 5. When would you avoid NAT?

5. When would you avoid NAT?

<details>
<summary>Answer</summary>

Skip NAT when the app has no outbound internet need, or when it only talks to AWS services. Use VPC endpoints for those AWS paths.

NAT costs money and widens egress. Justify every `0.0.0.0/0` private route.

</details>

---

## 6. Why use multiple Availability Zones?

6. Why use multiple Availability Zones?

<details>
<summary>Answer</summary>

One AZ is one failure domain. Spread public, application, and database subnets across at least two AZs so one AZ loss does not take the whole environment.

Two subnets in one AZ are not Multi-AZ. Placement must match the HA requirement.

</details>

---

## 7. Why should the database security group reference the application security group?

7. Why should the database security group reference the application security group?

<details>
<summary>Answer</summary>

The rule names who may start TCP 5432: `APP-SG → DB : 5432`. It does not open the VPC CIDR or the internet.

If a new app task joins `APP-SG`, it inherits the allow. Broad CIDR allows are weaker.

</details>

---

## 8. What is the difference between Security Groups and NACLs?

8. What is the difference between Security Groups and NACLs?

<details>
<summary>Answer</summary>

Security groups filter at the resource, are stateful, and handle return traffic for allowed connections. NACLs filter at the subnet, are stateless, and need explicit return rules.

Do not add complex NACLs just to show the feature. Extra layers must reduce risk, not hide failures.

</details>

---

## 9. Why can DNS be the root cause of an application outage?

9. Why can DNS be the root cause of an application outage?

<details>
<summary>Answer</summary>

The app connects to a name, not a mental picture of the database. Wrong or missing resolution sends traffic to the wrong IP, or nowhere.

Routes and security groups can be correct while `db.internal.example` is wrong. Test DNS with `nslookup` or `dig` first.

</details>

---

## 10. Why does a successful ping not prove database connectivity?

10. Why does a successful ping not prove database connectivity?

<details>
<summary>Answer</summary>

Ping uses ICMP. ShopSphere needs TCP 5432, authentication, and a query. ICMP success does not prove the engine listens or that the SG allows 5432.

Use `nc -vz <db-ip> 5432` after DNS. Then authenticate.

</details>

---

## 11. How would you troubleshoot `connection timed out`?

11. How would you troubleshoot `connection timed out`?

<details>
<summary>Answer</summary>

Timeout usually means the packet never completed the handshake. Check DNS IP, route to that IP, then source and destination security groups.

A dropped packet in a missing route or a silent SG deny looks like this. Do not restart the database first.

</details>

---

## 12. How would you troubleshoot `connection refused`?

12. How would you troubleshoot `connection refused`?

<details>
<summary>Answer</summary>

The host was reachable, but nothing accepted the port. Confirm PostgreSQL is running and listening on 5432 on the private IP.

This is closer to a service problem than a missing VPC route. Timeout and refused are different layers.

</details>

---

## 13. How would you troubleshoot `UnknownHostException`?

13. How would you troubleshoot `UnknownHostException`?

<details>
<summary>Answer</summary>

DNS failed before any TCP. Check the hostname, the VPC DNS settings, and `nslookup` or `dig` from the app network.

Fix resolution first. Opening 5432 cannot repair a name that does not exist.

</details>

---

## 14. How would you prove that the database is not publicly reachable?

14. How would you prove that the database is not publicly reachable?

<details>
<summary>Answer</summary>

From the internet, try the database endpoint on 5432. The path must fail. Confirm no public DB setting, no IGW route on database subnets, no public address, and no `0.0.0.0/0` on `DB-SG`.

Allowed and forbidden paths must both be tested.

</details>

---

## 15. How would you reduce outbound internet exposure?

15. How would you reduce outbound internet exposure?

<details>
<summary>Answer</summary>

List real destinations. Use VPC endpoints for AWS services. Restrict NAT to named APIs if they must leave the VPC. Remove NAT if nothing needs it.

General `0.0.0.0/0` egress is a security and cost choice, not a default.

</details>

---

## 16. How would you design networking across Dev/UAT/Prod?

16. How would you design networking across Dev/UAT/Prod?

<details>
<summary>Answer</summary>

Prefer separate accounts, each with its own VPC. Same module, different CIDRs and sizes. Do not share one VPC with Dev, UAT, and Prod subnets.

Account boundaries also split IAM, billing, quotas, and blast radius.

</details>

---

## 17. What happens if an Availability Zone fails?

17. What happens if an Availability Zone fails?

<details>
<summary>Answer</summary>

Targets and subnets in that AZ go away. The load balancer should send traffic to healthy targets in the other AZ. The database must also be Multi-AZ if the NFR says so.

NAT in a single AZ can still strand private egress. Place NAT and app capacity in more than one AZ.

</details>

---

## 18. What happens if the NAT Gateway fails?

18. What happens if the NAT Gateway fails?

<details>
<summary>Answer</summary>

Private workloads lose outbound internet through that NAT. App-to-database traffic on local VPC routes should still work.

If the app needs a payment API through NAT, checkout fails. If it only uses VPC endpoints and the private DB, NAT loss is narrower.

</details>

---

## 19. What happens if the load balancer is healthy but all application targets are unhealthy?

19. What happens if the load balancer is healthy but all application targets are unhealthy?

<details>
<summary>Answer</summary>

The ALB is up. It has no healthy backends, so users get errors. Check `/health`, target group status, `APP-SG` from `ALB-SG` on 8080, and app logs.

Do not treat “ALB is healthy” as “the app serves traffic.”

</details>

---

## 20. What is the largest network blast radius of your design?

20. What is the largest network blast radius of your design?

<details>
<summary>Answer</summary>

A VPC-wide CIDR allow, a public database, or one shared SG for every tier. Compromise of the app identity plus an open DB CIDR reaches all data in that VPC.

Keep SG references tight, database subnets private, and environments in separate accounts.

</details>

---

## 21. Failure drill: wrong route

Deliberately modify the application subnet's routing so the application cannot reach the database.

Do not change security groups.

Observe the failure.

Now reason:

```text
DNS
 ↓
Correct IP?
 ↓
Route?
 ↓
Security?
```

You should identify the route problem before changing the database security group.

Restore the correct route and verify recovery.

Record:

```text
Symptom:
Application cannot connect to DB

Evidence:
DNS resolves correctly
TCP connection fails

Root cause:
Incorrect/missing route

Fix:
Restore correct route

Preventive Control:
Terraform-managed routing + plan review
```

<details>
<summary>Answer</summary>

Remove or change the application subnet route toward the database. Leave security groups alone. DNS still resolves. TCP to 5432 fails.

Root cause is the missing route, not the SG. Restore the Terraform-managed route and confirm `nc -vz` succeeds.

</details>

---

## 22. Failure drill: security group

Now restore routing and deliberately remove the application-to-database security-group permission.

Test again.

The expected reasoning is:

```text
DNS works
 ↓
Route works
 ↓
TCP connection blocked
 ↓
Inspect DB security group
```

Restore the rule.

The important lesson is that a security-group failure can look similar to a route failure from the application's point of view.

Your evidence must distinguish them.

<details>
<summary>Answer</summary>

Restore routing. Remove `APP-SG → DB : 5432`. DNS and route still work. TCP is blocked.

Inspect `DB-SG`, restore the minimum rule, and retest. From the app, this can look like a route failure. Evidence must split the layers.

</details>

---

## 23. Failure drill: wrong DNS

Change the application configuration to use an incorrect database hostname.

Now investigate.

You should see something similar to:

```text
Application
 ↓
DNS lookup
 X
Correct IP
```

The database security group may be completely correct.

The route may be completely correct.

The database may be healthy.

Yet the application still fails.

This demonstrates why troubleshooting should start at the first broken layer rather than changing random infrastructure.

<details>
<summary>Answer</summary>

Point the app at a bad hostname. Lookup fails or returns the wrong IP. The database, routes, and `DB-SG` can all be healthy.

Start at DNS. Do not change random SGs. Fix the name, then `nc -vz` the real private IP.

</details>

---

## 24. Failure drill: public exposure

Now inspect the database from the internet-facing side.

Verify that:

```text
Internet → Database
```

is not an allowed path.

Then ask:

**What configuration would accidentally make this database public?**

Potential causes include:

- public database configuration
- inappropriate subnet routing
- public addressing
- overly broad security rules
- incorrect architecture changes

Do not rely on one security group rule as your entire protection model.

Security is the combination of network placement, routing, identity, service configuration, and access control.

<details>
<summary>Answer</summary>

Prove `Internet → Database` fails. Accidental public exposure comes from a public DB setting, IGW routing on data subnets, a public address, or `0.0.0.0/0` on 5432.

One SG deny is not the whole model. Placement, routing, identity, and service config must agree.

</details>

---

## 25. Security review questions

Review the architecture using these questions:

```text
Is the database public?
Are application ports publicly exposed?
Can the application communicate only with required dependencies?
Can developers directly access Production infrastructure?
Are IAM permissions scoped?
Are secrets outside Git?
Are logs enabled?
Are network changes Terraform-managed?
```

Then review the blast radius.

If the application identity is compromised:

```text
What can it access?
What can it modify?
Can it modify the database?
Can it modify infrastructure?
Can it access other environments?
```

The goal is not “perfect security.”

The goal is **controlled blast radius**.

<details>
<summary>Answer</summary>

Database is not public. App 8080 is only from `ALB-SG`. App talks only to required deps. Developers have no standing Prod admin. IAM is scoped. Secrets stay out of Git. Logs are on. Network lives in Terraform.

If the app identity is stolen: it can use its secrets and data path, not Terraform, not other accounts, not IAM admin.

</details>

---

## 26. Environment isolation

Dev, UAT, and Production should not simply differ by a variable called `ENV=prod`; they should have meaningful isolation. For AWS, separate accounts provide the strongest boundary, and within an account, separate VPCs or other resource boundaries can provide additional isolation.

Conceptually:

```text
Dev Account
 └── Dev VPC

UAT Account
 └── UAT VPC

Prod Account
 └── Prod VPC
```

This is stronger than:

```text
One VPC
 ├── Dev subnet
 ├── UAT subnet
 └── Prod subnet
```

for many enterprise scenarios because the account boundary also affects IAM, billing, quotas, and governance.

The exact architecture depends on organizational requirements.

<details>
<summary>Answer</summary>

`ENV=prod` is a label, not a boundary. Separate AWS accounts with separate VPCs isolate IAM, billing, and network blast radius.

One VPC with Dev/UAT/Prod subnets is weaker for enterprise ShopSphere.

</details>

---

## 27. Lead review: why NAT, and what destinations need egress?

Now challenge your own architecture.

Ask:

**Why does the application need NAT?**

If the answer is “because private subnets need internet,” refine it.

Private workloads do not inherently require internet access.

Ask:

**What destinations actually require outbound access?**

Then:

```text
Specific AWS services
→ VPC endpoints where appropriate

Specific external APIs
→ controlled egress

No outbound requirement
→ no unnecessary internet path
```

This is both a security and cost question.

<details>
<summary>Answer</summary>

Do not say “private subnets need internet.” Name destinations. AWS APIs → VPC endpoints. Named external APIs → controlled NAT. Nothing → no internet path.

This is security and cost together. Unused NAT still bills.

</details>

---

## 28. CIDR and subnet design (expected outcome)

Create a dedicated VPC for the ShopSphere environment.

For a simple lab, you could use:

```text
VPC
10.20.0.0/16
```

Then divide it into subnets.

For example:

```text
AZ-1
  Public:      10.20.1.0/24
  Application: 10.20.11.0/24
  Database:    10.20.21.0/24

AZ-2
  Public:      10.20.2.0/24
  Application: 10.20.12.0/24
  Database:    10.20.22.0/24
```

This is only an example address plan.

The important concepts are:

- The VPC provides the network boundary.
- A subnet is associated with one Availability Zone.
- CIDRs must not overlap with networks that need to communicate.
- Subnet placement should reflect routing and failure-domain requirements.
- Multiple AZs provide a foundation for application high availability.

Do not confuse “two subnets” with high availability. If both are in one AZ, you have not created AZ-level redundancy.

<details>
<summary>Answer</summary>

Example: VPC `10.20.0.0/16`. AZ-1 public `10.20.1.0/24`, app `10.20.11.0/24`, database `10.20.21.0/24`. AZ-2 public `10.20.2.0/24`, app `10.20.12.0/24`, database `10.20.22.0/24`.

CIDRs must not overlap with networks that must peer later. Subnet = one AZ.

</details>

---

## 29. Traffic flows and security relationships (expected outcome)

For ShopSphere, think in terms of allowed application flows:

```text
Internet
   ↓ TCP 443
Load Balancer
   ↓ TCP 8080
Application
   ↓ TCP 5432
PostgreSQL
```

The security groups should reflect these relationships.

Conceptually:

```text
ALB-SG
Allow:
Internet → ALB : 443

APP-SG
Allow:
ALB-SG → App : 8080

DB-SG
Allow:
APP-SG → DB : 5432
```

Notice that the database rule refers to the application security group rather than allowing the entire internet.

The application instances should only receive traffic from the load-balancing layer.

That creates this security relationship:

```text
Internet
   ↓
ALB-SG
   ↓
APP-SG
```

not:

```text
Internet
   ↓
APP-SG : 8080
```

<details>
<summary>Answer</summary>

`Internet → TCP 443 → ALB-SG → TCP 8080 → APP-SG → TCP 5432 → DB-SG`. Public subnets: IGW. App subnets: NAT only if justified. Database subnets: local VPC only.

Internet must not reach 8080 on the app or 5432 on the database.

</details>

---

## 30. Terraform network structure (expected outcome)

Organize the infrastructure into reusable modules.

A possible structure is:

```text
infra/
├── modules/
│   ├── network/
│   ├── security-groups/
│   ├── database/
│   └── application/
│
└── environments/
    ├── dev/
    ├── uat/
    └── prod/
```

The network module should accept values such as:

```text
vpc_cidr
availability_zones
public_subnets
application_subnets
database_subnets
```

The environment should provide the values.

The module should implement the common design.

This keeps:

```text
Architecture
    ↓
Reusable Terraform module
    ↓
Environment-specific inputs
```

rather than creating three unrelated network implementations.

<details>
<summary>Answer</summary>

`infra/modules/network` plus `security-groups`, `database`, and `application`. `environments/dev|uat|prod` pass `vpc_cidr`, AZs, and subnet lists.

One architecture, different inputs. Run `terraform fmt`, `terraform validate`, and `terraform plan` before apply.

</details>

---

## 31. Deploy, inspect, and connectivity tests (expected outcome)

After applying, inspect the actual AWS resources.

Verify:

```text
VPC
Subnets
Route Tables
Internet Gateway
NAT Gateway if required
Security Groups
```

Then compare the cloud environment with Terraform.

You should be able to answer:

- Which subnet is public?
- Which subnet is private?
- Why?
- Which route makes it public?
- Which route provides private outbound access?
- Which security group allows application-to-database traffic?
- Which resources can reach the internet?
- Which resources cannot?

Do not proceed until you can answer these without opening the Terraform code.

Test the architecture from the outside in.

First:

```text
Internet
 ↓
Load Balancer
```

Then:

```text
Load Balancer
 ↓
Application
```

Then:

```text
Application
 ↓
Database
```

Then test an intentionally forbidden path:

```text
Internet
 X
Database
```

The expected result is that the database is not publicly reachable.

The purpose is not merely to prove success.

You are proving that **allowed and forbidden paths behave differently**.

<details>
<summary>Answer</summary>

After apply, name which subnet is public and why (IGW route), which is private, which SG allows app→DB, and who can reach the internet.

Test Internet→ALB, ALB→app, app→DB, and Internet↛DB. Allowed and forbidden paths must differ.

</details>

---

## 32. Network architecture artifact

Update:

```text
docs/networking.md
```

Include:

### Network CIDRs

```text
VPC:
10.20.0.0/16
```

### Subnets

```text
Public
Application
Database
```

### Traffic Flows

```text
Internet → ALB → Application → Database
Application → Required External Services
Application → AWS Services
```

### Security Rules

Document the allowed relationships.

### Routing

Document why each route exists.

### Failure Scenarios

Document at least:

```text
DNS failure
Route failure
Security-group failure
Database unavailable
```

This document should be understandable to another engineer without opening your Terraform code.

<details>
<summary>Answer</summary>

`docs/networking.md` holds CIDRs, subnets, flows, SG relationships, why each route exists, and four failures: DNS, route, SG, database down.

Another engineer should understand the path without opening Terraform.

</details>
