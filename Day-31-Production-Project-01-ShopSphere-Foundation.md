# Day 31 — Production Project 01: ShopSphere Foundation

Day 30 finished the conceptual curriculum. Day 31 starts the **engineering phase**: instead of learning another collection of services, you will build a realistic production platform and use the previous lessons while building it. The project will use a Spring Boot backend, Angular frontend, relational database, Terraform, CI/CD, containers, cloud networking, identity, secrets, observability, and controlled deployments. The important rule is that you should make architecture decisions before writing infrastructure code. Every major decision should answer **what, why, how, failure mode, and trade-off**.

---

## Part 1 — The Project

You are going to build a fictional production platform called **ShopSphere**.

ShopSphere is an e-commerce application with:

- Angular frontend
- Spring Boot backend
- Relational database
- REST APIs
- Containerized backend
- Separate Dev, UAT, and Production environments
- CI/CD
- Terraform-managed infrastructure
- Centralized secrets
- Private application-to-database communication
- Monitoring and logging
- Controlled Production deployment
- High availability in Production
- Documented recovery and troubleshooting procedures

The project is deliberately designed around the problems a Senior/Lead DevOps engineer is expected to solve.

You are not trying to build Amazon.

You are building a system that is **small enough to understand but realistic enough to expose production engineering problems**.

---

## Part 2 — Start With the Business, Not Terraform

Before creating an AWS account, VPC, Terraform module, or pipeline, write a short business requirement.

ShopSphere needs to allow customers to browse products, authenticate, place orders, and view order status. The frontend is publicly accessible, while the backend and database should be protected from unnecessary public exposure. Development teams need rapid deployments to Dev, controlled promotion to UAT, and an auditable Production release process.

For the initial project, use these assumptions:

```text
Users:
Internet-facing

Frontend:
Angular

Backend:
Spring Boot

Database:
PostgreSQL or MySQL

Backend:
Containerized

Environments:
Dev / UAT / Prod

IaC:
Terraform

CI/CD:
Azure DevOps or AWS-native tooling

Production:
High availability

Secrets:
Central secret store

Database:
Private connectivity
```

Do not add requirements simply because they sound impressive. A Senior engineer learns to distinguish **requirements** from **technology preferences**.

---

## Part 3 — Define Non-Functional Requirements

Write the non-functional requirements before designing the architecture.

For the initial version, use:

| Requirement | Initial target |
|---|---|
| Availability | Production should tolerate failure of one application instance |
| Deployment | Minimal downtime |
| Recovery | Application rollback should be possible |
| Security | No public database access |
| Identity | Prefer workload identities/roles |
| Secrets | No secrets in Git or images |
| Infrastructure | Terraform-managed |
| Observability | Logs, metrics, health checks |
| Environments | Dev, UAT, Prod isolation |
| Cost | Development resources should remain inexpensive |
| Traceability | Production release must map to a Git commit |

These are starting assumptions, not universal production standards.

The important lesson is that architecture should be derived from requirements.

---

## Part 4 — Draw the First Architecture

Before implementing anything, draw this:

```text
                         Internet
                            │
                            ▼
                         DNS
                            │
                            ▼
                      Frontend
                            │
                            ▼
                    Load Balancer
                            │
                            ▼
                    Spring Boot App
                       /        \
                      /          \
                     ▼            ▼
              Secret Store      Database
```

Now add the DevOps layer:

```text
Developer
    │
    ▼
Git Repository
    │
    ▼
CI/CD
    │
    ├──────────────► Container Registry
    │                       │
    │                       ▼
    └────────────────► Application
```

Then add:

```text
Terraform
Identity
Security
Monitoring
Logging
Governance
Cost
```

Do not worry about exact AWS or Azure resources yet.

The purpose of this exercise is to force yourself to think in **responsibilities and relationships** before thinking in product names.

---

## Part 5 — Choose the Initial Runtime

For the first implementation, use a managed container runtime rather than immediately introducing Kubernetes.

The reason is educational as well as architectural: Kubernetes introduces another major control plane, networking model, scheduling model, and operational surface. ShopSphere's initial requirements do not require Kubernetes-specific capabilities.

Your first production-style flow should therefore be:

```text
Git
 ↓
Build
 ↓
Container Image
 ↓
Registry
 ↓
Managed Container Runtime
 ↓
Load Balancer
 ↓
Database
```

Later, you can create a second architecture using Kubernetes and compare the operational differences.

The question you should be able to answer is:

**What requirement would justify moving from managed containers to Kubernetes?**

Do not answer “because Kubernetes is more powerful.” Explain the specific capability or organizational requirement that creates the need.

---

## Part 6 — Design the Environment Model

Do not create three completely different architectures.

Use one architecture pattern with environment-specific values.

Conceptually:

```text
                    Common Architecture
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
             Dev          UAT          Prod
```

The environments should differ where the requirements differ.

For example:

```text
Dev
- small capacity
- lower availability requirement
- inexpensive resources
- rapid deployment

UAT
- production-like configuration
- controlled testing
- realistic integration testing

Prod
- high availability
- stricter access
- stronger monitoring
- controlled deployment
- stronger recovery requirements
```

Do not copy Terraform folders and modify resources independently for every environment. Aim for reusable modules with environment-specific inputs.

---

## Part 7 — Design the Network Before Creating It

Start with the logical network.

For AWS:

```text
VPC
│
├── Public Subnets
│     └── Internet-facing entry components
│
├── Private Application Subnets
│     └── ShopSphere application
│
└── Private Database Subnets
      └── Database
```

The exact AWS services will be selected during implementation.

The important traffic paths are:

```text
Internet
   ↓
Public Entry
   ↓
Application
   ↓
Database
```

and:

```text
Application
   ↓
Private Database Connection
   ↓
Database
```

The database should not require a public route for normal application access.

For outbound traffic, explicitly determine whether the application needs internet access and why. Do not automatically create expensive networking components without understanding their purpose.

---

## Part 8 — Design the Security Boundaries

For every communication path, ask:

```text
Who is communicating?
What are they accessing?
Why is access required?
Which identity is used?
Which network path is used?
Which security rule permits it?
```

For example:

```text
ShopSphere App
      │
      ├── Identity ──► Secret Store
      │
      └── Network ───► Database
```

The application should not receive permissions to modify infrastructure simply because the deployment pipeline requires those permissions.

Create separate conceptual identities:

```text
Developer Identity
Pipeline Identity
Infrastructure Identity
Application Runtime Identity
Database Identity
```

They may be implemented differently depending on the platform, but the separation of responsibilities should remain.

---

## Part 9 — Define the Repository Structure

Create a repository structure similar to:

```text
shopsphere/
│
├── backend/
│   ├── src/
│   ├── pom.xml
│   └── Dockerfile
│
├── frontend/
│   ├── src/
│   └── package.json
│
├── infra/
│   ├── modules/
│   ├── environments/
│   │   ├── dev/
│   │   ├── uat/
│   │   └── prod/
│   └── README.md
│
├── pipelines/
│   ├── app/
│   └── infra/
│
├── docs/
│   ├── architecture.md
│   ├── security.md
│   ├── networking.md
│   └── adr/
│
└── README.md
```

Do not treat this structure as mandatory.

The important separation is:

```text
Application
Infrastructure
Pipelines
Documentation
```

This makes ownership and change boundaries easier to reason about.

---

## Part 10 — Build the Application Locally First

Before cloud infrastructure, make sure the application can run locally.

The backend should expose at least:

```text
GET /health
GET /api/products
POST /api/orders
GET /api/orders/{id}
```

The frontend should call the backend.

The database should contain enough data to prove that the application is actually using it.

Do not spend the entire project building business functionality. The application exists primarily to give you something realistic to deploy, observe, break, and recover.

The `/health` endpoint is especially important because later the load balancer and deployment system need a meaningful health signal.

---

## Part 11 — Containerize the Backend

Create a production-oriented Dockerfile.

A basic starting point is:

```dockerfile
FROM eclipse-temurin:21-jre

WORKDIR /app

COPY target/shopsphere.jar app.jar

USER 10001

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]
```

Build the application first:

```bash
mvn clean package
```

Build the image:

```bash
docker build -t shopsphere-api:dev .
```

Run it:

```bash
docker run --rm -p 8080:8080 shopsphere-api:dev
```

Verify:

```bash
curl http://localhost:8080/health
```

Do not move to the cloud until you understand this chain:

```text
Source
 ↓
Maven Build
 ↓
JAR
 ↓
Docker Build
 ↓
Image
 ↓
Container
 ↓
HTTP Response
```

---

## Part 12 — Separate Build-Time and Runtime Configuration

Do not bake environment-specific configuration into the image.

The image should be reusable:

```text
Same Image
   │
   ├── Dev
   ├── UAT
   └── Prod
```

Environment-specific values should enter at runtime.

For example:

```text
DATABASE_HOST
DATABASE_PORT
DATABASE_NAME
APPLICATION_ENV
```

Secrets should come from the appropriate secret-management mechanism.

The principle is:

**Build the software once. Configure it when it runs.**

This is one of the most important concepts in the entire project.

---

## Part 13 — Create the Terraform Foundation

Start Terraform with the smallest possible foundation.

Your initial Terraform responsibilities should eventually include:

```text
Network
Security
Container Runtime
Load Balancer
Database
Secrets Integration
Monitoring
IAM
```

Do not create all of these at once.

Start with:

```text
Provider
 ↓
Resource Group / Account context
 ↓
Network
```

Then validate:

```bash
terraform fmt
terraform validate
terraform plan
```

Do not run `terraform apply` simply because the plan exists.

Read the plan.

For every resource, ask:

```text
Why is Terraform creating this?
Who owns it?
What depends on it?
What happens if it is deleted?
```

---

## Part 14 — Build the Network With Terraform

Create the VPC/VNet and subnets through Terraform.

Your first network milestone is:

```text
Cloud Network
 ├── Public/Ingress Subnet
 ├── Application Subnet
 └── Database Subnet
```

Do not create complex routing until you know why the application requires it.

After deployment, inspect the actual cloud resources and compare them with your Terraform configuration.

This is your first exposure to the complete IaC loop:

```text
Terraform Code
 ↓
Plan
 ↓
Apply
 ↓
Cloud Resource
 ↓
Inspect
 ↓
Compare with Desired State
```

---

## Part 15 — Create the Database Privately

Deploy the relational database so that normal application traffic reaches it privately.

The target flow is:

```text
Internet
   X
   │
   │  no direct database access
   X
Database

Application
   │
   ▼
Private Database Connectivity
```

Test the network deliberately.

From the application environment, verify that the database endpoint resolves and is reachable on the database port.

Then test from an environment that should **not** have database access.

The goal is to experience the difference between:

```text
Can resolve
Can route
Can connect
Can authenticate
Can query
```

These are different conditions.

---

## Part 16 — Add the Container Registry

Create the container registry and push the application image.

The delivery path becomes:

```text
Git Commit
 ↓
Build
 ↓
Docker Image
 ↓
Registry
 ↓
Runtime
```

Tag the image with traceable metadata, for example:

```text
shopsphere-api:<git-sha>
```

Also record the resulting image digest.

The digest gives you a stronger answer to:

**Which exact image is running?**

Do not rely exclusively on a mutable tag.

---

## Part 17 — Deploy the Application

Deploy the containerized Spring Boot application.

The runtime should:

- pull the image
- start the container
- provide the required runtime configuration
- obtain secrets through its identity
- connect to the private database
- expose the health endpoint
- register with the load-balancing layer

Then verify:

```text
Container Running
        ↓
Application Started
        ↓
Health Check Passing
        ↓
Load Balancer Target Healthy
        ↓
HTTP Request Successful
        ↓
Database Query Successful
```

Do not stop at “container is running.”

A running process can still be an unhealthy application.

---

## Part 18 — Build the First Application Pipeline

Create the application pipeline:

```text
Source
 ↓
Build
 ↓
Unit Test
 ↓
Security Checks
 ↓
Docker Build
 ↓
Push Image
 ↓
Deploy Dev
 ↓
Health Check
```

At this stage, do not automate Production.

First prove that the pipeline can reliably deliver to Dev.

The pipeline should record:

```text
Git Commit
Build ID
Image Tag
Image Digest
Deployment Version
```

You are building traceability from the beginning rather than trying to add it after the platform becomes complicated.

---

## Part 19 — Add UAT Promotion

Once Dev is stable, introduce UAT.

Do not rebuild the image.

Use:

```text
Build Once
     ↓
Image
     ↓
Dev
     ↓
UAT
```

This gives you an important test of artifact promotion.

Ask yourself:

**If the UAT image is different from the Dev image, what happened?**

Possible causes include rebuilding, mutable tags, different build inputs, or pipeline design problems.

The goal is to make the same artifact move through environments.

---

## Part 20 — Production Deployment Design

Only after Dev and UAT work should you design Production.

Production should introduce additional controls:

```text
UAT
 ↓
Validation
 ↓
Approval / Policy
 ↓
Production
 ↓
Health Verification
 ↓
Observe
```

Production should also have stronger access restrictions.

A developer should not need unrestricted infrastructure permissions simply to release an application.

The pipeline should be the controlled delivery mechanism.

---

## Part 21 — Add Observability

Add at least:

```text
Application Logs
Infrastructure Metrics
Container Metrics
Load Balancer Metrics
Database Metrics
Deployment History
Audit Logs
```

Create a simple dashboard.

Start with:

- request count
- error rate
- latency
- CPU
- memory
- application health
- database health

Then create one useful alert.

Do not create dozens of alerts.

Your first alert should represent a condition that genuinely requires investigation.

---

## Part 22 — Failure Drill: Bad Application Release

Deploy a version that intentionally fails its health check.

Observe what happens.

Do not immediately repair it.

Record:

```text
What changed?
Which commit?
Which image?
Which deployment?
Which task/container?
What does the health check report?
What do application logs show?
What does the load balancer show?
```

Then recover.

The recovery should be documented:

```text
Detection
 ↓
Diagnosis
 ↓
Containment
 ↓
Rollback / Fix
 ↓
Verification
 ↓
RCA
```

This is where your previous deployment-strategy and observability lessons become practical engineering.

---

## Part 23 — Failure Drill: Database Connectivity

Break the application-to-database path deliberately.

For example, introduce an incorrect database hostname or block the required port.

Then investigate without guessing.

Use:

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
Database Service
 ↓
Authentication
 ↓
Application
```

Your final incident note should identify:

```text
Symptom
Root Cause
Evidence
Fix
Preventive Control
```

Do not write “database was down” unless the evidence proves the database itself was down.

---

## Part 24 — Failure Drill: IAM

Remove one required permission from the application's runtime identity.

Deploy or restart the application.

Observe the failure.

Then determine:

```text
Which identity?
 ↓
What resource?
 ↓
Which API/action?
 ↓
Was authentication successful?
 ↓
Was authorization denied?
 ↓
What exact permission is required?
```

Restore the minimum required permission.

This exercise is important because IAM failures are often incorrectly diagnosed as application or networking failures.

---

## Part 25 — Infrastructure Pipeline

Now create the infrastructure pipeline:

```text
Terraform Commit
 ↓
fmt
 ↓
validate
 ↓
security/policy checks
 ↓
plan
 ↓
review
 ↓
apply
 ↓
verification
```

Production infrastructure changes should be controlled separately from application releases where appropriate.

For example:

```text
Application change
→ application pipeline

Network change
→ infrastructure pipeline

Database infrastructure change
→ infrastructure pipeline

IAM change
→ infrastructure pipeline / controlled security workflow
```

The exact organization can vary, but ownership and blast radius should be deliberate.

---

## Part 26 — Create the Architecture Decision Records

Create at least five ADRs.

Use this simple structure:

```text
# ADR-001: Application Runtime

Context:
What requirement exists?

Decision:
What did we choose?

Why:
Why does this satisfy the requirement?

Trade-offs:
What are we giving up?

Alternatives:
What else did we consider?

Consequences:
What operational impact does this create?
```

Create ADRs for:

```text
ADR-001 Runtime choice
ADR-002 Network architecture
ADR-003 Database connectivity
ADR-004 CI/CD design
ADR-005 Deployment strategy
```

Do not write generic textbook explanations.

Write why **your** project made each decision.

---

## Part 27 — Lead-Level Ownership Model

Pretend ShopSphere is owned by several teams.

Define ownership for:

```text
Application Team
Platform/DevOps Team
Security Team
Database Team
Cloud/FinOps Team
```

Then answer:

```text
Who owns the application code?
Who owns Terraform modules?
Who owns the production network?
Who approves production deployment?
Who owns secrets?
Who responds to application incidents?
Who controls cloud budgets?
Who can modify IAM?
```

This exercise moves the project from “I can deploy an application” toward “I can design a platform operating model.”

---

## Part 28 — Cost Review

Before declaring the platform complete, inspect its cloud cost.

For every billable resource, ask:

```text
Why does it exist?
Is it required?
Who owns it?
Can Dev use a cheaper configuration?
Can it scale?
Can it be stopped outside working hours?
What happens if traffic increases 10×?
```

Pay particular attention to resources that can create charges even when the application receives little traffic.

Do not optimize blindly.

For every cost reduction, identify the potential effect on:

```text
Availability
Performance
Security
Recovery
Operational complexity
```

A cost decision without its trade-off is incomplete.

---

## Part 29 — Final Architecture Review

Before moving on, review the entire platform from left to right:

```text
User
 ↓
DNS
 ↓
Frontend
 ↓
Load Balancer
 ↓
Application
 ↓
Database
```

Now review the supporting systems:

```text
Git
 ↓
CI/CD
 ↓
Registry
 ↓
Deployment
 ↓
Observability
```

Then the control systems:

```text
Identity
Security
Terraform
Governance
Cost
Audit
```

For every component, ask:

**What happens if it fails?**

If you cannot answer, the architecture is not finished.

---

## Part 30 — Senior/Lead Challenge

Now deliberately remove the assumption that the current architecture is correct.

Consider these changes:

### Scenario A — Traffic increases 10×

What becomes the bottleneck?

Do not automatically scale everything.

Identify:

```text
Frontend
Load Balancer
Application
Database
External APIs
Network
```

Then determine which layer actually limits throughput.

### Scenario B — Production must survive an Availability Zone failure

What changes?

Think about:

```text
Application placement
Load balancing
Database availability
Network resources
Secrets
Observability
Deployment
```

### Scenario C — Production deployment must have near-zero downtime

What changes?

Think about:

```text
Health checks
Traffic management
Capacity
Deployment strategy
Database compatibility
Rollback
```

### Scenario D — Security requires no long-lived cloud credentials in CI/CD

What changes?

Design the identity flow using short-lived/federated credentials where supported.

### Scenario E — Monthly cloud cost doubles

What evidence do you collect before changing architecture?

### Scenario F — A production deployment succeeds but users receive 503

Trace the system from:

```text
Load Balancer
 ↓
Target
 ↓
Runtime
 ↓
Container
 ↓
Application
 ↓
Dependency
```

---

## Part 31 — Final Recall

Without looking at your implementation, explain:

1. Why did you choose this application runtime?
2. Why is the database private?
3. How does application traffic reach the database?
4. Which identities exist?
5. Which identity does the application use?
6. Which identity deploys the application?
7. Where are secrets stored?
8. How does an image move from Git to Production?
9. How do you prove which commit is running?
10. How do Dev, UAT, and Prod differ?
11. How does Terraform manage the infrastructure?
12. Where is Terraform state stored?
13. How are infrastructure changes approved?
14. How does the application get observed?
15. What happens when the application fails its health check?
16. How do you troubleshoot database connectivity?
17. How do you troubleshoot an IAM failure?
18. How do you recover from a bad deployment?
19. What is the largest blast radius of each major identity?
20. What would you change if traffic became 10× larger?

If you cannot answer one, return to the relevant project component rather than rereading all 30 lessons.

---

## Part 32 — Day 31 Completion Criteria

Do not consider Day 31 complete because the cloud resources were created.

Complete the day when you have:

```text
[ ] Business requirements written
[ ] Non-functional requirements defined
[ ] Architecture diagram created
[ ] Environment model defined
[ ] Network design created
[ ] Security boundaries defined
[ ] Repository structure created
[ ] Application running locally
[ ] Backend containerized
[ ] Runtime configuration separated
[ ] Terraform foundation created
[ ] Network deployed through Terraform
[ ] Private database connectivity working
[ ] Container registry working
[ ] Application deployed
[ ] Dev pipeline working
[ ] Same artifact promoted to UAT
[ ] Production deployment controlled
[ ] Observability configured
[ ] Bad-release failure drill completed
[ ] Database failure drill completed
[ ] IAM failure drill completed
[ ] Infrastructure pipeline created
[ ] Five ADRs written
[ ] Ownership model documented
[ ] Cost review completed
[ ] Final architecture review completed
```

The key completion criterion is:

**You can explain every major component, its purpose, its dependency, its identity, its network path, its failure mode, its recovery method, and its cost.**

---

## Part 33 — What Comes Next

Day 31 establishes the platform.

The next days should not simply repeat the same theory.

The project should evolve through increasingly difficult engineering changes:

```text
Day 31
Foundation
   ↓
Day 32
Production Networking + Security
   ↓
Day 33
CI/CD + Artifact Promotion
   ↓
Day 34
Reliability + Deployment Strategies
   ↓
Day 35
Observability + Incident Response
   ↓
Day 36
Terraform Enterprise Hardening
   ↓
Day 37
Kubernetes Migration
   ↓
Day 38
Multi-Environment / Multi-Account Architecture
   ↓
Day 39
Disaster Recovery + Cost Engineering
   ↓
Day 40
Lead DevOps Architecture Review
```

The objective of this second phase is different from the first 30 days:

**You are no longer collecting knowledge. You are converting knowledge into engineering judgment.**

---

## Cleanup

Do not automatically destroy the entire ShopSphere platform at the end of Day 31 if it will be used for the following project days.

Instead, classify resources:

```text
Keep:
Core project infrastructure that will be reused

Destroy:
Temporary labs
Experimental resources
Failure-drill resources
Unnecessary billable components
```

For resources that remain, document:

```text
Resource
Purpose
Environment
Owner
Terraform module
Expected cost
```

This becomes the beginning of your real platform inventory.
