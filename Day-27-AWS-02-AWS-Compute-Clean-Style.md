# Day 27 — AWS Overlay 02: AWS Compute

The goal of this day is to understand how AWS compute services map to the underlying workload requirements you already learned in the core course and Azure overlays. The important skill is not memorizing every AWS compute service. It is deciding how much infrastructure you want to manage, how the workload should scale, how it should be deployed, how it should connect to the network, and what operational responsibilities remain with the DevOps team.

The core decision is:

**Workload requirements → Compute model → Networking → Identity → Scaling → Deployment → Observability → Cost**

---

## Part 1 — The AWS Compute Decision

AWS provides several ways to run applications, from virtual machines where you manage the operating system to highly managed services where AWS manages most of the underlying infrastructure. The more control you take, the more operational responsibility you also take. A Senior/Lead engineer should therefore start with the workload rather than starting with a favorite AWS service.

The main compute choices for this course are:

```text
EC2
ECS
EKS
Fargate
Elastic Beanstalk
Lambda
```

A simple way to think about them is:

```text
More infrastructure control
        EC2
         ↓
     ECS / EKS
         ↓
      Fargate
         ↓
   Elastic Beanstalk
         ↓
       Lambda
More managed execution
```

This is not a ranking. Each model solves a different operational problem.

Ask:

```text
Do I need OS-level control?
Do I need Kubernetes?
Do I need container orchestration?
Is the workload event-driven?
How much infrastructure do I want to manage?
What scaling behavior is required?
```

Practice:

Take a Spring Boot application and consider:

```text
EC2
ECS
EKS
Lambda
```

Before choosing one, list what the application needs in terms of runtime, networking, scaling, deployment, storage, and operational control.

---

## Part 2 — Amazon EC2

Amazon EC2 provides virtual machines in AWS. With EC2, you choose an instance type, operating system image, storage, networking, security groups, and other configuration while remaining responsible for much of the operating system and application environment.

A typical architecture is:

```text
Internet
   ↓
Load Balancer
   ↓
EC2 Instances
   ↓
Database
```

The DevOps team is responsible for tasks such as:

```text
OS patching
Runtime installation
Application deployment
Instance configuration
Security hardening
Monitoring
Scaling configuration
```

You can launch an EC2 instance with the AWS CLI:

```bash
aws ec2 run-instances \
  --image-id <AMI-ID> \
  --instance-type t3.micro \
  --subnet-id <SUBNET-ID> \
  --security-group-ids <SG-ID> \
  --iam-instance-profile Name=<INSTANCE-PROFILE>
```

The exact AMI and instance type depend on the Region and workload. The AMI (Amazon Machine Image) is the template the instance boots from; Part 3 covers it in detail.

Once running, inspect it:

```bash
aws ec2 describe-instances
```

For a Linux instance:

```bash
ssh ec2-user@<PUBLIC-IP>
```

EC2 is useful when you need control over the operating system, specialized software, custom agents, or legacy workloads that do not fit a more managed platform.

The trade-off is operational responsibility. If your team chooses EC2, AWS does not manage the guest operating system for you.

Practice:

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

---

## Part 3 — EC2 AMIs and Instance Lifecycle

An Amazon Machine Image, or AMI, is a template used to launch EC2 instances. It can contain an operating system and preconfigured software.

The traditional pattern is:

```text
AMI
 ↓
EC2 Instance
 ↓
Application
```

For repeatable infrastructure, do not configure every instance by hand after launch. Instead, automate the configuration with tools such as cloud-init, user data, configuration management, or image-building processes.

For example, EC2 user data can install software during first boot:

```bash
#!/bin/bash

dnf update -y
dnf install -y java-21-amazon-corretto
```

You can inspect instance metadata and configuration using AWS tooling and the EC2 console.

A mature architecture tends to move toward immutable infrastructure:

```text
Build Image
    ↓
Test Image
    ↓
Launch New Instances
    ↓
Replace Old Instances
```

rather than:

```text
Launch Instance
    ↓
SSH manually
    ↓
Change configuration
    ↓
Hope every server remains consistent
```

This is the same **golden image** factory you met on Day 23. On AWS the published artifact is an AMI instead of an Azure Compute Gallery version. The loop stays: start from a base OS, configure it as code (cloud-init or Ansible), harden it (for example a CIS baseline), scan it, publish the AMI, then launch new instances and replace the old ones. Do not SSH into a live server to apply a fix.

> **Remember:** Bake, do not patch in place. The AMI is the cake. Rebuild the image and replace the instance.

Practice:

Compare two approaches:

```text
Approach A:
SSH into EC2 and manually install Java

Approach B:
Bake/configure Java automatically and launch consistently
```

Explain which approach gives you more repeatability and why.

---

## Part 4 — Auto Scaling Groups

One EC2 instance creates a single-instance failure point. Auto Scaling Groups, or ASGs, let you manage EC2 capacity as a group. They can replace unhealthy instances or adjust capacity according to scaling policies.

A common architecture is:

```text
Application Load Balancer
        |
        v
Auto Scaling Group
   |       |       |
 EC2     EC2     EC2
```

The ASG can maintain a desired number of instances:

```text
Minimum: 2
Desired: 2
Maximum: 6
```

If an instance becomes unhealthy, the group can replace it.

You can inspect ASGs using:

```bash
aws autoscaling describe-auto-scaling-groups
```

Scaling can use metrics such as CPU utilization, but CPU is not always the correct application signal. For a queue-driven system, queue depth may be more useful. For a web application, request count or latency can sometimes be better indicators.

This is an important Senior/Lead concept:

**Scaling should follow the actual bottleneck, not simply a familiar metric.**

Practice:

Suppose a Spring Boot API has:

```text
CPU: 25%
Memory: 80%
Request latency: increasing
```

Do not automatically scale on CPU. Determine what resource or dependency is actually limiting the workload.

---

## Part 5 — Elastic Load Balancing with EC2

A production EC2 application normally sits behind a load balancer rather than exposing individual instance IPs to users.

The Application Load Balancer can distribute HTTP/HTTPS traffic:

```text
Client
  ↓
ALB
  ↓
Target Group
  ↓
EC2 instances
```

The target group performs health checks so the load balancer can direct traffic toward healthy targets.

You can inspect a basic ALB with:

```bash
aws elbv2 describe-load-balancers
aws elbv2 describe-target-groups
aws elbv2 describe-target-health \
  --target-group-arn <TARGET-GROUP-ARN>
```

This is useful during incidents.

Suppose:

```text
ALB healthy
EC2 instance running
Application returns 500
```

The EC2 instance being “running” does not prove that the application is healthy. The target health check and application logs provide stronger evidence.

Practice:

Deploy two EC2 instances behind an ALB. Stop one instance and observe how target health and traffic change.

---

## Part 6 — Amazon ECS

Amazon Elastic Container Service, or ECS, is AWS's managed container orchestration service. ECS lets you run containers without requiring you to operate Kubernetes.

A basic ECS architecture is:

```text
ALB
 ↓
ECS Service
 ↓
Task
 ↓
Container
```

The important ECS concepts are:

```text
Cluster
Task Definition
Task
Service
Container
```

A Task Definition describes how the container should run. A Task is a running instance of that definition. A Service maintains the desired number of tasks.

For example:

```text
ECS Service
desired count = 3

Task 1 → container
Task 2 → container
Task 3 → container
```

The service can replace failed tasks.

This is conceptually similar to the Kubernetes Deployment model:

```text
ECS Service
≈
Kubernetes Deployment
```

but ECS is not Kubernetes and the operational model is different.

Practice:

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

---

## Part 7 — ECS Task Definitions

A Task Definition describes the container configuration ECS should use. It can define the image, CPU/memory, ports, environment variables, logging, IAM roles, health checks, and other runtime settings.

A simplified task definition might look like:

```json
{
  "family": "shopsphere-api",
  "networkMode": "awsvpc",
  "containerDefinitions": [
    {
      "name": "api",
      "image": "<ACCOUNT>.dkr.ecr.ap-south-1.amazonaws.com/shopsphere:1.0.0",
      "portMappings": [
        {
          "containerPort": 8080
        }
      ],
      "essential": true
    }
  ],
  "cpu": "512",
  "memory": "1024"
}
```

The `awsvpc` networking mode gives tasks their own network interfaces and IP addresses in the VPC.

The task definition is therefore more than a Docker image reference. It describes how that image should operate inside the AWS environment.

Practice:

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

---

## Part 8 — ECS Services and Deployment

An ECS Service maintains a desired number of tasks and can integrate with load balancers and service discovery.

For example:

```text
Desired count = 3

Task 1
Task 2
Task 3
```

If Task 2 exits:

```text
Task 2 fails
   ↓
ECS detects failure
   ↓
New task starts
   ↓
Service returns to desired count
```

This is the same general reconciliation idea you learned in Kubernetes, although ECS implements it through its own service model.

A deployment changes the task definition revision:

```text
Task Definition Revision 1
        ↓
Task Definition Revision 2
        ↓
ECS Service deployment
```

The service can gradually replace old tasks with new tasks.

Practice:

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

---

## Part 9 — AWS Fargate

AWS Fargate is a serverless compute engine for containers used with services such as ECS and EKS. You define the container workload while AWS manages the underlying server infrastructure.

The distinction is:

```text
ECS on EC2:
You manage EC2 capacity

ECS on Fargate:
AWS manages the underlying compute
```

For many teams, Fargate reduces operational work because there is no EC2 node fleet to patch and scale.

A simplified ECS Fargate architecture is:

```text
ALB
 ↓
ECS Service
 ↓
Fargate Tasks
 ↓
Containers
```

The workload still needs:

```text
VPC
Subnets
Security Groups
IAM
Logs
Secrets
Scaling
```

“Serverless” does not mean “no infrastructure architecture.”

This distinction is important because network design and identity remain your responsibility.

Practice:

Compare an ECS service using:

```text
EC2 launch type
Fargate
```

Identify what your team still manages and what AWS manages in each model.

---

## Part 10 — ECS Scaling

ECS Services can scale task count horizontally. Scaling can use CloudWatch metrics and application signals.

For example:

```text
CPU > 70%
    ↓
Increase task count
```

But again, CPU is only one possible signal.

You may instead consider:

```text
Request count
Latency
Memory
Queue depth
Custom application metrics
```

A typical target-tracking strategy might maintain average CPU around a target:

```text
Target CPU = 60%
```

The service adjusts task count based on observed metrics.

The important concept is that scaling capacity does not fix every performance problem.

If the architecture is:

```text
API → Database
```

and the database is saturated, increasing API tasks may increase database pressure.

This is a classic Senior/Lead troubleshooting scenario.

Practice:

Suppose:

```text
ECS tasks: 4 → 12
API CPU: decreases
Database CPU: reaches 100%
Latency: increases
```

Explain why scaling the application made the overall system worse.

---

## Part 11 — Amazon EKS

Amazon Elastic Kubernetes Service, or EKS, is AWS's managed Kubernetes service. AWS manages the Kubernetes control plane, while you remain responsible for workload design and much of the data-plane architecture.

The conceptual model is:

```text
AWS-managed Kubernetes control plane
              |
              v
        Worker capacity
              |
              v
             Pods
```

EKS supports different compute approaches, including managed node groups and serverless-style Fargate workloads, as well as other AWS-integrated compute options.

The Kubernetes concepts remain the same:

```text
Pod
Deployment
Service
Ingress
ConfigMap
Secret
RBAC
NetworkPolicy
```

The AWS-specific layers add:

```text
VPC
IAM
Load Balancers
ECR
CloudWatch
AWS networking
```

This is why the Kubernetes lessons should be learned before EKS.

Practice:

Take the Kubernetes Deployment and Service from Days 14–17 and identify what changes when you move from a generic Kubernetes cluster to EKS.

---

## Part 12 — EKS Networking

EKS networking combines Kubernetes networking with AWS VPC networking.

A simplified path is:

```text
Internet
   ↓
ALB / NLB
   ↓
Kubernetes Service
   ↓
Pod
   ↓
AWS VPC
   ↓
RDS / AWS service
```

Depending on the EKS networking configuration, Pods can receive VPC-routable IP addresses through the AWS VPC CNI model. The CNI (container network interface) is the plugin that gives each Pod its IP address; the AWS version hands Pods real VPC addresses.

This means an EKS connectivity failure may involve both layers:

```text
Kubernetes
+
AWS VPC
```

For example, if a Pod cannot connect to RDS:

```text
Pod DNS
→ Pod/network configuration
→ Security Group
→ Route table
→ RDS endpoint
→ RDS Security Group
→ Port 5432
→ Database
```

Do not troubleshoot it as “just Kubernetes” or “just AWS networking.”

Practice:

Deploy an EKS application that connects to an RDS database. Deliberately restrict the RDS Security Group and diagnose the resulting failure.

---

## Part 13 — AWS Lambda

AWS Lambda is a serverless compute service designed around event-driven execution. You provide function code and configuration, while AWS manages the execution infrastructure.

A typical flow is:

```text
Event
  ↓
Lambda
  ↓
Application logic
  ↓
AWS service / database / API
```

Events can come from services such as:

```text
S3
EventBridge
SQS
API Gateway
DynamoDB
```

Lambda is particularly useful when workload execution is naturally event-driven and does not require a continuously running application process.

The important question is:

> “Can this workload be expressed as short-lived event-driven execution?”

A continuously running Spring Boot API may fit better on ECS, EKS, App Runner, or another managed application platform, depending on its requirements. A small asynchronous processing function may fit Lambda well.

Practice:

Take these workloads and decide whether the execution model naturally fits Lambda:

```text
Process an S3 upload
Generate a thumbnail
Process an SQS message
Run a continuously available Spring Boot API
```

Explain the reasoning for each.

---

## Part 14 — Lambda Networking and Cold Starts

Lambda functions do not require you to manage servers, but networking and runtime behavior still matter. A function may run without being attached to your VPC, or it may be configured for VPC access when it needs to reach private resources.

For example:

```text
Lambda
   ↓
RDS in private subnet
```

may require VPC networking configuration.

When you connect Lambda functions to a VPC, the networking path, security groups, subnets, DNS and available IP capacity become relevant.

Another important concept is startup latency. A newly initialized execution environment can introduce additional latency, commonly referred to as a cold start.

Do not assume that every Lambda invocation has the same latency.

Practice:

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

---

## Part 15 — Elastic Beanstalk

Elastic Beanstalk is a managed application platform that simplifies deployment of applications while provisioning AWS infrastructure such as EC2, load balancing, and Auto Scaling underneath.

Conceptually:

```text
Application
   ↓
Elastic Beanstalk
   ↓
AWS infrastructure
   ├── EC2
   ├── Load Balancer
   └── Auto Scaling
```

This can be useful when you want a managed application deployment experience but still use a conventional server-based application model.

The trade-off is that you have less direct control over infrastructure than raw EC2 while still operating within a platform that is more infrastructure-oriented than Lambda.

Practice:

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

---

## Part 16 — ECR and Container Image Delivery

Amazon Elastic Container Registry, or ECR, stores container images used by ECS, EKS and other AWS workloads.

A standard container delivery flow is:

```text
Git
 ↓
Build
 ↓
Test
 ↓
Docker Build
 ↓
Security Scan
 ↓
ECR
 ↓
ECS / EKS
```

Authenticate Docker to ECR:

```bash
aws ecr get-login-password \
  --region ap-south-1 \
  | docker login \
  --username AWS \
  --password-stdin <ACCOUNT>.dkr.ecr.ap-south-1.amazonaws.com
```

Tag and push:

```bash
docker tag shopsphere:1.0.0 \
  <ACCOUNT>.dkr.ecr.ap-south-1.amazonaws.com/shopsphere:1.0.0

docker push \
  <ACCOUNT>.dkr.ecr.ap-south-1.amazonaws.com/shopsphere:1.0.0
```

The deployment should use a traceable image identity. A digest is stronger than relying only on a mutable tag.

The same principle from Azure ACR applies:

**Build once, store once, promote the same artifact.**

Practice:

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

---

## Part 17 — Identity for AWS Compute

AWS compute services should use workload identities rather than embedding long-lived credentials into applications.

For EC2:

```text
EC2
 ↓
IAM Role / Instance Profile
 ↓
AWS API
```

For ECS:

```text
ECS Task
 ↓
Task Role
 ↓
AWS API
```

For EKS:

```text
Pod
 ↓
Kubernetes ServiceAccount
 ↓
IAM integration
 ↓
AWS API
```

For Lambda:

```text
Lambda
 ↓
Execution Role
 ↓
AWS API
```

The identity model changes slightly by compute platform, but the principle remains:

**The workload receives an identity and uses temporary credentials rather than storing permanent access keys in application configuration.**

For ECS, distinguish the task execution role from the task role. ECS uses the execution role for actions such as image pulls and log delivery. The task role provides AWS permissions to the application inside the container.

Practice:

For a Spring Boot container that needs to read S3, decide whether the S3 permission belongs to:

```text
ECR permissions
or
Application task role
```

The application should receive only the permission it needs to perform its business function.

---

## Part 18 — Storage and Compute

Treat compute and storage as separate architectural concerns.

EC2 has instance storage and can attach EBS volumes. Containers are generally ephemeral — their filesystem disappears when the container is replaced — so persistent application data should normally live outside the container filesystem.

Common AWS choices include:

```text
EBS
S3
EFS
RDS
DynamoDB
ElastiCache
OpenSearch
```

The right service depends on the type of data.

For example:

```text
Application binary:
ECR

Database:
RDS

Object/file storage:
S3

Shared POSIX filesystem:
EFS

Block storage:
EBS

Cache / session:
ElastiCache

Search / log analytics:
OpenSearch
```

In plain terms: EBS is a virtual disk attached to one instance. EFS is a shared network filesystem that many workloads can mount at once. S3 stores files as objects that you access through an API, not as a mounted disk. For S3 in production, keep Block Public Access on, encrypt objects at rest, and turn on versioning. Day 26 teaches the IAM and VPC-endpoint path to the bucket.

RDS is the managed relational database. AWS runs the engine (PostgreSQL, MySQL, and others), applies engine patches in a maintenance window, and takes automated backups you can restore to a point in time. **Multi-AZ** keeps a standby in a second Availability Zone so an AZ failure does not take the database with it. Put RDS in a private subnet. Let the application reach it through the RDS DNS endpoint and a Security Group that allows only the app on the database port. Day 28 Part 15 walks that network path.

Two more managed data services appear on Senior Platform JDs, including production AWS roles that list them next to EC2, EKS, S3, RDS, and IAM.

**ElastiCache** is a managed cache, usually Redis. The application stores session data or hot query results there so it does not hit RDS on every request. The cache is not the source of truth: if the cluster disappears, you can rebuild it from the database. Place it in a private subnet. Open the cache port (6379 for Redis) from the application Security Group only.

**OpenSearch** is a managed search and analytics service (the open-source fork of Elasticsearch). Applications use it to search documents or to query logs and traces. It is not a replacement for RDS. Place the domain in a VPC. Control access with IAM and the domain access policy, the same layered idea you used for S3.

> **Remember:** RDS holds the records. S3 holds the objects. ElastiCache holds a copy you can lose. OpenSearch holds what you need to search. All four stay private. The application reaches them through Security Groups and IAM, not through the Internet.

**Look-up when a JD names them:** RDS Proxy (connection pooling when many Pods open database connections), ElastiCache cluster mode, and OpenSearch fine-grained access control. Learn the product names, then map them onto the private-data pattern above.

Do not put a production database inside an ephemeral container simply because the application itself is containerized.

Practice:

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

---

## Part 19 — Deployment Strategies Across AWS Compute

The deployment strategy should match the compute platform.

For EC2:

```text
ALB
 ↓
Old instances + New instances
 ↓
Traffic gradually shifts
```

For ECS:

```text
Old task revision
       +
New task revision
       ↓
Service deployment
```

For EKS:

```text
Deployment
 ↓
Rolling update
 ↓
New Pods
 ↓
Readiness
 ↓
Old Pods removed
```

For Lambda:

```text
Version
 ↓
Alias
 ↓
Traffic
```

The underlying principle is the same:

**Deploy a new version while maintaining control over traffic and health.**

A production deployment should include health validation. “The deployment command succeeded” is not the same as “the application is healthy.”

Practice:

For a Spring Boot release, design rollback for:

```text
EC2
ECS
EKS
Lambda
```

Then identify what actually changes during rollback.

---

## Part 20 — Observability Across AWS Compute

Different compute services expose different operational surfaces, but the observability principles remain the same.

You need visibility into:

```text
Infrastructure
Application
Network
Dependencies
Deployment
```

CloudWatch is commonly used for AWS metrics, logs, alarms and dashboards.

For EC2:

```text
Instance metrics
System/application logs
```

For ECS:

```text
Task metrics
Container logs
Service events
```

For EKS:

```text
Pod metrics
Container logs
Cluster/node metrics
Kubernetes events
```

For Lambda:

```text
Invocation metrics
Duration
Errors
Throttles
Logs
```

The important Senior/Lead question is:

> “What evidence tells me whether the compute platform, application, or dependency is failing?”

Practice:

For an API returning HTTP 503, identify which telemetry you would inspect for:

```text
EC2
ECS
EKS
Lambda
```

---

## Part 21 — Cost and Operational Responsibility

Compute cost is not just the hourly price of a server or task. Architecture affects:

```text
Compute
Storage
Network traffic
Load balancing
Logging
Monitoring
NAT
Database
Operational effort
```

For example, a highly managed service may reduce engineering effort but have different runtime economics than self-managed EC2.

A small workload might be inexpensive on EC2 but require more maintenance. A container workload may be easier to operate on Fargate but incur a different cost profile.

Do not compare services using only:

```text
$/hour
```

Also consider:

```text
Engineering effort
Availability requirements
Scaling efficiency
Idle capacity
Operational risk
Security maintenance
```

Practice:

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

---

## Part 22 — Senior/Lead Scenario: Choosing AWS Compute

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

---

## Part 23 — Practice: Build an AWS Compute Comparison Lab

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

---

## Part 24 — Failure Drill: Compute Is Healthy, Application Is Not

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

Practice:

Make your application's health endpoint fail while keeping the container process alive. Observe how platform-level status and application-level health differ.

---

## Part 25 — Failure Drill: Scaling Does Not Solve the Problem

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

Practice:

Draw:

```text
Client
 ↓
API
 ↓
Database
```

Then identify at least five places where saturation could occur.

---

## Part 26 — AWS ↔ Azure Compute Mapping

The underlying compute concepts are similar across clouds.

| Concept | AWS | Azure |
|---|---|---|
| Virtual machine | EC2 | Azure VM |
| VM scaling | Auto Scaling Group | VM Scale Sets |
| Managed web/application platform | Elastic Beanstalk | App Service |
| Managed containers | ECS | Container Apps |
| Container serverless execution | Fargate | Container Apps consumption/serverless-style execution |
| Managed Kubernetes | EKS | AKS |
| Serverless functions | Lambda | Azure Functions |
| Container registry | ECR | ACR |
| Load balancing L4 | NLB | Azure Load Balancer |
| Load balancing L7 | ALB | Application Gateway |

The mapping is conceptual, not perfectly one-to-one. For example, ECS and Azure Container Apps both support managed container workloads, but their orchestration models and feature sets differ.

The better interview approach is:

```text
Workload requirement
       ↓
Compute capability
       ↓
AWS implementation
       ↓
Azure equivalent
```

rather than memorizing:

```text
EC2 = VM
ECS = Container Apps
EKS = AKS
```

---

## Part 27 — 5-Minute Recall

Without looking at the notes, explain:

1. What is the main difference between EC2 and a managed container service?
2. What operational responsibilities come with EC2?
3. What is an AMI?
4. Why are immutable images/configuration useful?
5. What does an Auto Scaling Group provide?
6. Why does scaling on CPU alone sometimes fail?
7. What are the main ECS concepts?
8. What is a Task Definition?
9. What is an ECS Service?
10. What does Fargate manage for you?
11. What does EKS manage and what do you still own?
12. Why does EKS require both Kubernetes and AWS networking knowledge?
13. When does Lambda fit naturally?
14. What is a Lambda execution role?
15. What is ECR used for?
16. Why should workloads use IAM roles rather than embedded AWS access keys?
17. What is the difference between ECS task role and task execution role?
18. Why should application state normally live outside containers? What does RDS keep that ElastiCache does not, and what problem does OpenSearch solve that RDS does not?
19. How does deployment differ across EC2, ECS, EKS and Lambda?
20. Why does “container is running” not prove application health?
21. Why can scaling the application make a database problem worse?
22. How would you troubleshoot an AWS compute deployment returning 503?
23. How do you compare compute services beyond price?
24. When would you choose EC2 over ECS?
25. When would EKS be justified over ECS?
26. What is the AWS equivalent of the Azure compute concepts you already learned?

The most important mental model is:

**Workload → Compute Model → Network → Identity → Scale → Deploy → Observe → Recover → Cost**

At Senior/Lead level, the question is rarely “Can you create an EC2 instance?” The more valuable question is:

> “Given this workload and its business requirements, what compute model should we use, what responsibilities does the team take on, and how will we operate it safely in production?”

---

## Part 28 — Cleanup

Delete only resources created for the lab.

For EC2:

```bash
aws ec2 terminate-instances \
  --instance-ids <INSTANCE-ID>
```

For ECS:

```bash
aws ecs update-service \
  --cluster <CLUSTER> \
  --service <SERVICE> \
  --desired-count 0
```

Then remove the service and cluster when no longer required.

For EKS, use the appropriate cluster deletion process. Verify that associated resources such as load balancers, node groups, NAT gateways, and public IPs do not stay behind, because they continue to cost money.

For ECR, remove lab images if appropriate:

```bash
aws ecr batch-delete-image \
  --repository-name shopsphere \
  --image-ids imageTag=1.0.0
```

Before deleting networking resources, inspect dependencies. NAT Gateways, load balancers, ENIs (elastic network interfaces), and security groups can keep other resources alive or continue generating charges.

For cost-sensitive labs, verify the account after cleanup:

```bash
aws ec2 describe-instances
aws ec2 describe-nat-gateways
aws elbv2 describe-load-balancers
aws ecs list-clusters
aws eks list-clusters
```

The learning lifecycle remains:

**Create → Inspect → Deploy → Scale → Break → Troubleshoot → Recover → Destroy → Verify**

The final Day 27 mental model is:

**EC2 gives control, ECS gives managed container orchestration, Fargate removes server management, EKS provides managed Kubernetes, Elastic Beanstalk provides a managed application platform, and Lambda provides event-driven serverless execution.**

The Senior/Lead skill is not choosing the most managed service. It is choosing the compute model that best matches the workload while making the operational, security, reliability, networking, deployment, and cost consequences explicit.

## Answers to practice

### 1. Spring Boot on EC2, ECS, EKS, and Lambda — list needs first

<details>
<summary>Answer</summary>

The app needs a JVM, HTTP on 8080, private DB access, horizontal scale, rolling deploys, durable storage outside the process, and an IAM role. EC2 gives OS control and you patch Java. ECS runs the image without Kubernetes. EKS adds Kubernetes APIs. Lambda does not fit a long-lived Spring Boot process.

Choose from those needs. Do not start with a favorite service.

</details>

### 2. Deploy Spring Boot on EC2 and list what you own

<details>
<summary>Answer</summary>

You own OS patches, Java, the JAR, `systemd` or similar, log files, Security Groups, AMI hardening, deploy scripts, and ASG policy. AWS owns the hypervisor.

Launch with `aws ec2 run-instances` using an AMI, subnet, SG, and instance profile. SSH is for break-glass, not for installing Java by hand every time.

</details>

### 3. SSH-install Java vs bake an AMI

<details>
<summary>Answer</summary>

Approach B wins. Bake Java into an AMI with cloud-init or an image pipeline, then launch identical instances. SSH install drifts: one host gets a patch, another does not.

The AMI is the golden image. Rebuild and replace. Do not patch live servers in place.

</details>

### 4. CPU 25%, memory 80%, latency rising — do not scale on CPU

<details>
<summary>Answer</summary>

CPU is not the limiter. Memory pressure or a slow dependency likely is. Inspect heap, GC, connection pools, and database latency before you add instances.

Scale on the bottleneck you measure. A familiar CPU policy can add capacity that does not help.

</details>

### 5. Two EC2 instances behind an ALB; stop one

<details>
<summary>Answer</summary>

The ALB target group marks the stopped instance unhealthy and stops sending new requests. The remaining healthy instance takes traffic. `aws elbv2 describe-target-health` shows the change.

Instance `running` is not application health. A live EC2 returning HTTP 500 can still fail the target health check.

</details>

### 6. Three copies of the Day 13 image on ECS

<details>
<summary>Answer</summary>

Push the image to ECR. Write a Task Definition with CPU, memory, port 8080, and `awsvpc`. An ECS Service desired count of 3 keeps three tasks. Put them in private subnets, behind an ALB, with a task role for AWS APIs.

The Service replaces failed tasks, similar in idea to a Kubernetes Deployment, but ECS is not Kubernetes.

</details>

### 7. Task Definition fields vs secrets

<details>
<summary>Answer</summary>

Put CPU, memory, port, log driver, health check, and non-secret env such as `SPRING_PROFILES_ACTIVE` in the Task Definition. Put database passwords in Secrets Manager or SSM and inject at runtime.

The Task Definition describes how the image runs in AWS. It is not a place for long-lived secrets.

</details>

### 8. ECS deploy `1.0.0` then `1.1.0` and watch the transition

<details>
<summary>Answer</summary>

The Service starts a new Task Definition revision. New tasks register with the ALB when healthy. Old tasks drain. Watch running count, revisions, target health, and service events.

Deployment is a transition, not one command. “Update succeeded” is not “users are healthy.”

</details>

### 9. ECS on EC2 vs Fargate: who manages what

<details>
<summary>Answer</summary>

ECS on EC2: you manage the EC2 capacity, AMIs, and node scaling. ECS still orchestrates tasks. Fargate: AWS manages the servers. You still manage VPC, subnets, Security Groups, IAM, logs, secrets, and scale.

Serverless does not mean no network architecture.

</details>

### 10. ECS 4 → 12 tasks, API CPU drops, database at 100%, latency worse

<details>
<summary>Answer</summary>

Extra tasks opened more database sessions. The database became the bottleneck. API CPU fell because the app spent time waiting on RDS.

Scaling the symptom increased pressure on the dependency. Scale or tune the database, pools, or cache.

</details>

### 11. What changes when Kubernetes moves to EKS

<details>
<summary>Answer</summary>

Deployments, Services, probes, and RBAC stay. AWS adds VPC CNI, IAM for ServiceAccounts, ALB Ingress, ECR, CloudWatch, and managed control plane. You still own node groups or Fargate, add-ons, and workloads.

Learn Kubernetes first. Then add the AWS layers.

</details>

### 12. Restrict the RDS Security Group and diagnose the EKS failure

<details>
<summary>Answer</summary>

Remove the Pod/node SG from RDS inbound 5432. The Pod times out. Walk Pod DNS → CNI → route → RDS SG → port → database. Restore only the app SG on 5432.

Do not treat this as “just Kubernetes” or “just AWS.” Both layers own the path.

</details>

### 13. Which workloads fit Lambda

<details>
<summary>Answer</summary>

S3 upload processing: yes, event-driven and short. Thumbnail generation: yes. SQS message processing: yes. A continuously available Spring Boot API: no; keep it on ECS/EKS or a similar always-on platform.

Ask whether the work is short-lived event execution. Not every Java app is a Function.

</details>

### 14. Lambda on S3 files vs Lambda on private RDS

<details>
<summary>Answer</summary>

S3 → Lambda → process → store can stay out of the VPC and is sensitive mainly to cold start on the first file. API → Lambda → private RDS needs VPC ENIs, subnets, SGs, and DNS, plus extra init latency.

Do not assume every invocation has the same latency. Cold start plus VPC attach can miss an API SLO.

</details>

### 15. Compare EC2, Elastic Beanstalk, and ECS Fargate for Spring Boot

<details>
<summary>Answer</summary>

EC2: you own OS, deploy, and scale. Beanstalk: you push the app; it provisions EC2, ALB, and ASG underneath. Fargate: you push an image; AWS runs tasks; you still design VPC and IAM.

Pick from OS need, container need, and operational load. More automation is not automatically the right platform.

</details>

### 16. Push `shopsphere:1.0.0` to ECR and promote the digest

<details>
<summary>Answer</summary>

`aws ecr get-login-password` then `docker tag` and `docker push`. Record Git SHA, build ID, tag, and digest. Deploy that digest in Dev, UAT, and Production.

Build once. A mutable tag can move. The digest cannot.

</details>

### 17. S3 read permission: ECR vs task role

<details>
<summary>Answer</summary>

ECR permissions belong on the task execution role (pull image). `s3:GetObject` belongs on the application task role.

The app gets only the business permission. Do not put S3 on the execution role “because ECS needs IAM.”

</details>

### 18. Classify Spring Boot data and map session/search

<details>
<summary>Answer</summary>

JAR: ECR. Profile image: S3. Database records: RDS. Temp files: ephemeral container disk. Shared reports: S3 or EFS if POSIX is required. Session tokens: ElastiCache. Product search: OpenSearch.

ElastiCache is a copy you can lose. OpenSearch searches documents; it does not replace RDS records. Keep all four private.

</details>

### 19. Rollback Spring Boot on EC2, ECS, EKS, and Lambda

<details>
<summary>Answer</summary>

EC2: shift the ALB to previous AMI/instances. ECS: deploy the previous Task Definition revision. EKS: `kubectl rollout undo` or Helm rollback. Lambda: point the alias back at the prior version.

Rollback changes which artifact receives traffic. Schema compatibility still applies.

</details>

### 20. Telemetry for HTTP 503 on EC2, ECS, EKS, Lambda

<details>
<summary>Answer</summary>

EC2: instance metrics, system and app logs, target health. ECS: task metrics, container logs, service events. EKS: Pod metrics, `kubectl logs`, Events, node metrics. Lambda: errors, duration, throttles, logs.

Ask which evidence says platform vs application vs dependency.

</details>

### 21. Trade-offs: 2 EC2, ECS on EC2, Fargate, EKS, Lambda for a small variable API

<details>
<summary>Answer</summary>

Two EC2: simple money, high OS work, idle cost. ECS on EC2: you still patch nodes. Fargate: no nodes, different runtime price, still VPC design. EKS: Kubernetes power and cluster cost for one API is usually too much. Lambda: poor fit for a long-lived Spring Boot process; good if you rewrite as events.

Compare effort, idle capacity, and risk, not only `$/hour`.

</details>

### 22. Health endpoint fails while the container stays alive

<details>
<summary>Answer</summary>

The task can stay `RUNNING` while the ALB marks the target unhealthy and users see 503. Platform status and application health differ.

Break `/health` in the lab and watch target health, service events, and logs. Do not stop at `RUNNING`.

</details>

### 23. Bottleneck chain: Client → API → Database, five saturation points

<details>
<summary>Answer</summary>

Saturation can sit at ALB, API CPU/memory, the connection pool, database CPU, database connections, database I/O, network, or a downstream API. Extra ECS tasks raise pool and DB pressure.

Scale the bottleneck, not the symptom.

</details>

### 24. Main difference between EC2 and a managed container service

<details>
<summary>Answer</summary>

EC2 gives OS-level VMs you patch and configure. ECS/EKS/Fargate run containers and take more of the server operations.

You still own networking, identity, and the application.

</details>

### 25. Operational responsibilities that come with EC2

<details>
<summary>Answer</summary>

OS patching, runtime, deploy, instance config, hardening, monitoring, and scaling configuration.

AWS does not manage the guest OS for you.

</details>

### 26. What is an AMI?

<details>
<summary>Answer</summary>

The template an EC2 instance boots from: OS plus optional baked software.

Treat it as the golden image. Rebuild and replace instances.

</details>

### 27. Why immutable images/configuration are useful

<details>
<summary>Answer</summary>

Every instance starts identical. Drift from SSH edits goes away.

Bake, test, launch new, retire old.

</details>

### 28. What does an Auto Scaling Group provide?

<details>
<summary>Answer</summary>

A managed EC2 group with min/desired/max that can replace unhealthy instances and follow scaling policies.

One EC2 is a single-instance failure point.

</details>

### 29. Why scaling on CPU alone sometimes fails

<details>
<summary>Answer</summary>

The limiter may be memory, connections, or a dependency. CPU can look fine while latency rises.

Pick the metric that matches the bottleneck.

</details>

### 30. Main ECS concepts

<details>
<summary>Answer</summary>

Cluster, Task Definition, Task, Service, Container.

The Service keeps the desired task count.

</details>

### 31. What is a Task Definition?

<details>
<summary>Answer</summary>

The blueprint: image, CPU/memory, ports, logs, roles, health checks.

A Task is a running copy of that definition.

</details>

### 32. What is an ECS Service?

<details>
<summary>Answer</summary>

The controller that maintains desired tasks and can attach a load balancer.

Failed tasks get replaced. New revisions roll forward.

</details>

### 33. What does Fargate manage for you?

<details>
<summary>Answer</summary>

The underlying servers for the container. You do not patch an EC2 node fleet.

You still manage VPC, IAM, logs, secrets, and scaling.

</details>

### 34. What EKS manages and what you still own

<details>
<summary>Answer</summary>

AWS manages the Kubernetes control plane. You own workloads, much of the data plane, IAM, VPC, and add-ons.

Pods, Deployments, and NetworkPolicy remain your design.

</details>

### 35. Why EKS needs Kubernetes and AWS networking knowledge

<details>
<summary>Answer</summary>

Traffic crosses Services and CNI, then VPC routes, Security Groups, and RDS.

A healthy Pod can still time out on an RDS SG.

</details>

### 36. When does Lambda fit naturally?

<details>
<summary>Answer</summary>

When the work is short-lived and event-driven: S3, SQS, EventBridge, API Gateway for small functions.

A always-on Spring Boot API is a different execution model.

</details>

### 37. What is a Lambda execution role?

<details>
<summary>Answer</summary>

The IAM role the function assumes to call AWS APIs.

It is workload identity, not an embedded access key.

</details>

### 38. What is ECR used for?

<details>
<summary>Answer</summary>

It stores container images for ECS, EKS, and other AWS compute.

Push once, scan, promote the digest.

</details>

### 39. Why workloads should use IAM roles, not embedded keys

<details>
<summary>Answer</summary>

Roles vend temporary credentials. Keys in images and env files leak and remain valid.

EC2 instance profiles, ECS task roles, EKS IRSA, and Lambda execution roles are the pattern.

</details>

### 40. ECS task role vs task execution role

<details>
<summary>Answer</summary>

Execution role: pull from ECR, write logs. Task role: application AWS APIs such as `s3:GetObject`.

Split them. The app should not inherit registry-pull power it does not need.

</details>

### 41. State outside containers; RDS vs ElastiCache vs OpenSearch

<details>
<summary>Answer</summary>

Container filesystems die with the task. Persist in RDS, S3, EFS, or similar. RDS keeps source-of-truth records ElastiCache does not. OpenSearch searches documents and logs; RDS does not replace that search model.

All stay private. None of them belong as a database inside the container.

</details>

### 42. How deployment differs across EC2, ECS, EKS, and Lambda

<details>
<summary>Answer</summary>

EC2: new instances or AMI roll behind an ALB. ECS: new Task Definition revision. EKS: rolling Deployment with readiness. Lambda: versions and aliases.

Always validate health. Command success is not user health.

</details>

### 43. Why “container is running” does not prove application health

<details>
<summary>Answer</summary>

`RUNNING` means the process has not exited. The app can still return 503, fail probes, or miss the database.

Use target health, `/health`, and logs.

</details>

### 44. Why scaling the application can make a database problem worse

<details>
<summary>Answer</summary>

More tasks mean more connections and queries. A saturated RDS gets worse.

Scale the bottleneck you measured.

</details>

### 45. Troubleshoot an AWS compute deploy returning 503

<details>
<summary>Answer</summary>

ALB target health → service or Deployment events → task/Pod status → logs → health endpoint → env/secrets → database.

Do not restart the cluster first.

</details>

### 46. How to compare compute services beyond price

<details>
<summary>Answer</summary>

Compare engineering effort, availability, scaling efficiency, idle capacity, operational risk, and security maintenance.

`$ /hour` hides OS patching and cluster upgrades.

</details>

### 47. When would you choose EC2 over ECS?

<details>
<summary>Answer</summary>

When you need OS-level agents, custom filesystems, or a runtime that does not fit a container platform.

Accept the patching and AMI factory that come with that choice.

</details>

### 48. When would EKS be justified over ECS?

<details>
<summary>Answer</summary>

When you need Kubernetes APIs, Helm ecosystem, custom controllers, or cluster-level networking policy.

A single Dockerized API does not need that complexity.

</details>

### 49. AWS equivalents of the Azure compute concepts

<details>
<summary>Answer</summary>

EC2 ≈ Azure VM. ASG ≈ VMSS. Elastic Beanstalk ≈ App Service (approximate). ECS/Fargate ≈ Container Apps. EKS ≈ AKS. Lambda ≈ Functions. ECR ≈ ACR.

Map capability, then name the service. The products are not identical.

</details>

### 50. Map workloads A–D to AWS compute with justification

<details>
<summary>Answer</summary>

A legacy Java with OS customization: EC2 (or Beanstalk if the platform fits). B Dockerized Spring Boot API: ECS Fargate. C Kubernetes-native platform with Helm and service networking: EKS. D S3-triggered image processing: Lambda.

Reason from runtime, control, scale, network, identity, deploy, observability, ownership, and cost. Not from “EKS is modern.”

</details>

### 51. Compute comparison lab: same image on Fargate, EKS, and EC2

<details>
<summary>Answer</summary>

Push Spring Boot to ECR. Run it on ECS Fargate, EKS Deployment+Service, and EC2+ALB if cost allows. For each, record who manages OS and control plane, scaling, deploy, IAM, logs, failure, and cleanup.

You do not need every model fully built. You need the operational comparison.

</details>

### 52. ALB → ECS task RUNNING but HTTP 503

<details>
<summary>Answer</summary>

Inspect target health, ECS events, logs, `/health`, secrets, and DB. The task process can be up while the app is not ready.

Do not conclude ECS is broken from `RUNNING` alone.

</details>

### 53. ECS scales 4 → 12, DB saturates, latency worse

<details>
<summary>Answer</summary>

The API was not the bottleneck. Added tasks saturated RDS. Identify the real limiter and scale or fix that.

Treat compute scale as one lever, not the only lever.

</details>
