# Day 21 — Senior/Lead DevOps Capstone

## Part 1 — The Capstone Mindset

The first 20 days taught individual capabilities: Linux and networking, CI/CD, Terraform, cloud architecture, containers, Kubernetes, identity, security, and observability. A Senior/Lead DevOps engineer is expected to combine these capabilities rather than solve each problem in isolation. In a real interview or production situation, you may receive a business requirement such as “move this application to Azure with high availability and secure CI/CD.” You then have to turn it into an architecture, explain the trade-offs, implement the important parts, and troubleshoot failures. This capstone is designed to make you practice exactly that.

Your core reasoning loop remains:

**WHY → WHAT → HOW → WHAT CAN GO WRONG → HOW DO I KNOW → HOW DO I FIX IT**

Do not start by choosing Azure services. Start with the application, business requirements, reliability needs, security boundaries, operational model, and cost constraints. Then choose the architecture that satisfies those requirements.

**Remember:** Senior-level DevOps is not knowing the most services. It is making sound engineering decisions and being able to explain them.

> **JD note:** What separates Lead from Senior in real JDs is scope, not tools. See the [Lead vs Senior pattern card](jd-insights/patterns/lead-vs-senior-signals.md).

---

## Part 2 — The Business Scenario

You are responsible for modernizing an existing e-commerce application called **ShopSphere**.

The application currently has:

```text
Frontend
  └── Angular

Backend
  └── Spring Boot

Database
  └── PostgreSQL

External services
  ├── Payment API
  ├── Email provider
  └── Object storage for product images
```

The current application runs on virtual machines and has several operational problems:

- Deployments require manual steps.
- Infrastructure is configured manually.
- Secrets are stored in configuration files.
- Monitoring is limited.
- A single application instance can become unavailable.
- Developers sometimes deploy directly to production.
- Database connectivity problems are difficult to diagnose.
- There is no reliable release traceability.
- Infrastructure changes are not consistently reviewed.

The business wants the modernized platform to support:

- Development, UAT, and Production.
- Automated CI/CD.
- Infrastructure as Code.
- Containerized application deployment.
- High availability for the application tier.
- Secure identity and secret management.
- Centralized observability.
- Controlled production releases.
- Rollback capability.
- Auditability.
- Reasonable cloud cost.

Your first task is not to build anything. **Understand the system.**

Practice: Write down the five most important risks in the current environment before proposing any new technology.

---

## Part 3 — Requirements to Architecture

Translate business requirements into technical requirements.

For example:

```text
Business requirement:
Application should remain available during an application-instance failure.

Technical requirement:
Run multiple application replicas with traffic distributed across healthy instances.
```

Another:

```text
Business requirement:
Only approved production changes should be released.

Technical requirement:
Protected source branch + CI validation + production authorization + auditable deployment.
```

Another:

```text
Business requirement:
Sensitive credentials must not be stored in source code.

Technical requirement:
Central secret management + workload identity/federated access + least privilege.
```

Another:

```text
Business requirement:
Operations must quickly diagnose failed requests.

Technical requirement:
Metrics + structured logs + distributed traces + actionable alerts.
```

Create this mapping for every requirement.

A strong Senior/Lead engineer can explain the chain:

```text
Business requirement
        ↓
Technical requirement
        ↓
Architecture decision
        ↓
Implementation
        ↓
Operational verification
```

Practice: Create at least 10 business-to-technical mappings for ShopSphere.

---

## Part 4 — Target Cloud Architecture

For the primary implementation, use Azure concepts you have learned. Keep the architecture provider-aware rather than memorizing a single service combination.

A reasonable target architecture is:

```text
                         Internet
                            │
                     DNS / Edge Layer
                            │
                    Public Entry Point
                            │
                    ┌───────┴───────┐
                    │               │
                 Frontend        API Traffic
                    │               │
              Static Hosting       Ingress/LB
                                      │
                                    AKS
                         ┌────────────┼────────────┐
                         │            │            │
                      Pod 1         Pod 2        Pod 3
                         │            │            │
                         └────────────┼────────────┘
                                      │
                               Private Services
                              ┌───────┴────────┐
                              │                │
                          PostgreSQL       Other APIs
                              │
                         Secret / Identity
                              │
                         Key Vault / MI
```

Infrastructure should be managed through Terraform or Bicep according to the ownership model.

The delivery architecture should be:

```text
Git
 ↓
Pull Request
 ↓
Review + Validation
 ↓
CI
 ├── Build
 ├── Unit Tests
 ├── Security Scans
 └── Image Build
 ↓
Container Registry
 ↓
UAT
 ↓
Approval / Policy
 ↓
Production
 ↓
Observe
```

Do not treat this diagram as the only possible architecture. During the capstone, you should be able to explain why you selected each major component and what alternative you considered.

---

## Part 5 — Enterprise Structure and Environment Isolation

Design the Azure enterprise hierarchy before creating application resources.

A simplified model is:

```text
Microsoft Entra Tenant
        │
        └── Management Group
              │
       ┌──────┼──────┐
       │      │      │
     Dev     UAT    Prod
     Sub     Sub    Sub
       │      │      │
      RGs    RGs    RGs
       │      │      │
   Resources...
```

The exact management-group hierarchy depends on organizational scale. The important architectural principle is to separate environments in a way that controls blast radius, access, policy, billing, and operational ownership.

Do not assume that “one subscription per environment” is always mandatory. It is one common pattern because it provides useful isolation, but the correct structure depends on organizational governance and workload boundaries.

For ShopSphere, decide:

- Which resources belong in each subscription?
- Which identities can access each environment?
- Which policies apply at management-group level?
- Which policies are environment-specific?
- Who can deploy production?
- Where does Terraform state live?
- How are logs separated or centralized?
- How are costs attributed?

Practice: Draw your complete hierarchy and explain why each boundary exists.

---

## Part 6 — Network Design

Design the application network from the traffic flows rather than from a list of services.

For example:

```text
Internet
   ↓
Frontend / Edge
   ↓
API ingress
   ↓
AKS workload
   ↓
Private database
```

Identify the required flows:

```text
User → Frontend
User → API
API → Database
API → Payment API
API → Email provider
AKS → Azure services
CI/CD → Registry
AKS → Registry
```

For every flow, ask:

```text
Who starts it?
What DNS name is used?
What IP/path is used?
Which route is required?
Which security rule permits it?
Which port is required?
Is the endpoint public or private?
```

Your troubleshooting sequence remains:

**DNS → IP → Route → Security → Port → Service → Application**

For Azure, consider:

- VNet and subnet design.
- NSGs.
- Private endpoints where appropriate.
- Private DNS.
- Load balancing/ingress.
- NAT/controlled outbound access.
- Hub-and-spoke or another enterprise network topology where appropriate.

Do not automatically make every component private. The design should follow actual traffic and security requirements.

Practice: Draw the API → PostgreSQL traffic path and identify every security boundary between them.

---

## Part 7 — Infrastructure as Code Architecture

Create a repository structure that separates reusable infrastructure code from environment configuration.

One possible structure:

```text
infrastructure/
├── modules/
│   ├── network/
│   ├── aks/
│   ├── database/
│   ├── registry/
│   └── monitoring/
│
└── environments/
    ├── dev/
    ├── uat/
    └── prod/
```

The exact structure can vary. The important principle is:

```text
Reusable design
      +
Environment-specific values
      ↓
Predictable infrastructure
```

For Terraform, use separate state boundaries appropriate to workload/environment ownership.

A production pipeline should generally perform:

```bash
terraform fmt -check
terraform validate
terraform plan
```

and require controlled authorization before applying production changes.

For Bicep, the equivalent reasoning includes:

```text
Parameters
    ↓
Modules
    ↓
Deployment
    ↓
What-if / validation
    ↓
Controlled production deployment
```

Practice: Design the Terraform module inputs and outputs for the AKS/network/database stack. Do not put environment-specific values directly inside reusable modules.

---

## Part 8 — CI/CD Architecture

The application pipeline should build a version once and promote the same artifact.

A strong flow is:

```text
Developer
   ↓
Feature branch
   ↓
Pull Request
   ↓
Build
   ↓
Test
   ↓
Security
   ↓
Container image
   ↓
Registry
   ↓
UAT
   ↓
Verification
   ↓
Production approval
   ↓
Production
```

Avoid rebuilding the application separately for each environment because that can create different artifacts.

The artifact identity should be traceable:

```text
Git commit
   ↓
Build ID
   ↓
Image tag
   ↓
Image digest
   ↓
Deployment
```

Environment configuration should remain outside the application artifact:

```text
DEV config
UAT config
PROD config
```

The same application image can therefore move through environments while configuration changes according to the target environment.

Practice: Design the pipeline stages and identify which stages need:

- Developer permissions.
- Build permissions.
- Registry push permissions.
- UAT deployment permissions.
- Production deployment permissions.

---

## Part 9 — Identity and Secret Architecture

Separate the identities used by different parts of the platform.

Conceptually:

```text
Developer Identity
       ↓
Source repository

CI Identity
       ↓
Build / registry / deployment operations

Terraform Identity
       ↓
Infrastructure management

Runtime Identity
       ↓
Application access to Azure resources

Human Production Operator
       ↓
Controlled administrative access
```

Do not give every identity broad Contributor-level access simply because it is convenient.

For the application:

```text
AKS Pod
  ↓
Workload Identity / Managed Identity
  ↓
Key Vault
  ↓
Required secret
```

For infrastructure:

```text
IaC pipeline identity
  ↓
Required Azure RBAC scope
  ↓
Infrastructure resources
```

For developers:

```text
Developer
  ↓
Required development scope
```

Practice: For each identity, answer:

```text
Who is it?
What can it access?
At what scope?
Why does it need that access?
How can it be revoked?
```

Then deliberately remove one unnecessary permission from your design.

---

## Part 10 — Kubernetes Workload Architecture

Deploy the application through Kubernetes objects that express desired state.

A simplified structure is:

```text
Deployment
    ↓
ReplicaSet
    ↓
Pods
    ↓
Container
```

A Service provides stable access:

```text
Client
  ↓
Service
  ↓
Healthy Pod endpoints
```

For production workloads, consider:

- Multiple replicas.
- Resource requests and limits.
- Readiness probes.
- Liveness probes.
- Startup probes for slow-starting applications.
- Pod disruption considerations.
- Appropriate rolling-update behavior.
- Workload identity.
- NetworkPolicy.
- Namespace boundaries.
- HPA where appropriate.
- Node placement and availability.

A simplified Deployment might look like:

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
      serviceAccountName: shopsphere-api
      containers:
        - name: api
          image: registry.example/shopsphere-api@sha256:<digest>
          ports:
            - containerPort: 8080
          resources:
            requests:
              cpu: "250m"
              memory: "512Mi"
            limits:
              cpu: "1"
              memory: "1Gi"
          readinessProbe:
            httpGet:
              path: /actuator/health/readiness
              port: 8080
```

The image digest here emphasizes exact artifact identity.

Practice: Explain what happens if one Pod dies, if one Pod becomes unready, and if the entire node hosting one or more Pods fails.

---

## Part 11 — Reliability and Availability Design

You do not achieve high availability simply by setting `replicas: 3`.

Ask what happens when each layer fails:

```text
Pod failure
Node failure
Zone failure
Load balancer failure
Application failure
Database failure
Network failure
Identity failure
Registry failure
Deployment failure
```

For application replicas, distribute workloads across appropriate failure domains where the platform supports it.

For deployment safety, use readiness probes and controlled rolling updates, so the platform does not send traffic to unhealthy Pods.

For database availability, understand the capabilities and limitations of the chosen managed database service. Do not assume the database automatically has the same availability characteristics as the application tier.

Practice: Take the architecture and perform a failure walk:

```text
What if Pod 2 dies?
What if Node 1 dies?
What if an entire availability zone becomes unavailable?
What if the database becomes unavailable?
What if the latest release is broken?
```

For every failure, identify:

```text
Detection
Mitigation
Recovery
Data impact
User impact
```

---

## Part 12 — Security and Supply Chain Architecture

Integrate Day 19 into the capstone.

The pipeline should include controls such as:

```text
Pull Request
 ↓
Code Review
 ↓
SAST
 ↓
Dependency Scan
 ↓
Secret Scan
 ↓
IaC Scan
 ↓
Container Build
 ↓
Image Scan
 ↓
Registry
 ↓
Controlled Deployment
```

Do not assume that a scan makes the system secure. Security is distributed across:

```text
Source protection
Identity
Build isolation
Dependency controls
Artifact integrity
Registry access
Deployment authorization
Runtime identity
Network security
Observability
```

For the image:

```text
Git commit
   ↓
Build
   ↓
Image
   ↓
Digest
   ↓
Registry
   ↓
Deployment
```

For the runtime:

```text
Pod
 ↓
Workload identity
 ↓
Azure resource
```

Practice: Assume the CI identity is compromised. Determine the attacker's maximum possible blast radius from your architecture. Then redesign the permissions to reduce that blast radius.

---

## Part 13 — Observability Architecture

Your production platform should expose enough telemetry to answer:

```text
Are users affected?
Which service is affected?
When did the problem start?
Which deployment changed?
Where is the latency?
Which dependency is failing?
What errors are occurring?
Is infrastructure saturated?
```

Implement:

```text
Metrics
Logs
Traces
Alerts
Dashboards
```

A useful application dashboard:

```text
REQUESTS
- Request rate
- Error rate
- p50
- p95
- p99

KUBERNETES
- Available replicas
- Restarts
- CPU
- Memory

DEPENDENCIES
- Database latency
- Database errors
- External API latency

RELEASE
- Current version
- Image digest
- Git commit
- Deployment time

BUSINESS
- Orders created
- Orders failed
- Payments failed
```

For Azure, map the architecture to the monitoring services appropriate for the implementation.

Practice: Define at least three alerts and specify what action each should trigger.

---

## Part 14 — Production Deployment Strategy

Choose a deployment strategy based on application requirements rather than popularity.

Possible strategies include:

```text
Rolling
Blue-Green
Canary
```

For ShopSphere, consider a rolling deployment initially because Kubernetes supports controlled rolling updates naturally. However, if the business requires rapid traffic reversal or very low release risk for major changes, blue-green or canary may be appropriate.

Your decision should consider:

```text
Application architecture
Traffic pattern
Release frequency
Rollback speed
Infrastructure cost
Database compatibility
Operational complexity
Risk tolerance
```

Database changes require special attention. An application rollback is not automatically safe if the new release has already performed an incompatible schema migration.

A safer pattern for many systems is to make schema changes backward-compatible where practical:

```text
Expand
 ↓
Deploy compatible application
 ↓
Migrate / backfill
 ↓
Switch behavior
 ↓
Contract
```

Practice: Explain how you would deploy a release that changes both the application and database schema without causing downtime.

---

## Part 15 — Incident Scenario 1: Bad Deployment

Production deployment completes.

Five minutes later:

```text
Error rate ↑
p95 latency ↑
Pod status = Running
CPU = normal
Memory = normal
Database = healthy
```

Your investigation:

```text
1. Check deployment timeline.
2. Check application metrics.
3. Compare previous/current versions.
4. Inspect traces.
5. Inspect application logs.
6. Identify affected endpoint.
7. Determine whether rollback is safe.
8. Mitigate.
9. Verify recovery.
10. Perform RCA.
```

Useful commands:

```bash
kubectl rollout status deployment/shopsphere-api
kubectl rollout history deployment/shopsphere-api
kubectl get pods
kubectl logs <pod>
kubectl describe pod <pod>
```

The key reasoning is that Kubernetes health does not equal application health.

A Pod can be:

```text
Running = yes
Ready = yes
```

while the application still returns incorrect responses.

Practice: Write the exact evidence you would want before deciding that the deployment caused the incident.

---

## Part 16 — Incident Scenario 2: Database Connectivity Failure

Users report:

```text
Orders fail
Product browsing works
```

Metrics show:

```text
orders-api 5xx ↑
orders-api latency ↑
database connection errors ↑
```

Trace:

```text
API
 ↓
Database span
 ↓
Timeout
```

Use the known troubleshooting chain:

```text
DNS
 ↓
IP
 ↓
Route
 ↓
Security
 ↓
Port
 ↓
Database listener
 ↓
Connection pool
 ↓
Authentication
 ↓
Application
```

From the Kubernetes environment:

```bash
kubectl exec -it <pod> -- sh
```

Then test appropriate DNS/network connectivity from the Pod.

Do not immediately change NSGs or firewall rules. First determine whether the failure is actually network-related.

Practice: Write three hypotheses and one test for each.

Example:

```text
Hypothesis:
DNS cannot resolve the database hostname.

Test:
nslookup database.internal
```

Then continue through the layers.

---

## Part 17 — Incident Scenario 3: CI/CD Security Failure

A production deployment suddenly fails because the pipeline is denied access to Key Vault.

Possible causes:

```text
Identity changed
Role assignment removed
Scope changed
Secret access policy changed
Federated identity configuration changed
Key Vault firewall/network rule changed
```

Troubleshooting:

```text
Who is the pipeline?
        ↓
Is authentication successful?
        ↓
What identity is actually being used?
        ↓
Is authorization present?
        ↓
What is the scope?
        ↓
Can the identity access Key Vault?
        ↓
Is network access permitted?
        ↓
Does the requested secret exist?
```

Do not solve this with:

```text
Give pipeline Owner access.
```

Instead identify the exact required permission and scope.

Practice: Explain the difference between:

```text
Authentication failure
Authorization failure
Network access failure
Secret-not-found failure
```

This distinction should become automatic.

---

## Part 18 — Incident Scenario 4: Terraform Drift

An engineer manually changes a production network rule.

Terraform later reports a difference.

Your response should not be:

```text
terraform apply
```

Instead:

```text
Detect drift
   ↓
Investigate change
   ↓
Was it intentional?
   ├── No → Restore desired state
   │
   └── Yes
        ↓
   Should it become desired state?
        ├── Yes → Update IaC
        └── No → Deliberately manage the exception
```

Ask:

```text
Who changed it?
Why?
What changed?
What was the security impact?
Was the change approved?
Should the configuration be codified?
```

Practice: Introduce controlled drift in a lab resource and document the investigation before reconciling it.

---

## Part 19 — Cost and FinOps Decision

A Senior/Lead engineer must include cost in architecture decisions without sacrificing required reliability or security.

For ShopSphere, identify the major cost drivers:

```text
AKS compute
Database
Load balancing / networking
Container registry
Monitoring/log ingestion
Storage
Data transfer
Non-production environments
```

Then ask:

```text
Which resources run 24/7?
Can non-production environments scale down?
Are logs retained longer than required?
Are workloads over-provisioned?
Are database tiers appropriate?
Are idle resources being detected?
```

Do not optimize by removing a control simply because it costs money.

A better decision pattern is:

```text
Requirement
 ↓
Reliability/Security need
 ↓
Cost driver
 ↓
Optimization option
 ↓
Trade-off
```

Practice: Identify three ways to reduce ShopSphere's cost and explain what each optimization could sacrifice.

---

## Part 20 — The Complete Architecture Review

Now present your final ShopSphere architecture as if you were interviewing for a Senior/Lead DevOps role.

You should be able to explain:

```text
1. Business requirements
2. Enterprise structure
3. Network architecture
4. Compute architecture
5. Kubernetes architecture
6. Database architecture
7. Identity model
8. Secret management
9. IaC structure
10. CI/CD design
11. Supply-chain security
12. Deployment strategy
13. Observability
14. Incident response
15. Disaster/recovery considerations
16. Cost controls
17. Governance
```

For each decision, use:

```text
Requirement
→ Decision
→ Why
→ Alternative
→ Trade-off
```

Example:

```text
Requirement:
Application must tolerate an instance failure.

Decision:
Run multiple Kubernetes replicas.

Why:
A single Pod is a single workload instance and can fail.

Alternative:
Single VM with restart.

Trade-off:
Multiple replicas increase infrastructure cost but reduce application-instance failure impact.
```

Do this for every major architectural decision.

---

## Part 21 — Final Senior/Lead Interview Simulation

Answer these without looking at previous lessons.

### Architecture

How would you design a highly available Spring Boot application on Azure?

What belongs in the management-group/subscription/resource-group hierarchy?

How would you separate Dev, UAT, and Prod?

How would you design the network?

Why would you use private endpoints?

When would you use a load balancer versus an ingress layer?

### Terraform

Why does Terraform need state?

What is drift?

How do you handle drift safely?

How would you structure modules and environments?

How would you protect production state?

Why should production Terraform apply be controlled?

### CI/CD

Why build once and promote the same artifact?

How do you trace a production image back to source?

How would you secure the pipeline?

How do you separate build and deployment permissions?

How would you implement rollback?

### Kubernetes

Why does Kubernetes use Deployments instead of directly managing Pods?

What is the purpose of a Service?

What causes a Pod to be `Running` but not `Ready`?

How do readiness and liveness differ?

How do you troubleshoot a Service that cannot reach Pods?

How do you investigate CrashLoopBackOff?

### Identity and Security

Authentication vs authorization?

Azure RBAC vs Kubernetes RBAC?

Managed identity/workload identity vs client secret?

How do you implement least privilege?

How do you reduce blast radius?

How do you protect CI/CD credentials?

### Networking

How do you troubleshoot application → database connectivity?

DNS vs routing vs firewall vs port?

What is private DNS?

How does Kubernetes Service discovery work?

How does cloud networking interact with Kubernetes networking?

### Observability

Metrics vs logs vs traces?

Why p95/p99?

What should trigger an alert?

How do you investigate a sudden 500 increase?

How do you distinguish application, network, database, and infrastructure failures?

### Production

What do you do first during a production incident?

When would you rollback?

When is rollback unsafe?

How do you write an RCA?

How do you prevent recurrence?

### Leadership

How do you decide between two valid architectures?

How do you balance security, reliability, complexity, and cost?

How do you standardize infrastructure across many teams?

How do you reduce operational toil?

How do you explain a technical trade-off to a non-technical stakeholder?

---

## Part 22 — Final Practical Challenge

Build a simplified version of ShopSphere.

Your lab should contain:

```text
Git repository
   ↓
CI/CD pipeline
   ↓
Docker image
   ↓
Container registry
   ↓
Kubernetes
   ↓
Spring Boot
   ↓
Database
```

Add:

```text
Terraform
Identity
Secrets
Security scanning
Observability
Deployment strategy
```

Then perform these controlled exercises:

### Exercise A — Application failure

Deploy a broken image.

Detect it through telemetry.

Rollback or fix forward.

Verify recovery.

### Exercise B — Networking failure

Break a controlled network path.

Diagnose:

```text
DNS → Route → Security → Port → Service → Application
```

Restore it.

### Exercise C — Identity failure

Remove a lab permission.

Observe the authentication/authorization failure.

Identify the exact missing permission.

Restore least privilege.

### Exercise D — IaC drift

Change a resource manually.

Run Terraform plan.

Investigate the change.

Reconcile it correctly.

### Exercise E — Supply-chain failure

Introduce a deliberately vulnerable dependency or image component in the lab.

Run the security gate.

Observe the pipeline behavior.

Fix or document the exception according to the defined policy.

### Exercise F — Resource saturation

Reduce available CPU/memory or deliberately create excessive load in a safe lab.

Observe:

```text
Metrics
Alerts
Pod behavior
HPA
Application latency
```

Then recover the system.

---

## Part 23 — Final Senior/Lead Deliverables

At the end of the capstone, you should have these artifacts:

```text
01 — ShopSphere Architecture Diagram
02 — Enterprise Cloud Hierarchy
03 — Network Diagram
04 — Terraform Repository Structure
05 — CI/CD Pipeline
06 — Dockerfile
07 — Kubernetes/Helm Deployment
08 — Identity & Access Model
09 — Security/Supply-Chain Flow
10 — Observability Dashboard
11 — Incident Timeline
12 — RCA
13 — Cost Optimization Notes
14 — Architecture Decision Records
```

These artifacts are more valuable than simply completing commands because they demonstrate that you can design, implement, operate, troubleshoot, and explain a system.

For every artifact, ask:

```text
Can I explain why I designed it this way?
Can I explain what could fail?
Can I troubleshoot that failure?
Can I explain the security implications?
Can I explain the cost?
Can I explain the alternative?
```

---

## Part 24 — Final Readiness Assessment

You are approaching Senior/Lead readiness when you can take an unfamiliar architecture and reason through it without depending on memorized commands.

A strong response should naturally move through:

```text
Business
 ↓
Architecture
 ↓
Network
 ↓
Identity
 ↓
Infrastructure
 ↓
Delivery
 ↓
Runtime
 ↓
Observability
 ↓
Failure
 ↓
Recovery
 ↓
Cost
 ↓
Governance
```

The most important transformation from this curriculum is:

```text
Junior-style thinking:
"Which command should I run?"

Senior-style thinking:
"What layer is failing, what evidence proves it,
what is the safest change, and what is the blast radius?"
```

Another important transformation is:

```text
Tool-centric thinking:
"I know Azure DevOps, Terraform, Docker and Kubernetes."

Architecture-centric thinking:
"I understand how source, infrastructure, network,
identity, delivery, runtime and operations fit together."
```

And finally:

```text
Implementation
     +
Reasoning
     +
Troubleshooting
     +
Trade-offs
     +
Communication
     =
Senior/Lead DevOps capability
```

---

## Part 25 — 5-Minute Final Recall

Explain the entire DevOps lifecycle in one flow:

**Code → Build → Test → Security → Artifact → Infrastructure → Deploy → Run → Observe → Recover → Improve**

Explain the Senior/Lead troubleshooting pattern:

**What changed? → What is affected? → Which layer is failing? → What evidence do I have? → What is the safest mitigation? → How do I verify recovery? → How do I prevent recurrence?**

Explain the cloud architecture hierarchy:

**Tenant/Organization → Management/Governance → Subscription/Account → Resource Group/Service Boundary → Resources**

Explain the application request path:

**DNS → Network → Load Balancer/Ingress → Service → Pod → Application → Dependency**

Explain the secure delivery path:

**Source → Review → Build → Test → Scan → Artifact → Registry → Authorization → Deploy → Observe**

Explain the security model:

**Identity → Authentication → Authorization → Network Controls → Secrets → Runtime Controls**

Explain the production model:

**Reliability + Security + Observability + Cost + Automation + Governance**

If you can explain those flows clearly and then apply them to an unfamiliar system, you have moved beyond memorizing individual DevOps tools and toward architectural reasoning.

**Final mental model:**

> **A Senior/Lead DevOps engineer builds a reliable path from code to production, understands every major trust and failure boundary along that path, and can make evidence-based decisions when the system changes or breaks.**

---

## Part 26 — Cleanup

Clean up all temporary capstone resources after completing the exercises.

Check:

```text
Cloud resources
Kubernetes namespaces/resources
Container images
Container registries
Load balancers
Public IPs
Databases
Storage
Monitoring/log retention
IAM/RBAC assignments
Service connections
Test identities
Terraform state/test backends
Pipeline environments
```

Use the appropriate IaC destroy workflow for resources created exclusively by the lab.

For Terraform-managed infrastructure:

```bash
terraform plan
terraform destroy
```

Do not blindly run `terraform destroy` against a shared state or production environment.

Verify the cleanup after completion rather than assuming the command removed everything.

---

## Next

**Core 20-day curriculum complete.**

The next stage is not another large theory lesson. It is **deliberate repetition through realistic architecture, implementation, troubleshooting, and interview drills**.

Recommended progression:

```text
Core 20 Days
     ↓
Capstone
     ↓
Azure Overlay
     ↓
AWS Overlay
     ↓
Architecture Drills
     ↓
Incident Drills
     ↓
Senior/Lead Interview Simulation
```

The goal now is to turn knowledge into fast, reliable engineering judgment.

## Answers to practice

### 1. Five most important risks in the current ShopSphere environment

<details>
<summary>Answer</summary>

1. Manual production deploys let an individual change live traffic without review. 2. Manual infrastructure has no desired state, so drift and rebuilds are guesswork. 3. Secrets in config files leak through Git and disks. 4. A single instance means one VM failure takes the shop down. 5. Weak monitoring and no release traceability make database and deploy failures slow to diagnose.

Write risks before you pick Azure services. Senior work starts with WHY, then WHAT, then HOW.

</details>

### 2. Ten business-to-technical mappings for ShopSphere

<details>
<summary>Answer</summary>

1. Survive instance failure → three replicas plus a Service to healthy Pods. 2. Only approved production changes → protected `main`, CI, production authorization, audit. 3. No secrets in source → Key Vault plus workload identity. 4. Diagnose failed requests quickly → metrics, structured logs, traces, alerts. 5. Dev, UAT, Prod → isolated subscriptions or resource groups and separate identities. 6. Automated CI/CD → build once, promote the same image. 7. IaC → Terraform or Bicep modules plus plan before apply. 8. Containers → Docker image in ACR, digest-pinned on AKS. 9. Rollback → Deployment or Helm history plus compatible schema. 10. Reasonable cost → right-size nodes, sleep non-prod, cap log retention.

Each chain is business requirement → technical requirement → architecture decision → implementation → operational verification.

</details>

### 3. Enterprise hierarchy and why each boundary exists

<details>
<summary>Answer</summary>

Draw Entra tenant → management group → Dev, UAT, Prod subscriptions → resource groups → resources. Management groups hold shared policy. Subscriptions isolate blast radius, billing, and who can deploy. Resource groups group lifetime and RBAC.

Terraform state lives per environment, not one global file. One subscription per environment is a common pattern, not a law. Prod deploy identities cannot touch Dev state. Cost tags or subscriptions attribute spend.

</details>

### 4. API → PostgreSQL path and every security boundary

<details>
<summary>Answer</summary>

User → DNS → ingress or load balancer → AKS Service → Pod → VNet routing → NSG → private endpoint → PostgreSQL. For every hop ask who starts it, which DNS name, which route, which rule, which port, public or private.

Walk DNS → IP → route → security → port → service → application. Do not make every component private by slogan. Follow real flows: user to frontend, API to database, API to payment, AKS to ACR, CI to registry.

</details>

### 5. Terraform module inputs and outputs for AKS, network, and database

<details>
<summary>Answer</summary>

Put reusable design in `modules/network`, `modules/aks`, `modules/database`, `modules/registry`, `modules/monitoring`. Environment folders pass CIDR ranges, node size, database SKU, and names. Modules emit subnet IDs, AKS kube config endpoint, and database FQDN. They do not hard-code Prod values.

Production pipeline runs `terraform fmt -check`, `terraform validate`, and `terraform plan`, then controlled apply. Separate state per environment. Bicep uses the same idea: parameters, modules, what-if, controlled deploy.

</details>

### 6. Pipeline stages and which identity each stage needs

<details>
<summary>Answer</summary>

Developers open PRs and cannot apply Prod. Build identity compiles, tests, scans, and pushes the image. Registry push is that identity only. UAT deploy identity applies the same digest to UAT. Production deploy identity plus approval applies the same digest to Prod.

Do not rebuild per environment. Config stays outside the image. Trace Git commit → build ID → tag → digest → deployment.

</details>

### 7. For each identity: who, access, scope, why, revoke — then drop one permission

<details>
<summary>Answer</summary>

Developer: source and Dev, not Prod admin. CI: build and push, not Key Vault data-plane on Prod. Terraform identity: infrastructure at environment scope, not Entra global admin. Runtime: Key Vault get on named secrets. Human Prod operator: break-glass, not standing Contributor.

Revoke by disabling the assignment or federation. Then remove one extra permission, such as CI read of Prod secrets. Convenience is not a reason for Contributor everywhere.

</details>

### 8. What happens if a Pod dies, a Pod is unready, or a node fails

<details>
<summary>Answer</summary>

If one Pod dies, the ReplicaSet creates a replacement. The Service keeps sending to remaining ready Endpoints. If one Pod is unready, readiness removes it from Endpoints while it may still `Running`. Users should not hit it.

If the node fails, Kubernetes reschedules those Pods onto other nodes. Three replicas on one node would all disappear. Spread replicas, set requests, and use a PodDisruptionBudget so maintenance does not take the last copy.

</details>

### 9. Failure walk — Pod, node, zone, database, bad release

<details>
<summary>Answer</summary>

Pod 2 dies: detect via restart metrics; mitigate by remaining replicas; recover when replacement is Ready; data impact none if stateless; users see little. Node 1 dies: detect node NotReady; mitigate by replicas on other nodes; recover when Pods reschedule. Zone loss: detect regional AZ failure; mitigate only if you spread nodes; recover when the zone returns or capacity scales.

Database down: detect DB errors and traces; mitigate cached reads if any, otherwise fail orders; recover when DB returns; data impact is the data plane. Bad release: detect error rate after deploy; mitigate rollback if schema-safe; recover when SLO returns. Detection, mitigation, recovery, data impact, user impact — every layer.

</details>

### 10. CI identity compromised — blast radius, then shrink it

<details>
<summary>Answer</summary>

If CI is account Contributor, the attacker can change infrastructure, push images, and deploy Prod. Shrink it: CI only builds and pushes. A separate deploy identity applies GitOps or Helm. Runtime cannot push. Developer branches cannot reach Prod. Pin digests and require approval.

Then the maximum blast radius is malicious images in the registry, not Key Vault wipe plus VNet change. Revoke the federation, quarantine recent images, and rotate anything that identity could read.

</details>

### 11. Three alerts and the action each should trigger

<details>
<summary>Answer</summary>

1. ShopSphere API error rate above 5% for 10 minutes → page, check last deploy, consider rollback. 2. p95 latency above SLO for 10 minutes → page, open traces for database or payment spans. 3. Replica count below desired or restart storm → page, `kubectl describe pod` and node health.

Dashboards hold CPU. Alerts page on user symptoms and availability. Each alert names the first action.

</details>

### 12. Deploy application plus schema change without downtime

<details>
<summary>Answer</summary>

Use expand → deploy compatible app → migrate and backfill → switch behavior → contract. Add new columns first. Deploy app code that works with old and new schema, then migrate data. Remove old columns in a later release.

Do not ship a breaking migration with an app that cannot roll back. Choose rolling for ShopSphere unless you need instant traffic switch. Then weigh blue-green or canary against cost and complexity.

</details>

### 13. Incident 1 — evidence before you blame the deployment

<details>
<summary>Answer</summary>

You want the error start time aligned with deploy time, and the previous version healthy. You want a new image digest, plus traces and logs that show a new exception on the failing endpoint. Pods can be `Running` and Ready, with CPU and database healthy. That pattern is application regression, not saturation.

Kubernetes health is not application health. A Ready Pod can still return 500s. Use `kubectl rollout history deployment/shopsphere-api` and `kubectl logs <pod>`. Rollback only if schema stays compatible, then confirm recovery.

</details>

### 14. Incident 2 — three hypotheses and one test each

<details>
<summary>Answer</summary>

1. DNS cannot resolve the database hostname. Test: `nslookup database.internal` from `kubectl exec -it <pod> -- sh`. 2. Network policy or NSG blocks 5432. Test: `nc -vz database.internal 5432` and inspect NetworkPolicy and NSG. 3. Credentials or pool exhaustion. Test: application logs for auth failures versus timeouts, plus connection metrics.

Product browsing works, so ingress and frontend are likely fine. Orders fail plus database spans timeout. Walk DNS → IP → route → security → port → listener → pool → auth → application. Do not change NSGs first.

</details>

### 15. Incident 3 — authentication versus authorization versus network versus secret-not-found

<details>
<summary>Answer</summary>

Authentication failure: pipeline cannot prove who it is; token acquisition fails. Authorization failure: identity is known, Key Vault returns 403; role or scope is wrong. Network access failure: timeout or Key Vault firewall deny; packets never complete. Secret-not-found: 404-style miss; name or version is wrong.

Do not grant Owner. Identify the pipeline identity, auth success, actual identity, role, scope, network, then secret existence.

</details>

### 16. Incident 4 — Terraform drift investigation before reconcile

<details>
<summary>Answer</summary>

An engineer changes a production NSG by hand. Do not run `terraform apply` blind. Detect drift with `terraform plan`. Ask who, why, what changed, and whether it was approved.

If accidental, restore desired state. If intentional and wanted, update IaC. If not wanted, manage the exception on purpose. In the lab, change one rule, plan, document, then reconcile.

</details>

### 17. Three cost reductions and what each could sacrifice

<details>
<summary>Answer</summary>

1. Shut down or scale Dev at night — sacrifices always-on Dev testing. 2. Shorter log retention — sacrifices deep forensics. 3. Smaller node SKUs or fewer always-on replicas — sacrifices headroom during peaks.

Do not remove Key Vault or NetworkPolicy to save money. Pattern: requirement → reliability or security need → cost driver → option → trade-off. AKS compute, database, logs, and non-prod are the usual drivers.

</details>

### 18. Architecture review — requirement, decision, why, alternative, trade-off

<details>
<summary>Answer</summary>

Example: tolerate instance failure → multiple Kubernetes replicas → a Pod is one instance → alternative is one VM with restart → cost rises, instance failure impact falls. Repeat that template for network isolation, Key Vault, GitOps, rolling deploys, private PostgreSQL, and monitoring.

Present ShopSphere in interview order: business, enterprise structure, network, compute, Kubernetes, and database. Then identity, secrets, IaC, CI/CD, supply chain, and deploy strategy. Then observability, incident response, DR, cost, and governance. Every major decision needs a reason.

</details>

### 19. Interview — Design a highly available Spring Boot application on Azure

<details>
<summary>Answer</summary>

Run the API as three or more AKS replicas spread across zones. Front them with Ingress and a public load balancer. Use managed PostgreSQL that matches the data SLA. Use readiness probes so only healthy Pods get traffic. Keep the database private.

HA is placement plus dependencies, not only `replicas: 3`. Plan node pools, PDBs, and what happens when a zone or the database fails.

</details>

### 20. Interview — What belongs in management group, subscription, and resource group

<details>
<summary>Answer</summary>

The tenant holds identity. Management groups hold org policy. Subscriptions hold billing, environment isolation, and assignment scope. Resource groups hold related resources and lifecycle.

Put shared guardrails high. Put environment blast radius in subscriptions or well-isolated resource groups.

</details>

### 21. Interview — How would you separate Dev, UAT, and Prod?

<details>
<summary>Answer</summary>

Separate identities, state files, networks, and deploy permissions. Promote the same image. Change only config and secrets. Developers do not hold Prod Contributor.

Policy can be stricter in Prod. Cost controls can be stricter in Dev. Isolation is about blast radius, not only folder names.

</details>

### 22. Interview — How would you design the network?

<details>
<summary>Answer</summary>

Design from flows: user to frontend, user to API, API to PostgreSQL, API to payment, AKS to ACR and Key Vault. Place AKS and database on private subnets. Use NSGs per subnet. Use private endpoints where the data plane must not be public.

Walk DNS → IP → route → security → port. Hub-and-spoke is optional at enterprise scale, not automatic for a small lab.

</details>

### 23. Interview — Why would you use private endpoints?

<details>
<summary>Answer</summary>

They keep PaaS data planes such as PostgreSQL or Key Vault off the public internet. Traffic stays on the VNet through a private IP and private DNS.

Private still needs authentication. A compromised Pod on the VNet can still reach the endpoint if you allow it.

</details>

### 24. Interview — Load balancer versus Ingress

<details>
<summary>Answer</summary>

A transport load balancer fronts TCP or any Service of type LoadBalancer. Ingress (or Application Gateway patterns) routes HTTP by host and path to several Services.

Use a load balancer for the entry VIP. Use Ingress when you need HTTP routing, TLS at the edge, and many APIs on one entry point.

</details>

### 25. Interview — Why does Terraform need state?

<details>
<summary>Answer</summary>

State maps configuration to real resource IDs. Without it, Terraform cannot know what it already created. Plan compares config, state, and cloud.

Protect Prod state with remote backend, lock, encryption, and tight IAM. State can contain secrets.

</details>

### 26. Interview — What is drift?

<details>
<summary>Answer</summary>

Drift is actual cloud state differing from Terraform configuration and state. A manual NSG change is drift.

Detect with plan. Do not assume apply is always the fix.

</details>

### 27. Interview — How do you handle drift safely?

<details>
<summary>Answer</summary>

Detect, investigate who and why, then restore IaC or update IaC. Intentional emergency changes need a decision: codify or revert.

Blind `terraform apply` can undo a needed hotfix or bake in an unsafe rule.

</details>

### 28. Interview — How would you structure modules and environments?

<details>
<summary>Answer</summary>

Reusable modules plus `environments/dev`, `uat`, `prod` with values only. One design, many environments. Separate state per environment.

Do not copy-paste a whole stack three times. Do not put Prod CIDRs inside the module.

</details>

### 29. Interview — How would you protect production state?

<details>
<summary>Answer</summary>

Use a remote backend with lock and encryption. Limit who can read and write the blob or bucket. Separate Prod state from Dev. Do not commit state files.

Pipeline apply uses a dedicated identity. Humans do not download Prod state to laptops.

</details>

### 30. Interview — Why should production Terraform apply be controlled?

<details>
<summary>Answer</summary>

Apply changes real networks, identity, and data stores. Require plan review and authorization. `fmt` and `validate` catch structure. Humans catch risk.

Uncontrolled apply is manual production change with extra automation.

</details>

### 31. Interview — Why build once and promote the same artifact?

<details>
<summary>Answer</summary>

Rebuilding per environment can produce a different binary than you tested. Promote the digest you scanned. Change config, not the artifact.

That is how UAT evidence still applies to Prod.

</details>

### 32. Interview — How do you trace a production image back to source?

<details>
<summary>Answer</summary>

Record Git SHA, build ID, image tag, digest, and deployment. From the running Pod read the digest, then the build, then the commit.

Tags are not enough. Digests identify content.

</details>

### 33. Interview — How would you secure the pipeline?

<details>
<summary>Answer</summary>

Protect `main`, scan code, dependencies, secrets, IaC, and images, use federated identity, split build from deploy, approve Prod, and pin digests. Treat pipeline YAML as infrastructure.

The pipeline is a production security boundary.

</details>

### 34. Interview — How do you separate build and deployment permissions?

<details>
<summary>Answer</summary>

Build pushes to ACR. Deploy pulls and applies to AKS. Runtime reads Key Vault. None of those identities is Owner.

A leaked build secret then cannot deploy Prod by itself.

</details>

### 35. Interview — How would you implement rollback?

<details>
<summary>Answer</summary>

Keep previous Deployment or Helm revisions. `kubectl rollout undo` or `helm rollback` returns the last good image digest. Verify with rollout status, error rate, and a test order.

Rollback is unsafe if the new schema is incompatible. Then fix forward or restore data with a planned process.

</details>

### 36. Interview — Why Deployments instead of managing Pods directly?

<details>
<summary>Answer</summary>

A Deployment declares replica count and rollout. It owns a ReplicaSet, which owns Pods. If a Pod dies, Kubernetes replaces it.

Standalone Pods do not self-heal that way. Production manages desired state, not instances by name.

</details>

### 37. Interview — What is the purpose of a Service?

<details>
<summary>Answer</summary>

A Service gives a stable DNS name and ClusterIP while Pod IPs change. Selectors fill Endpoints with ready Pods.

Clients talk to the Service, not to a remembered Pod IP.

</details>

### 38. Interview — Running but not Ready

<details>
<summary>Answer</summary>

The container process is up. Readiness failed, so the Pod is not a Service backend. Startup may still be running, or `/actuator/health/readiness` failed.

`Running` is not traffic eligibility.

</details>

### 39. Interview — Readiness versus liveness

<details>
<summary>Answer</summary>

Readiness controls traffic. Liveness controls restart. Startup delays liveness for slow boots.

A liveness probe on the database can restart every replica during a DB blip.

</details>

### 40. Interview — Troubleshoot a Service that cannot reach Pods

<details>
<summary>Answer</summary>

Check selector versus labels, Endpoints, readiness, `targetPort`, NetworkPolicy, then the app listen port. Use `kubectl get endpoints`, `kubectl describe svc`, and a debug `wget`.

Empty Endpoints versus Endpoints-but-fail are different signatures.

</details>

### 41. Interview — Investigate CrashLoopBackOff

<details>
<summary>Answer</summary>

The container starts and exits. Read `kubectl describe pod` Events and `kubectl logs <pod> --previous`. Causes include bad config, missing secret, failed command, or a crash on boot.

Fix the exit cause. Restarting the Pod without a change repeats the loop.

</details>

### 42. Interview — Authentication versus authorization

<details>
<summary>Answer</summary>

Authentication proves who the caller is. Authorization decides what that identity may do. A valid token can still get 403.

Timeouts are usually network, not IAM.

</details>

### 43. Interview — Azure RBAC versus Kubernetes RBAC

<details>
<summary>Answer</summary>

Azure RBAC controls Azure resource actions at a scope. Kubernetes RBAC controls verbs on cluster objects. You need both for AKS.

Cloud Owner is not a reason to grant `cluster-admin`.

</details>

### 44. Interview — Managed or workload identity versus client secret

<details>
<summary>Answer</summary>

Client secrets are long-lived and leak. Managed or workload identity issues short-lived tokens from a ServiceAccount mapping. Prefer that for AKS to Key Vault.

Never put a developer password in the Pod.

</details>

### 45. Interview — How do you implement least privilege?

<details>
<summary>Answer</summary>

Grant the smallest action at the smallest scope for each identity. Prove with `kubectl auth can-i` and `az role assignment list`. Separate human, CI, Terraform, and runtime.

Challenge every `yes`.

</details>

### 46. Interview — How do you reduce blast radius?

<details>
<summary>Answer</summary>

Split identities, split environments, pin images, NetworkPolicy, private data planes, and no standing Prod admin. Ask: if this credential leaks, what can it change?

That question is the interview-quality explanation of least privilege.

</details>

### 47. Interview — How do you protect CI/CD credentials?

<details>
<summary>Answer</summary>

Use federation, short-lived tokens, secret stores, no secrets in YAML, no echo to logs, and different identities per environment. Rotate anything that hit Git history.

The pipeline should prove who it is, not carry a password.

</details>

### 48. Interview — Troubleshoot application → database connectivity

<details>
<summary>Answer</summary>

From the Pod: DNS, IP, route, NSG, NetworkPolicy, port 5432, listener, then credentials and pool. Use `nslookup` and `nc -vz`. Match timeouts to network. Match 403 or auth errors to identity.

Do not start by opening the NSG to the world.

</details>

### 49. Interview — DNS versus routing versus firewall versus port

<details>
<summary>Answer</summary>

DNS answers which IP. Routing answers whether packets go there. Firewall or NSG answers whether they are allowed. Port answers whether a process listens.

Test in that order. An allow rule does not help if DNS is wrong.

</details>

### 50. Interview — What is private DNS?

<details>
<summary>Answer</summary>

Private DNS resolves names to private IPs inside the VNet, such as a private endpoint FQDN. Public DNS would return a public address or none.

Wrong zone links look like “database is down.”

</details>

### 51. Interview — How does Kubernetes Service discovery work?

<details>
<summary>Answer</summary>

CoreDNS serves `<service>.<namespace>.svc.cluster.local`. The short name works in the same namespace. The Service ClusterIP load-balances to Endpoints.

`nslookup myapp` tests discovery. `wget` tests the path after DNS.

</details>

### 52. Interview — How cloud networking interacts with Kubernetes networking

<details>
<summary>Answer</summary>

CNI and Services sit on VNet or VPC. Cloud load balancers, NSGs, and private endpoints still apply. A Pod to database hop crosses both.

Investigate Kubernetes only, or cloud only, and you miss the failing layer.

</details>

### 53. Interview — Metrics versus logs versus traces

<details>
<summary>Answer</summary>

Metrics are numeric time series: rate, errors, latency, saturation. Logs are events and exceptions. Traces follow one request across spans.

Connect them with `trace_id`.

</details>

### 54. Interview — Why p95 and p99?

<details>
<summary>Answer</summary>

They show the slow tail that averages hide. Users on p99 still suffer when the mean looks fine.

Alert and SLO on distribution for user-facing APIs.

</details>

### 55. Interview — What should trigger an alert?

<details>
<summary>Answer</summary>

A condition that needs action: sustained user-facing errors, SLO burn, or availability loss. Include impact and first step.

CPU at 81% alone is usually a dashboard panel, not a page.

</details>

### 56. Interview — Investigate a sudden 500 increase

<details>
<summary>Answer</summary>

Check time versus last deploy, error rate, traces to the failing span, logs for the exception, Pod and database health. If deploy-aligned and infra idle, rollback if safe.

Do not restart the cluster first.

</details>

### 57. Interview — Distinguish application, network, database, and infrastructure failures

<details>
<summary>Answer</summary>

Application: 500s, normal CPU, new exceptions after deploy. Network: timeouts, DNS or NSG evidence, other services fine. Database: DB spans slow or error, pool saturation. Infrastructure: node NotReady, Pending, CPU limit, restarts.

Use golden signals plus Kubernetes and dependency panels. Business metrics catch “HTTP 200 but orders created = 0.”

</details>

### 58. Interview — What do you do first during a production incident?

<details>
<summary>Answer</summary>

Detect, assess user impact, stabilize and mitigate, then verify recovery. Root cause comes after users are safe.

Do not chase RCA while checkout is down.

</details>

### 59. Interview — When would you rollback?

<details>
<summary>Answer</summary>

When evidence ties the incident to the last release, the previous artifact is known-good, and data is compatible. Then verify error rate and a synthetic order.

Rollback is mitigation, not shame.

</details>

### 60. Interview — When is rollback unsafe?

<details>
<summary>Answer</summary>

When the new version already ran a breaking schema migration, or when state cannot move backward. Then fix forward or restore data with a plan.

Application rollback and database rollback are separate problems.

</details>

### 61. Interview — How do you write an RCA?

<details>
<summary>Answer</summary>

Record incident, impact, timeline, detection, mitigation, technical root cause, contributing factors, why controls failed, corrective and preventive actions. Avoid “human error” as the root cause.

Ask why it passed tests, why it reached Prod, and what control changes.

</details>

### 62. Interview — How do you prevent recurrence?

<details>
<summary>Answer</summary>

Change a control: a test, a gate, a probe, an alert, a permission, or a runbook. Preventive action is not “be more careful.”

Error budget and post-incident review decide whether to slow features until the control exists.

</details>

### 63. Interview — How do you decide between two valid architectures?

<details>
<summary>Answer</summary>

Score them against requirements: reliability, security, complexity, cost, team skill, and operations. Pick the one that meets the need with less unnecessary risk.

Write the alternative and the trade-off. Senior judgment is choosing, not listing every Azure SKU.

</details>

### 64. Interview — Balance security, reliability, complexity, and cost

<details>
<summary>Answer</summary>

Meet the requirement first. Do not drop Key Vault to save money. Do not add every scanner if the team cannot run them. Complexity is a reliability cost.

Use the pattern requirement → need → cost driver → option → trade-off.

</details>

### 65. Interview — How do you standardize infrastructure across many teams?

<details>
<summary>Answer</summary>

Offer a paved road: repo template, pipeline, deploy path, monitoring defaults. Platform owns the path. App teams consume it. Terraform modules and GitOps charts are the reusable design.

Tickets for every new service do not scale. Guardrails live in policy and modules, not in tribal knowledge.

</details>

### 66. Interview — How do you reduce operational toil?

<details>
<summary>Answer</summary>

Automate repeatable work: IaC, GitOps reconciliation, autoscaling, golden dashboards, and self-service on the paved road. Delete manual Prod deploys and snowflake VMs.

Toil is manual, repetitive, interrupt-driven work. Measure it. Replace it with desired state.

</details>

### 67. Interview — Explain a trade-off to a non-technical stakeholder

<details>
<summary>Answer</summary>

State the user outcome, the risk, the money, and the choice in plain words. Example: three zones cost more and keep checkout up if one datacenter fails. One zone is cheaper and takes the shop down in that failure.

Do not start with SKU names. Start with what the business feels.

</details>

### 68. Exercise A — Application failure

<details>
<summary>Answer</summary>

Deploy a broken image. Detect via error-rate alert and 500s on the dashboard. Confirm with logs and rollout history. Rollback with `kubectl rollout undo deployment/shopsphere-api` or `helm rollback`. Verify Pods Ready and error rate down.

Kubernetes may still show `Running`. Application health is the SLO, not the Pod phase.

</details>

### 69. Exercise B — Networking failure

<details>
<summary>Answer</summary>

Break a lab path, such as DNS or NetworkPolicy to the database. Diagnose DNS → route → security → port → Service → application. Restore the object you broke. Prove with `nslookup` and `nc -vz` from the Pod.

Do not open all NSGs to recover. Restore the intended rule.

</details>

### 70. Exercise C — Identity failure

<details>
<summary>Answer</summary>

Remove one lab role assignment. Observe 403 or failed token, not a timeout. Identify the exact missing action and scope. Restore only that grant.

If you “fixed” it with Owner, you failed the exercise.

</details>

### 71. Exercise D — IaC drift

<details>
<summary>Answer</summary>

Change a lab resource by hand. Run `terraform plan`. Investigate the diff. If the change is unwanted, apply to restore. If wanted, code it and apply.

Document who, why, and security impact before reconcile.

</details>

### 72. Exercise E — Supply-chain failure

<details>
<summary>Answer</summary>

Add a vulnerable lab dependency or image package. Watch SCA or image scan fail or warn per policy. Patch, replace, or record an audited exception. Do not disable the gate.

The pipeline must show which control caught it.

</details>

### 73. Exercise F — Resource saturation

<details>
<summary>Answer</summary>

Lower CPU limits or raise load in the lab. Watch latency, 5xx, `kubectl top pods`, HPA, and maybe Pending Pods. Recover by scaling, restoring limits, or stopping the load.

If the database is the bottleneck, extra Pods make it worse. Read the evidence before you scale.

</details>

### 74. Recall — Entire DevOps lifecycle in one flow

<details>
<summary>Answer</summary>

Code → Build → Test → Security → Artifact → Infrastructure → Deploy → Run → Observe → Recover → Improve. That is ShopSphere from Git to RCA.

A Senior engineer can walk an unfamiliar system on this path without memorizing commands first.

</details>

### 75. Recall — Senior/Lead troubleshooting pattern

<details>
<summary>Answer</summary>

What changed? What is affected? Which layer is failing? What evidence do I have? What is the safest mitigation? How do I verify recovery? How do I prevent recurrence?

Junior thinking asks which command to run. Senior thinking asks which layer, which evidence, which blast radius.

</details>

### 76. Recall — Cloud architecture hierarchy

<details>
<summary>Answer</summary>

Tenant or organization → management and governance → subscription or account → resource group or service boundary → resources. Identity sits at the tenant. Policy sits high. Blast radius sits at subscription and assignment scope.

Place ShopSphere Prod in an isolated billing and IAM boundary.

</details>

### 77. Recall — Application request path

<details>
<summary>Answer</summary>

DNS → network → load balancer or Ingress → Service → Pod → application → dependency. Every arrow is a failure boundary.

Start at the client. Do not jump to the Pod.

</details>

### 78. Recall — Secure delivery path

<details>
<summary>Answer</summary>

Source → review → build → test → scan → artifact → registry → authorization → deploy → observe. Build once. Promote the digest. Approve Prod.

The pipeline is on this path. It is not a side tool.

</details>

### 79. Recall — Security model

<details>
<summary>Answer</summary>

Identity → authentication → authorization → network controls → secrets → runtime controls. Who, prove who, what they may do, where packets flow, how secrets arrive, what the Pod can do if compromised.

Private networking does not replace the rest.

</details>

### 80. Recall — Production model and capstone mindset

<details>
<summary>Answer</summary>

Reliability + security + observability + cost + automation + governance. A Senior/Lead DevOps engineer builds a reliable path from code to production. That person understands each trust and failure boundary. They make evidence-based decisions when the system changes or breaks.

Tool lists are not enough. Architecture-centric thinking is how source, infrastructure, network, identity, delivery, runtime, and operations fit together.

</details>
