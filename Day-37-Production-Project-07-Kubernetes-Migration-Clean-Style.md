# Day 37 — Production Project 07: Kubernetes Migration

Day 37 moves ShopSphere from a managed container runtime to Kubernetes. You already learned Kubernetes fundamentals earlier; this project is different because you now have to make an architectural decision and experience the operational responsibility that comes with it. The objective is not to memorize `kubectl` commands. It is to understand what Kubernetes adds, what it takes over from the platform, what you must now design yourself, and how to operate the application safely.

The central question for today is:

**What operational responsibility did ShopSphere gain by choosing Kubernetes?**

---

## Part 1 — Why Move to Kubernetes?

ShopSphere currently runs as a managed container workload. The platform handles much of the runtime orchestration: scheduling, service execution, scaling primitives, health integration, and parts of deployment management. Kubernetes gives you a broader and more programmable orchestration platform, but that flexibility comes with additional concepts and operational responsibility.

A Kubernetes migration should therefore begin with a business or engineering reason rather than “we use Kubernetes because it is standard.” Possible reasons include a requirement for Kubernetes-native workloads, a common enterprise platform, portability across environments, advanced scheduling, standardized deployment tooling, or an ecosystem requirement. If the existing managed container platform already satisfies the workload requirements, Kubernetes may add complexity without enough benefit.

Your architecture decision should explicitly record:

```text
Why Kubernetes?
What capability do we need?
What responsibility are we accepting?
What is the operational cost?
What alternatives were considered?
```

---

## Part 2 — The Responsibility Shift

With a managed container runtime, the platform hides many implementation details.

With Kubernetes, the application team or platform team must understand:

```text
Cluster
Nodes
Scheduling
Namespaces
Workloads
Networking
Ingress
Identity
Storage
Autoscaling
Upgrades
Policies
Observability
```

Managed Kubernetes reduces some of this operational burden, but it does not eliminate Kubernetes operations.

For ShopSphere, the responsibility shifts from:

```text
Application
      ↓
Managed Container Platform
```

toward:

```text
Application
      ↓
Kubernetes Workloads
      ↓
Kubernetes Control Plane
      ↓
Cloud Infrastructure
```

The control plane may be managed by the cloud provider, but nodes, workload configuration, networking, identities, policies, upgrades, and application behavior still require deliberate engineering.

---

## Part 3 — Kubernetes Cluster Architecture

A Kubernetes cluster has a control plane and worker capacity.

The control plane exposes the Kubernetes API and maintains the desired state of the cluster. Worker nodes provide the compute capacity where Pods run. Kubernetes controllers continuously compare desired state with observed state and take actions to move the system toward the desired state.

The simplified model is:

```text
You declare:
"Run 3 healthy ShopSphere replicas"

        ↓

Kubernetes API

        ↓

Controllers + Scheduler

        ↓

Suitable Nodes

        ↓

Pods

        ↓

Application
```

This is the same reconciliation model you learned earlier, but now it becomes part of a production architecture.

---

## Part 4 — Managed Kubernetes Does Not Mean Fully Managed Operations

For ShopSphere, use a managed Kubernetes service such as Amazon EKS or Azure AKS.

The cloud provider manages the Kubernetes control plane, but you still need to understand and operate:

```text
Node pools / node groups
Workloads
Namespaces
Networking
Ingress
Identity
Resource requests and limits
Autoscaling
Secrets
Policies
Observability
Deployment strategy
Application health
```

This distinction is important in interviews.

Do not say:

**“EKS manages Kubernetes for us.”**

Say:

**“EKS provides a managed Kubernetes control plane, while we remain responsible for the workloads and much of the cluster-integrated platform configuration.”**

---

## Part 5 — Node Pools and Capacity

Kubernetes schedules Pods onto nodes.

A node has finite resources:

```text
CPU
Memory
Storage
Network
```

Suppose ShopSphere requires:

```text
API:
500m CPU
1 GiB memory

Worker:
1000m CPU
2 GiB memory
```

Kubernetes uses resource requests when deciding whether a Pod can fit on a node.

Requests are therefore not just documentation.

They influence scheduling.

Limits define the resource ceiling imposed on the container.

A common operational problem is:

```text
Request too low
      ↓
Pod scheduled successfully
      ↓
Application consumes more resources
      ↓
Node pressure / throttling / OOM
```

Good resource settings require observation rather than guessing.

---

## Part 6 — Kubernetes Namespaces

Namespaces provide a logical boundary inside a cluster.

For ShopSphere, you might use:

```text
shopsphere-dev
shopsphere-uat
shopsphere-prod
```

However, namespaces do not automatically provide complete security isolation.

You still need:

```text
RBAC
NetworkPolicy
ResourceQuota
LimitRange
Cloud identity controls
```

A namespace is therefore a useful organizational and policy boundary, not a replacement for account-level or cluster-level isolation.

---

## Part 7 — Deployments and ReplicaSets

ShopSphere's Spring Boot application should be represented by a Deployment.

A Deployment describes the desired workload state.

For example:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shopsphere-api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: shopsphere-api
  template:
    metadata:
      labels:
        app: shopsphere-api
    spec:
      containers:
        - name: api
          image: <registry>/shopsphere-api:<version>
          ports:
            - containerPort: 8080
```

The Deployment manages ReplicaSets, which manage the Pods.

Think:

```text
Deployment
   ↓
ReplicaSet
   ↓
Pods
```

You normally manage the Deployment rather than manually creating individual Pods.

---

## Part 8 — Services Provide Stable Application Access

Pods are temporary.

Their IP addresses can change when Pods are recreated.

A Kubernetes Service provides a stable access point for a group of Pods.

For ShopSphere:

```text
Frontend / Ingress
        ↓
Service
        ↓
Healthy API Pods
```

The Service uses label selectors to identify its backend Pods.

For example:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: shopsphere-api
spec:
  selector:
    app: shopsphere-api
  ports:
    - port: 80
      targetPort: 8080
```

The key relationship is:

**Service → selector → Pod labels.**

If the selector is wrong, the Service can exist perfectly while having no usable backends.

---

## Part 9 — Readiness Is Traffic Control

A running process is not necessarily ready to receive traffic.

ShopSphere should expose a health endpoint that can be used by Kubernetes.

For example:

```text
/actuator/health
```

A readiness probe answers:

**“Should this Pod receive traffic right now?”**

A liveness probe answers:

**“Is this container still functioning, or should Kubernetes restart it?”**

A startup probe can protect slow-starting applications from being killed before initialization completes.

The distinction matters:

```text
Process running
      ≠
Application ready
```

This principle connects directly to the safe deployment work from Day 34.

---

## Part 10 — Graceful Shutdown

When Kubernetes terminates a Pod, ShopSphere should stop accepting new work while allowing active requests to finish within a controlled period.

The desired flow is:

```text
Termination requested
        ↓
Pod removed from ready traffic
        ↓
Application begins graceful shutdown
        ↓
Existing requests finish
        ↓
Process exits
```

Without graceful shutdown, a deployment can create avoidable failed requests.

This is especially important for Spring Boot applications with:

```text
HTTP requests
Database connections
Message processing
Background jobs
```

---

## Part 11 — Configuration and Secrets

Do not build environment-specific configuration into the container image.

Keep:

```text
Image
```

separate from:

```text
Environment Configuration
Secrets
```

Kubernetes ConfigMaps can hold non-sensitive configuration.

Kubernetes Secrets provide a Kubernetes API object for sensitive configuration, but they should not automatically be treated as a complete secrets-management solution.

For production, integrate the workload with the cloud's secret-management system where appropriate.

For example:

```text
AWS Secrets Manager
        ↓
Kubernetes workload

or

Azure Key Vault
        ↓
Kubernetes workload
```

The important principle remains:

**Do not bake secrets into images or Git repositories.**

---

## Part 12 — Workload Identity

A Kubernetes application often needs to call cloud services.

Do not solve this by putting long-lived cloud access keys inside the Pod.

Instead use workload identity mechanisms.

For AWS:

```text
Kubernetes Service Account
        ↓
AWS IAM Role
        ↓
AWS API
```

For Azure:

```text
Kubernetes Workload Identity
        ↓
Microsoft Entra identity
        ↓
Azure resource
```

This gives the application an identity without distributing permanent credentials.

The runtime identity should have only the permissions the application actually needs.

---

## Part 13 — Kubernetes Networking

ShopSphere networking now spans two systems:

```text
Cloud Network
      +
Kubernetes Network
```

A request may travel through:

```text
Client
 ↓
DNS
 ↓
Cloud Load Balancer / Ingress
 ↓
Ingress Controller
 ↓
Kubernetes Service
 ↓
Pod
 ↓
Application
```

Inside the cluster, Pod networking and Service networking provide connectivity.

When something fails, do not immediately blame Kubernetes.

Use the same layered reasoning you learned in Days 3, 12, 15, 24, and 28:

```text
DNS
 ↓
Route
 ↓
Security
 ↓
Port
 ↓
Service
 ↓
Endpoints
 ↓
Pod
 ↓
Application
```

---

## Part 14 — Ingress

A Service provides internal or externally exposed connectivity depending on its type and platform integration.

Ingress provides HTTP/HTTPS routing rules into Kubernetes.

For example:

```text
api.shopsphere.example
        ↓
Ingress
        ↓
shopsphere-api Service
        ↓
API Pods
```

Ingress can route based on:

```text
Hostname
Path
TLS
```

In managed Kubernetes, the actual implementation often integrates with a cloud load balancer or gateway.

Do not confuse:

```text
Ingress
```

with:

```text
Load Balancer
```

Ingress describes application-layer routing behavior; the cloud load balancer may provide the external network entry point.

---

## Part 15 — NetworkPolicy

By default, application Pods may have broader network reachability than you want.

ShopSphere should explicitly consider:

```text
Frontend → API
API → Database
API → External dependencies
Monitoring → workloads
```

A NetworkPolicy can restrict which Pods or network sources can communicate.

The design should follow:

```text
Allow required traffic
Deny unnecessary traffic
```

For example:

```text
API
 ├── allowed → Database
 ├── allowed → required AWS services
 └── denied → unrelated application namespaces
```

NetworkPolicy is an additional security layer; it does not replace cloud security groups, firewall rules, or identity controls.

---

## Part 16 — Horizontal Pod Autoscaling

HPA changes the number of Pod replicas based on configured metrics.

For example:

```text
CPU increases
      ↓
HPA increases replicas
      ↓
More Pods
      ↓
Traffic distributed
```

But autoscaling does not solve every bottleneck.

If the database is saturated:

```text
More API Pods
      ↓
More DB connections
      ↓
Database becomes worse
```

Therefore:

**Scale the bottleneck, not merely the symptom.**

HPA should be designed together with:

```text
Resource requests
Resource limits
Application capacity
Database capacity
Node capacity
Load balancing
Cluster autoscaling
```

---

## Part 17 — Cluster Autoscaling

Suppose HPA increases the desired Pod count but no node has enough capacity.

Then the cluster itself may need additional compute capacity.

The relationship becomes:

```text
Traffic increases
 ↓
HPA increases Pods
 ↓
Insufficient node capacity
 ↓
Node autoscaling
 ↓
New node
 ↓
Scheduler places Pod
```

This is why application scaling and infrastructure scaling are different control loops.

HPA manages workload replicas.

Cluster/node autoscaling manages compute capacity.

---

## Part 18 — High Availability

Three replicas do not automatically guarantee high availability.

If all three Pods run on one node:

```text
Node failure
 ↓
All Pods unavailable
```

A better design spreads replicas across failure domains.

For managed Kubernetes, consider:

```text
Multiple nodes
Multiple availability zones
Pod topology spread
Pod anti-affinity
PodDisruptionBudget
```

The goal is not merely:

**“Run 3 Pods.”**

The goal is:

**“Place sufficient independent capacity across meaningful failure domains.”**

---

## Part 19 — PodDisruptionBudget

A PodDisruptionBudget can help limit how much voluntary disruption affects an application.

For example:

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: shopsphere-api
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: shopsphere-api
```

This can help during operations such as node maintenance.

It does not protect against every possible failure.

A sudden node crash can still remove a Pod.

This is another example of a control that improves availability without creating absolute guarantees.

---

## Part 20 — Rolling Updates

A Deployment can progressively replace old Pods with new Pods.

Conceptually:

```text
v1 v1 v1
 ↓
v1 v1 v2
 ↓
v1 v2 v2
 ↓
v2 v2 v2
```

Readiness probes determine whether new Pods are ready for traffic.

The deployment strategy should also account for:

```text
Capacity
Startup time
Graceful shutdown
Database compatibility
Failure detection
Rollback
```

A Kubernetes rollout is therefore part of the application release strategy, not merely a YAML setting.

---

## Part 21 — Rollback

If version `v2` is unhealthy:

```bash
kubectl rollout status deployment/shopsphere-api
kubectl rollout history deployment/shopsphere-api
kubectl rollout undo deployment/shopsphere-api
```

Rollback is only safe when the previous application version remains compatible with the current infrastructure and database state.

This connects directly to Day 34:

**A deployment rollback is not necessarily a database rollback.**

Database migrations should therefore follow backward-compatible patterns when zero-downtime rollback is required.

---

## Part 22 — Helm

ShopSphere should not maintain large numbers of duplicated Kubernetes manifests for each environment.

Helm can package the Kubernetes configuration.

Conceptually:

```text
Chart
 ↓
Templates
 ↓
Values
 ↓
Environment-specific Deployment
```

For example:

```text
values-dev.yaml
values-uat.yaml
values-prod.yaml
```

The container image can remain the same while environment-specific values change.

This follows the same principle as Day 33:

**Build once, promote the same artifact.**

---

## Part 23 — GitOps

For the production project, distinguish Helm from GitOps.

Helm packages and renders Kubernetes applications.

GitOps adds a continuous reconciliation model in which Git represents the desired deployment state and a controller applies that state to the cluster.

Conceptually:

```text
Git
 ↓
Desired State
 ↓
GitOps Controller
 ↓
Kubernetes
 ↓
Actual State
```

If someone manually changes a Deployment, the GitOps controller can detect the difference and reconcile it according to the configured model.

GitOps therefore extends the reconciliation concept you learned in Kubernetes itself.

---

## Part 24 — CI/CD Changes After Kubernetes Migration

The application pipeline still follows:

```text
Git SHA
 ↓
Build
 ↓
Test
 ↓
Security
 ↓
Image
 ↓
Registry
```

But the deployment target changes:

```text
Registry
 ↓
Helm / GitOps
 ↓
Kubernetes
 ↓
Rollout
 ↓
Health Verification
```

The pipeline should not rebuild the application for every environment.

Instead:

```text
One image
      ↓
Dev
      ↓
UAT
      ↓
Production
```

Environment differences should be expressed through controlled configuration.

---

## Part 25 — Terraform and Kubernetes Boundaries

Terraform should continue to manage infrastructure such as:

```text
VPC
EKS / AKS
Node groups
IAM
Security groups
Load balancer integration
Cloud resources
```

Kubernetes tooling should manage application workloads such as:

```text
Namespace
Deployment
Service
Ingress
ConfigMap
HPA
NetworkPolicy
PDB
```

There can be overlap, but a clear ownership model prevents two systems from fighting over the same resource.

A useful boundary is:

```text
Terraform
→ Platform Infrastructure

Kubernetes / Helm / GitOps
→ Application Runtime Objects
```

Do not automatically put every Kubernetes YAML object into Terraform just because Terraform can create it.

---

## Part 26 — Migration Architecture

ShopSphere's target architecture becomes:

```text
Users
  ↓
DNS
  ↓
Cloud Load Balancer / Ingress
  ↓
Kubernetes
  ↓
ShopSphere API Pods
  ↓
Private Database
```

Around this runtime are:

```text
Terraform
CI/CD
Container Registry
Secrets
IAM
Monitoring
Logging
Tracing
Policy
```

The migration should be incremental rather than a single uncontrolled cutover.

A practical path is:

```text
Existing Runtime
      ↓
Kubernetes Environment
      ↓
Deploy Same Image
      ↓
Validate
      ↓
Load Test
      ↓
Observe
      ↓
Controlled Traffic Shift
      ↓
Retire Old Runtime
```

---

## Part 27 — Failure Drill: Service Has No Backends

Create a harmless selector mismatch.

For example, change:

```yaml
selector:
  app: shopsphere-api
```

to a label that does not exist.

Then investigate:

```bash
kubectl get svc
kubectl get endpoints
kubectl get pods --show-labels
kubectl describe svc shopsphere-api
```

Reason through:

```text
DNS works
 ↓
Service exists
 ↓
Service has no endpoints
 ↓
Selector mismatch
 ↓
No Pod receives traffic
```

Fix the selector and verify recovery.

The important lesson is:

**A healthy Pod does not help if the Service cannot select it.**

---

## Part 28 — Failure Drill: Pod Is Running but Traffic Fails

Create a readiness failure.

Observe:

```bash
kubectl get pods
kubectl describe pod <pod-name>
```

You may see:

```text
Pod:
Running

Ready:
False
```

Then inspect:

```bash
kubectl get endpoints shopsphere-api
```

The unhealthy Pod should not receive normal Service traffic.

Reason through:

```text
Process exists
 ↓
Container running
 ↓
Readiness fails
 ↓
Pod removed from ready endpoints
 ↓
Traffic goes elsewhere
```

This is one of the most important Kubernetes production behaviors to understand.

---

## Part 29 — Failure Drill: Deployment Causes 5xx

Deploy a deliberately broken application version in a non-production environment.

Observe:

```text
Deployment
 ↓
New Pods
 ↓
Readiness / application failure
 ↓
Traffic impact
 ↓
Metrics / logs
```

Investigate using:

```bash
kubectl rollout status deployment/shopsphere-api
kubectl rollout history deployment/shopsphere-api
kubectl get pods
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

Then rollback.

After recovery, determine:

```text
What failed?
When did it fail?
Why did Kubernetes consider the Pod available or unavailable?
What detected the issue?
Why did rollback work?
How could the release gate detect this earlier?
```

---

## Part 30 — Failure Drill: Database Connectivity

Break the API's database connectivity in a non-production environment.

Follow the full path:

```text
Application
 ↓
DNS
 ↓
Network
 ↓
Security
 ↓
Database Port
 ↓
Database
 ↓
Credentials
```

Then inspect both cloud and Kubernetes layers.

Useful commands include:

```bash
kubectl exec -it <pod-name> -- sh
kubectl get networkpolicy
kubectl describe networkpolicy
```

The exact testing command inside the image depends on what diagnostic tools are available.

Do not assume that because a Pod can reach another Pod, it can reach the database.

---

## Part 31 — Failure Drill: Resource Exhaustion

Give the application intentionally low resource limits in a non-production environment.

Observe:

```text
Application load
 ↓
Memory pressure / CPU pressure
 ↓
Container behavior
 ↓
Pod status
 ↓
Node behavior
```

Inspect:

```bash
kubectl describe pod <pod-name>
kubectl top pod
kubectl top node
```

Determine whether the bottleneck is:

```text
Container
Pod
Node
Cluster
Database
External dependency
```

This reinforces the Senior/Lead habit of identifying the actual bottleneck before scaling.

---

## Part 32 — Security Review

Review ShopSphere's Kubernetes security model.

Ask:

```text
Who can deploy to the production namespace?

Who can create privileged Pods?

Who can read Secrets?

Can one namespace reach another?

What cloud permissions does the application have?

Can a compromised Pod access unnecessary AWS/Azure services?

Who can access the Kubernetes API?

Can developers modify Production directly?
```

The answer should involve several layers:

```text
Cloud IAM
Kubernetes RBAC
NetworkPolicy
Pod security controls
Secrets management
Image security
Admission / policy
Audit logging
```

No single Kubernetes feature provides complete security.

---

## Part 33 — Observability

Kubernetes adds more moving parts, so observability becomes more important.

Monitor at least:

```text
Cluster health
Node health
Pod health
Deployment health
CPU
Memory
Restart counts
Network behavior
Application latency
Application errors
Database health
```

Connect this with Day 35.

The useful question is not:

**“Is the cluster green?”**

It is:

**“Can users successfully complete business operations?”**

For ShopSphere, examples include:

```text
Product search success rate
Order creation success rate
Checkout latency
Payment integration failures
```

Kubernetes health is necessary but not sufficient.

---

## Part 34 — Cost and Operational Trade-Off

Kubernetes introduces platform overhead.

You now need to account for:

```text
Cluster/control-plane charges where applicable
Worker nodes
Load balancers
Storage
Logging
Monitoring
Network traffic
Engineering time
Upgrade effort
Platform maintenance
```

The infrastructure bill is only part of the cost.

Operational complexity is also a cost.

Therefore, the Kubernetes architecture decision should compare:

```text
Capability gained
+
Operational responsibility
+
Infrastructure cost
+
Engineering cost
+
Portability / standardization value
```

This is why “Kubernetes is better” is not a useful architecture argument by itself.

---

## Part 35 — Hands-On Kubernetes Migration

Now migrate the ShopSphere API.

Build the same application image you already used.

Do not create a Kubernetes-specific application image unless the runtime requires a change.

Deploy it to the managed Kubernetes environment.

Implement:

```text
Namespace
Deployment
Service
Readiness
Liveness
Startup probe if required
Resource requests
Resource limits
ConfigMap
Secret integration
Workload identity
Ingress
NetworkPolicy
HPA
PDB
```

Then expose the application through the intended production path.

Verify:

```text
DNS
Ingress
Service
Endpoints
Pods
Application
Database
Observability
```

The objective is to prove the entire request path, not merely obtain a `Running` Pod.

---

## Part 36 — Production Migration Plan

Create a migration runbook.

It should contain:

```text
Pre-checks
Capacity
Database compatibility
Container image
Kubernetes manifests
Secrets
Identity
Networking
DNS
Observability
Rollback
Traffic migration
Post-migration verification
Old platform retirement
```

Define the rollback boundary before the migration begins.

For example:

```text
Before traffic shift:
Old runtime remains active

During controlled shift:
Observe Kubernetes

If unhealthy:
Return traffic to old runtime

If healthy:
Continue migration
```

This is safer than treating migration as an irreversible deployment.

---

## Part 37 — Senior/Lead Architecture Review

Now challenge the decision itself.

Answer:

1. Why does ShopSphere need Kubernetes?
2. What did the previous managed runtime already provide?
3. What operational responsibilities did Kubernetes add?
4. Why use managed Kubernetes instead of self-managed Kubernetes?
5. How will Pods receive cloud identities?
6. How will Secrets reach the application?
7. How will traffic reach Pods?
8. How will the application scale?
9. What happens when a node fails?
10. What happens when a Pod becomes unhealthy?
11. How will deployments be rolled back?
12. How will database changes remain compatible?
13. Who can deploy to Production?
14. Who can read Kubernetes Secrets?
15. How are namespaces isolated?
16. How are workloads protected from unnecessary network access?
17. What does Terraform own?
18. What does Helm/GitOps own?
19. How will cluster upgrades be handled?
20. How will you know Kubernetes is actually improving the platform?

The strongest answers should describe **trade-offs and operational consequences**, not just Kubernetes features.

---

## Part 38 — Azure ↔ AWS Mapping

The Kubernetes concepts remain largely the same across clouds.

```text
Azure                         AWS
------------------------------------------------
AKS                           EKS
Azure VNet                    AWS VPC
Azure Load Balancer           AWS Load Balancer
Application Gateway           ALB / ingress integration
Azure Workload Identity       EKS Pod Identity / IRSA patterns
Azure Monitor                 CloudWatch / ecosystem tooling
Azure Key Vault               AWS Secrets Manager
ACR                           ECR
Azure RBAC / Entra ID         IAM / AWS IAM Identity Center
```

The important skill is not memorizing service names.

It is recognizing:

```text
Kubernetes concept
        ↓
Cloud integration
        ↓
Security
        ↓
Networking
        ↓
Operations
```

That is what makes Kubernetes knowledge transferable.

---

## Part 39 — 5-Minute Recall

Without looking at the lesson, explain:

```text
Why Kubernetes?
Managed Kubernetes vs Kubernetes
Control plane vs worker nodes
Pod
Deployment
ReplicaSet
Service
Ingress
Readiness
Liveness
Startup probe
Resource requests
Resource limits
HPA
Node autoscaling
Namespace
NetworkPolicy
Workload identity
PodDisruptionBudget
Rolling update
Rollback
Helm
GitOps
Terraform vs Kubernetes ownership
Kubernetes networking
Kubernetes security
Kubernetes observability
Kubernetes cost
```

Then explain this flow in your own words:

```text
User
 ↓
DNS
 ↓
Load Balancer / Ingress
 ↓
Service
 ↓
Pod
 ↓
Application
 ↓
Database
```

Finally answer:

**What operational responsibility did ShopSphere gain by moving to Kubernetes?**

If your answer is only “we now manage Kubernetes,” go deeper.

---

## Part 40 — Day 37 Completion Criteria

Complete Day 37 when you can demonstrate:

```text
[ ] Kubernetes architecture understood
[ ] Managed Kubernetes responsibility boundary understood
[ ] ShopSphere deployed to Kubernetes
[ ] Namespace created
[ ] Deployment created
[ ] Service created
[ ] Readiness configured
[ ] Liveness configured
[ ] Startup behavior considered
[ ] Resource requests/limits configured
[ ] Config separated from image
[ ] Secrets handled securely
[ ] Workload identity configured
[ ] Ingress configured
[ ] NetworkPolicy considered/implemented
[ ] HPA configured
[ ] High availability considered
[ ] PDB configured
[ ] Rolling deployment tested
[ ] Rollback tested
[ ] Service selector failure drilled
[ ] Readiness failure drilled
[ ] Deployment failure drilled
[ ] Database connectivity failure drilled
[ ] Resource exhaustion drilled
[ ] Kubernetes observability integrated
[ ] Terraform/Kubernetes ownership documented
[ ] Migration runbook created
[ ] Rollback boundary documented
[ ] Cost/complexity trade-off documented
[ ] AWS/Azure Kubernetes mapping understood
```

The most important completion criterion is:

**You can explain and operate the complete ShopSphere request path through Kubernetes, identify which layer is failing, collect evidence, recover safely, and explain why Kubernetes is justified for the workload.**

---

## Cleanup

Keep the managed Kubernetes platform and ShopSphere manifests because the next project days build on this environment.

Remove only temporary failure-drill resources and restore the application to its known-good version.

Verify:

```text
Known-good image
Healthy replicas
Healthy endpoints
Working ingress
Working database connectivity
Working identity
No temporary permissive NetworkPolicy
No temporary oversized resources
No intentionally broken configuration
```

Record:

```text
Cluster:
Region:
Kubernetes Version:
Node Pools:
Namespace:
Application Image:
Ingress:
Service:
Workload Identity:
Secrets Source:
HPA:
PDB:
Terraform Owner:
Kubernetes/Helm/GitOps Owner:
Known-Good Commit:
```

Do not retire the previous managed runtime yet.

The next project will use the Kubernetes environment while introducing **multi-environment and multi-account architecture**, forcing us to decide where cluster boundaries, account boundaries, state boundaries, and team ownership should exist.
