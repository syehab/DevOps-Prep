# Day 23 — Azure Overlay 02: Azure Compute & PaaS

This Day uses three files. Read them in this order.

1. [01-concepts.md](01-concepts.md) — lesson content (this file)
2. [02-questions-and-answers.md](02-questions-and-answers.md) — practice items, each with a model answer
3. [03-implementation.md](03-implementation.md) — hands-on lab

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

Observability follows the same split. Azure Container Apps already records environment logs, revision metrics, and platform diagnostics. Your application still emits traces, metrics, and logs, usually through OpenTelemetry, into Azure Monitor or a second backend such as Datadog. You do not scrape kube-state metrics here, because you do not operate the Kubernetes API.

On AKS you own the Collector, the dashboards, and kube-state. On Container Apps you own the app signals and you read the platform signals Azure already stores. Day 20 is the observability lesson. This Day only names where those signals live for Container Apps.

> **Remember:** Same three signals as AKS. The platform holds environment telemetry. Your app still emits OpenTelemetry.

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

For Container Apps, inspect revision logs, application logs, and platform diagnostics. Follow the same OpenTelemetry trace your app emits. Do not start with `kubectl`.

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
