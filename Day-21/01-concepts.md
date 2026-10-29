# Day 21 — Senior/Lead DevOps Capstone

This Day uses three files. Read them in this order.

1. [01-concepts.md](01-concepts.md) — lesson content (this file)
2. [02-questions-and-answers.md](02-questions-and-answers.md) — practice items, each with a model answer
3. [03-implementation.md](03-implementation.md) — hands-on lab

## Part 1 — The Capstone Mindset

The first 20 days taught individual capabilities: Linux and networking, CI/CD, Terraform, cloud architecture, containers, Kubernetes, identity, security, and observability. A Senior/Lead DevOps engineer is expected to combine these capabilities rather than solve each problem in isolation. In a real interview or production situation, you may receive a business requirement such as “move this application to Azure with high availability and secure CI/CD.” You then have to turn it into an architecture, explain the trade-offs, implement the important parts, and troubleshoot failures. This capstone is designed to make you practice exactly that.

Your core reasoning loop remains:

**WHY → WHAT → HOW → WHAT CAN GO WRONG → HOW DO I KNOW → HOW DO I FIX IT**

Do not start by choosing Azure services. Start with the application, business requirements, reliability needs, security boundaries, operational model, and cost constraints. Then choose the architecture that satisfies those requirements.

**Remember:** Senior-level DevOps is not knowing the most services. It is making sound engineering decisions and being able to explain them.

> **JD note:** What separates Lead from Senior in real JDs is scope, not tools. See the [Lead vs Senior pattern card](../jd-insights/patterns/lead-vs-senior-signals.md).

Lead JDs now also name a small DevOps team, about four people, and they still want you on the keyboard. You assign who cuts the release and who is primary on-call, and you keep the escalation and the story after. Interviewers grade one STAR example of that split. They do not grade a manager title you did not hold.

> **Remember:** Delegate the deploy and the pager. Keep the outcome. That is leading a team of four.

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

## Takeaway

Explain the DevOps lifecycle, the troubleshooting pattern, the architecture hierarchy, the request path, the secure delivery path, the security model, and the production model. Then apply those flows to an unfamiliar system. That is architectural reasoning, not a memorized tool list.

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

