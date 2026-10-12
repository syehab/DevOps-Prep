# Day 37 — Questions and answers

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Then answer each item below before you open the Answer block. After that, do the lab in [03-implementation.md](03-implementation.md).

Write your own answer first. Open the Answer block only after you try. Keep the original numbering.

---

## Senior/Lead Architecture Review

Now challenge the decision itself.

The strongest answers should describe **trade-offs and operational consequences**, not just Kubernetes features.

---

## 1. Why does ShopSphere need Kubernetes?

1. Why does ShopSphere need Kubernetes?

<details>
<summary>Answer</summary>

Record a real need: Kubernetes-native workloads, a common enterprise platform, portability, advanced scheduling, or an ecosystem requirement.

If the managed container runtime already meets the NFRs, Kubernetes adds operations without enough benefit. “It is standard” is not a reason.

</details>

---

## 2. What did the previous managed runtime already provide?

2. What did the previous managed runtime already provide?

<details>
<summary>Answer</summary>

Scheduling, service execution, scaling primitives, health integration, and parts of deploy management.

Kubernetes keeps those jobs but makes you design workloads, networking, identity, policies, and upgrades yourself.

</details>

---

## 3. What operational responsibilities did Kubernetes add?

3. What operational responsibilities did Kubernetes add?

<details>
<summary>Answer</summary>

Node pools, namespaces, Ingress, NetworkPolicy, requests/limits, HPA, cluster autoscaling, PDBs, RBAC, secrets wiring, upgrades, and workload observability.

EKS/AKS manage the control plane. You still run the rest.

</details>

---

## 4. Why use managed Kubernetes instead of self-managed Kubernetes?

4. Why use managed Kubernetes instead of self-managed Kubernetes?

<details>
<summary>Answer</summary>

EKS or AKS run the API server and etcd. You avoid operating the control plane yourself.

Say: the provider manages the control plane; we still own nodes, workloads, and cluster-integrated platform config.

</details>

---

## 5. How will Pods receive cloud identities?

5. How will Pods receive cloud identities?

<details>
<summary>Answer</summary>

Use workload identity, not keys in the Pod. AWS: Service Account → IAM role → AWS API. Azure: workload identity → Entra → Azure resource.

Grant only the actions the app needs.

</details>

---

## 6. How will Secrets reach the application?

6. How will Secrets reach the application?

<details>
<summary>Answer</summary>

Keep the image environment-neutral. ConfigMaps hold non-secret config. Do not treat Kubernetes Secrets as a full secret store.

Prefer Secrets Manager or Key Vault into the workload. Never bake secrets into images or Git.

</details>

---

## 7. How will traffic reach Pods?

7. How will traffic reach Pods?

<details>
<summary>Answer</summary>

User → DNS → cloud load balancer / Ingress → Ingress controller → Service → ready endpoints → Pod → app.

Ingress is HTTP routing. The cloud load balancer is the network entry. A Service with a bad selector has no backends.

</details>

---

## 8. How will the application scale?

8. How will the application scale?

<details>
<summary>Answer</summary>

HPA changes replica count from metrics. If nodes are full, cluster autoscaling adds nodes, then the scheduler places Pods.

Scale the bottleneck. More API Pods on a saturated database make connections worse.

</details>

---

## 9. What happens when a node fails?

9. What happens when a node fails?

<details>
<summary>Answer</summary>

Pods on that node die. Three replicas on one node all die together. Spread across nodes and AZs with topology spread or anti-affinity.

A PDB does not save you from a crash. It limits voluntary disruption.

</details>

---

## 10. What happens when a Pod becomes unhealthy?

10. What happens when a Pod becomes unhealthy?

<details>
<summary>Answer</summary>

Failed readiness removes the Pod from Service endpoints. Traffic goes to ready Pods. Failed liveness can restart the container.

Running ≠ ready. Check `kubectl get endpoints` and `kubectl describe pod`.

</details>

---

## 11. How will deployments be rolled back?

11. How will deployments be rolled back?

<details>
<summary>Answer</summary>

`kubectl rollout status`, `kubectl rollout history`, then `kubectl rollout undo deployment/shopsphere-api`.

Safe only if the previous image still fits current schema and infra. App rollback is not a database rollback.

</details>

---

## 12. How will database changes remain compatible?

12. How will database changes remain compatible?

<details>
<summary>Answer</summary>

Use expand-and-contract so v1 and v2 can overlap during a rolling update.

A Kubernetes rollout is a release strategy. Schema must fit both versions in that window.

</details>

---

## 13. Who can deploy to Production?

13. Who can deploy to Production?

<details>
<summary>Answer</summary>

The Production deploy identity through Helm or GitOps, after promotion and approval. Developers do not apply YAML on the Prod cluster from a laptop.

RBAC plus cloud IAM enforce that.

</details>

---

## 14. Who can read Kubernetes Secrets?

14. Who can read Kubernetes Secrets?

<details>
<summary>Answer</summary>

Only identities that need them: the workload and a tight operator role. Broad `get secrets` in Prod is a data leak.

Prefer cloud secret stores and least privilege on the Kubernetes API.

</details>

---

## 15. How are namespaces isolated?

15. How are namespaces isolated?

<details>
<summary>Answer</summary>

A namespace is an org and policy boundary, not an account. Add RBAC, NetworkPolicy, ResourceQuota, LimitRange, and cloud identity.

Dev/UAT/Prod as namespaces in one cluster still share cluster blast radius.

</details>

---

## 16. How are workloads protected from unnecessary network access?

16. How are workloads protected from unnecessary network access?

<details>
<summary>Answer</summary>

Allow Frontend→API, API→database, required AWS paths, and monitoring. Deny other namespaces.

NetworkPolicy adds a layer. It does not replace security groups, firewalls, or IAM.

</details>

---

## 17. What does Terraform own?

17. What does Terraform own?

<details>
<summary>Answer</summary>

Platform infrastructure: VPC, EKS/AKS, node groups, IAM, security groups, load-balancer integration, cloud resources.

Do not put every Kubernetes object in Terraform just because you can.

</details>

---

## 18. What does Helm/GitOps own?

18. What does Helm/GitOps own?

<details>
<summary>Answer</summary>

Application objects: Namespace, Deployment, Service, Ingress, ConfigMap, HPA, NetworkPolicy, PDB.

Helm packages charts and values. GitOps reconciles Git desired state to the cluster. Keep one owner per resource.

</details>

---

## 19. How will cluster upgrades be handled?

19. How will cluster upgrades be handled?

<details>
<summary>Answer</summary>

Upgrade the managed control plane, then node pools, with PDBs and capacity so ShopSphere keeps minAvailable. Test in Dev/UAT first.

Upgrades are planned operations, not a surprise node recycle.

</details>

---

## 20. How will you know Kubernetes is actually improving the platform?

20. How will you know Kubernetes is actually improving the platform?

<details>
<summary>Answer</summary>

Measure checkout success, latency, deploy safety, and engineering time, not “the cluster is green.”

If capability gained does not beat operational cost and complexity, the ADR is wrong.

</details>

---

## 21. Rehost vs re-platform vs refactor — which is Day 37?

Without looking at the lesson, explain:

```text
Rehost vs re-platform vs refactor (which one is this project?)
```

This kind of move has a name, and recent job descriptions use the vocabulary directly. Migration teams commonly describe three types. A rehost (also called lift and shift) moves a system as it is, for example the same VM moved from an on-prem datacentre to a cloud VM. A re-platform keeps the application and its code the same but runs it on a new runtime platform with small changes, which is exactly what Day 37 does: the same ShopSphere image moves from the managed container runtime to Kubernetes. A refactor changes the application's design or code to fit the cloud. The trade-off runs in one direction: the more you change, the more benefit you can unlock, but the more risk and effort the migration carries.

```text
Type          What changes                       Example                               Risk / effort
Rehost        Nothing in the app                 On-prem VM → cloud VM                 Lowest
Re-platform   Runtime platform, small changes    Same image → Kubernetes (Day 37)      Medium
Refactor      Application design or code         Redesign app for cloud services       Highest
```

Whatever the type, real programmes that migrate many applications do not move everything at once. They move in small batches, often called waves, with a rollback boundary defined for each batch. That is the incremental path above plus the Part 36 rollback boundary, applied at scale.

<details>
<summary>Answer</summary>

This project is a re-platform: the same ShopSphere image moves from the managed container runtime to Kubernetes with small platform changes.

Rehost moves a VM as-is. Refactor changes app design. More change unlocks more benefit and more risk. Move in waves with a rollback boundary.

</details>

---

## 22. Failure drill: Service has no backends

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

<details>
<summary>Answer</summary>

Break the selector. `kubectl get svc`, `kubectl get endpoints`, `kubectl get pods --show-labels`, `kubectl describe svc shopsphere-api`.

DNS and the Service exist. Endpoints are empty. Healthy Pods do not help if the Service cannot select them. Fix the selector.

</details>

---

## 23. Failure drill: Pod running but traffic fails

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

<details>
<summary>Answer</summary>

Fail readiness. Pod is Running, Ready is False. `kubectl get endpoints shopsphere-api` omits it.

Process exists; Kubernetes keeps it off traffic. This is production traffic control.

</details>

---

## 24. Failure drill: deployment causes 5xx

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

<details>
<summary>Answer</summary>

Deploy a broken version in non-prod. Use `kubectl rollout status`, `history`, `kubectl get pods`, `describe`, `logs`. Then `kubectl rollout undo`.

Ask what failed, when, why Kubernetes called it available, what detected it, why undo worked, and which gate should have caught it.

</details>

---

## 25. Failure drill: database connectivity

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

<details>
<summary>Answer</summary>

Walk app → DNS → network → security → port → engine → credentials. Check cloud SG/NACL and `kubectl get networkpolicy`.

`kubectl exec` into the Pod to test. Pod-to-Pod success does not prove Pod-to-database.

</details>

---

## 26. Failure drill: resource exhaustion

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

<details>
<summary>Answer</summary>

Set low limits. Watch pressure, OOM, throttling. `kubectl describe pod`, `kubectl top pod`, `kubectl top node`.

Name the bottleneck: container, Pod, node, cluster, database, or external API. Do not scale blindly.

</details>

---

## 27. Hands-on migration (expected outcome)

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

<details>
<summary>Answer</summary>

Deploy the same image into a namespace with Deployment, Service, probes, requests/limits, ConfigMap, secret integration, workload identity, Ingress, NetworkPolicy, HPA, and PDB.

Prove DNS → Ingress → Service → endpoints → Pods → app → database → telemetry. `Running` is not the finish.

</details>

---

## 28. Production migration plan (expected outcome)

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

<details>
<summary>Answer</summary>

Runbook: pre-checks, capacity, schema, image, manifests, secrets, identity, network, DNS, observability, rollback, traffic shift, verify, retire old runtime.

Before shift, old runtime stays up. If Kubernetes is unhealthy, return traffic. Migration is not irreversible.

</details>

---

## 29. 5-minute recall: user request path

Without looking at the lesson, explain:

```text
Why Kubernetes?
Rehost vs re-platform vs refactor (which one is this project?)
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

<details>
<summary>Answer</summary>

User → DNS → load balancer / Ingress → Service → ready Pod → application → private database.

ShopSphere gained node, network, identity, policy, upgrade, and rollout operations. The provider did not take those.

</details>

---

## 30. Cost and operational trade-off

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

<details>
<summary>Answer</summary>

Bill: control plane, nodes, LBs, storage, logs, traffic. Also engineer time, upgrades, and platform work.

Compare capability gained against that cost. “Kubernetes is better” is not an architecture argument.

</details>

---

## 31. Azure ↔ AWS mapping (Kubernetes)

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

<details>
<summary>Answer</summary>

AKS↔EKS, VNet↔VPC, Azure LB/App Gateway↔AWS LB/ALB, workload identity↔IRSA/Pod Identity, Key Vault↔Secrets Manager, ACR↔ECR.

Map the Kubernetes concept to cloud integration, then security, networking, and operations. Names are secondary.

</details>

---

## Day 37 Completion Criteria

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
