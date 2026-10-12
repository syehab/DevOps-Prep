# Day 23 — Azure Overlay 02: Azure Compute & PaaS

**Goal of today:** learn to choose between Azure's compute services by asking one question — how much infrastructure responsibility does this workload require us to keep?

## Part 1 — The Azure Compute Decision

Azure provides several ways to run application workloads, and the Senior/Lead challenge is not memorizing their names. The important question is **how much of the infrastructure you want Azure to manage versus how much control your team needs to retain**. Azure Virtual Machines give you the most operating-system-level control. Services such as App Service, Container Apps, Functions, and AKS progressively move more operational responsibility to the platform. This is what **PaaS** (platform as a service) means in plain terms: Azure runs the servers, operating system, and much of the plumbing. You bring only the application. The right choice depends on workload shape, runtime requirements, networking, scaling, operational complexity, security, and cost.

A useful spectrum is:

```text
More infrastructure control
        ↓
Azure VM
VM Scale Sets
App Service
Container Apps
AKS
Functions
        ↓
More platform-managed behavior
```

This is not a strict ranking because AKS can provide extensive infrastructure control while Functions can still require substantial application design work. Think of it as a **management-responsibility spectrum**, not a “better to worse” scale.

Before choosing a compute service, ask:

```text
What does the application need?
How does it run?
How does it scale?
What network access does it need?
How much OS control is required?
How much platform management do we want?
What availability is required?
What is the operational skill level?
What is the cost model?
```

**Remember:** Choose the compute model based on workload requirements, not because one service sounds more modern.

Practice: Take the Spring Boot application from the previous lessons and explain how you could run it on a VM, App Service, Container Apps, and AKS.

---

## Part 2 — Azure Virtual Machines

An Azure Virtual Machine is essentially a cloud-hosted server where you retain substantial control over the operating system, installed software, runtime, filesystem, networking, and configuration. This makes VMs useful when an application needs OS-level access, custom agents, legacy software, specialized configuration, or a runtime that does not fit cleanly into a higher-level PaaS service. The trade-off is that you become responsible for much more operational work: patching, hardening, monitoring, capacity, OS configuration, and often availability architecture.

The model is:

```text
Azure
 ↓
VM
 ├── OS
 ├── Runtime
 ├── Application
 ├── Agents
 └── Configuration
```

Azure manages the underlying physical infrastructure, but your team still owns the guest OS and workload configuration.

You can inspect a VM with Azure CLI:

```bash
az vm list \
  --output table
```

Create a small lab VM using the CLI or Terraform rather than repeatedly creating infrastructure manually.

When evaluating a VM architecture, ask:

```text
Who patches the OS?
Who installs Java?
Who manages certificates?
Who monitors disk space?
Who handles OS hardening?
What happens when the VM fails?
How is the application deployed?
How is the VM replaced?
```

**Important:** A VM restart is not the same thing as a highly available architecture.

Practice: Deploy a Spring Boot application to a Linux VM and configure it as a systemd service. Compare this operational model with your Kubernetes deployment from Day 14.

---

## Part 3 — VM Scale Sets

A Virtual Machine Scale Set (VMSS) manages a group of similar VMs from a common configuration and can integrate with autoscaling and load balancing. Instead of manually creating VM1, VM2, VM3, you define a desired VM configuration and let the platform maintain a set of instances.

Conceptually:

```text
VM Scale Set
     │
 ┌───┼────┬───┐
VM1  VM2  VM3  VM4
 │    │    │    │
 └────┴────┴────┘
       Load Balancer
```

This is useful for stateless workloads that need multiple instances and horizontal scaling.

However, VMSS does not magically make an application stateless. If the application stores important state locally, scaling or replacing instances can cause problems. State should generally live in appropriate external systems such as a managed database or durable storage.

A typical scaling mental model is:

```text
Traffic ↑
   ↓
More instances
   ↓
Traffic distributed
```

But scaling needs capacity planning and health checks. If the database is already saturated, adding more application VMs may make the overall system worse.

Where does the "common configuration" above actually come from? In mature teams it comes from a **golden image**: a pre-built, tested, and hardened VM template that your team owns. Every new VM or scale-set instance boots from that image, so servers start identical instead of being configured by hand after launch. **Hardening** means locking down the operating system's security settings, often against a **CIS benchmark**, which is a published security configuration checklist. When a patch or change is needed, you do not SSH into live servers and fix them one by one. Instead, an image-build pipeline produces a new image version, publishes it to **Azure Compute Gallery** (Azure's store for versioned VM images, formerly called Shared Image Gallery), and the scale set rolls its instances onto the new version.

```text
Base OS image
 ↓
Configure (scripts / Ansible as code)
 ↓
Harden (e.g. CIS baseline)
 ↓
Scan the image
 ↓
Publish version to Azure Compute Gallery
 ↓
VMSS rolling update to the new version
```

This is the "Image / model update → Rolling instance update" step you will meet again in Part 15: a VM Scale Set can reference a specific gallery image version, and a rolling upgrade replaces old instances with new ones booted from it. Day 27 Part 3 teaches the same immutable idea on AWS, where the golden image is called an AMI.

**Remember:** Bake, don't patch in place. Fix the image, then replace the servers.

Practice: Imagine your Spring Boot application receives 10x normal traffic. Explain how VMSS could respond and what other component could become the bottleneck.

---

## Part 4 — App Service

Azure App Service is a managed platform that hosts web applications and APIs. You do not manage the underlying operating system in the same way as a VM. You deploy your application to an App Service app and Azure manages much of the platform infrastructure, patching, and runtime hosting. It is well suited to conventional web applications and APIs where you want PaaS operational simplicity without adopting Kubernetes.

The model is:

```text
Application code
      ↓
App Service
      ↓
Azure-managed platform
      ↓
Underlying infrastructure
```

For a Spring Boot API, the application can run as a Java web application on App Service, depending on the supported runtime and deployment approach.

The key question is:

```text
Do I need Kubernetes?
```

If the answer is only “I have a Spring Boot application,” the answer is not automatically yes.

App Service can provide:

- Managed web hosting.
- TLS/custom domains.
- Deployment slots.
- Autoscaling options.
- Managed platform/runtime behavior.
- Integration with Azure networking and identity capabilities.

The exact capabilities depend on the App Service plan and architecture.

**Important correction to a common misconception:** App Service is not limited to deploying source code. Azure App Service also supports containerized web applications, so a container image can serve as the deployment artifact for supported App Service scenarios.

Practice: Compare these two designs:

```text
Spring Boot → Linux VM
Spring Boot → App Service
```

List what your team must manage in each design.

---

## Part 5 — App Service Deployment Slots

Deployment slots allow supported App Service applications to have separate deployment environments such as:

```text
Production
Staging
```

You can deploy a new version to the staging slot, validate it, and then perform a slot swap to production. This can reduce deployment risk because you can warm and test the application before you move production traffic.

Conceptually:

```text
                 App Service
                     │
             ┌───────┴───────┐
             │               │
          Staging         Production
          v2               v1
             │
          Validate
             │
          Swap
             ↓
          Production
          v2
```

This is conceptually similar to blue-green deployment, although the exact mechanics and operational behavior differ.

Slot configuration needs careful thought. You can mark some settings as deployment-slot-specific, so that environment-specific values do not unintentionally move during a swap.

Practice: Explain how you would use a staging slot for a Spring Boot API and what you would verify before swapping it into production.

---

## Part 6 — Azure Container Apps

Azure Container Apps (ACA) is a managed platform for running containerized applications without requiring you to operate a Kubernetes cluster directly. It supports application deployment using containers and provides platform features such as scaling, revisions, ingress, networking integrations, and workload execution models. It is useful when you want container packaging and modern deployment capabilities but do not need direct Kubernetes API/control over the platform.

The mental model is:

```text
Container Image
      ↓
Azure Container Apps
      ↓
Managed application platform
```

This is different from AKS:

```text
Container Image
      ↓
AKS
      ↓
Kubernetes
      ↓
Deployment / Service / Ingress / Pods / Nodes
```

With Container Apps, Azure abstracts much of the Kubernetes infrastructure and operational machinery.

Container Apps supports revisions — a revision is an immutable snapshot of one version of your application and its settings. Multiple revisions can exist at the same time, which enables traffic-management patterns.

A conceptual flow is:

```text
Revision 1
    ↓
Revision 2
    ↓
Traffic split / controlled transition
```

This can support progressive deployment approaches without requiring your team to manage Kubernetes directly.

Practice: Take your Spring Boot container and explain what you would need to operate if you ran it on ACA compared with AKS.

---

## Part 7 — Azure Container Apps Scaling and the “Always Running” Question

Container Apps can scale based on configured rules and workload behavior. Depending on configuration, an application can scale down substantially or potentially to zero for supported scenarios. However, “scale to zero” is not automatically appropriate for every backend. Cold-start behavior, startup time, minimum replicas, ingress configuration, workload characteristics, and availability requirements all affect the result. A **cold start** is the delay a scaled-to-zero application adds to its first request, because the platform must start the container before it can respond.

The decision is:

```text
Scale to zero?
     ↓
Lower idle cost
     +
Potential cold-start latency
```

or:

```text
Minimum running replicas
     ↓
Higher baseline cost
     +
Lower startup latency / continuous availability
```

For a user-facing API with strict latency requirements, you may deliberately keep a minimum number of replicas. For an infrequently used background workload, scaling toward zero may be more attractive.

Practice: Take a backend that receives requests only during business hours. Compare:

```text
24/7 minimum replica
vs
scale-to-zero outside demand
```

Explain the cost and latency trade-off.

---

## Part 8 — Azure Kubernetes Service (AKS)

AKS is Azure's managed Kubernetes service. Azure manages the Kubernetes control-plane aspects of the service. Your team still manages many data-plane and workload concerns such as Pods, Deployments, Services, workloads, resource requests, node pools, application configuration, and cluster-level operational choices. AKS is therefore appropriate when Kubernetes itself provides capabilities you need, rather than simply because the application happens to be containerized.

The architecture is:

```text
Azure
 │
 └── AKS
      │
      ├── Managed control plane
      │
      └── Node pools
            ├── Node
            │    ├── Pod
            │    └── Pod
            └── Node
                 ├── Pod
                 └── Pod
```

AKS becomes attractive when you need Kubernetes capabilities such as:

```text
Complex workload scheduling
Many services
Custom Kubernetes controllers
Advanced networking
Helm
GitOps
Kubernetes-native policy
Service mesh
Custom operators
Multi-workload cluster platform
```

But those capabilities also introduce operational complexity.

**Remember:** “We use containers” does not automatically mean “we need Kubernetes.”

Practice: Explain why the ShopSphere application might use AKS and what requirements would justify that complexity over Container Apps.

---

## Part 9 — Azure Functions

Azure Functions is a serverless compute platform designed around executing code in response to events or triggers. Rather than continuously operating a traditional application server, you deploy functions that execute in response to HTTP requests, queues, timers, events, and other supported triggers.

Conceptually:

```text
Event
  ↓
Function
  ↓
Code executes
  ↓
Result
```

Examples include:

```text
HTTP request
Queue message
Timer
Event Hub event
Blob event
```

Functions are particularly useful for event-driven processing, scheduled jobs, lightweight APIs, integration tasks, and asynchronous workloads.

They are not simply “small Spring Boot applications.” The execution model, scaling behavior, runtime constraints, timeout characteristics, state model, and architecture are different.

Practice: Identify three tasks in ShopSphere that could reasonably be event-driven:

```text
Order-created processing
Email notification
Image processing
```

Then decide whether each should be synchronous or asynchronous.

---

## Part 10 — Compute Selection: A Practical Decision Model

Use this decision sequence instead of memorizing a service comparison table.

```text
Do I need OS-level control?
        │
       Yes
        ↓
       VM / VMSS

       No
        ↓
Is it a conventional web/API application?
        │
       Yes
        ↓
   App Service

       No / Container required
        ↓
Do I need Kubernetes-specific capabilities?
        │
       Yes
        ↓
       AKS

       No
        ↓
Do I want a managed container platform?
        │
       Yes
        ↓
 Container Apps

For event-driven execution:
        ↓
     Functions
```

This is deliberately simplified. Real architectures can cross these categories, and the final choice depends on networking, compliance, runtime, scaling, integration, operational model, and cost.

The Senior/Lead question is:

> **What requirement eliminates the simpler option?**

For example:

```text
"Why AKS instead of Container Apps?"

Because the workload requires Kubernetes-native scheduling,
custom controllers, advanced Kubernetes networking,
or other capabilities that the simpler platform does not provide.
```

That is stronger than:

```text
"AKS is more powerful."
```

Practice: For each compute option, write one requirement that would justify selecting it.

---

## Part 11 — Spring Boot Deployment Comparison

Take the same Spring Boot application and imagine deploying it using four models.

### VM

```text
Spring Boot
    ↓
systemd
    ↓
Linux VM
```

You manage the OS, runtime, deployment process, scaling architecture, and much of the operational stack.

### App Service

```text
Spring Boot
    ↓
App Service
```

Azure manages more of the platform and you focus primarily on application configuration and deployment.

### Container Apps

```text
Spring Boot
    ↓
Docker Image
    ↓
Container Apps
```

You package the application as a container while Azure manages much of the underlying platform.

### AKS

```text
Spring Boot
    ↓
Docker Image
    ↓
AKS
    ↓
Deployment
    ↓
Pod
```

You gain Kubernetes capabilities but also take on Kubernetes workload and platform responsibilities.

The application code can remain essentially the same while the operational model changes significantly.

Practice: For each architecture, answer:

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

---

## Part 12 — Networking Across Azure Compute Services

Compute choice changes how networking is designed.

For a VM:

```text
VNet
 ↓
Subnet
 ↓
NIC
 ↓
VM
```

For VMSS, multiple instances share the scale-set architecture and networking configuration.

For App Service, networking is abstracted more heavily and can be integrated with VNets through supported features such as VNet integration. This does not mean the App Service app simply becomes a VM inside your subnet.

For Container Apps, the environment provides the networking boundary for containerized workloads, with supported ingress and VNet integration options depending on the environment architecture.

For AKS:

```text
VNet
 ↓
AKS networking
 ↓
Nodes / Pods / Services
```

This is why the same question must be asked for every compute service:

```text
How does inbound traffic reach it?
How does outbound traffic leave it?
What is its private connectivity model?
How does DNS work?
Where are security rules applied?
```

Practice: Draw the path:

```text
Internet → Spring Boot API → PostgreSQL
```

for App Service, Container Apps, and AKS. Identify what changes in each architecture.

---

## Part 13 — Identity Across Compute Services

Compute services should use workload identities rather than embedding long-lived credentials in application configuration whenever the platform supports appropriate identity mechanisms.

The desired model is:

```text
Application workload
      ↓
Managed / Workload Identity
      ↓
Azure RBAC
      ↓
Azure Resource
```

Examples:

```text
App Service → Managed Identity → Key Vault
Container Apps → Managed Identity → Key Vault
AKS Pod → Workload Identity → Key Vault
VM → Managed Identity → Storage
```

The implementation differs by service, but the security principle is the same.

Do not do this:

```text
DB_PASSWORD=permanent-secret
```

inside application code or images.

Prefer:

```text
Application
   ↓
Identity
   ↓
Secret store / Azure resource
```

Practice: Design identity access for the same Spring Boot application on App Service, Container Apps, and AKS. Explain what changes and what remains conceptually identical.

---

## Part 14 — Scaling: Horizontal vs Vertical

Azure compute services support different scaling mechanisms, but the underlying concepts remain the same.

**Vertical scaling** means increasing the capacity of an instance:

```text
2 CPU / 8 GB
      ↓
4 CPU / 16 GB
```

**Horizontal scaling** means increasing the number of instances:

```text
1 instance
   ↓
3 instances
```

Horizontal scaling is often useful for stateless web applications because requests can be distributed across instances.

However:

```text
Application scales
      ↓
Database may become bottleneck
```

or:

```text
Application scales
      ↓
External API rate limit reached
```

Therefore scaling must be considered as a system property.

Practice: For ShopSphere, identify whether each component should scale vertically, horizontally, or through a different mechanism:

```text
API
Database
Image processing
Message queue
Frontend
```

---

## Part 15 — Deployment and Rollback Across Compute Models

Deployment strategy depends on the compute service.

VM:

```text
Build
 ↓
Artifact
 ↓
Copy to VM
 ↓
Restart / process replacement
```

VMSS:

```text
Build
 ↓
Image / model update
 ↓
Rolling instance update
```

App Service:

```text
Build
 ↓
Deploy to staging slot
 ↓
Validate
 ↓
Swap
```

Container Apps:

```text
Build image
 ↓
Deploy revision
 ↓
Validate / control traffic
```

AKS:

```text
Build image
 ↓
Update Deployment
 ↓
Rolling update
 ↓
Readiness checks
 ↓
Observe
```

The platform changes, but the delivery principle remains:

```text
Build once
 ↓
Deploy controlled version
 ↓
Verify health
 ↓
Observe
 ↓
Continue / rollback / fix forward
```

Practice: Explain how you would rollback the same bad Spring Boot release on VM, App Service, Container Apps, and AKS.

---

## Part 16 — Cost and Operational Responsibility

Compute price alone does not tell you the total operational cost.

Consider:

```text
Infrastructure cost
+
Management effort
+
Monitoring
+
Networking
+
Storage
+
Operational complexity
+
Engineering time
```

A VM may look simple but require substantial operational work.

AKS may provide powerful capabilities but introduce:

```text
Cluster management
Networking complexity
Node pools
Upgrades
Kubernetes troubleshooting
Security policy
Observability
```

App Service or Container Apps may reduce operational burden but provide a different control surface.

The right question is not:

```text
Which service is cheapest?
```

It is:

```text
Which architecture satisfies the requirements
with an acceptable total cost and operational burden?
```

Practice: For a small internal Spring Boot API, compare VM, App Service, Container Apps, and AKS in terms of:

```text
Infrastructure
Operations
Scaling
Security
Complexity
```

Do not produce a “winner.” Explain the trade-offs.

---

## Part 17 — Senior/Lead Scenario: Choosing Compute

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

Practice: Write your decisions and then identify one alternative for each application.

---

## Part 18 — Failure Drill: Compute Is Healthy, Application Is Not

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

The same principle applies to Container Apps and AKS.

For Kubernetes:

```bash
kubectl get pods
kubectl get pods -o wide
kubectl logs <pod>
kubectl describe pod <pod>
```

For App Service, inspect application and platform logs using the Azure monitoring/logging facilities configured for the app.

For Container Apps, inspect revision and application logs.

The lesson is:

**Infrastructure health ≠ application health.**

---

## Part 19 — Failure Drill: Scaling Does Not Solve the Problem

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

The correct reasoning is:

```text
Traffic ↑
 ↓
Application scaled
 ↓
Database pressure ↑
 ↓
Database latency ↑
 ↓
Application latency ↑
```

Possible solutions could involve database capacity, connection-pool tuning, caching, query optimization, workload shaping, asynchronous processing, or other architectural changes.

The correct solution depends on evidence.

Practice: Draw the bottleneck chain and explain why “just add more application instances” was insufficient.

---

## Part 20 — Practice Lab: Compare Azure Compute Models

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

---

## Part 21 — Azure ↔ AWS Compute Mapping

Map concepts rather than forcing exact service equivalence.

| Concept | Azure | AWS |
|---|---|---|
| Virtual machine | Azure VM | EC2 |
| VM fleet | VM Scale Sets | Auto Scaling Groups |
| Managed web app platform | App Service | Elastic Beanstalk / other managed application platforms depending on workload |
| Managed containers | Container Apps | ECS / Fargate |
| Managed Kubernetes | AKS | EKS |
| Serverless functions | Azure Functions | Lambda |
| Container registry | ACR | ECR |

The mapping is approximate because the services differ in architecture and capabilities.

For example:

```text
Azure Container Apps
```

and:

```text
AWS ECS/Fargate
```

both support managed container workloads, but they do not expose exactly the same operational model.

Similarly:

```text
App Service
```

does not have a single perfect AWS equivalent for every feature.

**Remember:** Use the mapping to transfer knowledge, not to pretend the platforms are identical.

---

## Part 22 — Final Senior/Lead Recall

What is the main difference between VM and PaaS?

A VM gives you substantial OS and infrastructure-level control; PaaS abstracts more of the platform so you manage less infrastructure directly.

When should you consider VM/VMSS?

When OS-level control, legacy compatibility, custom agents, or specialized infrastructure requirements justify the additional operational responsibility.

When should you consider App Service?

For supported web applications and APIs where you want managed hosting without operating Kubernetes or the guest OS directly.

When should you consider Container Apps?

When you want containerized workloads with a managed application platform and do not need direct Kubernetes capabilities.

When should you consider AKS?

When Kubernetes-native capabilities are actually required by the workload or platform architecture.

When should you consider Functions?

For event-driven or function-oriented workloads where the serverless execution model fits the application.

What is the key question when choosing compute?

**What requirement justifies the operational complexity of this compute model?**

What is horizontal scaling?

Adding more workload instances.

What is vertical scaling?

Increasing the capacity of an existing instance.

Does scaling the application guarantee better performance?

No. Another dependency can become the bottleneck.

What is a golden image and why rebuild instead of patching live VMs?

A pre-built, tested, hardened VM template that every new instance boots from. Building a new image version and rolling instances onto it keeps every server identical; patching live servers by hand lets their configurations drift apart.

Does containerization automatically require AKS?

No.

Does App Service only support source-code deployment?

No. Supported App Service scenarios can also run containerized web applications.

What is the Senior/Lead compute mindset?

**Choose the simplest compute abstraction that satisfies the workload's requirements, while explicitly understanding the operational, networking, security, reliability, and cost trade-offs.**

**Final mental model:**

> **Azure compute is a choice about workload execution and operational responsibility: the more control you require, the more infrastructure responsibility you generally take on.**

---

## Part 23 — Cleanup

Remove lab resources created specifically for this lesson.

For a dedicated resource group:

```bash
az group delete \
  --name rg-azure-compute-lab \
  --yes \
  --no-wait
```

Before deleting it, verify that it contains only lab resources.

Check for remaining resources:

```bash
az resource list \
  --output table
```

Also review:

```text
VMs
VM Scale Sets
Public IPs
Disks
Network interfaces
Load balancers
App Service plans
App Services
Container Apps
Container App environments
AKS clusters
Container registry images
Log/monitoring resources
```

Remember that deleting an application does not necessarily remove every related resource. Check the resource-group contents and billing impact.

Do not delete shared or production resources.

---

## Next

**Day 24 — Azure Overlay 03: Azure Advanced Networking**

The next lesson will map the networking concepts from Days 3, 12, and 15 into deeper Azure architecture:

```text
VNet
Subnets
NSGs
UDRs
Azure Firewall
NAT Gateway
Private Endpoint
Private DNS
VNet Peering
Hub-Spoke
VPN Gateway
ExpressRoute
Application Gateway
Azure Load Balancer
```

The focus will be **traffic flow, private connectivity, routing, security boundaries, hybrid networking, and Senior/Lead troubleshooting** rather than memorizing Azure networking services.

## Answers to practice

### 1. Run the same Spring Boot app on VM, App Service, Container Apps, and AKS

<details>
<summary>Answer</summary>

On a VM, install Java, run the JAR under `systemd`, and own OS patching. On App Service, deploy the JAR or a container to a plan Azure patches. On Container Apps, push the image and run a revision with platform scaling. On AKS, run a Deployment, Service, and probes on node pools you still operate.

The code can stay the same. Operational responsibility changes. Pick from workload need, not from which name sounds modern.

</details>

### 2. Deploy Spring Boot on a Linux VM as systemd and compare with Kubernetes

<details>
<summary>Answer</summary>

Install the JRE, copy the JAR, and run a `systemd` unit that starts the process on boot. You patch the OS, watch disk, rotate certificates, and replace the VM when it dies. One VM restart is not high availability.

On Kubernetes from Day 14, a Deployment replaces Pods, a Service keeps a stable endpoint, and probes gate traffic. The VM model is simpler until you need replicas, rolling updates, and self-heal. Then the operational load on the guest OS becomes the cost.

</details>

### 3. 10× traffic on VMSS and the next bottleneck

<details>
<summary>Answer</summary>

VMSS can add instances from the golden image and put them behind a load balancer. Health checks must pass before instances take traffic. State must live in the database or durable storage, not on the VM disk.

The next bottleneck is often PostgreSQL connections, disk I/O, or an external API rate limit. Adding VMs increases concurrency against that dependency. Scale the bottleneck you measure, not CPU by habit.

</details>

### 4. What the team manages: Linux VM vs App Service

<details>
<summary>Answer</summary>

On the VM you manage OS patches, Java, `systemd`, disks, NSGs, certificates, backups of the guest, and the deploy script. Azure manages the host hardware.

On App Service you manage the app, settings, slots, scale rules, and identity. Azure manages the OS, much of the runtime host, and platform patching. App Service can also run a container. You still do not get a VM you SSH into.

</details>

### 5. Staging slot for a Spring Boot API before swap

<details>
<summary>Answer</summary>

Deploy the new version to the staging slot. Warm it, hit `/health`, run smoke tests, and check logs and dependency calls. Keep slot-specific settings (connection strings, hostname bindings) marked so they do not move on swap.

Swap only after staging looks healthy. Then watch production error rate and latency. Slot swap is a controlled cutover, similar in intent to blue-green, with App Service mechanics.

</details>

### 6. Operate the Spring Boot container on ACA vs AKS

<details>
<summary>Answer</summary>

On Azure Container Apps you operate the image, revisions, ingress, scale rules, and identity. Azure hides nodes, kubelets, and the Kubernetes API.

On AKS you still operate node pools, Deployments, Services, Ingress, RBAC, upgrades, and cluster networking. Use AKS when you need those Kubernetes surfaces. “We have a container” is not that requirement.

</details>

### 7. Business-hours backend: 24/7 replica vs scale-to-zero

<details>
<summary>Answer</summary>

A 24/7 minimum replica costs more at idle and avoids cold start. Scale-to-zero saves idle compute and adds first-request latency while the container starts.

For a user-facing API with a latency SLO, keep a minimum replica during business hours. For a batch or internal job, scale toward zero overnight. Configure the rule from availability need, not from a default of zero.

</details>

### 8. When ShopSphere should use AKS instead of Container Apps

<details>
<summary>Answer</summary>

Use AKS when ShopSphere needs Kubernetes-native scheduling, custom controllers, Helm plus GitOps, service mesh, or a multi-workload cluster platform. Those needs justify node pools, upgrades, and cluster troubleshooting.

A few Spring Boot APIs with HTTP ingress do not. Container Apps already runs the image with revisions and scale. Complexity must match a real requirement.

</details>

### 9. Three event-driven ShopSphere tasks: sync vs async

<details>
<summary>Answer</summary>

Order-created processing: asynchronous. Accept the order, publish an event, and let a Function or worker reserve stock and call payment. Email notification: asynchronous. A queue trigger sends mail after the order exists. Image processing: asynchronous. A blob event resizes the upload.

Keep the HTTP API synchronous only for the user-facing create/read path. Long work belongs on a trigger so the request thread does not wait on email or image CPU.

</details>

### 10. One justifying requirement per compute option

<details>
<summary>Answer</summary>

VM/VMSS: OS-level agents or a runtime Azure PaaS does not host. App Service: a conventional HTTP API with managed hosting and slots. Container Apps: a container without a Kubernetes API requirement. AKS: custom controllers or Kubernetes-native policy. Functions: an event or timer, not a long-lived Spring Boot process.

Ask what requirement removes the simpler option. “More powerful” is not a requirement.

</details>

### 11. Who patches, scales, networks, deploys, and owns failure on each architecture

<details>
<summary>Answer</summary>

VM: you patch OS and Java, you scale (or VMSS), you own NIC/NSG, you copy artifacts, you own the outage. App Service: Azure patches the platform; you scale the plan, bind VNet integration, deploy slots, and own app failures. Container Apps: Azure runs the platform; you scale revisions, configure ingress, and own app health. AKS: Azure manages the control plane; you patch node images, HPA and node pools, CNI/NSG, Deployments, cert-manager or Ingress TLS, and still own application failure.

The JAR can be identical. The RACI is not.

</details>

### 12. Internet → Spring Boot API → PostgreSQL on App Service, ACA, and AKS

<details>
<summary>Answer</summary>

App Service: Internet → App Service front end / TLS → app → VNet integration → Private Endpoint → PostgreSQL. The app is not a NIC in your subnet by default.

Container Apps: Internet → environment ingress → revision → VNet integration → Private Endpoint → PostgreSQL. AKS: Internet → Application Gateway or load balancer → Service → Pod → VNet routing → NSG → Private Endpoint → PostgreSQL.

What changes is where the frontend lives, how outbound leaves, and which security rules apply. The database stays private in all three.

</details>

### 13. Identity for the same app on App Service, Container Apps, and AKS

<details>
<summary>Answer</summary>

Give each platform a managed or workload identity. Assign Key Vault secret get (and database identity if used) to that identity. Do not put `DB_PASSWORD` in the image.

App Service and Container Apps attach a managed identity on the app. AKS uses workload identity on the Pod. The principle stays: workload → identity → Azure RBAC → resource. Only the attachment mechanism changes.

</details>

### 14. How ShopSphere API, database, images, queue, and frontend should scale

<details>
<summary>Answer</summary>

API: horizontal replicas behind a load balancer. Database: vertical SKU first, then read replicas or sharding only with evidence. Image processing: horizontal workers or Functions on a queue. Message queue: scale consumers; the queue itself is a managed service. Frontend: horizontal static hosting or CDN, not a bigger VM.

Do not scale the API to fix a saturated database. Scaling is a system property.

</details>

### 15. Rollback the same bad Spring Boot release on VM, App Service, ACA, and AKS

<details>
<summary>Answer</summary>

VM: restore the previous JAR and restart `systemd`, or roll VMSS to the previous gallery image version. App Service: swap back to the previous slot or redeploy the last good package. Container Apps: shift traffic to the previous revision. AKS: `kubectl rollout undo` or Helm rollback to the previous Deployment revision.

Rollback still needs a compatible database schema. The platform changes. Build once, verify health, then continue or roll back.

</details>

### 16. Small internal API: trade-offs across VM, App Service, Container Apps, AKS

<details>
<summary>Answer</summary>

VM: cheap-looking SKU, high OS operations, manual scale, NSG hardening, simple mental model. App Service: plan cost, low OS work, easy scale and slots, less OS control. Container Apps: image-centric scale including toward zero, less cluster work, less Kubernetes power. AKS: highest platform power and the highest cluster, network, and upgrade burden.

For a small internal API, App Service or Container Apps usually fit. AKS is justified only by Kubernetes requirements. There is no universal winner.

</details>

### 17. Map Applications A–D and name one alternative each

<details>
<summary>Answer</summary>

A (legacy Java, OS agents, custom filesystem): VM or VMSS. Alternative: a dedicated VMSS baseline image if you later need replicas. B (standard Spring Boot REST): App Service. Alternative: Container Apps if the artifact is already an image. C (microservices, operators, complex scheduling): AKS. Alternative: Container Apps only if operators are dropped. D (image processing on upload): Functions on a blob trigger. Alternative: a Container Apps job if the runtime exceeds Function limits.

Reason from requirement → runtime → operations → platform. Not from “Kubernetes is modern.”

</details>

### 18. Bottleneck chain: scaling 3 → 12 made latency worse

<details>
<summary>Answer</summary>

Traffic rose. You scaled the API from 3 to 12. Each replica opened more database connections. The database hit its connection and CPU limit. Query latency rose, so API latency rose even while API CPU stayed moderate.

Adding instances increased pressure on the bottleneck. Fix database capacity, pool size, queries, cache, or async work. Do not add more APIs until evidence says the API is the constraint.

</details>

### 19. Main difference between VM and PaaS

<details>
<summary>Answer</summary>

A VM gives substantial OS and infrastructure control. PaaS abstracts more of the platform so you manage less infrastructure directly.

You still own the application, identity, and much of networking integration.

</details>

### 20. When to consider VM/VMSS

<details>
<summary>Answer</summary>

When OS-level control, legacy compatibility, custom agents, or a specialized runtime justifies the extra operational work.

Bake a golden image and roll VMSS. Do not patch live VMs by hand.

</details>

### 21. When to consider App Service

<details>
<summary>Answer</summary>

For supported web apps and APIs where you want managed hosting without operating Kubernetes or the guest OS.

It can deploy source or a container. Slots support a staged production cutover.

</details>

### 22. When to consider Container Apps

<details>
<summary>Answer</summary>

When you want containerized workloads on a managed application platform and you do not need the Kubernetes API.

Revisions, ingress, and scale rules are the control surface.

</details>

### 23. When to consider AKS

<details>
<summary>Answer</summary>

When Kubernetes-native capabilities are actually required: custom controllers, complex scheduling, GitOps at cluster scale, or a multi-workload platform.

Azure manages the control plane. You still own node pools and workloads.

</details>

### 24. When to consider Functions

<details>
<summary>Answer</summary>

For event-driven or function-oriented work where the serverless execution model fits. Triggers include HTTP, queue, timer, Event Hub, and blob.

A Function is not a small Spring Boot server. Timeouts, state, and scale differ.

</details>

### 25. Key question when choosing compute

<details>
<summary>Answer</summary>

What requirement justifies the operational complexity of this compute model?

Choose the simplest abstraction that meets the workload.

</details>

### 26. What is horizontal scaling?

<details>
<summary>Answer</summary>

Adding more workload instances and distributing traffic across them.

It fits stateless APIs. It can overload a shared database.

</details>

### 27. What is vertical scaling?

<details>
<summary>Answer</summary>

Increasing the capacity of an existing instance, for example 2 CPU / 8 GB to 4 CPU / 16 GB.

It is common for databases before you shard.

</details>

### 28. Does scaling the application guarantee better performance?

<details>
<summary>Answer</summary>

No. Another dependency can become the bottleneck.

Measure the chain: API, connection pool, database, and external APIs.

</details>

### 29. Golden image and why rebuild instead of patching live VMs

<details>
<summary>Answer</summary>

A golden image is a pre-built, tested, hardened VM template. Every new instance boots from it. Publish versions to Azure Compute Gallery and roll VMSS onto the new version.

Patching live servers by hand lets configuration drift. Rebuild the image, then replace instances.

</details>

### 30. Does containerization automatically require AKS?

<details>
<summary>Answer</summary>

No. App Service and Container Apps can run containers without a Kubernetes cluster.

Need Kubernetes capabilities before you accept cluster operations.

</details>

### 31. Does App Service only support source-code deployment?

<details>
<summary>Answer</summary>

No. Supported App Service scenarios can run containerized web applications.

The artifact can be a JAR or an image. The platform is still App Service, not a VM.

</details>

### 32. Senior/Lead compute mindset

<details>
<summary>Answer</summary>

Choose the simplest compute abstraction that satisfies the workload. State the operational, networking, security, reliability, and cost trade-offs.

Azure compute is a choice about execution model and operational responsibility. More control usually means more infrastructure work.

</details>

### 33. Map Applications A–D with requirement-driven justification

<details>
<summary>Answer</summary>

A needs OS agents and custom files: VM/VMSS. B is a standard HTTP API: App Service, or Container Apps if already containerized. C needs operators and complex scheduling: AKS. D is file-triggered image work: Functions.

Write requirement → runtime → operations → platform → choice. Name one alternative per app so the decision is reversible when requirements change.

</details>

### 34. App Service running, CPU normal, users get HTTP 500

<details>
<summary>Answer</summary>

Do not stop at platform metrics. Read application logs, error rate, dependency calls, database connectivity, configuration, and the last deployment.

Infrastructure health is not application health. The same rule applies to Container Apps and AKS. On AKS use `kubectl logs` and `kubectl describe pod`. On App Service use the app’s configured logs and metrics.

</details>

### 35. API scaled 3 → 12, DB connections near limit, latency worse

<details>
<summary>Answer</summary>

The API was not the bottleneck. Extra replicas multiplied database sessions. Database latency then dominated API latency.

Draw traffic → more APIs → more connections → database saturation → worse user latency. Scale or tune the database, pools, queries, or cache. Do not keep adding APIs.

</details>

### 36. Compare at least two compute models for one Spring Boot app

<details>
<summary>Answer</summary>

Run the same API on two of VM, App Service, Container Apps, or AKS. For each, record deployment, networking, identity, secrets, scaling, health checks, logs, monitoring, rollback, cost, and operational ownership.

Write a short note: requirement, option, why, alternative, trade-off. Example: App Service for a standard API with less OS work; Container Apps as the container-centric alternative. You do not need every service. You need to feel how the abstraction changes operations.

</details>
