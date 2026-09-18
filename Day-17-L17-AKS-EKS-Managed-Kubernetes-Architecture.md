# Day 17 — AKS + EKS: Managed Kubernetes Architecture

**Goal:** Understand what changes when Kubernetes moves from a self-managed cluster to a managed cloud service, and learn the Azure/AWS architecture and operational decisions behind AKS and EKS.

**Core idea:** AKS and EKS do not replace Kubernetes; they provide managed Kubernetes control-plane capabilities and integrate Kubernetes with their respective cloud platforms. The important Senior/Lead skill is knowing **what Kubernetes owns, what the cloud provider owns, what your team owns, and where networking, identity, security, scaling and cost decisions sit**.

## Part 1 — Why Managed Kubernetes Exists

1. Running Kubernetes yourself means operating a large distributed platform in addition to operating your applications. You have to think about the API server, etcd, scheduler, controllers, certificates, upgrades, networking, node lifecycle and high availability. Managed Kubernetes reduces some of this operational burden by having the cloud provider manage important parts of the control plane. Your team still owns the workloads and many aspects of the worker/data plane, networking, identity, security and application operations.

2. This is the basic distinction:

```text
Self-managed Kubernetes

You
 ├── Control Plane
 ├── Worker Nodes
 ├── Networking
 ├── Upgrades
 ├── Security
 └── Applications
```

versus:

```text
Managed Kubernetes

Cloud Provider
 └── Managed Control Plane

You
 ├── Worker / Compute Layer
 ├── Workloads
 ├── Application Configuration
 ├── Access & Security
 ├── Networking Design
 └── Operations
```

The exact ownership boundary differs between AKS and EKS and changes depending on which managed features you choose. Therefore, never answer “the cloud provider manages Kubernetes” as though everything is managed.

3. AKS is Azure's managed Kubernetes service, while EKS is AWS's managed Kubernetes service. Both provide Kubernetes control-plane capabilities and integrate with native cloud services, but the surrounding architecture is different. AKS naturally integrates with Azure VNets, Entra ID, Azure Load Balancer, Azure Monitor and Azure Container Registry. EKS integrates with AWS VPCs, IAM, AWS load-balancing components, CloudWatch and Amazon ECR.

4. The real value of managed Kubernetes is not simply “less work.” It is the ability to consume Kubernetes as a managed platform while using cloud-native identity, networking, security, scaling and observability services. A Senior engineer should therefore evaluate a managed Kubernetes design as a **platform architecture**, not merely as “a place where containers run.”

**Practice:** Compare a self-managed cluster with AKS/EKS and list which responsibilities you would no longer have to operate yourself and which responsibilities would remain yours.

---

## Part 2 — AKS Architecture

1. An AKS cluster contains a managed Kubernetes control plane and a worker/compute layer where your workloads run. Azure operates the managed control-plane components, while your node pools provide the compute capacity for Pods. The control plane includes the Kubernetes API server and other Kubernetes control-plane functionality, while your workloads ultimately execute on nodes represented to Kubernetes as worker capacity.

2. A simplified AKS architecture is:

```text
                    Azure
                      │
          ┌───────────┴───────────┐
          │   Managed AKS Control │
          │        Plane          │
          │                       │
          │ API Server            │
          │ Scheduler             │
          │ Controllers           │
          │ etcd / cluster state  │
          └───────────┬───────────┘
                      │
                Kubernetes API
                      │
          ┌───────────┴───────────┐
          │      Node Pools       │
          │                       │
          │ Node   Node   Node    │
          │  ↓      ↓      ↓      │
          │ Pods   Pods   Pods    │
          └───────────────────────┘
```

The diagram is intentionally simplified. The important point is the ownership boundary: Azure manages the AKS control plane, while your configuration determines the worker capacity and workloads.

3. Node pools allow different workloads to use different types of compute. For example, you might have a general-purpose pool for normal applications and another pool with different VM characteristics for memory-intensive workloads. Kubernetes scheduling decisions then determine where Pods can run based on available resources, taints, tolerations, affinity and other constraints.

4. AKS also integrates with Azure networking. Depending on the networking model, Pods and nodes interact with Azure virtual networking in different ways. This means your Day 12 networking knowledge remains important: VNet, subnets, routing, NSGs, private connectivity, DNS and load balancing still matter. Kubernetes does not make the underlying Azure network disappear.

5. AKS can integrate with Azure identity through Microsoft Entra ID and Kubernetes RBAC. This allows organizations to avoid treating every cluster user as an independent static credential. A mature architecture separates **who can access the Azure resource**, **who can access the Kubernetes API**, and **what Kubernetes resources that identity can operate**.

**Practice:** Draw an AKS architecture containing:

```text
Azure Subscription
   ↓
VNet
   ↓
AKS
   ├── Managed Control Plane
   └── Node Pools
          ↓
         Pods
          ↓
       Services
          ↓
      Application
```

Then mark which components are primarily managed by Azure and which are controlled by your team.

---

## Part 3 — EKS Architecture

1. EKS follows the same fundamental Kubernetes model but maps it into AWS infrastructure concepts. AWS manages the EKS control plane, while worker capacity can be provided through managed node groups, self-managed nodes or serverless-style compute options such as Fargate, depending on the architecture. Workloads are connected to the surrounding AWS VPC and its networking controls.

2. A simplified EKS architecture is:

```text
                     AWS
                      │
          ┌───────────┴───────────┐
          │    Managed EKS        │
          │    Control Plane      │
          │                       │
          │ API Server            │
          │ Scheduler             │
          │ Controllers           │
          │ Cluster State         │
          └───────────┬───────────┘
                      │
                Kubernetes API
                      │
          ┌───────────┴───────────┐
          │     Compute Layer     │
          │                       │
          │ Managed Node Groups   │
          │ EC2 / Fargate etc.    │
          │          ↓            │
          │         Pods          │
          └───────────────────────┘
```

The exact compute architecture can vary significantly. This is why “EKS runs on EC2” is incomplete: EKS can use several compute models, each with different operational and cost characteristics.

3. EKS networking is strongly connected to the AWS VPC. Nodes and Pods can use AWS networking capabilities depending on the selected CNI and configuration. Security groups, subnets, routing tables, NAT gateways, load balancers and VPC endpoints can therefore become part of a Kubernetes application's connectivity path.

4. EKS identity also introduces an important cloud/Kubernetes boundary. AWS IAM controls access to AWS resources and can participate in authentication to the Kubernetes cluster, while Kubernetes RBAC controls authorization within Kubernetes. These are related but different systems. A user being an AWS administrator does not mean you should treat that person as unrestricted Kubernetes workload administrator in a well-designed platform.

5. EKS can integrate with Amazon ECR for container images and AWS load-balancing services for external traffic. This means a typical application architecture might look like:

```text
Developer
   ↓
CI
   ↓
ECR
   ↓
EKS
   ↓
Service / Load Balancer
   ↓
Pods
```

The same underlying application architecture can be built on AKS with ACR and Azure networking/load balancing.

**Practice:** Draw the equivalent EKS architecture and replace each Azure-specific component from the previous exercise with its AWS counterpart.

---

## Part 4 — Node Pools, Managed Node Groups and Workload Placement

1. A Kubernetes cluster needs compute capacity to run Pods. In AKS this is commonly organized through node pools; in EKS, managed node groups are one common approach for EC2 worker capacity. The important design question is not “How many nodes do I need?” but **“What workload characteristics require which type of compute?”** Different applications may have different CPU, memory, architecture, scaling and availability requirements.

2. Consider:

```text
Application A
CPU-heavy

Application B
Memory-heavy

Application C
GPU workload
```

Putting everything into one generic node pool may be simple, but it can produce poor utilization, scheduling constraints or unnecessary cost. A more deliberate design can use different node pools/groups and Kubernetes scheduling rules to place workloads appropriately.

3. Kubernetes resource requests are particularly important:

```yaml
resources:
  requests:
    cpu: "500m"
    memory: "1Gi"
  limits:
    cpu: "2"
    memory: "2Gi"
```

The scheduler primarily uses resource requests when determining whether a Pod can fit on a node. If requests are missing or unrealistically low, Kubernetes can make poor scheduling decisions. If requests are too high, Pods may remain Pending even though the cluster appears to have substantial unused capacity.

4. Taints and tolerations can create dedicated workload pools. For example, a node pool may be reserved for specialized workloads, while a toleration allows only selected Pods to use it. Labels and node affinity can further influence placement. These mechanisms become important when building production clusters where different teams or workloads have different infrastructure requirements.

5. Scaling adds another layer. Horizontal Pod Autoscaling can increase the number of Pods, but if the cluster has no available node capacity, the new Pods may remain Pending. Cluster/node autoscaling can add compute capacity. Therefore:

```text
More traffic
   ↓
More Pods required
   ↓
Insufficient node capacity?
   ↓
More nodes required
```

This is why application scaling and infrastructure scaling are related but distinct problems.

**Practice:** Create three hypothetical workloads and decide:

```text
Workload
↓
CPU / Memory requirement
↓
Node pool
↓
Requests
↓
Scaling behavior
```

Then explain why you would not necessarily put every workload into the same node pool.

---

## Part 5 — Kubernetes Networking Inside AKS/EKS

1. Managed Kubernetes networking is where your cloud networking and Kubernetes networking knowledge meet. A Pod needs network connectivity, a Service needs stable internal access, and external traffic may require a cloud load balancer or ingress controller. At the same time, the cluster exists inside or alongside a VNet/VPC, so routing, DNS, security controls and private connectivity still matter.

2. Think of the architecture as layered:

```text
Azure VNet / AWS VPC
        ↓
Subnet / Network
        ↓
Nodes
        ↓
CNI
        ↓
Pods
        ↓
Services
        ↓
Ingress / Load Balancer
        ↓
Users
```

A failure at any layer can look like “the application is down.” This is why Day 15's troubleshooting sequence is essential when working with AKS or EKS.

3. Consider a Pod connecting to a managed database:

```text
Application Pod
      ↓
Pod networking
      ↓
Node / cloud network
      ↓
Route
      ↓
Security controls
      ↓
Private endpoint / database network
      ↓
Database
```

On Azure, this may involve VNet routing, NSGs, private endpoints and Azure DNS. On AWS, the equivalent may involve VPC routing, security groups/NACLs, VPC endpoints or private connectivity patterns. Kubernetes configuration alone cannot fix a missing cloud route or a blocked cloud security rule.

4. External traffic follows another path:

```text
User
 ↓
DNS
 ↓
Cloud Load Balancer
 ↓
Ingress / Service
 ↓
Pod
```

The cloud provider may provision the external load balancer based on Kubernetes resources and controllers. Therefore, a Kubernetes object can be correct while the surrounding cloud integration is misconfigured or unavailable.

5. Private clusters add another important architecture decision. A private AKS/EKS control-plane configuration can restrict how the Kubernetes API is reached, reducing public exposure but increasing networking and operational requirements. Engineers must then consider how administrators, CI/CD agents and other management systems securely reach the cluster API.

**Practice:** Take the Day 15 external request path and map every step to either Kubernetes or Azure/AWS. Then repeat for a Pod connecting to a private database.

---

## Part 6 — Identity and Access: Cloud IAM vs Kubernetes RBAC

1. Managed Kubernetes creates two related but distinct authorization worlds. The cloud provider controls access to the cloud account/subscription and its resources, while Kubernetes RBAC controls what identities can do to Kubernetes objects. This distinction is critical because an identity might be allowed to access the cluster API but still have limited permissions inside Kubernetes. Conversely, a Kubernetes administrator does not automatically receive permission to manage unrelated cloud resources.

2. In Azure, a common identity architecture involves Microsoft Entra ID for user identity and Azure RBAC for Azure resources, combined with Kubernetes RBAC for cluster resources. The conceptual path is:

```text
User
 ↓
Microsoft Entra ID
 ↓
AKS authentication
 ↓
Kubernetes authorization / RBAC
 ↓
Namespace / Resource permissions
```

In AWS:

```text
User / Role
 ↓
AWS IAM
 ↓
EKS authentication integration
 ↓
Kubernetes authorization / RBAC
 ↓
Namespace / Resource permissions
```

The exact integration mechanism depends on the platform configuration, but the separation of authentication and authorization remains the key concept.

3. Workload identity is different from human access. A Spring Boot Pod may need to access Azure Key Vault or an AWS service without storing a long-lived cloud access key inside the container. Managed workload identity mechanisms allow the workload to obtain cloud credentials through an identity associated with the workload. This is much safer than putting static cloud credentials in a Kubernetes Secret merely to allow an application to call a cloud API.

4. This creates three questions you should ask in every managed Kubernetes design:

```text
Who is the human?
What can the human do?

What is the workload identity?
What cloud resources can the workload access?

What can the workload do inside Kubernetes?
```

Keeping these questions separate prevents many identity design mistakes.

5. Least privilege should exist at both layers. A CI/CD identity might need permission to update Kubernetes Deployments but should not automatically receive broad subscription/account administrator permissions. Similarly, an application identity might need access to one Key Vault secret or one AWS service capability rather than unrestricted cloud access.

**Practice:** Design an identity model for a Spring Boot application running on AKS and then map it to EKS. Identify the human deployment identity, GitOps identity and application workload identity separately.

---

## Part 7 — Scaling and Availability

1. Managed Kubernetes does not automatically make an application highly available. Kubernetes can restart failed Pods and schedule replicas across available nodes, but the application architecture still determines whether the system can survive failures. For example, three replicas running on one node do not provide the same failure isolation as three replicas spread across multiple failure domains.

2. Think in layers:

```text
Application replicas
        ↓
Pods
        ↓
Nodes
        ↓
Availability Zones / failure domains
        ↓
Region
```

If all replicas are placed on one node and that node fails, the application can temporarily lose every replica. Kubernetes scheduling constraints such as topology spread constraints and affinity can help distribute workloads intentionally.

3. Managed Kubernetes also requires careful thinking about node availability. A cluster with multiple nodes is not automatically resilient if all nodes are in one failure domain or depend on a single infrastructure component. Production architecture should consider the failure boundaries of the cloud platform and place critical workloads appropriately.

4. Scaling also has a cost dimension. More replicas increase compute consumption, while larger nodes may improve packing efficiency but increase blast radius and scaling granularity. Small nodes can provide finer scaling but may introduce more operational overhead. There is no universally correct node size; the decision depends on workload behavior, availability requirements, scaling patterns and cost.

5. A Senior/Lead engineer should therefore answer availability questions at the architecture level:

```text
How many replicas?
Where are they placed?
What happens when a Pod fails?
What happens when a node fails?
What happens when an availability zone fails?
How quickly can capacity be restored?
What happens during cluster upgrades?
```

**Practice:** Design a production deployment with three replicas and explain how you would prevent all three replicas from being placed on the same failure domain.

---

## Part 8 — Cluster Upgrades and Operations

1. Kubernetes clusters require regular lifecycle management because the Kubernetes version, node operating system, container runtime, networking components and cloud integrations evolve over time. Managed services reduce the control-plane maintenance burden, but they do not remove upgrade planning. Your workloads can still break because APIs change, admission behavior changes, deprecated resources disappear, or application dependencies behave differently.

2. A safe upgrade mindset is:

```text
Check compatibility
      ↓
Test in non-production
      ↓
Review deprecated APIs
      ↓
Upgrade control plane
      ↓
Upgrade node pools
      ↓
Validate workloads
      ↓
Observe
```

The exact order and supported upgrade path depend on the managed service and version combination, so production upgrades should always follow the provider's current support policy.

3. Node upgrades can cause workload disruption because Pods may need to move from old nodes to new ones. Kubernetes mechanisms such as PodDisruptionBudgets can help define how much voluntary disruption is acceptable. Applications should also have multiple replicas and correct readiness probes so that traffic is not sent to Pods before they are ready.

4. Cluster upgrades are therefore closely connected to application design. A Deployment with one replica, no readiness probe and no disruption strategy is operationally very different from a Deployment with multiple replicas, graceful shutdown, readiness checks and appropriate resource requests. Kubernetes can provide the mechanisms, but the workload must be designed to use them correctly.

5. Observability is part of upgrade operations. Before and during an upgrade, monitor node health, Pod restarts, Pending Pods, readiness failures, application errors and request latency. A successful infrastructure upgrade is not enough; the real success criterion is that the workloads continue serving correctly.

**Practice:** Create an upgrade checklist for your hypothetical production AKS/EKS cluster. Include application compatibility, Kubernetes APIs, node capacity, disruption, monitoring and rollback considerations.

---

## Part 9 — AKS vs EKS: Learn the Concept, Then the Cloud Mapping

1. You do not need two separate Kubernetes mental models. The underlying Kubernetes concepts remain the same: Pods, Deployments, Services, Ingress, RBAC, resource requests, scheduling, probes and controllers. What changes is how Azure or AWS provides the surrounding infrastructure and integrations. This is the same learning strategy used throughout the course: **learn the concept once, then map the cloud implementation.**

2. Keep this mapping in your head:

| Kubernetes / Platform Concept | Azure | AWS |
|---|---|---|
| Managed Kubernetes | AKS | EKS |
| Container registry | ACR | ECR |
| Cloud identity | Microsoft Entra ID / Azure RBAC | IAM |
| Virtual network | VNet | VPC |
| Load balancing | Azure Load Balancer / Application Gateway | ELB family |
| Monitoring | Azure Monitor | CloudWatch |
| Secrets / key management | Key Vault | Secrets Manager / KMS |
| Infrastructure as Code | Bicep / Terraform | Terraform / CloudFormation |
| Managed database examples | Azure Database services | RDS / other managed DB services |

The table is a conceptual map, not a claim that each service has identical behavior or features.

3. For interviews, avoid answering with product names alone. If asked, “How would you secure AKS?” do not simply list Azure services. Explain the layers: identity, Kubernetes RBAC, workload identity, network segmentation, NetworkPolicy, secret management, image security, private connectivity, logging and least privilege. Then map those concepts to Azure services. The same answer structure works for EKS.

4. This approach also makes migration easier. If you understand that AKS and EKS both provide managed Kubernetes but use different identity and networking integrations, moving an application between them becomes primarily a platform-integration exercise rather than relearning Kubernetes itself.

**Practice:** Take your Spring Boot application architecture and produce two versions:

```text
Azure:
Spring Boot → AKS → ACR → Azure networking → Key Vault → Azure Monitor

AWS:
Spring Boot → EKS → ECR → VPC networking → AWS secrets/identity → CloudWatch
```

For each component, write what problem it solves rather than only its product name.

---

## Part 10 — Senior/Lead Architecture Exercise

1. Design a production platform for a Spring Boot application with the following requirements:

```text
Multiple environments
Private application networking
High availability
Containerized deployment
CI/CD
Centralized secrets
Autoscaling
Monitoring
Controlled production access
```

Start from the business workload rather than immediately selecting cloud services. Determine the application's traffic path, availability requirements, data dependencies, deployment model, identity requirements and operational ownership. Only then choose the Azure or AWS implementation.

2. Your architecture should conceptually contain:

```text
Developer
   ↓
Git
   ↓
CI
   ↓
Container Registry
   ↓
GitOps / Deployment
   ↓
AKS / EKS
   ├── Ingress
   ├── Service
   └── Pods
          ↓
      Private DB

Identity
   ↓
Human + CI + Workload identities

Observability
   ↓
Logs + Metrics + Alerts

Security
   ↓
RBAC + NetworkPolicy + Cloud network controls + Secrets
```

3. Now introduce failures one at a time:

```text
Node fails
Pod fails
Image cannot be pulled
Service has no endpoints
Ingress is incorrect
Database becomes unreachable
Cluster has insufficient capacity
Identity loses permission
Deployment introduces a bad version
```

For each failure, identify the owner and the evidence you would expect. For example, an image-pull failure is different from a Service endpoint failure, and a database authorization problem is different from a VNet/VPC routing problem.

4. Finally, explain the architecture as if you were answering a Lead DevOps interview question:

> “We need to migrate a Spring Boot application to managed Kubernetes on Azure or AWS. How would you design it?”

Your answer should move through:

```text
Requirements
 ↓
Application architecture
 ↓
Cluster architecture
 ↓
Networking
 ↓
Identity
 ↓
Security
 ↓
Deployment
 ↓
Scaling
 ↓
Observability
 ↓
Failure recovery
 ↓
Cost / governance
```

The goal is not to produce the longest architecture. The goal is to demonstrate that every major design decision has a reason.

**Practice:** Create a one-page AKS architecture and a one-page EKS architecture for the same Spring Boot application. Keep the application design identical and change only the cloud-specific integrations.

---

## Part 11 — 5-Minute Recall

Without looking at the notes, explain these in your own words:

1. What problem does managed Kubernetes solve?

2. What does the cloud provider manage in AKS/EKS, and what remains your responsibility?

3. What is the difference between the Kubernetes control plane and worker/compute layer?

4. Why do AKS and EKS still depend heavily on VNet/VPC networking?

5. What is a node pool or managed node group?

6. Why might an enterprise use multiple node pools?

7. How do resource requests affect Kubernetes scheduling?

8. What is the relationship between Pod autoscaling and node autoscaling?

9. Why is three replicas on one node not equivalent to three replicas spread across failure domains?

10. What is the difference between cloud IAM/Entra identity and Kubernetes RBAC?

11. What is workload identity, and why is it preferable to static cloud credentials inside Pods?

12. How would a Pod in AKS/EKS reach a private database?

13. What additional layers exist when exposing an application to the Internet?

14. Why can a Kubernetes cluster upgrade still cause application downtime?

15. What role do readiness probes and PodDisruptionBudgets play during node maintenance?

16. What is the conceptual difference between AKS and EKS?

17. What are the Azure equivalents of EKS, ECR, VPC, IAM and CloudWatch?

18. What are the AWS equivalents of AKS, ACR, VNet, Microsoft Entra ID/Azure RBAC and Azure Monitor?

19. If a Pod is Pending because there is no capacity, would restarting the Pod solve the problem? Why?

20. If the application works inside the cluster but users cannot access it externally, which layers would you investigate?

**Core mental model:**

> **AKS/EKS = managed Kubernetes control plane + cloud-integrated compute, networking, identity, security and operations.**

**Ownership model to remember:**

> **Cloud provider manages the managed control-plane service; your team still owns the workload architecture and many data-plane, security, networking, identity, scaling and operational decisions.**

**Architecture model to remember:**

```text
Cloud
 ↓
Network
 ↓
Managed Kubernetes
 ↓
Node Pools / Compute
 ↓
Pods
 ↓
Services
 ↓
Ingress / Load Balancer
 ↓
Users
```

And around the entire platform:

```text
Identity + Security + Secrets + Observability + Governance + Cost
```

---

## Part 12 — Cleanup

If you created a local Kubernetes lab during this lesson, remove only the resources you created.

For a Helm-based application:

```bash
helm uninstall myapp
```

Then verify:

```bash
helm list
kubectl get all
```

If you created a dedicated namespace for the exercise:

```bash
kubectl delete namespace aks-eks-lab
```

For actual AKS/EKS resources created in a cloud subscription/account, do not delete the cluster simply as a generic cleanup step if it is shared or contains other workloads. Instead, remove only the lab resources you created and verify the resulting cloud resources and billing state.

The operational habit remains:

**Design → Provision → Deploy → Observe → Break → Diagnose → Recover → Destroy → Verify**

**Next: Day 18 — Identity, Secrets & Cloud Security**
