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

An EC2 instance can be launched using the AWS CLI:

```bash
aws ec2 run-instances \
  --image-id <AMI-ID> \
  --instance-type t3.micro \
  --subnet-id <SUBNET-ID> \
  --security-group-ids <SG-ID> \
  --iam-instance-profile Name=<INSTANCE-PROFILE>
```

The exact AMI and instance type depend on the Region and workload.

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

For repeatable infrastructure, you should avoid manually configuring every instance after launch. Instead, configuration can be automated using tools such as cloud-init, user data, configuration management, or image-building processes.

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

Running one EC2 instance creates a single-instance failure point. Auto Scaling Groups, or ASGs, allow EC2 capacity to be managed as a group and can replace unhealthy instances or adjust capacity according to scaling policies.

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

Scaling can be based on metrics such as CPU utilization, but CPU is not always the correct application signal. For a queue-driven system, queue depth may be more useful. For a web application, request count or latency can sometimes be better indicators.

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

The target group performs health checks so traffic can be directed toward healthy targets.

A basic ALB can be inspected using:

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

Depending on the EKS networking configuration, Pods can receive VPC-routable IP addresses through the AWS VPC CNI model.

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

A continuously running Spring Boot API may fit better on ECS, EKS, App Runner, or another managed application platform depending on its requirements, while a small asynchronous processing function may fit Lambda well.

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

When Lambda functions are connected to a VPC, the networking path, security groups, subnets, DNS and available IP capacity become relevant.

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

For ECS, distinguish the task execution role from the task role. The execution role is used by ECS for actions such as pulling images and sending logs, while the task role provides AWS permissions to the application running inside the container.

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

Compute and storage should be treated as separate architectural concerns.

EC2 has instance storage and can attach EBS volumes. Containers are generally ephemeral, so persistent application data should normally live outside the container filesystem.

Common AWS choices include:

```text
EBS
S3
EFS
RDS
DynamoDB
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
```

Do not put a production database inside an ephemeral container simply because the application itself is containerized.

Practice:

For a Spring Boot application, classify:

```text
JAR
Uploaded profile image
Database records
Temporary files
Shared generated reports
```

Then select the appropriate storage model.

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
18. Why should application state normally live outside containers?
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

For EKS, use the appropriate cluster deletion process and verify that associated resources such as load balancers, node groups, NAT gateways, and public IPs are not left behind.

For ECR, remove lab images if appropriate:

```bash
aws ecr batch-delete-image \
  --repository-name shopsphere \
  --image-ids imageTag=1.0.0
```

Before deleting networking resources, inspect dependencies. NAT Gateways, load balancers, ENIs, and security groups can keep other resources alive or continue generating charges.

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
