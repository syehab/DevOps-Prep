# Day 27 — AWS Overlay 02: AWS Compute

This Day uses three files. Read them in this order.

1. [01-concepts.md](01-concepts.md) — lesson content (this file)
2. [02-questions-and-answers.md](02-questions-and-answers.md) — practice items, each with a model answer
3. [03-implementation.md](03-implementation.md) — hands-on lab

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

Some platforms also stream row changes out of the database. **Change data capture (CDC)** reads the database change log (the write-ahead log PostgreSQL already keeps) and publishes each insert, update, or delete as an event. Debezium is a common CDC connector. Amazon MSK is managed Kafka, the bus those events often land on.

The application writes to RDS once. Downstream services consume the events. They do not need a second write from the app to Kafka. That second write is a dual-write, and the two stores drift when one write fails.

**Look-up when a JD names them:** Debezium connectors, MSK topic design, consumer groups. Learn the product names, then map them onto this idea: the log is the source of events.

Do not put a production database inside an ephemeral container simply because the application itself is containerized.

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
