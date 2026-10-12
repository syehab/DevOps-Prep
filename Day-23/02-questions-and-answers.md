# Day 23 — Questions and answers

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Then answer each item below before you open the Answer block. After that, do the lab in [03-implementation.md](03-implementation.md).

Write your own answer first. Open the Answer block only after you try. Keep the original numbering.

---

## 1. Run the same Spring Boot app on VM, App Service, Container Apps, and AKS

**Practice:** Take the Spring Boot application from the previous lessons and explain how you could run it on a VM, App Service, Container Apps, and AKS.

<details>
<summary>Answer</summary>

On a VM, install Java, run the JAR under `systemd`, and own OS patching. On App Service, deploy the JAR or a container to a plan Azure patches. On Container Apps, push the image and run a revision with platform scaling. On AKS, run a Deployment, Service, and probes on node pools you still operate.

The code can stay the same. Operational responsibility changes. Pick from workload need, not from which name sounds modern.

</details>

---

## 2. Deploy Spring Boot on a Linux VM as systemd and compare with Kubernetes

**Practice:** Deploy a Spring Boot application to a Linux VM and configure it as a systemd service. Compare this operational model with your Kubernetes deployment from Day 14.

<details>
<summary>Answer</summary>

Install the JRE, copy the JAR, and run a `systemd` unit that starts the process on boot. You patch the OS, watch disk, rotate certificates, and replace the VM when it dies. One VM restart is not high availability.

On Kubernetes from Day 14, a Deployment replaces Pods, a Service keeps a stable endpoint, and probes gate traffic. The VM model is simpler until you need replicas, rolling updates, and self-heal. Then the operational load on the guest OS becomes the cost.

</details>

---

## 3. 10× traffic on VMSS and the next bottleneck

**Practice:** Imagine your Spring Boot application receives 10x normal traffic. Explain how VMSS could respond and what other component could become the bottleneck.

<details>
<summary>Answer</summary>

VMSS can add instances from the golden image and put them behind a load balancer. Health checks must pass before instances take traffic. State must live in the database or durable storage, not on the VM disk.

The next bottleneck is often PostgreSQL connections, disk I/O, or an external API rate limit. Adding VMs increases concurrency against that dependency. Scale the bottleneck you measure, not CPU by habit.

</details>

---

## 4. What the team manages: Linux VM vs App Service

**Practice:** Compare these two designs:

```text
Spring Boot → Linux VM
Spring Boot → App Service
```

List what your team must manage in each design.

<details>
<summary>Answer</summary>

On the VM you manage OS patches, Java, `systemd`, disks, NSGs, certificates, backups of the guest, and the deploy script. Azure manages the host hardware.

On App Service you manage the app, settings, slots, scale rules, and identity. Azure manages the OS, much of the runtime host, and platform patching. App Service can also run a container. You still do not get a VM you SSH into.

</details>

---

## 5. Staging slot for a Spring Boot API before swap

**Practice:** Explain how you would use a staging slot for a Spring Boot API and what you would verify before swapping it into production.

<details>
<summary>Answer</summary>

Deploy the new version to the staging slot. Warm it, hit `/health`, run smoke tests, and check logs and dependency calls. Keep slot-specific settings (connection strings, hostname bindings) marked so they do not move on swap.

Swap only after staging looks healthy. Then watch production error rate and latency. Slot swap is a controlled cutover, similar in intent to blue-green, with App Service mechanics.

</details>

---

## 6. Operate the Spring Boot container on ACA vs AKS

**Practice:** Take your Spring Boot container and explain what you would need to operate if you ran it on ACA compared with AKS.

<details>
<summary>Answer</summary>

On Azure Container Apps you operate the image, revisions, ingress, scale rules, and identity. Azure hides nodes, kubelets, and the Kubernetes API.

On AKS you still operate node pools, Deployments, Services, Ingress, RBAC, upgrades, and cluster networking. Use AKS when you need those Kubernetes surfaces. “We have a container” is not that requirement.

</details>

---

## 7. Business-hours backend: 24/7 replica vs scale-to-zero

**Practice:** Take a backend that receives requests only during business hours. Compare:

```text
24/7 minimum replica
vs
scale-to-zero outside demand
```

Explain the cost and latency trade-off.

<details>
<summary>Answer</summary>

A 24/7 minimum replica costs more at idle and avoids cold start. Scale-to-zero saves idle compute and adds first-request latency while the container starts.

For a user-facing API with a latency SLO, keep a minimum replica during business hours. For a batch or internal job, scale toward zero overnight. Configure the rule from availability need, not from a default of zero.

</details>

---

## 8. When ShopSphere should use AKS instead of Container Apps

**Practice:** Explain why the ShopSphere application might use AKS and what requirements would justify that complexity over Container Apps.

<details>
<summary>Answer</summary>

Use AKS when ShopSphere needs Kubernetes-native scheduling, custom controllers, Helm plus GitOps, service mesh, or a multi-workload cluster platform. Those needs justify node pools, upgrades, and cluster troubleshooting.

A few Spring Boot APIs with HTTP ingress do not. Container Apps already runs the image with revisions and scale. Complexity must match a real requirement.

</details>

---

## 9. Three event-driven ShopSphere tasks: sync vs async

**Practice:** Identify three tasks in ShopSphere that could reasonably be event-driven:

```text
Order-created processing
Email notification
Image processing
```

Then decide whether each should be synchronous or asynchronous.

<details>
<summary>Answer</summary>

Order-created processing: asynchronous. Accept the order, publish an event, and let a Function or worker reserve stock and call payment. Email notification: asynchronous. A queue trigger sends mail after the order exists. Image processing: asynchronous. A blob event resizes the upload.

Keep the HTTP API synchronous only for the user-facing create/read path. Long work belongs on a trigger so the request thread does not wait on email or image CPU.

</details>

---

## 10. One justifying requirement per compute option

**Practice:** For each compute option, write one requirement that would justify selecting it.

<details>
<summary>Answer</summary>

VM/VMSS: OS-level agents or a runtime Azure PaaS does not host. App Service: a conventional HTTP API with managed hosting and slots. Container Apps: a container without a Kubernetes API requirement. AKS: custom controllers or Kubernetes-native policy. Functions: an event or timer, not a long-lived Spring Boot process.

Ask what requirement removes the simpler option. “More powerful” is not a requirement.

</details>

---

## 11. Who patches, scales, networks, deploys, and owns failure on each architecture

**Practice:** For each architecture, answer:

```text
Who patches the OS?
Who scales the workload?
Who manages the runtime?
Who manages networking?
Who handles deployment?
Who manages certificates?
Who monitors the workload?
Who is responsible when the application fails?
```

<details>
<summary>Answer</summary>

VM: you patch OS and Java, you scale (or VMSS), you own NIC/NSG, you copy artifacts, you own the outage. App Service: Azure patches the platform; you scale the plan, bind VNet integration, deploy slots, and own app failures. Container Apps: Azure runs the platform; you scale revisions, configure ingress, and own app health. AKS: Azure manages the control plane; you patch node images, HPA and node pools, CNI/NSG, Deployments, cert-manager or Ingress TLS, and still own application failure.

The JAR can be identical. The RACI is not.

</details>

---

## 12. Internet → Spring Boot API → PostgreSQL on App Service, ACA, and AKS

**Practice:** Draw the path:

```text
Internet → Spring Boot API → PostgreSQL
```

for App Service, Container Apps, and AKS. Identify what changes in each architecture.

<details>
<summary>Answer</summary>

App Service: Internet → App Service front end / TLS → app → VNet integration → Private Endpoint → PostgreSQL. The app is not a NIC in your subnet by default.

Container Apps: Internet → environment ingress → revision → VNet integration → Private Endpoint → PostgreSQL. AKS: Internet → Application Gateway or load balancer → Service → Pod → VNet routing → NSG → Private Endpoint → PostgreSQL.

What changes is where the frontend lives, how outbound leaves, and which security rules apply. The database stays private in all three.

</details>

---

## 13. Identity for the same app on App Service, Container Apps, and AKS

**Practice:** Design identity access for the same Spring Boot application on App Service, Container Apps, and AKS. Explain what changes and what remains conceptually identical.

<details>
<summary>Answer</summary>

Give each platform a managed or workload identity. Assign Key Vault secret get (and database identity if used) to that identity. Do not put `DB_PASSWORD` in the image.

App Service and Container Apps attach a managed identity on the app. AKS uses workload identity on the Pod. The principle stays: workload → identity → Azure RBAC → resource. Only the attachment mechanism changes.

</details>

---

## 14. How ShopSphere API, database, images, queue, and frontend should scale

**Practice:** For ShopSphere, identify whether each component should scale vertically, horizontally, or through a different mechanism:

```text
API
Database
Image processing
Message queue
Frontend
```

<details>
<summary>Answer</summary>

API: horizontal replicas behind a load balancer. Database: vertical SKU first, then read replicas or sharding only with evidence. Image processing: horizontal workers or Functions on a queue. Message queue: scale consumers; the queue itself is a managed service. Frontend: horizontal static hosting or CDN, not a bigger VM.

Do not scale the API to fix a saturated database. Scaling is a system property.

</details>

---

## 15. Rollback the same bad Spring Boot release on VM, App Service, ACA, and AKS

**Practice:** Explain how you would rollback the same bad Spring Boot release on VM, App Service, Container Apps, and AKS.

<details>
<summary>Answer</summary>

VM: restore the previous JAR and restart `systemd`, or roll VMSS to the previous gallery image version. App Service: swap back to the previous slot or redeploy the last good package. Container Apps: shift traffic to the previous revision. AKS: `kubectl rollout undo` or Helm rollback to the previous Deployment revision.

Rollback still needs a compatible database schema. The platform changes. Build once, verify health, then continue or roll back.

</details>

---

## 16. Small internal API: trade-offs across VM, App Service, Container Apps, AKS

**Practice:** For a small internal Spring Boot API, compare VM, App Service, Container Apps, and AKS in terms of:

```text
Infrastructure
Operations
Scaling
Security
Complexity
```

Do not produce a “winner.” Explain the trade-offs.

<details>
<summary>Answer</summary>

VM: cheap-looking SKU, high OS operations, manual scale, NSG hardening, simple mental model. App Service: plan cost, low OS work, easy scale and slots, less OS control. Container Apps: image-centric scale including toward zero, less cluster work, less Kubernetes power. AKS: highest platform power and the highest cluster, network, and upgrade burden.

For a small internal API, App Service or Container Apps usually fit. AKS is justified only by Kubernetes requirements. There is no universal winner.

</details>

---

## Part 17 — Senior/Lead Scenario: Choosing Compute

---

## 17. Map Applications A–D and name one alternative each

A company gives you four applications.

### Application A

Legacy Java application requiring OS-level agents and custom filesystem configuration.

### Application B

Standard Spring Boot REST API with conventional HTTP traffic.

### Application C

Containerized microservices platform requiring Kubernetes-native operators and complex workload scheduling.

### Application D

Event-driven image-processing function triggered by uploaded files.

Map each workload to a reasonable Azure compute category and justify the decision.

Your reasoning should sound like:

```text
Requirement
   ↓
Runtime characteristics
   ↓
Operational requirement
   ↓
Platform capability
   ↓
Architecture choice
```

Avoid reasoning like:

```text
"AKS because Kubernetes is modern."
```

or:

```text
"Functions because serverless is cheaper."
```

Those statements ignore workload requirements.

**Practice:** Write your decisions and then identify one alternative for each application.

<details>
<summary>Answer</summary>

A (legacy Java, OS agents, custom filesystem): VM or VMSS. Alternative: a dedicated VMSS baseline image if you later need replicas. B (standard Spring Boot REST): App Service. Alternative: Container Apps if the artifact is already an image. C (microservices, operators, complex scheduling): AKS. Alternative: Container Apps only if operators are dropped. D (image processing on upload): Functions on a blob trigger. Alternative: a Container Apps job if the runtime exceeds Function limits.

Reason from requirement → runtime → operations → platform. Not from “Kubernetes is modern.”

</details>

---

## 18. Bottleneck chain: scaling 3 → 12 made latency worse

**Practice:** Draw the bottleneck chain and explain why “just add more application instances” was insufficient.

<details>
<summary>Answer</summary>

Traffic rose. You scaled the API from 3 to 12. Each replica opened more database connections. The database hit its connection and CPU limit. Query latency rose, so API latency rose even while API CPU stayed moderate.

Adding instances increased pressure on the bottleneck. Fix database capacity, pool size, queries, cache, or async work. Do not add more APIs until evidence says the API is the constraint.

</details>

---

## Part 22 — Final Senior/Lead Recall

Without looking at the notes, explain these in your own words:

---

## 19. Main difference between VM and PaaS

What is the main difference between VM and PaaS?

<details>
<summary>Answer</summary>

A VM gives substantial OS and infrastructure control. PaaS abstracts more of the platform so you manage less infrastructure directly.

You still own the application, identity, and much of networking integration.

</details>

---

## 20. When to consider VM/VMSS

When should you consider VM/VMSS?

<details>
<summary>Answer</summary>

When OS-level control, legacy compatibility, custom agents, or a specialized runtime justifies the extra operational work.

Bake a golden image and roll VMSS. Do not patch live VMs by hand.

</details>

---

## 21. When to consider App Service

When should you consider App Service?

<details>
<summary>Answer</summary>

For supported web apps and APIs where you want managed hosting without operating Kubernetes or the guest OS.

It can deploy source or a container. Slots support a staged production cutover.

</details>

---

## 22. When to consider Container Apps

When should you consider Container Apps?

<details>
<summary>Answer</summary>

When you want containerized workloads on a managed application platform and you do not need the Kubernetes API.

Revisions, ingress, and scale rules are the control surface.

</details>

---

## 23. When to consider AKS

When should you consider AKS?

<details>
<summary>Answer</summary>

When Kubernetes-native capabilities are actually required: custom controllers, complex scheduling, GitOps at cluster scale, or a multi-workload platform.

Azure manages the control plane. You still own node pools and workloads.

</details>

---

## 24. When to consider Functions

When should you consider Functions?

<details>
<summary>Answer</summary>

For event-driven or function-oriented work where the serverless execution model fits. Triggers include HTTP, queue, timer, Event Hub, and blob.

A Function is not a small Spring Boot server. Timeouts, state, and scale differ.

</details>

---

## 25. Key question when choosing compute

What is the key question when choosing compute?

<details>
<summary>Answer</summary>

What requirement justifies the operational complexity of this compute model?

Choose the simplest abstraction that meets the workload.

</details>

---

## 26. What is horizontal scaling?

What is horizontal scaling?

<details>
<summary>Answer</summary>

Adding more workload instances and distributing traffic across them.

It fits stateless APIs. It can overload a shared database.

</details>

---

## 27. What is vertical scaling?

What is vertical scaling?

<details>
<summary>Answer</summary>

Increasing the capacity of an existing instance, for example 2 CPU / 8 GB to 4 CPU / 16 GB.

It is common for databases before you shard.

</details>

---

## 28. Does scaling the application guarantee better performance?

Does scaling the application guarantee better performance?

<details>
<summary>Answer</summary>

No. Another dependency can become the bottleneck.

Measure the chain: API, connection pool, database, and external APIs.

</details>

---

## 29. Golden image and why rebuild instead of patching live VMs

What is a golden image and why rebuild instead of patching live VMs?

<details>
<summary>Answer</summary>

A golden image is a pre-built, tested, hardened VM template. Every new instance boots from it. Publish versions to Azure Compute Gallery and roll VMSS onto the new version.

Patching live servers by hand lets configuration drift. Rebuild the image, then replace instances.

</details>

---

## 30. Does containerization automatically require AKS?

Does containerization automatically require AKS?

<details>
<summary>Answer</summary>

No. App Service and Container Apps can run containers without a Kubernetes cluster.

Need Kubernetes capabilities before you accept cluster operations.

</details>

---

## 31. Does App Service only support source-code deployment?

Does App Service only support source-code deployment?

<details>
<summary>Answer</summary>

No. Supported App Service scenarios can run containerized web applications.

The artifact can be a JAR or an image. The platform is still App Service, not a VM.

</details>

---

## 32. Senior/Lead compute mindset

What is the Senior/Lead compute mindset?

<details>
<summary>Answer</summary>

Choose the simplest compute abstraction that satisfies the workload. State the operational, networking, security, reliability, and cost trade-offs.

Azure compute is a choice about execution model and operational responsibility. More control usually means more infrastructure work.

</details>

---

## 33. Map Applications A–D with requirement-driven justification

Map each workload to a reasonable Azure compute category and justify the decision using this sequence:

```text
Requirement
   ↓
Runtime characteristics
   ↓
Operational requirement
   ↓
Platform capability
   ↓
Architecture choice
```

### Application A

Legacy Java application requiring OS-level agents and custom filesystem configuration.

### Application B

Standard Spring Boot REST API with conventional HTTP traffic.

### Application C

Containerized microservices platform requiring Kubernetes-native operators and complex workload scheduling.

### Application D

Event-driven image-processing function triggered by uploaded files.

<details>
<summary>Answer</summary>

A needs OS agents and custom files: VM/VMSS. B is a standard HTTP API: App Service, or Container Apps if already containerized. C needs operators and complex scheduling: AKS. D is file-triggered image work: Functions.

Write requirement → runtime → operations → platform → choice. Name one alternative per app so the decision is reversible when requirements change.

</details>

---

## Part 18 — Failure Drill: Compute Is Healthy, Application Is Not

---

## 34. App Service running, CPU normal, users get HTTP 500

A Spring Boot application is running on App Service.

The platform reports:

```text
Application running
CPU normal
Memory normal
```

Users report:

```text
HTTP 500 errors
```

Do not conclude that the compute platform is healthy from resource metrics alone.

Investigate:

```text
Application logs
 ↓
Request/error metrics
 ↓
Dependency calls
 ↓
Database connectivity
 ↓
Configuration
 ↓
Recent deployment
```

<details>
<summary>Answer</summary>

Do not stop at platform metrics. Read application logs, error rate, dependency calls, database connectivity, configuration, and the last deployment.

Infrastructure health is not application health. The same rule applies to Container Apps and AKS. On AKS use `kubectl logs` and `kubectl describe pod`. On App Service use the app’s configured logs and metrics.

</details>

---

## Part 19 — Failure Drill: Scaling Does Not Solve the Problem

---

## 35. API scaled 3 → 12, DB connections near limit, latency worse

Suppose ShopSphere receives a large traffic spike.

You increase API replicas from:

```text
3 → 12
```

but latency becomes worse.

Observability shows:

```text
API CPU: moderate
API replicas: 12
Database connections: near limit
Database latency: high
```

The scaling action increased concurrency against the bottleneck.

Draw the bottleneck chain and explain why the extra replicas made latency worse.

<details>
<summary>Answer</summary>

The API was not the bottleneck. Extra replicas multiplied database sessions. Database latency then dominated API latency.

Draw traffic → more APIs → more connections → database saturation → worse user latency. Scale or tune the database, pools, queries, or cache. Do not keep adding APIs.

</details>

---

## Part 20 — Practice Lab: Compare Azure Compute Models

---

## 36. Compare at least two compute models for one Spring Boot app

Use one simple Spring Boot application.

Implement at least two of these:

```text
VM
App Service
Container Apps
AKS
```

For each implementation record:

```text
Deployment method
Networking
Identity
Secrets
Scaling
Health checks
Logs
Monitoring
Rollback
Cost
Operational responsibility
```

Then create a small comparison note using this structure:

```text
Requirement:
Standard Spring Boot API.

Option:
App Service.

Why:
Managed web application platform with less infrastructure
management than a VM.

Alternative:
Container Apps.

Trade-off:
Container Apps provides container-centric deployment and
scaling behavior, while App Service provides a different
managed application hosting model.
```

Repeat for the second compute model.

The goal is not to deploy every service. The goal is to learn how architecture changes when the compute abstraction changes.

<details>
<summary>Answer</summary>

Run the same API on two of VM, App Service, Container Apps, or AKS. For each, record deployment, networking, identity, secrets, scaling, health checks, logs, monitoring, rollback, cost, and operational ownership.

Write a short note: requirement, option, why, alternative, trade-off. Example: App Service for a standard API with less OS work; Container Apps as the container-centric alternative. You do not need every service. You need to feel how the abstraction changes operations.

</details>

