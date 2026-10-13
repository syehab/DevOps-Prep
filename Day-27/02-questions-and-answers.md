# Day 27 — Questions and answers

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Then answer each item below before you open the Answer block. After that, do the lab in [03-implementation.md](03-implementation.md).

Write your own answer first. Open the Answer block only after you try. Keep the original numbering.

---

## 1. Spring Boot on EC2, ECS, EKS, and Lambda — list needs first

**Practice**

Take a Spring Boot application and consider:

```text
EC2
ECS
EKS
Lambda
```

Before choosing one, list what the application needs in terms of runtime, networking, scaling, deployment, storage, and operational control.

<details>
<summary>Answer</summary>

The app needs a JVM, HTTP on 8080, private DB access, horizontal scale, rolling deploys, durable storage outside the process, and an IAM role. EC2 gives OS control and you patch Java. ECS runs the image without Kubernetes. EKS adds Kubernetes APIs. Lambda does not fit a long-lived Spring Boot process.

Choose from those needs. Do not start with a favorite service.

</details>

---

## 2. Deploy Spring Boot on EC2 and list what you own

**Practice**

Deploy a small Spring Boot application on EC2 and identify every component you are responsible for:

```text
OS
Java
Application
Process management
Logs
Security
Patching
Deployment
Scaling
```

<details>
<summary>Answer</summary>

You own OS patches, Java, the JAR, `systemd` or similar, log files, Security Groups, AMI hardening, deploy scripts, and ASG policy. AWS owns the hypervisor.

Launch with `aws ec2 run-instances` using an AMI, subnet, SG, and instance profile. SSH is for break-glass, not for installing Java by hand every time.

</details>

---

## 3. SSH-install Java vs bake an AMI

**Practice**

Compare two approaches:

```text
Approach A:
SSH into EC2 and manually install Java

Approach B:
Bake/configure Java automatically and launch consistently
```

Explain which approach gives you more repeatability and why.

<details>
<summary>Answer</summary>

Approach B wins. Bake Java into an AMI with cloud-init or an image pipeline, then launch identical instances. SSH install drifts: one host gets a patch, another does not.

The AMI is the golden image. Rebuild and replace. Do not patch live servers in place.

</details>

---

## 4. CPU 25%, memory 80%, latency rising — do not scale on CPU

**Practice**

Suppose a Spring Boot API has:

```text
CPU: 25%
Memory: 80%
Request latency: increasing
```

Do not automatically scale on CPU. Determine what resource or dependency is actually limiting the workload.

<details>
<summary>Answer</summary>

CPU is not the limiter. Memory pressure or a slow dependency likely is. Inspect heap, GC, connection pools, and database latency before you add instances.

Scale on the bottleneck you measure. A familiar CPU policy can add capacity that does not help.

</details>

---

## 5. Two EC2 instances behind an ALB; stop one

**Practice**

Deploy two EC2 instances behind an ALB. Stop one instance and observe how target health and traffic change.

<details>
<summary>Answer</summary>

The ALB target group marks the stopped instance unhealthy and stops sending new requests. The remaining healthy instance takes traffic. `aws elbv2 describe-target-health` shows the change.

Instance `running` is not application health. A live EC2 returning HTTP 500 can still fail the target health check.

</details>

---

## 6. Three copies of the Day 13 image on ECS

**Practice**

Take the Dockerized Spring Boot application from Day 13 and describe how you would run three copies using ECS.

Identify:

```text
Image
Task Definition
Service
Networking
Load Balancer
Scaling
Identity
```

<details>
<summary>Answer</summary>

Push the image to ECR. Write a Task Definition with CPU, memory, port 8080, and `awsvpc`. An ECS Service desired count of 3 keeps three tasks. Put them in private subnets, behind an ALB, with a task role for AWS APIs.

The Service replaces failed tasks, similar in idea to a Kubernetes Deployment, but ECS is not Kubernetes.

</details>

---

## 7. Task Definition fields vs secrets

**Practice**

Take your Docker container and define:

```text
CPU
Memory
Port
Environment variables
Log destination
IAM role
Health check
```

Then explain which values belong in the task definition and which sensitive values should come from a secret-management system.

<details>
<summary>Answer</summary>

Put CPU, memory, port, log driver, health check, and non-secret env such as `SPRING_PROFILES_ACTIVE` in the Task Definition. Put database passwords in Secrets Manager or SSM and inject at runtime.

The Task Definition describes how the image runs in AWS. It is not a place for long-lived secrets.

</details>

---

## 8. ECS deploy `1.0.0` then `1.1.0` and watch the transition

**Practice**

Deploy:

```text
shopsphere:1.0.0
```

Then release:

```text
shopsphere:1.1.0
```

Observe:

```text
Running task count
Old task revision
New task revision
Load balancer health
Deployment events
```

The goal is to understand what happens during the transition rather than treating deployment as one command.

<details>
<summary>Answer</summary>

The Service starts a new Task Definition revision. New tasks register with the ALB when healthy. Old tasks drain. Watch running count, revisions, target health, and service events.

Deployment is a transition, not one command. “Update succeeded” is not “users are healthy.”

</details>

---

## 9. ECS on EC2 vs Fargate: who manages what

**Practice**

Compare an ECS service using:

```text
EC2 launch type
Fargate
```

Identify what your team still manages and what AWS manages in each model.

<details>
<summary>Answer</summary>

ECS on EC2: you manage the EC2 capacity, AMIs, and node scaling. ECS still orchestrates tasks. Fargate: AWS manages the servers. You still manage VPC, subnets, Security Groups, IAM, logs, secrets, and scale.

Serverless does not mean no network architecture.

</details>

---

## 10. ECS 4 → 12 tasks, API CPU drops, database at 100%, latency worse

**Practice**

Suppose:

```text
ECS tasks: 4 → 12
API CPU: decreases
Database CPU: reaches 100%
Latency: increases
```

Explain why scaling the application made the overall system worse.

<details>
<summary>Answer</summary>

Extra tasks opened more database sessions. The database became the bottleneck. API CPU fell because the app spent time waiting on RDS.

Scaling the symptom increased pressure on the dependency. Scale or tune the database, pools, or cache.

</details>

---

## 11. What changes when Kubernetes moves to EKS

**Practice**

Take the Kubernetes Deployment and Service from Days 14–17 and identify what changes when you move from a generic Kubernetes cluster to EKS.

<details>
<summary>Answer</summary>

Deployments, Services, probes, and RBAC stay. AWS adds VPC CNI, IAM for ServiceAccounts, ALB Ingress, ECR, CloudWatch, and managed control plane. You still own node groups or Fargate, add-ons, and workloads.

Learn Kubernetes first. Then add the AWS layers.

</details>

---

## 12. Restrict the RDS Security Group and diagnose the EKS failure

**Practice**

Deploy an EKS application that connects to an RDS database. Deliberately restrict the RDS Security Group and diagnose the resulting failure.

<details>
<summary>Answer</summary>

Remove the Pod/node SG from RDS inbound 5432. The Pod times out. Walk Pod DNS → CNI → route → RDS SG → port → database. Restore only the app SG on 5432.

Do not treat this as “just Kubernetes” or “just AWS.” Both layers own the path.

</details>

---

## 13. Which workloads fit Lambda

**Practice**

Take these workloads and decide whether the execution model naturally fits Lambda:

```text
Process an S3 upload
Generate a thumbnail
Process an SQS message
Run a continuously available Spring Boot API
```

Explain the reasoning for each.

<details>
<summary>Answer</summary>

S3 upload processing: yes, event-driven and short. Thumbnail generation: yes. SQS message processing: yes. A continuously available Spring Boot API: no; keep it on ECS/EKS or a similar always-on platform.

Ask whether the work is short-lived event execution. Not every Java app is a Function.

</details>

---

## 14. Lambda on S3 files vs Lambda on private RDS

**Practice**

Design:

```text
S3 upload
  ↓
Lambda
  ↓
Process file
  ↓
Store result
```

Then design:

```text
API request
  ↓
Lambda
  ↓
Private RDS
```

Identify the networking and latency considerations for each.

<details>
<summary>Answer</summary>

S3 → Lambda → process → store can stay out of the VPC and is sensitive mainly to cold start on the first file. API → Lambda → private RDS needs VPC ENIs, subnets, SGs, and DNS, plus extra init latency.

Do not assume every invocation has the same latency. Cold start plus VPC attach can miss an API SLO.

</details>

---

## 15. Compare EC2, Elastic Beanstalk, and ECS Fargate for Spring Boot

**Practice**

Compare:

```text
EC2
Elastic Beanstalk
ECS Fargate
```

For a Spring Boot application, identify:

```text
OS responsibility
Deployment model
Scaling
Networking
Container support
Operational complexity
```

Do not choose based solely on which service has the most automation.

<details>
<summary>Answer</summary>

EC2: you own OS, deploy, and scale. Beanstalk: you push the app; it provisions EC2, ALB, and ASG underneath. Fargate: you push an image; AWS runs tasks; you still design VPC and IAM.

Pick from OS need, container need, and operational load. More automation is not automatically the right platform.

</details>

---

## 16. Push `shopsphere:1.0.0` to ECR and promote the digest

**Practice**

Push:

```text
shopsphere:1.0.0
```

to ECR and record:

```text
Git SHA
Build ID
Image tag
Image digest
```

Then use the same image in Dev, UAT and Production.

<details>
<summary>Answer</summary>

`aws ecr get-login-password` then `docker tag` and `docker push`. Record Git SHA, build ID, tag, and digest. Deploy that digest in Dev, UAT, and Production.

Build once. A mutable tag can move. The digest cannot.

</details>

---

## 17. S3 read permission: ECR vs task role

**Practice**

For a Spring Boot container that needs to read S3, decide whether the S3 permission belongs to:

```text
ECR permissions
or
Application task role
```

The application should receive only the permission it needs to perform its business function.

<details>
<summary>Answer</summary>

ECR permissions belong on the task execution role (pull image). `s3:GetObject` belongs on the application task role.

The app gets only the business permission. Do not put S3 on the execution role “because ECS needs IAM.”

</details>

---

## 18. Classify Spring Boot data and map session/search

**Practice**

For a Spring Boot application, classify:

```text
JAR
Uploaded profile image
Database records
Temporary files
Shared generated reports
Session tokens
Product search queries
```

Then select the appropriate storage model. Map session tokens to ElastiCache and product search to OpenSearch, and say why neither replaces RDS.

<details>
<summary>Answer</summary>

JAR: ECR. Profile image: S3. Database records: RDS. Temp files: ephemeral container disk. Shared reports: S3 or EFS if POSIX is required. Session tokens: ElastiCache. Product search: OpenSearch.

ElastiCache is a copy you can lose. OpenSearch searches documents; it does not replace RDS records. Keep all four private.

</details>

---

## 19. Rollback Spring Boot on EC2, ECS, EKS, and Lambda

**Practice**

For a Spring Boot release, design rollback for:

```text
EC2
ECS
EKS
Lambda
```

Then identify what actually changes during rollback.

<details>
<summary>Answer</summary>

EC2: shift the ALB to previous AMI/instances. ECS: deploy the previous Task Definition revision. EKS: `kubectl rollout undo` or Helm rollback. Lambda: point the alias back at the prior version.

Rollback changes which artifact receives traffic. Schema compatibility still applies.

</details>

---

## 20. Telemetry for HTTP 503 on EC2, ECS, EKS, Lambda

**Practice**

For an API returning HTTP 503, identify which telemetry you would inspect for:

```text
EC2
ECS
EKS
Lambda
```

<details>
<summary>Answer</summary>

EC2: instance metrics, system and app logs, target health. ECS: task metrics, container logs, service events. EKS: Pod metrics, `kubectl logs`, Events, node metrics. Lambda: errors, duration, throttles, logs.

Ask which evidence says platform vs application vs dependency.

</details>

---

## 21. Trade-offs: 2 EC2, ECS on EC2, Fargate, EKS, Lambda for a small variable API

**Practice**

Compare:

```text
2 EC2 instances
ECS on EC2
ECS Fargate
EKS
Lambda
```

for a small Spring Boot API with variable traffic.

Do not select a winner automatically. Explain the trade-offs.

<details>
<summary>Answer</summary>

Two EC2: simple money, high OS work, idle cost. ECS on EC2: you still patch nodes. Fargate: no nodes, different runtime price, still VPC design. EKS: Kubernetes power and cluster cost for one API is usually too much. Lambda: poor fit for a long-lived Spring Boot process; good if you rewrite as events.

Compare effort, idle capacity, and risk, not only `$/hour`.

</details>

---

## 22. Health endpoint fails while the container stays alive

**Practice**

Make your application's health endpoint fail while keeping the container process alive. Observe how platform-level status and application-level health differ.

<details>
<summary>Answer</summary>

The task can stay `RUNNING` while the ALB marks the target unhealthy and users see 503. Platform status and application health differ.

Break `/health` in the lab and watch target health, service events, and logs. Do not stop at `RUNNING`.

</details>

---

## 23. Bottleneck chain: Client → API → Database, five saturation points

**Practice**

Draw:

```text
Client
 ↓
API
 ↓
Database
```

Then identify at least five places where saturation could occur.

<details>
<summary>Answer</summary>

Saturation can sit at ALB, API CPU/memory, the connection pool, database CPU, database connections, database I/O, network, or a downstream API. Extra ECS tasks raise pool and DB pressure.

Scale the bottleneck, not the symptom.

</details>

---

## Part 27 — 5-Minute Recall

Without looking at the notes, explain:

---

## 24. Main difference between EC2 and a managed container service

What is the main difference between EC2 and a managed container service?

<details>
<summary>Answer</summary>

EC2 gives OS-level VMs you patch and configure. ECS/EKS/Fargate run containers and take more of the server operations.

You still own networking, identity, and the application.

</details>

---

## 25. Operational responsibilities that come with EC2

What operational responsibilities come with EC2?

<details>
<summary>Answer</summary>

OS patching, runtime, deploy, instance config, hardening, monitoring, and scaling configuration.

AWS does not manage the guest OS for you.

</details>

---

## 26. What is an AMI?

What is an AMI?

<details>
<summary>Answer</summary>

The template an EC2 instance boots from: OS plus optional baked software.

Treat it as the golden image. Rebuild and replace instances.

</details>

---

## 27. Why immutable images/configuration are useful

Why are immutable images/configuration useful?

<details>
<summary>Answer</summary>

Every instance starts identical. Drift from SSH edits goes away.

Bake, test, launch new, retire old.

</details>

---

## 28. What does an Auto Scaling Group provide?

What does an Auto Scaling Group provide?

<details>
<summary>Answer</summary>

A managed EC2 group with min/desired/max that can replace unhealthy instances and follow scaling policies.

One EC2 is a single-instance failure point.

</details>

---

## 29. Why scaling on CPU alone sometimes fails

Why does scaling on CPU alone sometimes fail?

<details>
<summary>Answer</summary>

The limiter may be memory, connections, or a dependency. CPU can look fine while latency rises.

Pick the metric that matches the bottleneck.

</details>

---

## 30. Main ECS concepts

What are the main ECS concepts?

<details>
<summary>Answer</summary>

Cluster, Task Definition, Task, Service, Container.

The Service keeps the desired task count.

</details>

---

## 31. What is a Task Definition?

What is a Task Definition?

<details>
<summary>Answer</summary>

The blueprint: image, CPU/memory, ports, logs, roles, health checks.

A Task is a running copy of that definition.

</details>

---

## 32. What is an ECS Service?

What is an ECS Service?

<details>
<summary>Answer</summary>

The controller that maintains desired tasks and can attach a load balancer.

Failed tasks get replaced. New revisions roll forward.

</details>

---

## 33. What does Fargate manage for you?

What does Fargate manage for you?

<details>
<summary>Answer</summary>

The underlying servers for the container. You do not patch an EC2 node fleet.

You still manage VPC, IAM, logs, secrets, and scaling.

</details>

---

## 34. What EKS manages and what you still own

What does EKS manage and what do you still own?

<details>
<summary>Answer</summary>

AWS manages the Kubernetes control plane. You own workloads, much of the data plane, IAM, VPC, and add-ons.

Pods, Deployments, and NetworkPolicy remain your design.

</details>

---

## 35. Why EKS needs Kubernetes and AWS networking knowledge

Why does EKS require both Kubernetes and AWS networking knowledge?

<details>
<summary>Answer</summary>

Traffic crosses Services and CNI, then VPC routes, Security Groups, and RDS.

A healthy Pod can still time out on an RDS SG.

</details>

---

## 36. When does Lambda fit naturally?

When does Lambda fit naturally?

<details>
<summary>Answer</summary>

When the work is short-lived and event-driven: S3, SQS, EventBridge, API Gateway for small functions.

A always-on Spring Boot API is a different execution model.

</details>

---

## 37. What is a Lambda execution role?

What is a Lambda execution role?

<details>
<summary>Answer</summary>

The IAM role the function assumes to call AWS APIs.

It is workload identity, not an embedded access key.

</details>

---

## 38. What is ECR used for?

What is ECR used for?

<details>
<summary>Answer</summary>

It stores container images for ECS, EKS, and other AWS compute.

Push once, scan, promote the digest.

</details>

---

## 39. Why workloads should use IAM roles, not embedded keys

Why should workloads use IAM roles rather than embedded AWS access keys?

<details>
<summary>Answer</summary>

Roles vend temporary credentials. Keys in images and env files leak and remain valid.

EC2 instance profiles, ECS task roles, EKS IRSA, and Lambda execution roles are the pattern.

</details>

---

## 40. ECS task role vs task execution role

What is the difference between ECS task role and task execution role?

<details>
<summary>Answer</summary>

Execution role: pull from ECR, write logs. Task role: application AWS APIs such as `s3:GetObject`.

Split them. The app should not inherit registry-pull power it does not need.

</details>

---

## 41. State outside containers; RDS vs ElastiCache vs OpenSearch

Why should application state normally live outside containers? What does RDS keep that ElastiCache does not, and what problem does OpenSearch solve that RDS does not?

<details>
<summary>Answer</summary>

Container filesystems die with the task. Persist in RDS, S3, EFS, or similar. RDS keeps source-of-truth records ElastiCache does not. OpenSearch searches documents and logs; RDS does not replace that search model.

All stay private. None of them belong as a database inside the container.

</details>

---

## 41b. CDC from RDS to Kafka / MSK, not a dual-write

Why would you use change data capture (Debezium reading the RDS change log into Kafka / Amazon MSK) instead of letting the application write to the database and to Kafka in the same request?

<details>
<summary>Answer</summary>

The application writes to RDS once. Debezium reads the database change log and publishes row changes as events. Downstream consumers read Kafka / MSK.

A dual-write (the app writes RDS and Kafka) drifts when one write fails. The log is the source of events.

</details>

---

## 42. How deployment differs across EC2, ECS, EKS, and Lambda

How does deployment differ across EC2, ECS, EKS and Lambda?

<details>
<summary>Answer</summary>

EC2: new instances or AMI roll behind an ALB. ECS: new Task Definition revision. EKS: rolling Deployment with readiness. Lambda: versions and aliases.

Always validate health. Command success is not user health.

</details>

---

## 43. Why “container is running” does not prove application health

Why does “container is running” not prove application health?

<details>
<summary>Answer</summary>

`RUNNING` means the process has not exited. The app can still return 503, fail probes, or miss the database.

Use target health, `/health`, and logs.

</details>

---

## 44. Why scaling the application can make a database problem worse

Why can scaling the application make a database problem worse?

<details>
<summary>Answer</summary>

More tasks mean more connections and queries. A saturated RDS gets worse.

Scale the bottleneck you measured.

</details>

---

## 45. Troubleshoot an AWS compute deploy returning 503

How would you troubleshoot an AWS compute deployment returning 503?

<details>
<summary>Answer</summary>

ALB target health → service or Deployment events → task/Pod status → logs → health endpoint → env/secrets → database.

Do not restart the cluster first.

</details>

---

## 46. How to compare compute services beyond price

How do you compare compute services beyond price?

<details>
<summary>Answer</summary>

Compare engineering effort, availability, scaling efficiency, idle capacity, operational risk, and security maintenance.

`$ /hour` hides OS patching and cluster upgrades.

</details>

---

## 47. When would you choose EC2 over ECS?

When would you choose EC2 over ECS?

<details>
<summary>Answer</summary>

When you need OS-level agents, custom filesystems, or a runtime that does not fit a container platform.

Accept the patching and AMI factory that come with that choice.

</details>

---

## 48. When would EKS be justified over ECS?

When would EKS be justified over ECS?

<details>
<summary>Answer</summary>

When you need Kubernetes APIs, Helm ecosystem, custom controllers, or cluster-level networking policy.

A single Dockerized API does not need that complexity.

</details>

---

## 49. AWS equivalents of the Azure compute concepts

What is the AWS equivalent of the Azure compute concepts you already learned?

<details>
<summary>Answer</summary>

EC2 ≈ Azure VM. ASG ≈ VMSS. Elastic Beanstalk ≈ App Service (approximate). ECS/Fargate ≈ Container Apps. EKS ≈ AKS. Lambda ≈ Functions. ECR ≈ ACR.

Map capability, then name the service. The products are not identical.

</details>

---

## Part 22 — Senior/Lead Scenario: Choosing AWS Compute

---

## 50. Map workloads A–D to AWS compute with justification

A company has four workloads:

```text
A. Legacy Java application requiring OS customization

B. Spring Boot API packaged as a Docker image

C. Kubernetes-native platform with multiple services,
   Helm charts and service-level networking requirements

D. Event-driven image processing triggered by S3 uploads
```

For each workload, evaluate:

```text
Runtime model
Infrastructure control
Scaling
Networking
Identity
Deployment
Observability
Operational ownership
Cost
```

Possible architectural directions to investigate are:

```text
A → EC2 / managed server platform
B → ECS/Fargate or another managed container platform
C → EKS
D → Lambda
```

The point is not to memorize this mapping. The point is to explain why the workload characteristics lead you toward a particular compute model.

A Senior/Lead interview answer should sound like:

> “I would first establish the workload's operational and runtime requirements. If OS-level customization is mandatory, I would retain a VM-based model. If the application is already containerized and does not require Kubernetes capabilities, I would evaluate ECS. If the organization genuinely needs Kubernetes APIs, ecosystem, scheduling and networking behavior, I would evaluate EKS. For event-driven short-lived execution, Lambda may be appropriate.”

That demonstrates decision reasoning rather than service memorization.

<details>
<summary>Answer</summary>

A legacy Java with OS customization: EC2 (or Beanstalk if the platform fits). B Dockerized Spring Boot API: ECS Fargate. C Kubernetes-native platform with Helm and service networking: EKS. D S3-triggered image processing: Lambda.

Reason from runtime, control, scale, network, identity, deploy, observability, ownership, and cost. Not from “EKS is modern.”

</details>

---

## Part 23 — Practice: Build an AWS Compute Comparison Lab

---

## 51. Compute comparison lab: same image on Fargate, EKS, and EC2

Use the same simple Spring Boot application from the earlier Docker and Kubernetes exercises.

Start with:

```text
Spring Boot
   ↓
Docker image
   ↓
ECR
```

Then evaluate three deployment paths:

```text
ECS Fargate
EKS
EC2
```

For EC2:

```text
EC2
 ↓
Java
 ↓
Spring Boot
 ↓
ALB
```

For ECS:

```text
ECR
 ↓
ECS Service
 ↓
Fargate Tasks
 ↓
ALB
```

For EKS:

```text
ECR
 ↓
EKS
 ↓
Deployment
 ↓
Service
 ↓
ALB/NLB
```

For each one, record:

```text
Who manages the OS?
Who manages the control plane?
How does scaling work?
How does deployment work?
How does the workload receive AWS permissions?
How are logs collected?
What is the failure model?
What is the cleanup procedure?
```

You do not need to build every model fully if cost is a concern. The purpose is to compare the operational model.

<details>
<summary>Answer</summary>

Push Spring Boot to ECR. Run it on ECS Fargate, EKS Deployment+Service, and EC2+ALB if cost allows. For each, record who manages OS and control plane, scaling, deploy, IAM, logs, failure, and cleanup.

You do not need every model fully built. You need the operational comparison.

</details>

---

## Part 24 — Failure Drill: Compute Is Healthy, Application Is Not

---

## 52. ALB → ECS task RUNNING but HTTP 503

Scenario:

```text
ALB
 ↓
ECS
 ↓
Task is RUNNING
```

Users receive:

```text
HTTP 503
```

Do not conclude that ECS is broken.

Investigate:

```text
ALB target health
→ ECS service events
→ task status
→ container logs
→ application health endpoint
→ environment variables
→ secret retrieval
→ database connectivity
```

A container being `RUNNING` only tells you that the container process has not exited. It does not prove that the application is healthy.

The same principle applies to EC2:

```text
EC2 instance = running
```

does not mean:

```text
Spring Boot = healthy
```

<details>
<summary>Answer</summary>

Inspect target health, ECS events, logs, `/health`, secrets, and DB. The task process can be up while the app is not ready.

Do not conclude ECS is broken from `RUNNING` alone.

</details>

---

## Part 25 — Failure Drill: Scaling Does Not Solve the Problem

---

## 53. ECS scales 4 → 12, DB saturates, latency worse

Scenario:

```text
Traffic increases
   ↓
API latency increases
   ↓
ECS scales from 4 → 12 tasks
   ↓
Database becomes saturated
   ↓
Latency becomes worse
```

The mistake is treating application compute as the only bottleneck.

Investigate:

```text
API CPU
API memory
Connection pool
Database CPU
Database connections
Database I/O
Network latency
External API latency
Queue depth
```

The Senior/Lead lesson is:

**Scale the bottleneck, not the symptom.**

Adding compute capacity can sometimes amplify pressure on a downstream dependency.

<details>
<summary>Answer</summary>

The API was not the bottleneck. Added tasks saturated RDS. Identify the real limiter and scale or fix that.

Treat compute scale as one lever, not the only lever.

</details>
