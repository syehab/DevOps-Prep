# Day 30 — Questions and answers

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Then answer each item below before you open the Answer block. After that, do the lab in [03-implementation.md](03-implementation.md).

Write your own answer first. Open the Answer block only after you try. Keep the original numbering.

---

## Part 18 — Final Interview Drill

Answer these without looking at your notes.

## 1. Journey of an HTTP request from a user to Spring Boot

Explain the complete journey of an HTTP request from a user to a Spring Boot application.

<details>
<summary>Answer</summary>

User → DNS → load balancer or ingress → Service or target group → Pod/task/instance → Spring Boot on 8080. Then the app may call private PostgreSQL on 5432.

Name every hop: who starts it, which name, which IP, which route, which security rule, which port. That is the production path, not a service catalog.

</details>

---

## 2. DNS is correct but the connection still fails

Explain what happens when DNS resolves correctly but the connection still fails.

<details>
<summary>Answer</summary>

Resolution succeeded. The packet still needs a route, an allow rule, an open port, a listening process, and a healthy app. Walk IP → route → security → port → service → application.

A public IP from DNS when you expected a private endpoint is a different failure: the path is wrong even though “DNS worked.”

</details>

---

## 3. Authentication vs authorization

Explain the difference between authentication and authorization.

<details>
<summary>Answer</summary>

Authentication proves who the principal is. Authorization decides what that principal may do.

A federated pipeline can authenticate and still get `AccessDenied` if RBAC or IAM denies the action.

</details>

---

## 4. Why workload identity beats long-lived access keys

Explain why workload identity is preferable to long-lived access keys.

<details>
<summary>Answer</summary>

Roles and managed identities vend short-lived tokens. Keys in Git, images, and YAML leak and stay valid.

If the identity is stolen, blast radius is the role’s scope. Keys multiply that risk.

</details>

---

## 5. Why application and infrastructure pipelines are often separated

Explain why application and infrastructure pipelines are often separated.

<details>
<summary>Answer</summary>

A Java change should not run `terraform apply`. A node-pool change should not rebuild the JAR.

Separate repos, identities, and approvals keep application risk off infrastructure state.

</details>

---

## 6. Why promote the same artifact across environments

Explain why the same artifact should be promoted across environments.

<details>
<summary>Answer</summary>

Production must run the bytes that passed UAT. A new build can differ even from the same Git SHA.

Pin the image digest. Move that digest Dev → UAT → Prod.

</details>

---

## 7. Terraform state, remote state, and locking

Explain Terraform state and why teams need remote state and locking.

<details>
<summary>Answer</summary>

State maps config to real resources. Remote state (Azure Storage or S3) gives one team copy. Locking stops two applies from corrupting it.

State can hold secrets. Restrict IAM, encrypt, version, and split by environment.

</details>

---

## 8. How you would investigate Terraform drift

Explain how you would investigate Terraform drift.

<details>
<summary>Answer</summary>

Do not auto-apply. Ask what changed, who changed it, whether it was intentional. Accidental: reconcile to code. Intentional: update Terraform. External owner: stop fighting that attribute.

Detect → investigate → reconcile or codify → prevent recurrence.

</details>

---

## 9. Load balancer vs route table vs security rule

Explain the difference between a load balancer, route table, and security rule.

<details>
<summary>Answer</summary>

A load balancer distributes traffic to healthy targets. A route table chooses the next hop. A security rule (NSG or Security Group) allows or denies the packet.

Wrong path is routing. Correct path but dropped is security. Healthy targets are a load-balancer concern.

</details>

---

## 10. How a private application reaches a public internet endpoint

Explain how a private application reaches a public internet endpoint.

<details>
<summary>Answer</summary>

Private subnet default route to NAT (or hub firewall SNAT) → Internet Gateway → public API. The app has no public IP.

Inbound still uses the load balancer. Outbound is a different path.

</details>

---

## 11. How a private application reaches a managed cloud service privately

Explain how a private application reaches a managed cloud service privately.

<details>
<summary>Answer</summary>

Private Endpoint or VPC endpoint plus private DNS so the usual hostname returns a private IP. Route locally. Filter with NSG or Security Group.

If DNS is still public, you never take the private path.

</details>

---

## 12. Why a container can be running while the application is unhealthy

Explain why a container can be running while the application is unhealthy.

<details>
<summary>Answer</summary>

`Running` means the process has not exited. The app can still return 503, fail `/health`, or miss the database.

Use probes, target health, and logs. Do not trust process state alone.

</details>

---

## 13. Readiness vs liveness vs startup probes

Explain readiness vs liveness vs startup health checks.

<details>
<summary>Answer</summary>

Readiness: stop sending traffic until ready. Liveness: restart if stuck. Startup: give a slow JVM time before liveness fires.

Wrong probes either flap Pods or send users to a booting app.

</details>

---

## 14. How Kubernetes Services give stable access to temporary Pods

Explain how Kubernetes Services provide stable access to temporary Pods.

<details>
<summary>Answer</summary>

A Service keeps a stable name and virtual IP. Endpoints track ready Pods. Pods can die and be replaced.

Clients talk to the Service, not to Pod IPs.

</details>

---

## 15. How HPA differs from node scaling

Explain how HPA differs from node scaling.

<details>
<summary>Answer</summary>

HPA adds or removes Pods. Cluster autoscaler or node pools add nodes when Pods cannot schedule.

More Pods on a full node does nothing. Scale the layer that is actually short.

</details>

---

## 16. Why Helm and GitOps are not the same thing

Explain why Helm and GitOps are not the same thing.

<details>
<summary>Answer</summary>

Helm packages and templates Kubernetes YAML. GitOps (Argo CD or Flux) continuously reconciles cluster state from Git.

You can Helm without GitOps. You can GitOps without Helm. Together they are a delivery model.

</details>

---

## 17. Pipeline identity vs runtime identity

Explain the difference between pipeline identity and runtime identity.

<details>
<summary>Answer</summary>

Pipeline identity builds, pushes, and deploys. Runtime identity is the app’s role for Key Vault, S3, or RDS.

Do not give the Spring Boot task the permission to update ECS.

</details>

---

## 18. How you would secure a CI/CD supply chain

Explain how you would secure a CI/CD supply chain.

<details>
<summary>Answer</summary>

Protect `main`, review PRs, SAST/SCA and image scan, federated identities, no Prod creds on untrusted PRs, digest pinning, and environment approvals.

The pipeline is part of the product. Treat YAML and agents as attack surface.

</details>

---

## 19. Zero or minimal-downtime deployment

Explain how you would perform a zero/minimal-downtime deployment.

<details>
<summary>Answer</summary>

Roll new instances or tasks behind health checks, or use blue/green or slots, then shift traffic. Keep enough old capacity until new is ready.

Schema must stay compatible. Command success is not user success.

</details>

---

## 20. Why database migrations complicate rollback

Explain why database migrations complicate rollback.

<details>
<summary>Answer</summary>

Application v2 may require schema v2. Reverting the app to v1 does not undo an irreversible migration.

Plan backward-compatible migrations, expand/contract, or a data rollback path before you ship.

</details>

---

## 21. Investigate a sudden increase in HTTP 5xx

Explain how you would investigate a sudden increase in HTTP 5xx errors.

<details>
<summary>Answer</summary>

Check deploy time, error rate, which endpoint, which instances, target health, logs, traces, and one dependency. Do not restart everything.

CPU normal does not mean the app is healthy. Start with evidence.

</details>

---

## 22. How metrics, logs, and traces complement each other

Explain how metrics, logs, and traces complement each other.

<details>
<summary>Answer</summary>

Metrics show what is happening (rate, errors, latency). Logs show the exception. Traces show which span ate the time.

Use a correlation ID across all three.

</details>

---

## 23. Dev/UAT/Prod isolation in Azure

Explain how you would design Dev/UAT/Prod isolation in Azure.

<details>
<summary>Answer</summary>

Entra tenant → management groups → separate subscriptions (or strongly split RGs) → resource groups. Tighter RBAC and Policy on Prod. Separate Terraform state and pipeline identities.

Subscriptions isolate billing, quota, and blast radius better than names in one subscription.

</details>

---

## 24. Dev/UAT/Prod isolation in AWS

Explain how you would design Dev/UAT/Prod isolation in AWS.

<details>
<summary>Answer</summary>

Organization → OUs → separate accounts. SCPs on Prod. IAM Identity Center permission sets. Separate VPCs, roles, and state.

Accounts are stronger isolation than three VPCs in one account.

</details>

---

## 25. Cross-account AWS deployment

Explain how you would design cross-account AWS deployment.

<details>
<summary>Answer</summary>

CI in a tooling account assumes a deploy role in the target account via STS or OIDC. Trust is tight. IAM on the role is least privilege. SCP still applies.

The pipeline is not org admin.

</details>

---

## 26. Terraform for multiple environments

Explain how you would design Terraform for multiple environments.

<details>
<summary>Answer</summary>

One module, environment folders or workspaces with separate backends: `dev/`, `uat/`, `prod/`. Different variable files and roles. Plan then approved apply.

Never one state file for all environments.

</details>

---

## 27. Reduce cloud cost without blindly cutting capacity

Explain how you would reduce cloud cost without blindly reducing capacity.

<details>
<summary>Answer</summary>

Find the driver: compute, NAT, logs, idle non-prod, data transfer. Right-size, schedule non-prod, cap log retention, use endpoints instead of NAT where it fits.

Do not drop Production HA to save money. Cost is a constraint next to reliability.

</details>

---

## 28. Azure VNet vs AWS VPC

Explain the difference between an Azure VNet and AWS VPC.

<details>
<summary>Answer</summary>

Both are the private IP network boundary with subnets, routes, and filtering. Azure uses NSGs and UDRs. AWS uses route tables, Security Groups, and NACLs.

Same job, different knobs. Do not force one-to-one product names.

</details>

---

## 29. Azure RBAC vs AWS IAM

Explain the difference between Azure RBAC and AWS IAM.

<details>
<summary>Answer</summary>

Azure RBAC is scope-based roles on management groups, subscriptions, RGs, and resources. AWS IAM is identity policies plus resource policies plus SCPs.

Both separate authentication from authorization. Evaluation layers differ.

</details>

---

## 30. AKS vs EKS at an architectural level

Explain the difference between AKS and EKS at an architectural level.

<details>
<summary>Answer</summary>

Both are managed Kubernetes control planes. You still own node pools or Fargate, CNI, IAM/workload identity, ingress, and workloads.

Azure wraps VNet, AAD/Entra, and ACR. AWS wraps VPC, IAM, and ECR. Kubernetes concepts stay; the cloud attachments change.

</details>

---

If you cannot answer a question, do not immediately reread the entire lesson. Identify the layer you are missing and revisit only that lesson.

---

## 31. Design ShopSphere modernization from Part 2 requirements

You are the Lead DevOps Engineer for a company called **ShopSphere**, an e-commerce platform.

The current application is a Spring Boot monolith with an Angular frontend and a relational database. The company wants to modernize the platform and support customers across multiple geographic regions.

The requirements are:

- Spring Boot backend
- Angular frontend
- Relational database
- Containerized application
- Separate Dev, UAT, and Production environments
- Production must have high availability
- Zero/minimal downtime deployments
- Infrastructure must be managed as code
- Secrets must not be stored in Git
- Developers should not have direct Production infrastructure access
- CI/CD must automatically build and test changes
- Production deployment requires controlled promotion
- Application and infrastructure changes should be traceable
- Monitoring and alerting are required
- The platform must support incident investigation
- Cloud cost should be controlled
- Architecture should be portable enough to support both Azure and AWS concepts

Your first task is to design the system without worrying about the exact cloud products.

Start with:

```text
Users
 ↓
DNS
 ↓
Frontend
 ↓
API
 ↓
Database
```

Then add the engineering layers:

```text
Users
 ↓
DNS / Traffic Management
 ↓
Frontend
 ↓
Load Balancing
 ↓
Application Runtime
 ↓
Database

Around the system:
Identity
Security
Secrets
CI/CD
IaC
Observability
Governance
Cost
```

Do not immediately add Kubernetes, service meshes, Kafka, microservices, or other technologies just because they are available. Every additional component introduces operational cost and another failure mode.

<details>
<summary>Answer</summary>

Users → DNS → load balancer → containerized Spring Boot (managed containers unless Kubernetes is required) → private relational database. Angular on static hosting or the same ingress. Dev/UAT/Prod isolated. IaC with Terraform. Secrets in Key Vault or Secrets Manager. CI builds once and promotes a digest. Prod needs approval, HA across AZs, monitoring, alerts, and traceability.

Do not add Kafka, mesh, or microservices without a requirement. Every extra box is a failure mode. Map the same design onto Azure or AWS products second.

</details>

---

## 32. Incident: post-deploy partial 5xx, CPU normal, then `UnknownHostException: payments.internal`

At 10:15 AM, a new version of ShopSphere is deployed.

At 10:18 AM:

- HTTP 5xx errors increase.
- CPU is normal.
- Memory is normal.
- Database CPU is normal.
- The deployment pipeline reports success.
- Some users can access the application.
- Others receive errors.

Do not restart everything.

Start with evidence.

Ask:

```text
Did the failure begin with the deployment?
        ↓
Which application instances are affected?
        ↓
Are healthy instances receiving traffic?
        ↓
Are load-balancer health checks correct?
        ↓
Are all instances running the same artifact?
        ↓
Are requests failing on a specific endpoint?
        ↓
Are logs showing a common exception?
        ↓
Is a dependency failing?
```

Now imagine the logs show:

```text
UnknownHostException: payments.internal
```

Your troubleshooting path changes immediately.

This is no longer primarily a CPU problem. Investigate:

```text
Application
 ↓
DNS resolution
 ↓
Private DNS
 ↓
Network path
 ↓
Security rules
 ↓
Payments service
```

This illustrates why observability and the network mental model must work together.

<details>
<summary>Answer</summary>

Do not restart everything. Correlate 10:15 deploy with 10:18 errors. Check which instances, target health, same digest, which endpoint, and logs. When logs show `UnknownHostException: payments.internal`, switch to DNS → private DNS → route → security → payments service.

This is not a CPU incident. Observability plus the network sequence finds it.

</details>

---

## 33. Pipeline success, users see 503

The pipeline reports:

```text
Deployment successful
```

Users report:

```text
503 Service Unavailable
```

Your first principle should be:

**Deployment success does not equal application success.**

Check:

```text
Load Balancer
 ↓
Target health
 ↓
Service / Deployment
 ↓
Pod / Task / Instance
 ↓
Container
 ↓
Application process
 ↓
Application logs
```

Then check the release itself:

```text
Running image digest
 ↓
Expected image digest
 ↓
Pipeline artifact
 ↓
Git commit
```

This prevents a common mistake: investigating the wrong application version.

<details>
<summary>Answer</summary>

Deployment success is not application success. Walk load balancer → target health → Service/Deployment → Pod/task → process → logs. Compare running digest with the expected digest and Git SHA.

You may be debugging the wrong version if the digest does not match.

</details>

---

## 34. Unexpected Terraform plan — drift

Terraform reports a change that you did not expect.

Do not automatically apply.

First determine:

```text
What changed?
 ↓
Who changed it?
 ↓
Why was it changed?
 ↓
Was it intentional?
 ↓
Should the configuration reflect it?
 ↓
Or should the infrastructure be reconciled?
```

If the change was accidental, reconcile the resource with the desired configuration.

If the change was intentional and should remain, update the Terraform configuration so the desired state reflects reality.

If another system legitimately owns the attribute, redesign ownership rather than fighting the external controller.

The Senior/Lead principle is:

**Detect → Investigate → Reconcile or Codify → Prevent recurrence.**

<details>
<summary>Answer</summary>

Do not apply. Identify the attribute, actor, and intent. Accidental portal edit: apply to restore code. Intentional ops change: update Terraform. Another controller owns it: change ownership.

Locking and pipeline-only Prod applies prevent a class of this drift.

</details>

---

## 35. Monthly bill too high

The platform works, but the monthly bill is much higher than expected.

Do not immediately reduce instance sizes.

First identify the cost driver.

Ask:

```text
Which service costs the most?
        ↓
Which resource generates that cost?
        ↓
Is usage expected?
        ↓
Is the resource required?
        ↓
Is it right-sized?
        ↓
Can it scale?
        ↓
Can it be scheduled?
        ↓
Can architecture reduce the cost?
```

Typical cloud cost drivers can include compute, databases, NAT gateways, load balancers, data transfer, storage, logging, and idle resources.

Cost optimization is therefore not simply “use the cheapest service.” A cheaper component can create higher operational cost, lower reliability, or additional engineering work.

At Senior/Lead level, cost is an architectural constraint alongside security, reliability, and performance.

<details>
<summary>Answer</summary>

Name the top services first: compute, database, NAT, logs, idle non-prod. Right-size, sleep Dev, shorten log retention, private endpoints to cut NAT. Keep Prod HA.

A cheaper runtime that doubles incidents is not cheaper. Cost sits beside security and reliability.

</details>

---

## 36. Guardrails for 50 teams on Azure and AWS

Imagine 50 engineering teams are deploying workloads into the organization.

Without governance, every team may create:

- different naming conventions
- different network designs
- excessive permissions
- unmanaged public endpoints
- inconsistent logging
- untagged resources
- expensive idle resources
- manually created production infrastructure

Governance should establish guardrails without turning the platform team into a bottleneck.

For Azure, think about:

```text
Tenant
 ↓
Management Groups
 ↓
Subscriptions
 ↓
Resource Groups
 ↓
Resources

Policy + RBAC + Tags + Budgets
```

For AWS:

```text
Organization
 ↓
OUs
 ↓
Accounts
 ↓
Resources

SCPs + IAM + Config + Tags + Budgets
```

The important distinction is between **central governance** and **application ownership**. The platform organization establishes guardrails; workload teams should still own their applications and day-to-day delivery.

<details>
<summary>Answer</summary>

Azure: management groups, Policy, RBAC, tags, budgets. AWS: OUs, SCPs, IAM, Config, tags, budgets. Platform owns templates, identity patterns, and network hub. Teams own app code and resource-group or account-scoped delivery.

Guardrails without a ticket for every VM. Central governance, local ownership.

</details>

---

## Part 17 — Architecture Communication Exercise

## 37. Why managed containers instead of Kubernetes?

Imagine an interviewer asks:

> “Why did you choose managed containers instead of Kubernetes?”

Do not answer with a product comparison.

Answer using requirements:

> “The application is containerized and needs long-running services, but the current requirements do not require Kubernetes-specific orchestration capabilities. A managed container platform reduces operational responsibility while still giving us container deployment, scaling, identity, networking, and observability. If future requirements introduce Kubernetes-specific capabilities or an organizational Kubernetes platform standard, we can reconsider AKS/EKS.”

<details>
<summary>Answer</summary>

The app is containerized and long-running. Current requirements do not need Kubernetes APIs, operators, or cluster networking. A managed container platform gives deploy, scale, identity, and observability with less cluster work.

If Kubernetes becomes a platform standard or a real capability need, reconsider AKS/EKS. Requirement → decision → reason → trade-off → alternative.

</details>

---

## 38. Why separate Production into another account or subscription?

Now imagine:

> “Why did you separate Production into another account/subscription?”

A strong answer focuses on isolation:

> “The separate environment boundary reduces blast radius and gives us stronger isolation for identity, governance, quotas, billing, and operational access. Production can therefore have stricter permissions and deployment controls than lower environments.”

The pattern is:

**Requirement → Decision → Reason → Trade-off → Alternative**

This is one of the most useful Senior/Lead interview patterns.

<details>
<summary>Answer</summary>

The boundary reduces blast radius for identity, governance, quotas, billing, and access. Production can use stricter permissions and approvals than Dev.

A naming convention in one account is weaker isolation.

</details>

---

## Part 19 — The 10-Minute Whiteboard Test

## 39. 10-minute whiteboard: ShopSphere production from memory

Set a timer for 10 minutes.

Draw a production architecture for ShopSphere from memory.

Your drawing should include:

```text
Users
 ↓
DNS
 ↓
Ingress / Load Balancer
 ↓
Application
 ↓
Database
```

Then add:

```text
CI/CD
Terraform
Identity
Secrets
Monitoring
Logging
Security
Networking
Dev/UAT/Prod
Backup / Recovery
Cost / Governance
```

Now explain the architecture aloud.

For every major component, answer:

**Why is it here?**

**Who owns it?**

**How does it communicate?**

**How is it secured?**

**How does it scale?**

**How does it fail?**

**How do I detect failure?**

**How do I recover?**

**What does it cost?**

**What would I change at 10× the scale?**

This is more valuable than memorizing another 100 cloud-service definitions.

<details>
<summary>Answer</summary>

Draw users → DNS → LB → app → private DB. Add CI/CD, Terraform, identity, secrets, monitoring, logs, security, network, Dev/UAT/Prod, backup, cost. For each box say why, owner, communication, security, scale, failure, detection, recovery, cost, and 10× change.

If you cannot explain a box, it does not belong on the board.

</details>

---

## Part 23 — Final Course Completion Exercise

## 40. `Senior-DevOps-Production-Architecture.md` with the 20 sections

Create one final artifact called:

**`Senior-DevOps-Production-Architecture.md`**

It should contain:

1. Business requirements
2. Architecture diagram
3. Azure implementation
4. AWS implementation
5. Network design
6. Identity model
7. Security model
8. Terraform structure
9. CI/CD architecture
10. Deployment strategy
11. Secrets architecture
12. Observability architecture
13. High-availability design
14. Disaster-recovery approach
15. Cost controls
16. Governance model
17. Failure scenarios
18. Troubleshooting workflows
19. Architecture decisions and trade-offs
20. Future scaling considerations

Do not copy the lessons.

Build the document from your own understanding.

That document becomes your final proof that the 30-day curriculum has turned individual topics into one coherent engineering model.

<details>
<summary>Answer</summary>

Write the document from your own design, not copied lessons: business, diagram, Azure, AWS, network, identity, security, Terraform, CI/CD, deploy, secrets, observability, HA, DR, cost, governance, failures, troubleshooting, ADRs, and 10× scale.

That file is the course proof. Keep it as a revision artifact with diagrams and decisions, not a command dump.

</details>
