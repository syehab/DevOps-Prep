# Day 17 — Questions and answers

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Then answer each item below before you open the Answer block. After that, do the lab in [03-implementation.md](03-implementation.md).

Write your own answer first. Open the Answer block only after you try. Keep the original numbering.

---

## 1. Self-managed cluster versus AKS/EKS: what you no longer operate, what stays yours

**Practice:** Compare a self-managed cluster with AKS/EKS and list which responsibilities you would no longer have to operate yourself and which responsibilities would remain yours.

<details>
<summary>Answer</summary>

On a self-managed cluster you operate the API server, etcd, scheduler, controllers, certificates, control-plane upgrades, and worker nodes. On AKS or EKS the cloud provider manages the Kubernetes control plane. You no longer run etcd or the API server yourself.

You still own worker compute, workloads, application configuration, access and security, networking design, and operations. Never say “the cloud provider manages Kubernetes” as if everything is managed. The exact boundary depends on managed features you choose.

</details>

---

## 2. Draw AKS and mark Azure-managed versus team-controlled

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

<details>
<summary>Answer</summary>

Draw Azure Subscription → VNet → AKS. Split AKS into Managed Control Plane and Node Pools. Node Pools run Pods → Services → Application. Azure manages the API server, scheduler, controllers, and etcd. Your team chooses node-pool size, VM type, and workload YAML.

The VNet, subnets, NSGs, identity bindings, and application still belong to you. Kubernetes API is the boundary between the managed control plane and your node pools. Day 12 networking does not disappear.

</details>

---

## 3. Draw the equivalent EKS architecture

**Practice:** Draw the equivalent EKS architecture and replace each Azure-specific component from the previous exercise with its AWS counterpart.

<details>
<summary>Answer</summary>

Replace AKS with EKS, VNet with VPC, and ACR with ECR. Replace Azure Load Balancer with the ELB family, Entra ID with IAM, and Azure Monitor with CloudWatch. Replace Key Vault with Secrets Manager or KMS. AWS manages the EKS control plane. Compute can be managed node groups, self-managed EC2, or Fargate.

Do not say “EKS runs on EC2” as the whole story. Each compute model has different operations and cost. IAM authenticates to the cluster. Kubernetes RBAC still authorizes inside Kubernetes. An AWS administrator is not automatically a cluster-admin.

</details>

---

## 4. Three workloads: node pool, requests, and scaling

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

<details>
<summary>Answer</summary>

Workload A is CPU-heavy: a compute node pool, higher CPU requests, HPA on CPU. Workload B is memory-heavy: a memory-optimized pool, higher memory requests, HPA on memory or custom metrics. Workload C is GPU: a tainted GPU pool, only Pods with the matching toleration, scale that pool separately.

Do not put every workload in one generic pool. Mixing them wastes capacity and creates scheduling conflicts. The scheduler uses requests to fit Pods. Missing requests cause packing mistakes. Too-high requests leave Pods Pending while nodes look idle.

</details>

---

## 5. Map the external path and the private-database path to Kubernetes or cloud

**Practice:** Take the Day 15 external request path and map every step to either Kubernetes or Azure/AWS. Then repeat for a Pod connecting to a private database.

<details>
<summary>Answer</summary>

External: User and DNS are cloud or public DNS. Cloud Load Balancer is cloud. Ingress Controller, Ingress, Service, Endpoints, and Pods are Kubernetes. The application is the workload. A correct Kubernetes object can still fail if the cloud load-balancer integration is wrong.

Pod to private database: Pod networking and NetworkPolicy are Kubernetes. Node network, route, NSG or Security Group, private endpoint, and cloud DNS are Azure or AWS. Kubernetes YAML cannot fix a missing VNet route. Walk both sides.

</details>

---

## 6. Identity model for Spring Boot on AKS, then map to EKS

**Practice:** Design an identity model for a Spring Boot application running on AKS and then map it to EKS. Identify the human deployment identity, GitOps identity and application workload identity separately.

<details>
<summary>Answer</summary>

Separate three identities. Humans use Entra ID (AKS) or IAM (EKS), then Kubernetes RBAC in a namespace. The GitOps or CI deploy identity updates Deployments only, not subscription admin. The application uses a ServiceAccount mapped to cloud identity: Azure Workload Identity, or on AWS IRSA or EKS Pod Identity.

Workload identity maps a ServiceAccount to a cloud role. No access keys live in the Pod. The CI/CD role that deploys the app is a different identity from the runtime role the Pod assumes. Ask: who is the human, what is the workload identity, and what can the workload do inside Kubernetes.

</details>

---

## 7. Three replicas that do not share one failure domain

**Practice:** Design a production deployment with three replicas and explain how you would prevent all three replicas from being placed on the same failure domain.

<details>
<summary>Answer</summary>

Set `replicas: 3`. Spread Pods with topology spread constraints or anti-affinity across nodes and availability zones. One node must not hold every replica. A node failure then removes one replica, not the application.

Also plan node pools in more than one zone. Three replicas on one node are not high availability. Kubernetes can restart Pods. Placement still decides whether they survive a node or zone failure.

</details>

---

## 8. Production AKS/EKS upgrade checklist

**Practice:** Create an upgrade checklist for your hypothetical production AKS/EKS cluster. Include application compatibility, Kubernetes APIs, node capacity, disruption, monitoring and rollback considerations.

<details>
<summary>Answer</summary>

1. Check Kubernetes version compatibility and deprecated APIs in non-production.
2. Confirm node capacity so draining does not leave Pods Pending.
3. Confirm PodDisruptionBudgets, multiple replicas, and readiness probes.
4. Upgrade the control plane, then node pools, then validate workloads.
5. Watch restarts, Pending Pods, errors, and latency. Plan rollback of workloads if the app breaks.

Managed control-plane upgrades still need this plan. Application downtime happens when APIs change or Pods have no disruption strategy. A successful infrastructure upgrade is not enough. Workloads must keep serving.

</details>

---

## 9. Spring Boot on Azure versus AWS: problem each component solves

**Practice:** Take your Spring Boot application architecture and produce two versions:

```text
Azure:
Spring Boot → AKS → ACR → Azure networking → Key Vault → Azure Monitor

AWS:
Spring Boot → EKS → ECR → VPC networking → AWS secrets/identity → CloudWatch
```

For each component, write what problem it solves rather than only its product name.

<details>
<summary>Answer</summary>

AKS and EKS run the managed Kubernetes control plane. ACR and ECR store images. VNet and VPC isolate networks. Key Vault and Secrets Manager or KMS hold secrets. Azure Monitor and CloudWatch collect telemetry. Workload Identity and IRSA or EKS Pod Identity give the Pod cloud access without keys.

Keep the application design identical. Change only the cloud integrations. In interviews, name the layer first, then the product. “How would you secure AKS?” is identity, RBAC, network, secrets, images, and logs, then Azure names.

</details>

---

## Part 10 — Senior/Lead Architecture Exercise

Design a production platform for a Spring Boot application with the following requirements:

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

---

## 10. Architecture exercise — one-page AKS and one-page EKS

Your architecture should conceptually contain:

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

**Practice:** Create a one-page AKS architecture and a one-page EKS architecture for the same Spring Boot application. Keep the application design identical and change only the cloud-specific integrations.

<details>
<summary>Answer</summary>

Keep Shop-style Spring Boot the same: Git → CI → registry → GitOps → managed Kubernetes → Ingress → Service → Pods → private database. Add human, CI, and workload identities. Add logs, metrics, and alerts. Add RBAC, NetworkPolicy, cloud network controls, and secrets.

Azure page: AKS, ACR, VNet, Key Vault, Entra ID, Workload Identity, Azure Monitor. AWS page: EKS, ECR, VPC, Secrets Manager, IAM, IRSA or EKS Pod Identity, CloudWatch. Start from traffic, availability, data, deploy, identity, and ownership. Then pick products.

</details>

---

## 11. Failure owners and expected evidence

Now introduce failures one at a time:

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

<details>
<summary>Answer</summary>

Node fails: you own node pools; evidence is node NotReady and replacement Pods. Pod fails: you own the workload; evidence is restart count and logs. Image cannot be pulled: you own registry permissions and tag; evidence is `ImagePullBackOff`. Service has no endpoints: you own selector and readiness; evidence is empty Endpoints.

Ingress incorrect: you own Ingress rules. Database unreachable: you and the cloud network; evidence is DNS, route, security, then credentials. Insufficient capacity: you own requests and autoscaling; evidence is Pending. Identity loses permission: you own IAM or Entra plus RBAC; evidence is 403. Bad version: you own the release; evidence is error rate after deploy. Image-pull is not an Endpoints failure. Database authorization is not a missing VNet route.

</details>

---

## 12. Interview — migrate Spring Boot to managed Kubernetes on Azure or AWS

Finally, explain the architecture as if you were answering a Lead DevOps interview question:

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

<details>
<summary>Answer</summary>

Start with requirements, not product names. Then application architecture, cluster, networking, identity, security, deployment, scaling, observability, failure recovery, cost, and governance. Use AKS or EKS for the managed control plane. Put the app in private subnets. Use a cloud load balancer and Ingress for HTTP.

Use Workload Identity on Azure, or IRSA or EKS Pod Identity on AWS, for Key Vault or Secrets Manager. Deploy with CI building one image and GitOps applying Git. Spread replicas across zones. Prove health with metrics, logs, and traces. Every decision needs a reason. Longest architecture is not the goal.

</details>

---

## Part 11 — 5-Minute Recall

Without looking at the notes, explain these in your own words:

---

## 13. Recall — What problem does managed Kubernetes solve?

1. What problem does managed Kubernetes solve?

<details>
<summary>Answer</summary>

It reduces the burden of operating the Kubernetes control plane: API server, etcd, scheduler, certificates, and control-plane upgrades. You consume Kubernetes as a managed platform and still use cloud identity, networking, and observability.

It is not “less work on everything.” It is a platform architecture, not only a place where containers run.

</details>

---

## 14. Recall — What the provider manages versus what stays yours

2. What does the cloud provider manage in AKS/EKS, and what remains your responsibility?

<details>
<summary>Answer</summary>

The provider manages the managed control-plane service. Your team owns workload architecture and many data-plane, security, networking, identity, scaling, and operational decisions.

Node pools, YAML, NetworkPolicy, and application health remain yours. The boundary differs between AKS and EKS and by features you enable.

</details>

---

## 15. Recall — Control plane versus worker/compute layer

3. What is the difference between the Kubernetes control plane and worker/compute layer?

<details>
<summary>Answer</summary>

The control plane is the API server, scheduler, controllers, and cluster state. The worker or compute layer is the nodes or Fargate capacity where Pods run.

On AKS and EKS the control plane is managed. You still size and operate the compute layer where your workloads run.

</details>

---

## 16. Recall — Why AKS and EKS still depend on VNet or VPC

4. Why do AKS and EKS still depend heavily on VNet/VPC networking?

<details>
<summary>Answer</summary>

The cluster sits inside or alongside the cloud network. Pods, nodes, load balancers, and private databases use that network for routing, DNS, and security.

Kubernetes does not make the VNet or VPC disappear. A missing cloud route still looks like “the application is down.”

</details>

---

## 17. Recall — What is a node pool or managed node group?

5. What is a node pool or managed node group?

<details>
<summary>Answer</summary>

It is a set of worker machines with a VM size, OS, and scaling settings. AKS calls them node pools. EKS often uses managed node groups for EC2 capacity.

Kubernetes schedules Pods onto that capacity. Different pools can serve different workload types.

</details>

---

## 18. Recall — Why an enterprise uses multiple node pools

6. Why might an enterprise use multiple node pools?

<details>
<summary>Answer</summary>

Workloads differ in CPU, memory, GPU, scaling, and isolation. One generic pool can waste money or block scheduling. Dedicated pools plus taints, tolerations, and affinity place work on the right machines.

Use multiple pools when characteristics differ, not as a default for every small app.

</details>

---

## 19. Recall — How resource requests affect scheduling

7. How do resource requests affect Kubernetes scheduling?

<details>
<summary>Answer</summary>

The scheduler uses CPU and memory requests to decide whether a Pod fits a node. Missing or tiny requests pack too tightly. Huge requests leave Pods Pending.

Limits cap usage later. Requests decide placement. Set them from observed need.

</details>

---

## 20. Recall — Pod autoscaling versus node autoscaling

8. What is the relationship between Pod autoscaling and node autoscaling?

<details>
<summary>Answer</summary>

Horizontal Pod Autoscaling adds Pods when traffic rises. If nodes have no room, new Pods stay Pending. Cluster or node autoscaling then adds machines.

More traffic → more Pods → maybe more nodes. Application scaling and infrastructure scaling are related but distinct.

</details>

---

## 21. Recall — Three replicas on one node versus spread across failure domains

9. Why is three replicas on one node not equivalent to three replicas spread across failure domains?

<details>
<summary>Answer</summary>

Three replicas on one node die together when that node fails. Spread across nodes and zones so one failure does not remove every replica.

Kubernetes restarts Pods. Topology still decides isolation. Count of replicas is not the same as placement.

</details>

---

## 22. Recall — Cloud IAM or Entra versus Kubernetes RBAC

10. What is the difference between cloud IAM/Entra identity and Kubernetes RBAC?

<details>
<summary>Answer</summary>

Cloud IAM and Entra control access to cloud resources and often authenticate to the cluster API. Kubernetes RBAC authorizes actions on Kubernetes objects after that.

A cloud administrator should not automatically be unrestricted inside the cluster. A Kubernetes admin does not automatically manage unrelated cloud resources.

</details>

---

## 23. Recall — Workload identity, and Azure versus AWS names

11. What is workload identity, and why is it preferable to static cloud credentials inside Pods? What are the Azure and AWS names for that mechanism?

<details>
<summary>Answer</summary>

Workload identity maps a Kubernetes ServiceAccount to a cloud role so the Pod gets a short-lived token. No access keys live in the Pod. Azure calls it Workload Identity.

AWS calls it IRSA (IAM Roles for Service Accounts) or EKS Pod Identity. IRSA uses an OIDC trust. EKS Pod Identity attaches an IAM role without you wiring the OIDC provider by hand. Both replace long-lived keys. Day 26 covers debugging the trust policy.

</details>

---

## 24. Recall — How a Pod in AKS or EKS reaches a private database

12. How would a Pod in AKS/EKS reach a private database?

<details>
<summary>Answer</summary>

The Pod uses CNI networking on the node, then VNet or VPC routing, then cloud security rules, then a private endpoint or private database address. DNS must resolve the private name.

Check Kubernetes and cloud layers. A NetworkPolicy, NSG, Security Group, or missing route can each block the same symptom.

</details>

---

## 25. Recall — Extra layers when exposing an application to the Internet

13. What additional layers exist when exposing an application to the Internet?

<details>
<summary>Answer</summary>

Add public DNS, a cloud load balancer, and often an Ingress Controller and Ingress rules in front of the Service. The Internet cannot use a ClusterIP or Pod IP.

Troubleshoot those extra hops before you blame the Pod. Cloud integration can fail while Kubernetes objects look correct.

</details>

---

## 26. Recall — Why a cluster upgrade can still cause application downtime

14. Why can a Kubernetes cluster upgrade still cause application downtime?

<details>
<summary>Answer</summary>

Node upgrades move Pods. APIs can change. Deprecated resources can disappear. A one-replica app with no readiness probe goes offline during drain.

Managed control-plane upgrades do not remove this risk. Plan compatibility, capacity, disruption, and workload validation.

</details>

---

## 27. Recall — Readiness probes and PodDisruptionBudgets during maintenance

15. What role do readiness probes and PodDisruptionBudgets play during node maintenance?

<details>
<summary>Answer</summary>

Readiness keeps unready Pods out of Service backends while replacements start. A PodDisruptionBudget limits how many Pods voluntary disruption may remove at once.

Together they keep some ready replicas during node upgrades. The workload must be designed to use them.

</details>

---

## 28. Recall — Conceptual difference between AKS and EKS

16. What is the conceptual difference between AKS and EKS?

<details>
<summary>Answer</summary>

Both are managed Kubernetes. Azure versus AWS changes the surrounding identity, network, registry, load balancing, and monitoring integrations. Kubernetes objects stay the same.

Learn the concept once, then map the cloud implementation. Do not keep two Kubernetes mental models.

</details>

---

## 29. Recall — Azure equivalents of EKS, ECR, VPC, IAM, and CloudWatch

17. What are the Azure equivalents of EKS, ECR, VPC, IAM and CloudWatch?

<details>
<summary>Answer</summary>

EKS maps to AKS. ECR maps to ACR. VPC maps to VNet. IAM maps to Microsoft Entra ID and Azure RBAC. CloudWatch maps to Azure Monitor.

The map is conceptual. Behavior is not identical.

</details>

---

## 30. Recall — AWS equivalents of AKS, ACR, VNet, Entra/Azure RBAC, and Azure Monitor

18. What are the AWS equivalents of AKS, ACR, VNet, Microsoft Entra ID/Azure RBAC and Azure Monitor?

<details>
<summary>Answer</summary>

AKS maps to EKS. ACR maps to ECR. VNet maps to VPC. Microsoft Entra ID and Azure RBAC map to IAM. Azure Monitor maps to CloudWatch.

Workload Identity maps to IRSA or EKS Pod Identity. Key Vault maps to Secrets Manager or KMS.

</details>

---

## 31. Recall — Pending for no capacity: would restarting the Pod help?

19. If a Pod is Pending because there is no capacity, would restarting the Pod solve the problem? Why?

<details>
<summary>Answer</summary>

No. Pending means the Scheduler cannot place the Pod. Restarting does not add node capacity or lower requests.

Add nodes, free capacity, or reduce requests. `kubectl describe pod` shows the scheduling events.

</details>

---

## 32. Recall — Works inside the cluster, users cannot access it externally

20. If the application works inside the cluster but users cannot access it externally, which layers would you investigate?

<details>
<summary>Answer</summary>

Investigate public DNS, the cloud load balancer, listeners, Ingress Controller, Ingress rules, and then the Service. Internal ClusterIP success already proved Pods can serve.

This is an external-path problem. Do not restart healthy Pods as the first move.

</details>
