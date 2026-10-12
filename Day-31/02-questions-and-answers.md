# Day 31 — Questions and answers

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Then answer each item below before you open the Answer block. After that, do the lab in [03-implementation.md](03-implementation.md).

Write your own answer first. Open the Answer block only after you try. Keep the original numbering.

---

## Part 31 — Final Recall

Without looking at your implementation, explain:

---

## 1. Why did you choose this application runtime?

<details>
<summary>Answer</summary>

ShopSphere is a long-running Spring Boot API in a container. Initial requirements do not need Kubernetes APIs, operators, or cluster networking. A managed container runtime (Container Apps or ECS Fargate) gives deploy, scale, and identity with less cluster work.

Move to AKS/EKS only when a named Kubernetes capability or platform standard appears. “More powerful” is not a requirement.

</details>

---

## 2. Why is the database private?

<details>
<summary>Answer</summary>

PostgreSQL holds orders and customer data. Internet users must not reach TCP 5432. Only the application subnet or Security Group may connect.

Public database access is out of scope for this project’s security NFR.

</details>

---

## 3. How does application traffic reach the database?

<details>
<summary>Answer</summary>

The app resolves the private DNS name to a private IP, routes inside the VPC/VNet, passes SG/NSG on 5432, then authenticates. No public route is required for that path.

Can resolve, can route, can connect, can authenticate, and can query are five different checks.

</details>

---

## 4. Which identities exist?

<details>
<summary>Answer</summary>

Developer, pipeline, infrastructure (Terraform), application runtime, and database. Humans use Identity Center or Entra. Workloads use roles or managed identity.

Do not collapse these into one Contributor.

</details>

---

## 5. Which identity does the application use?

<details>
<summary>Answer</summary>

The runtime identity on the task, revision, or Pod. It reads named secrets and talks to the database. It cannot apply Terraform or update the Production service.

Compromise blast radius is secret-get plus app data, not the landing zone.

</details>

---

## 6. Which identity deploys the application?

<details>
<summary>Answer</summary>

The application pipeline deploy identity. It updates the container app or ECS service with an already-built digest. It does not own the hub network.

Production humans release through this pipeline, not with standing admin.

</details>

---

## 7. Where are secrets stored?

<details>
<summary>Answer</summary>

Key Vault or Secrets Manager. The runtime identity retrieves them. Nothing in Git, Dockerfiles, or pipeline logs.

`DATABASE_HOST` can be config. The password is a secret.

</details>

---

## 8. How does an image move from Git to Production?

<details>
<summary>Answer</summary>

Commit → build, test, scan → image in ACR/ECR tagged with Git SHA and recorded digest → Dev → same digest to UAT → approval → same digest to Prod.

Do not rebuild for Production.

</details>

---

## 9. How do you prove which commit is running?

<details>
<summary>Answer</summary>

Read the running digest. Map it to the registry, build ID, and Git SHA recorded by the pipeline. An info endpoint can show non-secret `GIT_COMMIT`.

A mutable `:latest` tag does not prove anything.

</details>

---

## 10. How do Dev, UAT, and Prod differ?

<details>
<summary>Answer</summary>

Same architecture pattern, different inputs. Dev: small, cheap, fast deploys. UAT: production-like tests. Prod: Multi-AZ, stricter IAM, approvals, stronger monitoring.

Do not fork three unrelated Terraform trees.

</details>

---

## 11. How does Terraform manage the infrastructure?

<details>
<summary>Answer</summary>

Modules for network, database, runtime, and registry. Environment folders pass CIDR, SKU, and names. `fmt`, `validate`, plan, approval, apply.

Read every plan resource: why, owner, dependency, delete impact.

</details>

---

## 12. Where is Terraform state stored?

<details>
<summary>Answer</summary>

Remote backend: Azure Storage or S3 with versioning, encryption, tight IAM, and locking. Separate keys for `dev`, `uat`, and `prod`.

State is a control system, not a scratch file.

</details>

---

## 13. How are infrastructure changes approved?

<details>
<summary>Answer</summary>

Infra PR: `terraform fmt`, `validate`, policy checks, saved plan, review, then apply in the infra pipeline. Network and IAM changes do not ride the app pipeline.

Prod apply is not a laptop command.

</details>

---

## 14. How does the application get observed?

<details>
<summary>Answer</summary>

Logs, metrics (rate, errors, latency, CPU, memory, DB), health checks, load-balancer target health, deploy history, and audit logs. One dashboard and one real alert.

Container `Running` is not the SLO.

</details>

---

## 15. What happens when the application fails its health check?

<details>
<summary>Answer</summary>

The load balancer stops sending new traffic to that target. The orchestrator may replace the task. Users should keep hitting healthy replicas if capacity remains.

A failed `/health` is a deploy signal. Capture digest, logs, and LB status before you patch.

</details>

---

## 16. How do you troubleshoot database connectivity?

<details>
<summary>Answer</summary>

DNS → IP → route → security → port → database service → authentication → application. Prove each layer. Do not write “database was down” without evidence the engine itself failed.

A blocked SG with a healthy RDS is a security failure, not an RDS outage.

</details>

---

## 17. How do you troubleshoot an IAM failure?

<details>
<summary>Answer</summary>

Name the identity, resource, and action. Confirm authentication succeeded. Then find the deny: IAM, resource policy, SCP, or Azure RBAC/data plane. Restore the minimum allow.

IAM failures often look like app or network bugs. Check the identity first.

</details>

---

## 18. How do you recover from a bad deployment?

<details>
<summary>Answer</summary>

Detect via health and errors. Stop widening traffic. If schema allows, roll back to the previous digest. Verify LB health and a smoke test. Then RCA.

Preserve logs. Do not destroy evidence with a cluster restart.

</details>

---

## 19. What is the largest blast radius of each major identity?

<details>
<summary>Answer</summary>

Developer: source and Dev, not Prod admin. Pipeline deploy: the app in one environment. Terraform identity: that environment’s infrastructure. Runtime: secrets and data the app needs. Database admin: data plane of the DB.

A stolen runtime role must not be able to rewrite the VPC.

</details>

---

## 20. What would you change if traffic became 10× larger?

<details>
<summary>Answer</summary>

Measure the limiter: LB, app CPU, connection pool, database, or a payment API. Scale that layer. Horizontal app replicas first if the API is CPU-bound. Database SKU, pooling, or cache if RDS saturates.

Do not scale everything. 10× frontend CDN does not fix a 5432 bottleneck.

</details>

---

## Foundation practice

These items follow the foundation and ADR teaching in [01-concepts.md](01-concepts.md). Write your own answer first.

---

## 21. Write the ShopSphere business requirement before cloud or Terraform

Before creating an AWS account, VPC, Terraform module, or pipeline, write a short business requirement.

ShopSphere needs to allow customers to browse products, authenticate, place orders, and view order status. The frontend is publicly accessible, while the backend and database should be protected from unnecessary public exposure. Development teams need rapid deployments to Dev, controlled promotion to UAT, and an auditable Production release process.

Do not add requirements simply because they sound impressive. A Senior engineer learns to distinguish **requirements** from **technology preferences**.

<details>
<summary>Answer</summary>

Customers browse products, authenticate, place orders, and view status. The frontend is internet-facing. Backend and PostgreSQL stay private. Teams deploy fast to Dev, promote to UAT, and release Production with an audit trail.

These are requirements. Kubernetes, Kafka, and a service mesh are not requirements until a gap appears.

</details>

---

## 22. Document the non-functional requirements table

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

The important lesson: derive the architecture from the requirements.

<details>
<summary>Answer</summary>

Availability: survive one app instance failure. Deploy: minimal downtime. Recovery: app rollback possible. Security: no public DB. Identity: workload roles. Secrets: not in Git or images. IaC: Terraform. Observability: logs, metrics, health. Envs: Dev/UAT/Prod. Cost: cheap Dev. Traceability: Prod maps to a Git commit.

Architecture comes from this table, not from a service wishlist.

</details>

---

## 23. Draw the first logical architecture plus DevOps layer

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

<details>
<summary>Answer</summary>

Internet → DNS → frontend → load balancer → Spring Boot → secret store and private database. Developer → Git → CI/CD → registry and deploy. Around it: Terraform, identity, security, monitoring, logging, governance, cost.

Boxes are responsibilities. Product names come after the drawing.

</details>

---

## 24. Justify managed containers vs Kubernetes for v1

For the first implementation, use a managed container runtime rather than immediately introducing Kubernetes.

The question you should be able to answer is:

**What requirement would justify moving from managed containers to Kubernetes?**

Do not answer “because Kubernetes is more powerful.” Explain the specific capability or organizational requirement that creates the need.

<details>
<summary>Answer</summary>

v1 needs a containerized long-running API, private DB, and CI promotion. It does not need custom controllers or cluster-wide NetworkPolicy. Managed containers reduce operational surface for the first production-style loop.

Justify Kubernetes later with a specific capability or org standard, then compare operations in a later project day.

</details>

---

## 25. Define Dev/UAT/Prod on one architecture pattern

Do not create three completely different architectures.

Use one architecture pattern with environment-specific values.

The environments should differ where the requirements differ.

Do not copy Terraform folders and modify resources independently for every environment. Aim for reusable modules with environment-specific inputs.

<details>
<summary>Answer</summary>

One module set. Dev: small SKUs, no Multi-AZ requirement, automatic deploy. UAT: production-like config and tests. Prod: HA, approvals, stricter IAM, stronger alerts.

Change inputs, not architecture copies.

</details>

---

## 26. Design network paths and outbound needs before implementation

Start with the logical network.

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

<details>
<summary>Answer</summary>

Public subnets: DNS/LB entry only. Private app subnets: containers. Private data subnets: PostgreSQL. App → DB is private. Outbound internet only if a real dependency needs it (payments, package pulls). Do not add NAT “just in case.”

Draw the two paths: user → app, and app → database.

</details>

---

## 27. Security boundaries and five separate identities

For every communication path, ask:

```text
Who is communicating?
What are they accessing?
Why is access required?
Which identity is used?
Which network path is used?
Which security rule permits it?
```

Create separate conceptual identities:

```text
Developer Identity
Pipeline Identity
Infrastructure Identity
Application Runtime Identity
Database Identity
```

The application should not receive permissions to modify infrastructure simply because the deployment pipeline requires those permissions.

The platform can implement them differently, but the separation of responsibilities should remain.

<details>
<summary>Answer</summary>

For each path answer who, what, why, which identity, which network, which rule. Developer: Git/Dev. Pipeline: build and deploy. Infra: Terraform. Runtime: secrets and DB. Database: engine auth.

The app identity never inherits Terraform’s create-VPC power.

</details>

---

## 28. Repository structure: app, infra, pipelines, docs

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

<details>
<summary>Answer</summary>

`backend/`, `frontend/`, `infra/modules` plus `environments/dev|uat|prod`, `pipelines/app` and `pipelines/infra`, `docs/adr`. README at the root.

The split is ownership: application vs infrastructure vs pipelines vs documentation. Exact folder names can vary.

</details>

---

## 29. Run the backend locally with health, products, orders, and a DB-backed frontend

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

<details>
<summary>Answer</summary>

Expose `GET /health`, `GET /api/products`, `POST /api/orders`, `GET /api/orders/{id}`. Seed enough rows that a failed DB is visible. Point the Angular app at the local API.

`/health` must mean “ready for traffic,” because the load balancer will use it later. Do not gold-plate business features.

</details>

---

## 30. Containerize the backend; `docker run` and `/health`

Create a production-oriented Dockerfile.

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

<details>
<summary>Answer</summary>

`mvn clean package`, then `docker build -t shopsphere-api:dev .`, then `docker run --rm -p 8080:8080 shopsphere-api:dev`. `curl http://localhost:8080/health` must succeed.

Prove source → Maven → JAR → image → container → HTTP before any cloud deploy. Run as a non-root `USER`. Do not bake secrets into the Dockerfile.

</details>

---

## 31. Separate build-time vs runtime configuration

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

Secrets should come from the appropriate secret-management mechanism.

The principle is:

**Build the software once. Configure it when it runs.**

<details>
<summary>Answer</summary>

One image for Dev, UAT, and Prod. Inject `DATABASE_HOST`, port, name, and `APPLICATION_ENV` at run. Pull passwords from the secret store.

If UAT required a rebuild, the promotion design failed.

</details>

---

## 32. Terraform foundation: fmt, validate, plan, and review each resource

Start Terraform with the smallest possible foundation.

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

<details>
<summary>Answer</summary>

Start with provider, account/RG context, and network. Run `terraform fmt`, `terraform validate`, and `terraform plan`. Do not apply because a plan file exists.

For each resource in the plan: why, owner, dependency, delete impact.

</details>

---

## 33. Deploy the network via Terraform and inspect the IaC loop

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

<details>
<summary>Answer</summary>

Apply public/ingress, application, and database subnets. Inspect the real VPC/VNet and compare with code. That is code → plan → apply → cloud → inspect → compare.

Skip fancy UDRs until a traffic path needs them.

</details>

---

## 34. Deploy a private database; test connect vs deny paths

Deploy the relational database so that normal application traffic reaches it privately.

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

<details>
<summary>Answer</summary>

Create PostgreSQL/MySQL with no public endpoint. From the app subnet, resolve, `nc` the port, authenticate, and query. From a public or unrelated subnet, the same port must fail.

Write down which of resolve/route/connect/auth/query failed when you blocked it.

</details>

---

## 35. Push the image with a git-sha tag and record the digest

Create the container registry and push the application image.

Tag the image with traceable metadata, for example:

```text
shopsphere-api:<git-sha>
```

Also record the resulting image digest.

The digest gives you a stronger answer to:

**Which exact image is running?**

Do not rely exclusively on a mutable tag.

<details>
<summary>Answer</summary>

Tag `shopsphere-api:<git-sha>` to ACR or ECR. Record `@sha256:...`. Deploy that digest, not `:dev`.

The digest answers “which exact image is running?”

</details>

---

## 36. Deploy the app with identity, secrets, private DB, health, and LB — end to end

Deploy the containerized Spring Boot application.

The runtime should:

- pull the image
- start the container
- provide the required runtime configuration
- obtain secrets through its identity
- connect to the private database
- expose the health endpoint
- register with the load-balancing layer

Do not stop at “container is running.”

A running process can still be an unhealthy application.

<details>
<summary>Answer</summary>

Runtime pulls the digest, gets config and secrets, connects privately to the DB, passes `/health`, and the load balancer marks the target healthy. Then a user HTTP call returns products from the database.

Stop only when that whole chain works. `Running` is step one, not the finish.

</details>

---

## 37. First application pipeline to Dev with traceability metadata

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

<details>
<summary>Answer</summary>

Source → build → unit test → security checks → Docker → push → deploy Dev → health check. Record Git SHA, build ID, tag, digest, and deployment version.

Do not automate Production yet. Prove Dev is reliable first.

</details>

---

## 38. Promote the same artifact to UAT without rebuild

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

Ask yourself:

**If the UAT image is different from the Dev image, what happened?**

Possible causes include rebuilding, mutable tags, different build inputs, or pipeline design problems.

The goal is to make the same artifact move through environments.

<details>
<summary>Answer</summary>

UAT deploys the Dev digest. If the UAT image differs, you rebuilt, used a mutable tag, or mixed build inputs.

Promotion is the test. Rebuild is the bug.

</details>

---

## 39. Design Production deployment controls and access restrictions

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

<details>
<summary>Answer</summary>

UAT validation → approval/policy → Prod → health → observe. Developers have no unrestricted Prod infra. The pipeline identity is the release path.

Prod is a governed promotion, not a faster Dev.

</details>

---

## 40. Observability dashboard and one meaningful alert

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

<details>
<summary>Answer</summary>

Dashboard: request count, error rate, latency, CPU, memory, app health, database health. One alert, for example error rate above a threshold after a deploy, with a first investigation step.

Dozens of CPU warnings are noise. An alert must need a human.

</details>

---

## 41. Failure drill: bad release failing health check — evidence and recover

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

Document the recovery:

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

<details>
<summary>Answer</summary>

Deploy a build that fails `/health`. Record commit, image, deployment, task, health output, app logs, and LB status. Then detect → diagnose → contain → rollback to previous digest → verify → RCA.

The lesson is the recovery path, not a perfect first release.

</details>

---

## 42. Failure drill: break DB connectivity and walk DNS → app

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

<details>
<summary>Answer</summary>

Use a wrong hostname or a blocked port. Walk DNS, IP, route, security, port, service, auth, app. Incident note: symptom, root cause, evidence, fix, prevention.

“Database was down” is allowed only if the engine evidence says so.

</details>

---

## 43. Failure drill: remove a runtime IAM permission and restore the minimum

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

This exercise is important because engineers often misdiagnose IAM failures as application or networking failures.

<details>
<summary>Answer</summary>

Drop secret-get or `s3:GetObject`. Restart. Confirm auth succeeded and authorization denied. Restore only that action on that resource.

Do not grant Administrator to “make it work.” IAM is not a network timeout.

</details>

---

## 44. Infrastructure pipeline separate from the application pipeline

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

Control production infrastructure changes separately from application releases where appropriate.

The exact organization can vary, but ownership and blast radius should be deliberate.

<details>
<summary>Answer</summary>

Terraform commit → fmt → validate → policy → plan → review → apply → verify. App code stays on the app pipeline. Network, DB infra, and IAM use this pipeline.

Blast radius stays deliberate. A JAR bump must not apply a VPC change.

</details>

---

## 45. Five ADRs: runtime, network, DB connectivity, CI/CD, deployment

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

<details>
<summary>Answer</summary>

Each ADR: context, decision, why, trade-offs, alternatives, consequences. Example: ADR-001 managed containers because v1 has no Kubernetes requirement; trade-off is less cluster control; alternative AKS/EKS later.

Write why this project chose it, not a textbook paragraph.

</details>

---

## 46. Multi-team ownership model

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

<details>
<summary>Answer</summary>

App team owns code and app incidents. Platform/DevOps owns Terraform modules, pipelines, and Prod network patterns. Security owns IAM standards and secret policy. Database team owns engine and backups. FinOps owns budgets.

Who approves Prod deploy: product/platform via environment checks. Who modifies IAM: security plus infra pipeline, not every developer.

</details>

---

## 47. Cost review with a trade-off per optimization

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

<details>
<summary>Answer</summary>

Ask why each billable resource exists, who owns it, whether Dev can be smaller or off after hours, and what 10× traffic does. NAT, LB, DB, and logs often burn idle money.

Every cut needs an availability, performance, security, recovery, or complexity trade-off. Blind right-sizing of Prod HA is incomplete.

</details>

---

## 48. Final architecture review — failure impact for every component

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

<details>
<summary>Answer</summary>

Walk user → DNS → frontend → LB → app → DB. Then Git → CI/CD → registry → deploy → observability. Then identity, security, Terraform, governance, cost, audit. For each box: what happens if it fails?

If you cannot answer, the architecture is not finished. Document keep vs destroy for the next project days.

</details>

---

## 49. Senior/Lead scenarios A–F

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

<details>
<summary>Answer</summary>

A: Find the real limiter (often DB or pool), do not scale every tier. B: Multi-AZ app, LB, NAT, and database; secrets and observability must survive the AZ. C: Health-gated rolling or blue/green, extra capacity, compatible schema, tested rollback. D: OIDC/federation; no long-lived keys in CI. E: Collect the bill by service before redesign; NAT, logs, and idle Dev are usual suspects. F: LB → target → runtime → container → app → dependency; digest vs expected.

Each scenario is a requirement change. Revisit ADRs instead of bolting on services.

</details>
