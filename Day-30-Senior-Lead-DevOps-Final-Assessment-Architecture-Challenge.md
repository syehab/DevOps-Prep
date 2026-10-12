# Day 30 — Senior/Lead DevOps Final Assessment & Architecture Challenge

Day 30 is different from the previous lessons. You are not learning another cloud service. You are proving that you can connect the concepts from the previous 29 days into one production-grade engineering approach. The focus is on **reasoning, architecture, troubleshooting, security, reliability, cost, and communication** — the skills that separate a Senior/Lead DevOps engineer from someone who mainly knows commands and tools.

---

## Part 1 — The Senior/Lead DevOps Mental Model

A Senior/Lead DevOps engineer should be able to look at a business requirement and move through the system from left to right: **Business → Application → Delivery → Infrastructure → Network → Identity → Runtime → Observability → Operations → Cost → Governance**. You should not start by choosing Azure or AWS services. First understand what the system needs: availability, latency, security, deployment frequency, recovery objectives, compliance, expected traffic, team ownership, and budget. Then choose the simplest architecture that satisfies those requirements. The technology is the implementation; the reasoning is the engineering skill.

When someone asks you to design a platform, use this sequence:

```text
What does the business need?
        ↓
What does the application need?
        ↓
Where should it run?
        ↓
How does traffic flow?
        ↓
How does it authenticate?
        ↓
How is it deployed?
        ↓
How is it observed?
        ↓
How does it fail?
        ↓
How does it recover?
        ↓
What does it cost?
        ↓
How is it governed?
```

The goal is not to produce the most complicated architecture. The goal is to produce an architecture you can explain, operate, secure, troubleshoot, and justify.

---

## Part 2 — Final Architecture Scenario

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

---

## Part 3 — Architecture Decision: Compute

You have several possible runtime models: virtual machines, managed application platforms, managed containers, container orchestration platforms, or serverless functions.

Your decision should start with the application characteristics rather than the service name. Ask: Does the application need long-running processes? Does it need container-level control? Does it require Kubernetes? How much operational control does the team need? What scaling pattern exists? What networking and security requirements exist? What is the team's operational maturity?

For ShopSphere, a containerized Spring Boot application could run on a managed container platform without Kubernetes, if it does not need Kubernetes-specific capabilities. If the organization already operates Kubernetes at scale and needs its ecosystem, AKS/EKS becomes reasonable. A VM-based architecture gives more control but increases infrastructure responsibility.

The Senior/Lead answer is therefore not “Kubernetes is better.” It is: **choose the runtime according to workload requirements, operational responsibility, team capability, and cost.**

---

## Part 4 — Architecture Decision: Networking

Design the network around traffic paths.

For an internet-facing application:

```text
Internet
   ↓
DNS
   ↓
Public entry point / Load Balancer
   ↓
Application
   ↓
Private Database
```

The database should not normally be directly exposed to the public internet. Application workloads should reach it through private networking and controlled security rules.

Your troubleshooting model should remain:

```text
DNS
 ↓
Destination IP
 ↓
Route
 ↓
Security
 ↓
Port
 ↓
Service
 ↓
Application
```

Azure and AWS implement these ideas using different products, but the underlying model is the same.

Azure:

```text
VNet
 ├── Public/Ingress Subnet
 ├── Application Subnet
 └── Database/Private Connectivity
```

AWS:

```text
VPC
 ├── Public Subnet
 ├── Private Application Subnet
 └── Private Database Subnet
```

At Senior/Lead level, explain why the network allows the traffic, where it filters the traffic, how outbound traffic works, and how DNS resolves private resources.

---

## Part 5 — Architecture Decision: Identity

Separate three questions:

**Who is the person or workload?**

**How is that identity authenticated?**

**What is that identity authorized to do?**

For cloud workloads, prefer workload identities/roles over long-lived access keys wherever the platform supports them.

The identity model should look roughly like:

```text
Developer
   ↓
Source / CI platform

Pipeline Identity
   ↓
Build / Registry / Deployment

Application Identity
   ↓
Runtime resources

Terraform Identity
   ↓
Infrastructure resources
```

Do not give the Spring Boot application's runtime identity permissions simply because the deployment pipeline needs them.

For Production, access should be deliberately restricted. A developer may be able to inspect logs and deploy through the approved pipeline without being able to directly modify the production network or database.

The key Senior/Lead question is:

**If this identity is compromised, what is the maximum damage it can cause?**

---

## Part 6 — Architecture Decision: CI/CD

Design the delivery path as:

```text
Git Commit
   ↓
Build
   ↓
Unit Tests
   ↓
Security Checks
   ↓
Container Build
   ↓
Container Registry
   ↓
Dev
   ↓
UAT
   ↓
Production Approval
   ↓
Production
   ↓
Health Verification
```

The same principle applies whether the implementation uses Azure DevOps or AWS-native tooling.

For Azure:

```text
Azure Repos / GitHub
        ↓
Azure Pipelines
        ↓
ACR
        ↓
AKS / Container Apps / App Service
```

For AWS:

```text
GitHub / CodeCommit
        ↓
CodePipeline + CodeBuild
        ↓
ECR
        ↓
ECS / EKS
```

Build once and promote the same artifact.

A deployment should be traceable:

```text
Git SHA
 ↓
Pipeline Run
 ↓
Build
 ↓
Image Digest
 ↓
Deployment
 ↓
Running Workload
```

If you cannot trace a Production workload back to its source change, your delivery platform has a serious operational weakness.

---

## Part 7 — Architecture Decision: Terraform and Infrastructure

Separate application delivery from infrastructure delivery.

Application pipeline:

```text
Application Code
 ↓
Build
 ↓
Test
 ↓
Image
 ↓
Deploy
```

Infrastructure pipeline:

```text
Terraform Code
 ↓
Format / Validate
 ↓
Security / Policy
 ↓
Plan
 ↓
Review / Approval
 ↓
Apply
 ↓
Verify
```

Terraform state must have an enterprise-safe design: remote storage, controlled access, state locking, versioning/recovery, and appropriate separation between environments or workloads.

Never treat Terraform state as an ordinary file. It is part of the control system that allows Terraform to understand managed infrastructure.

The Senior/Lead question is:

**What happens if two engineers or pipelines attempt to change the same infrastructure at the same time?**

Your answer should include state locking and controlled pipeline execution.

---

## Part 8 — Architecture Decision: Secrets

The application needs:

- database credentials
- JWT signing material
- third-party API credentials
- potentially cloud-service credentials

Do not commit any of them to Git.

A production flow is:

```text
Secret Store
    ↓
Runtime Identity
    ↓
Application
```

Azure commonly uses Key Vault. AWS commonly uses Secrets Manager and/or Parameter Store depending on the type of configuration.

The important principle is not the product name. It is:

**Store secrets centrally, control access through identity, avoid embedding them in source or images, and minimize where they are exposed.**

Also consider the pipeline itself. Build logs can accidentally expose secrets. A step can print environment variables. Debug commands can leak credentials. Container images can permanently preserve values copied into layers.

---

## Part 9 — Architecture Decision: Reliability

High availability does not simply mean “run two instances.”

Ask where the failure boundaries are.

For example:

```text
                    Load Balancer
                   /             \
               App 1             App 2
                 \                 /
                  \               /
                    Database
```

If both application instances run on the same failed node, availability may still be lost. If both are in the same Availability Zone, an AZ failure can affect both.

Therefore think in terms of **failure domains**:

```text
Process
 ↓
Container
 ↓
Node
 ↓
Availability Zone
 ↓
Region
 ↓
Cloud / External Dependency
```

Your architecture should place critical redundancy across meaningful failure boundaries.

Also distinguish:

- availability
- durability
- scalability
- recoverability

They are related but not the same thing.

---

## Part 10 — Architecture Decision: Deployment and Rollback

Suppose version `2.0` introduces a production problem.

A good deployment architecture should allow you to:

1. Detect the problem.
2. Stop further traffic exposure.
3. Determine whether rollback is safe.
4. Restore the previous known-good version if appropriate.
5. Preserve evidence for investigation.
6. Correct the underlying issue.

A deployment strategy might be:

```text
Old Version
     ↓
New Version
     ↓
Health Checks
     ↓
Controlled Traffic
     ↓
Observe
     ↓
Continue or Roll Back
```

But application rollback and database rollback are different problems.

For example:

```text
Application v1
Database schema v1

        ↓ migration

Application v2
Database schema v2
```

If the database migration is irreversible, simply deploying Application v1 again may not restore compatibility.

Therefore production deployment design must consider **application compatibility, database compatibility, backward/forward-compatible migrations, and rollback strategy**.

---

## Part 11 — Architecture Decision: Observability

A production platform should answer three questions:

**What is happening?**

Metrics.

**What happened?**

Logs.

**Where did this request go?**

Traces.

For an API, useful signals include:

- request rate
- error rate
- latency
- saturation
- CPU/memory
- database connections
- dependency failures
- deployment changes

Use correlation IDs so you can follow a request across components.

The operational chain is:

```text
Metrics / Logs / Traces
          ↓
       Alert
          ↓
      Incident
          ↓
    Investigation
          ↓
      Recovery
          ↓
        RCA
          ↓
    Improvement
```

Monitoring without actionable alerts creates noise. Alerts should identify conditions that require attention rather than simply report every unusual metric.

---

## Part 12 — Production Incident Challenge

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

---

## Part 13 — Second Incident: Deployment Succeeded but Application Is Down

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

---

## Part 14 — Third Incident: Terraform Drift

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

---

## Part 15 — Cost Engineering Challenge

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

---

## Part 16 — Governance Challenge

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

---

## Part 17 — Architecture Communication Exercise

Imagine an interviewer asks:

> “Why did you choose managed containers instead of Kubernetes?”

Do not answer with a product comparison.

Answer using requirements:

> “The application is containerized and needs long-running services, but the current requirements do not require Kubernetes-specific orchestration capabilities. A managed container platform reduces operational responsibility while still giving us container deployment, scaling, identity, networking, and observability. If future requirements introduce Kubernetes-specific capabilities or an organizational Kubernetes platform standard, we can reconsider AKS/EKS.”

Now imagine:

> “Why did you separate Production into another account/subscription?”

A strong answer focuses on isolation:

> “The separate environment boundary reduces blast radius and gives us stronger isolation for identity, governance, quotas, billing, and operational access. Production can therefore have stricter permissions and deployment controls than lower environments.”

The pattern is:

**Requirement → Decision → Reason → Trade-off → Alternative**

This is one of the most useful Senior/Lead interview patterns.

---

## Part 18 — Final Interview Drill

Answer these without looking at your notes.

1. Explain the complete journey of an HTTP request from a user to a Spring Boot application.
2. Explain what happens when DNS resolves correctly but the connection still fails.
3. Explain the difference between authentication and authorization.
4. Explain why workload identity is preferable to long-lived access keys.
5. Explain why application and infrastructure pipelines are often separated.
6. Explain why the same artifact should be promoted across environments.
7. Explain Terraform state and why teams need remote state and locking.
8. Explain how you would investigate Terraform drift.
9. Explain the difference between a load balancer, route table, and security rule.
10. Explain how a private application reaches a public internet endpoint.
11. Explain how a private application reaches a managed cloud service privately.
12. Explain why a container can be running while the application is unhealthy.
13. Explain readiness vs liveness vs startup health checks.
14. Explain how Kubernetes Services provide stable access to temporary Pods.
15. Explain how HPA differs from node scaling.
16. Explain why Helm and GitOps are not the same thing.
17. Explain the difference between pipeline identity and runtime identity.
18. Explain how you would secure a CI/CD supply chain.
19. Explain how you would perform a zero/minimal-downtime deployment.
20. Explain why database migrations complicate rollback.
21. Explain how you would investigate a sudden increase in HTTP 5xx errors.
22. Explain how metrics, logs, and traces complement each other.
23. Explain how you would design Dev/UAT/Prod isolation in Azure.
24. Explain how you would design Dev/UAT/Prod isolation in AWS.
25. Explain how you would design cross-account AWS deployment.
26. Explain how you would design Terraform for multiple environments.
27. Explain how you would reduce cloud cost without blindly reducing capacity.
28. Explain the difference between an Azure VNet and AWS VPC.
29. Explain the difference between Azure RBAC and AWS IAM.
30. Explain the difference between AKS and EKS at an architectural level.

If you cannot answer a question, do not immediately reread the entire lesson. Identify the layer you are missing and revisit only that lesson.

---

## Part 19 — The 10-Minute Whiteboard Test

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

---

## Part 20 — Your Final Senior/Lead Checklist

You are building the right level of capability when you can move naturally between these layers:

```text
Business Requirement
        ↓
Architecture
        ↓
Cloud Platform
        ↓
Networking
        ↓
Identity & Security
        ↓
Infrastructure as Code
        ↓
CI/CD
        ↓
Containers
        ↓
Kubernetes / Managed Runtime
        ↓
Observability
        ↓
Incident Response
        ↓
Reliability
        ↓
Cost
        ↓
Governance
```

You should also be able to move in the opposite direction during troubleshooting:

```text
Business Impact
      ↑
Application
      ↑
Runtime
      ↑
Deployment
      ↑
Infrastructure
      ↑
Network
      ↑
Identity
      ↑
Underlying Resource
```

That bidirectional thinking is the real objective of this course.

---

## Part 21 — What You Should Be Able to Say in an Interview

You do not need to sound like a walking cloud-service catalog.

A strong Senior/Lead answer usually sounds like this:

> “First I would clarify the availability, security, traffic, recovery, and deployment requirements. Then I would identify the appropriate runtime and network boundaries. I would use workload identity rather than long-lived credentials, manage infrastructure through Terraform with remote state and controlled production changes, and build once before promoting the same artifact through environments. For deployment, I would choose a traffic strategy appropriate to the application and database compatibility requirements. Finally, I would make sure the platform is observable, auditable, recoverable, and cost-controlled.”

That answer demonstrates a way of thinking.

The interviewer can then drill down into any layer.

You should be ready to go deeper.

---

## Part 22 — Final Recall: The One Mental Model

Remember this:

**A DevOps engineer delivers software.**

**A Senior DevOps engineer designs the system that delivers, runs, secures, observes, and recovers that software.**

**A Lead DevOps engineer also designs the platform, standards, governance, ownership model, and engineering practices that allow many teams to do that safely and repeatedly.**

The complete mental model is:

```text
             ┌───────────────┐
             │   BUSINESS    │
             └───────┬───────┘
                     ↓
             ┌───────────────┐
             │  APPLICATION  │
             └───────┬───────┘
                     ↓
             ┌───────────────┐
             │     CI/CD     │
             └───────┬───────┘
                     ↓
             ┌───────────────┐
             │ INFRASTRUCTURE│
             └───────┬───────┘
                     ↓
             ┌───────────────┐
             │    RUNTIME    │
             └───────┬───────┘
                     ↓
             ┌───────────────┐
             │   USERS /     │
             │   BUSINESS    │
             └───────────────┘

       Security • Identity • Network
       Observability • Reliability
       Cost • Governance
       exist across every layer
```

Your goal is not to memorize the diagram.

Your goal is to be able to enter any layer and understand what is happening. You should be able to trace dependencies across layers, identify the failure boundary, make a safe change, and explain the trade-off.

---

## Part 23 — Final Course Completion Exercise

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

---

## Part 24 — Where to Go After Day 30

The curriculum has now covered the core Senior/Lead DevOps foundation across Linux, networking, CI/CD, Azure DevOps, Terraform, cloud architecture, Docker, Kubernetes, Helm, GitOps, identity, security, supply chain, observability, Azure architecture, AWS architecture, and production troubleshooting.

The next phase should **not** be another large theory course.

Instead, convert the knowledge into increasingly realistic engineering work:

```text
Learn
 ↓
Build
 ↓
Break
 ↓
Troubleshoot
 ↓
Redesign
 ↓
Document
 ↓
Explain
```

Repeat that loop with progressively harder systems.

The strongest next step is to take the ShopSphere scenario and actually implement it in a cloud environment. Then deliberately introduce failures and solve them with evidence. That is where the knowledge from these 30 days becomes engineering skill.

---

## Final Cleanup

If you created cloud resources during the final assessment, remove temporary resources and verify that no billable resources remain.

Keep the following artifacts:

```text
Architecture diagram
Terraform code
CI/CD pipeline
Docker configuration
Kubernetes/Helm manifests
Security/IAM model
Observability design
Incident RCA
Architecture decision records
Final Senior-DevOps-Production-Architecture.md
```

These are more valuable for future revision than a large collection of copied commands.

## Answers to practice

### 1. Journey of an HTTP request from a user to Spring Boot

<details>
<summary>Answer</summary>

User → DNS → load balancer or ingress → Service or target group → Pod/task/instance → Spring Boot on 8080. Then the app may call private PostgreSQL on 5432.

Name every hop: who starts it, which name, which IP, which route, which security rule, which port. That is the production path, not a service catalog.

</details>

### 2. DNS is correct but the connection still fails

<details>
<summary>Answer</summary>

Resolution succeeded. The packet still needs a route, an allow rule, an open port, a listening process, and a healthy app. Walk IP → route → security → port → service → application.

A public IP from DNS when you expected a private endpoint is a different failure: the path is wrong even though “DNS worked.”

</details>

### 3. Authentication vs authorization

<details>
<summary>Answer</summary>

Authentication proves who the principal is. Authorization decides what that principal may do.

A federated pipeline can authenticate and still get `AccessDenied` if RBAC or IAM denies the action.

</details>

### 4. Why workload identity beats long-lived access keys

<details>
<summary>Answer</summary>

Roles and managed identities vend short-lived tokens. Keys in Git, images, and YAML leak and stay valid.

If the identity is stolen, blast radius is the role’s scope. Keys multiply that risk.

</details>

### 5. Why application and infrastructure pipelines are often separated

<details>
<summary>Answer</summary>

A Java change should not run `terraform apply`. A node-pool change should not rebuild the JAR.

Separate repos, identities, and approvals keep application risk off infrastructure state.

</details>

### 6. Why promote the same artifact across environments

<details>
<summary>Answer</summary>

Production must run the bytes that passed UAT. A new build can differ even from the same Git SHA.

Pin the image digest. Move that digest Dev → UAT → Prod.

</details>

### 7. Terraform state, remote state, and locking

<details>
<summary>Answer</summary>

State maps config to real resources. Remote state (Azure Storage or S3) gives one team copy. Locking stops two applies from corrupting it.

State can hold secrets. Restrict IAM, encrypt, version, and split by environment.

</details>

### 8. How you would investigate Terraform drift

<details>
<summary>Answer</summary>

Do not auto-apply. Ask what changed, who changed it, whether it was intentional. Accidental: reconcile to code. Intentional: update Terraform. External owner: stop fighting that attribute.

Detect → investigate → reconcile or codify → prevent recurrence.

</details>

### 9. Load balancer vs route table vs security rule

<details>
<summary>Answer</summary>

A load balancer distributes traffic to healthy targets. A route table chooses the next hop. A security rule (NSG or Security Group) allows or denies the packet.

Wrong path is routing. Correct path but dropped is security. Healthy targets are a load-balancer concern.

</details>

### 10. How a private application reaches a public internet endpoint

<details>
<summary>Answer</summary>

Private subnet default route to NAT (or hub firewall SNAT) → Internet Gateway → public API. The app has no public IP.

Inbound still uses the load balancer. Outbound is a different path.

</details>

### 11. How a private application reaches a managed cloud service privately

<details>
<summary>Answer</summary>

Private Endpoint or VPC endpoint plus private DNS so the usual hostname returns a private IP. Route locally. Filter with NSG or Security Group.

If DNS is still public, you never take the private path.

</details>

### 12. Why a container can be running while the application is unhealthy

<details>
<summary>Answer</summary>

`Running` means the process has not exited. The app can still return 503, fail `/health`, or miss the database.

Use probes, target health, and logs. Do not trust process state alone.

</details>

### 13. Readiness vs liveness vs startup probes

<details>
<summary>Answer</summary>

Readiness: stop sending traffic until ready. Liveness: restart if stuck. Startup: give a slow JVM time before liveness fires.

Wrong probes either flap Pods or send users to a booting app.

</details>

### 14. How Kubernetes Services give stable access to temporary Pods

<details>
<summary>Answer</summary>

A Service keeps a stable name and virtual IP. Endpoints track ready Pods. Pods can die and be replaced.

Clients talk to the Service, not to Pod IPs.

</details>

### 15. How HPA differs from node scaling

<details>
<summary>Answer</summary>

HPA adds or removes Pods. Cluster autoscaler or node pools add nodes when Pods cannot schedule.

More Pods on a full node does nothing. Scale the layer that is actually short.

</details>

### 16. Why Helm and GitOps are not the same thing

<details>
<summary>Answer</summary>

Helm packages and templates Kubernetes YAML. GitOps (Argo CD or Flux) continuously reconciles cluster state from Git.

You can Helm without GitOps. You can GitOps without Helm. Together they are a delivery model.

</details>

### 17. Pipeline identity vs runtime identity

<details>
<summary>Answer</summary>

Pipeline identity builds, pushes, and deploys. Runtime identity is the app’s role for Key Vault, S3, or RDS.

Do not give the Spring Boot task the permission to update ECS.

</details>

### 18. How you would secure a CI/CD supply chain

<details>
<summary>Answer</summary>

Protect `main`, review PRs, SAST/SCA and image scan, federated identities, no Prod creds on untrusted PRs, digest pinning, and environment approvals.

The pipeline is part of the product. Treat YAML and agents as attack surface.

</details>

### 19. Zero or minimal-downtime deployment

<details>
<summary>Answer</summary>

Roll new instances or tasks behind health checks, or use blue/green or slots, then shift traffic. Keep enough old capacity until new is ready.

Schema must stay compatible. Command success is not user success.

</details>

### 20. Why database migrations complicate rollback

<details>
<summary>Answer</summary>

Application v2 may require schema v2. Reverting the app to v1 does not undo an irreversible migration.

Plan backward-compatible migrations, expand/contract, or a data rollback path before you ship.

</details>

### 21. Investigate a sudden increase in HTTP 5xx

<details>
<summary>Answer</summary>

Check deploy time, error rate, which endpoint, which instances, target health, logs, traces, and one dependency. Do not restart everything.

CPU normal does not mean the app is healthy. Start with evidence.

</details>

### 22. How metrics, logs, and traces complement each other

<details>
<summary>Answer</summary>

Metrics show what is happening (rate, errors, latency). Logs show the exception. Traces show which span ate the time.

Use a correlation ID across all three.

</details>

### 23. Dev/UAT/Prod isolation in Azure

<details>
<summary>Answer</summary>

Entra tenant → management groups → separate subscriptions (or strongly split RGs) → resource groups. Tighter RBAC and Policy on Prod. Separate Terraform state and pipeline identities.

Subscriptions isolate billing, quota, and blast radius better than names in one subscription.

</details>

### 24. Dev/UAT/Prod isolation in AWS

<details>
<summary>Answer</summary>

Organization → OUs → separate accounts. SCPs on Prod. IAM Identity Center permission sets. Separate VPCs, roles, and state.

Accounts are stronger isolation than three VPCs in one account.

</details>

### 25. Cross-account AWS deployment

<details>
<summary>Answer</summary>

CI in a tooling account assumes a deploy role in the target account via STS or OIDC. Trust is tight. IAM on the role is least privilege. SCP still applies.

The pipeline is not org admin.

</details>

### 26. Terraform for multiple environments

<details>
<summary>Answer</summary>

One module, environment folders or workspaces with separate backends: `dev/`, `uat/`, `prod/`. Different variable files and roles. Plan then approved apply.

Never one state file for all environments.

</details>

### 27. Reduce cloud cost without blindly cutting capacity

<details>
<summary>Answer</summary>

Find the driver: compute, NAT, logs, idle non-prod, data transfer. Right-size, schedule non-prod, cap log retention, use endpoints instead of NAT where it fits.

Do not drop Production HA to save money. Cost is a constraint next to reliability.

</details>

### 28. Azure VNet vs AWS VPC

<details>
<summary>Answer</summary>

Both are the private IP network boundary with subnets, routes, and filtering. Azure uses NSGs and UDRs. AWS uses route tables, Security Groups, and NACLs.

Same job, different knobs. Do not force one-to-one product names.

</details>

### 29. Azure RBAC vs AWS IAM

<details>
<summary>Answer</summary>

Azure RBAC is scope-based roles on management groups, subscriptions, RGs, and resources. AWS IAM is identity policies plus resource policies plus SCPs.

Both separate authentication from authorization. Evaluation layers differ.

</details>

### 30. AKS vs EKS at an architectural level

<details>
<summary>Answer</summary>

Both are managed Kubernetes control planes. You still own node pools or Fargate, CNI, IAM/workload identity, ingress, and workloads.

Azure wraps VNet, AAD/Entra, and ACR. AWS wraps VPC, IAM, and ECR. Kubernetes concepts stay; the cloud attachments change.

</details>

### 31. Design ShopSphere modernization from Part 2 requirements

<details>
<summary>Answer</summary>

Users → DNS → load balancer → containerized Spring Boot (managed containers unless Kubernetes is required) → private relational database. Angular on static hosting or the same ingress. Dev/UAT/Prod isolated. IaC with Terraform. Secrets in Key Vault or Secrets Manager. CI builds once and promotes a digest. Prod needs approval, HA across AZs, monitoring, alerts, and traceability.

Do not add Kafka, mesh, or microservices without a requirement. Every extra box is a failure mode. Map the same design onto Azure or AWS products second.

</details>

### 32. Incident: post-deploy partial 5xx, CPU normal, then `UnknownHostException: payments.internal`

<details>
<summary>Answer</summary>

Do not restart everything. Correlate 10:15 deploy with 10:18 errors. Check which instances, target health, same digest, which endpoint, and logs. When logs show `UnknownHostException: payments.internal`, switch to DNS → private DNS → route → security → payments service.

This is not a CPU incident. Observability plus the network sequence finds it.

</details>

### 33. Pipeline success, users see 503

<details>
<summary>Answer</summary>

Deployment success is not application success. Walk load balancer → target health → Service/Deployment → Pod/task → process → logs. Compare running digest with the expected digest and Git SHA.

You may be debugging the wrong version if the digest does not match.

</details>

### 34. Unexpected Terraform plan — drift

<details>
<summary>Answer</summary>

Do not apply. Identify the attribute, actor, and intent. Accidental portal edit: apply to restore code. Intentional ops change: update Terraform. Another controller owns it: change ownership.

Locking and pipeline-only Prod applies prevent a class of this drift.

</details>

### 35. Monthly bill too high

<details>
<summary>Answer</summary>

Name the top services first: compute, database, NAT, logs, idle non-prod. Right-size, sleep Dev, shorten log retention, private endpoints to cut NAT. Keep Prod HA.

A cheaper runtime that doubles incidents is not cheaper. Cost sits beside security and reliability.

</details>

### 36. Guardrails for 50 teams on Azure and AWS

<details>
<summary>Answer</summary>

Azure: management groups, Policy, RBAC, tags, budgets. AWS: OUs, SCPs, IAM, Config, tags, budgets. Platform owns templates, identity patterns, and network hub. Teams own app code and resource-group or account-scoped delivery.

Guardrails without a ticket for every VM. Central governance, local ownership.

</details>

### 37. Why managed containers instead of Kubernetes?

<details>
<summary>Answer</summary>

The app is containerized and long-running. Current requirements do not need Kubernetes APIs, operators, or cluster networking. A managed container platform gives deploy, scale, identity, and observability with less cluster work.

If Kubernetes becomes a platform standard or a real capability need, reconsider AKS/EKS. Requirement → decision → reason → trade-off → alternative.

</details>

### 38. Why separate Production into another account or subscription?

<details>
<summary>Answer</summary>

The boundary reduces blast radius for identity, governance, quotas, billing, and access. Production can use stricter permissions and approvals than Dev.

A naming convention in one account is weaker isolation.

</details>

### 39. 10-minute whiteboard: ShopSphere production from memory

<details>
<summary>Answer</summary>

Draw users → DNS → LB → app → private DB. Add CI/CD, Terraform, identity, secrets, monitoring, logs, security, network, Dev/UAT/Prod, backup, cost. For each box say why, owner, communication, security, scale, failure, detection, recovery, cost, and 10× change.

If you cannot explain a box, it does not belong on the board.

</details>

### 40. `Senior-DevOps-Production-Architecture.md` with the 20 sections

<details>
<summary>Answer</summary>

Write the document from your own design, not copied lessons: business, diagram, Azure, AWS, network, identity, security, Terraform, CI/CD, deploy, secrets, observability, HA, DR, cost, governance, failures, troubleshooting, ADRs, and 10× scale.

That file is the course proof. Keep it as a revision artifact with diagrams and decisions, not a command dump.

</details>
