# Day 18 — Identity, Secrets & Cloud Security

**Goal:** Build a practical security mental model for cloud and Kubernetes environments, then implement the core patterns with Azure, AWS and Kubernetes examples.

**Core idea:** Security is not one product or one firewall. A production workload has multiple identities, trust boundaries and protection layers. The Senior/Lead question is always: **Who is trying to access what, from where, using which identity, and what should they be allowed to do?**

## Part 1 — The Security Mental Model

1. Cloud security becomes much easier when you separate **identity, authentication, authorization and resource**. Identity answers “who or what is requesting access?”, authentication verifies that identity, authorization determines what that identity is allowed to do, and the resource is the thing being accessed. For example, a CI pipeline may authenticate as a deployment identity and then be authorized to deploy infrastructure, while a Spring Boot Pod may authenticate as its own workload identity and be authorized to read one secret. These are different identities because they have different jobs and therefore different required permissions.

2. A useful model is:

```text
Who?
 ↓
Identity
 ↓
Can I prove who you are?
 ↓
Authentication
 ↓
What are you allowed to do?
 ↓
Authorization
 ↓
What are you accessing?
 ↓
Resource
```

A common interview mistake is saying “authentication means permission.” It does not. A valid token proves that the caller is associated with an identity; a separate authorization decision determines whether that identity can perform the requested action.

3. A real DevOps platform can involve several identities in one delivery path:

```text
Developer
   ↓
Git Repository
   ↓
CI Identity
   ↓
Container Registry
   ↓
GitOps / Deployment Identity
   ↓
Kubernetes
   ↓
Application Workload Identity
   ↓
Cloud Service / Database
```

The developer should not need to give their personal credentials to the application. The CI pipeline should not normally use a developer's credentials. The application should not use the CI identity. Separating these identities creates smaller blast radii and makes audit logs meaningful.

4. Trust boundaries matter just as much as identities. Moving from a developer workstation to Git, from Git to CI, from CI to a registry, from a cluster to a cloud service and from an application to a database crosses different security boundaries. At each boundary, ask what identity is presented, how it is authenticated, what permissions it has, how traffic is protected and what logs are generated.

5. Security is therefore best thought of as several controls working together:

```text
Identity
   +
Authentication
   +
Authorization
   +
Network Security
   +
Secrets
   +
Application Security
   +
Supply-chain Security
   +
Logging / Detection
```

No single control should be expected to compensate for every other missing control. For example, private networking does not replace authentication, and strong IAM does not fix an exposed application vulnerability.

**Implementation example — identify the actors:** For the Spring Boot application used throughout this course, create a simple table in your notes with:

```text
Actor              Identity             Access Needed
Developer          Human identity      Source code / Dev
CI Pipeline        CI identity         Build / Registry / Deploy
GitOps Controller  Workload identity   Kubernetes resources
Spring Boot        Workload identity   Key Vault / AWS service
Database           DB identity         Database authentication
```

Then add one column: **“What should this identity NOT be allowed to access?”**

**Practice:** Take one real deployment flow and trace every identity from source code to production. If two unrelated components are using the same credential, ask whether they genuinely need the same permissions.

---

## Part 2 — Authentication vs Authorization

1. Authentication and authorization solve different problems. Authentication establishes the identity of the caller, while authorization evaluates whether that identity may perform the requested action. Think of entering an office: your badge proves who you are, while the doors you can open represent authorization. In cloud systems, authentication may involve an Entra ID-issued token or AWS identity credentials, while authorization may involve Azure RBAC, AWS IAM policies or Kubernetes RBAC.

2. Consider a developer accessing AKS:

```text
Developer
   ↓
Microsoft Entra ID
   ↓
Authentication
   ↓
AKS / Kubernetes API
   ↓
Authorization
   ↓
Allowed Kubernetes resources
```

The identity provider establishes who the developer is. The authorization layer determines whether that identity can, for example, read Pods, create Deployments or administer the cluster.

3. The same separation exists for applications:

```text
Spring Boot Pod
      ↓
Workload Identity
      ↓
Token / Cloud credentials
      ↓
Authorization policy
      ↓
Key Vault / Secrets Manager
```

The application first obtains an identity credential and then uses it to request a resource. If the identity is valid but lacks permission, authentication succeeded while authorization failed.

4. This distinction is extremely useful during troubleshooting. A failure such as “invalid token,” “unauthenticated” or failure to acquire credentials points toward authentication. A `403 Forbidden`, `AccessDenied` or equivalent permission error usually points toward authorization. A timeout may instead indicate DNS, routing, firewall, NetworkPolicy or another network problem. Treating all failures as “IAM problems” leads to dangerous permission escalation.

5. The Senior/Lead troubleshooting sequence is:

```text
Who is the caller?
        ↓
Which identity is being used?
        ↓
Did authentication succeed?
        ↓
What authorization policy applies?
        ↓
What resource is being accessed?
        ↓
Is the resource reachable and healthy?
```

**Implementation example — Kubernetes RBAC:** Create a read-only ServiceAccount and Role:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-reader
  namespace: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: default
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-reader-binding
  namespace: default
subjects:
  - kind: ServiceAccount
    name: app-reader
    namespace: default
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

Apply it:

```bash
kubectl apply -f rbac.yaml
kubectl auth can-i get pods \
  --as=system:serviceaccount:default:app-reader
kubectl auth can-i delete pods \
  --as=system:serviceaccount:default:app-reader
```

The first check should return `yes`; the second should return `no`. This demonstrates authorization independently of your application's code.

**Practice:** Deliberately ask Kubernetes whether the identity can perform actions it was not granted. Explain why “authentication succeeded” does not imply “authorization succeeded.”

---

## Part 3 — Cloud IAM: Azure RBAC and AWS IAM

1. Cloud IAM controls access to cloud resources. Azure commonly combines Microsoft Entra identities with Azure role-based access control, while AWS uses IAM identities, roles and policies. The terminology differs, but the fundamental question is the same: **Who can perform which action on which resource, at what scope, and under what conditions?** Senior engineers should understand this model rather than memorizing hundreds of role names.

2. Azure RBAC can be understood as:

```text
Security Principal
       +
Role Definition
       +
Scope
       ↓
Role Assignment
       ↓
Effective Access
```

A security principal might be a user, group, service principal or managed identity. The role defines allowed operations and scope determines where the permission applies.

3. Azure scope is hierarchical:

```text
Management Group
      ↓
Subscription
      ↓
Resource Group
      ↓
Resource
```

A role assigned at subscription scope can affect resources throughout that subscription. Therefore, if a deployment only needs to modify one resource group, giving it broad subscription-level permissions increases blast radius unnecessarily.

4. A simplified Azure CLI example is:

```bash
az role assignment create \
  --assignee <IDENTITY-ID> \
  --role Contributor \
  --scope /subscriptions/<SUBSCRIPTION-ID>/resourceGroups/<RESOURCE-GROUP>
```

The command creates a role assignment at the resource-group scope. In a real environment, choose the narrowest appropriate built-in or custom role rather than automatically using `Contributor`.

5. AWS IAM uses policies that describe allowed or denied actions against resources. Roles are particularly important because they can provide temporary credentials to trusted identities instead of requiring long-lived access keys.

A simplified conceptual policy is:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject"
      ],
      "Resource": "arn:aws:s3:::example-bucket/app/*"
    }
  ]
}
```

This grants a narrowly defined operation over a specific resource path rather than broad S3 access.

6. A useful cross-cloud translation is:

```text
Azure:
Principal → Role → Scope → Resource

AWS:
Principal / Role → Policy → Resource / Conditions
```

The implementation differs, but the design question remains the same.

**Implementation practice — Azure:** Create a test identity and assign it only the permissions needed for a lab resource group. Use:

```bash
az role assignment list \
  --assignee <IDENTITY-ID> \
  --all
```

Then inspect the actual scope rather than assuming it from the role name.

**Implementation practice — AWS:** Create a test IAM role with a deliberately narrow policy, attach it to a test workload or session, and verify that an allowed action succeeds while an unrelated action is denied.

**Practice:** Take a deployment identity and design its permissions at the smallest practical scope. Then ask: **If this identity is compromised, what is the maximum damage it can cause?**

---

## Part 4 — Service Principals, Managed Identities and Workload Identity

1. Azure provides several ways for applications and automation to obtain an identity. A service principal represents an application identity and can authenticate using credentials such as a client secret or certificate. Managed identities allow Azure-managed credentials to be associated with supported resources, reducing the need to create and rotate application-managed secrets. Workload identity extends this principle to workloads such as Kubernetes applications so that a Pod can obtain cloud permissions without embedding a long-lived cloud credential in the container.

2. The traditional secret-based pattern looks like:

```text
Application
   ↓
Client ID
   +
Client Secret
   ↓
Token
   ↓
Azure Service
```

The secret must be created, stored, rotated and revoked. It can also accidentally appear in Git, CI variables, shell history, debugging output or logs.

3. A managed/workload identity model looks conceptually like:

```text
Application
   ↓
Workload Identity
   ↓
Short-lived token
   ↓
Cloud service
```

The exact token exchange is platform-specific, but the important security improvement is that the application does not need a permanent cloud password embedded in its configuration.

4. In AKS, Microsoft Entra Workload ID can associate a Kubernetes workload with an Azure identity. A simplified conceptual flow is:

```text
Pod
 ↓
Kubernetes ServiceAccount
 ↓
Workload identity federation
 ↓
Microsoft Entra ID
 ↓
Azure access token
 ↓
Azure resource
```

This lets the application access Azure resources using its own identity.

5. In EKS, IAM roles for service accounts and newer EKS Pod Identity patterns provide the same broad goal: associate AWS permissions with workloads instead of embedding access keys in containers. The exact implementation depends on the EKS configuration and supported mechanism.

6. Never use a developer's personal cloud credentials inside an application. That creates a terrible ownership and blast-radius model: when the developer leaves, changes password or loses access, the application can break; if the credential leaks, the application inherits the developer's permissions.

**Implementation example — AKS Workload Identity:** The conceptual setup is:

```text
Azure managed identity
        ↓
Federated identity credential
        ↓
Kubernetes ServiceAccount
        ↓
Spring Boot Pod
```

The ServiceAccount is annotated/configured for the workload identity, and the Azure identity receives only the required Azure role.

A simplified ServiceAccount might look like:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: myapp-sa
  namespace: myapp
  annotations:
    azure.workload.identity/client-id: "<CLIENT-ID>"
```

The exact labels, federation setup and cluster configuration should follow the current AKS Workload ID implementation used by your cluster.

**Implementation example — EKS:** Conceptually:

```text
IAM Role
   ↓
Trust relationship
   ↓
Kubernetes workload identity
   ↓
Pod
   ↓
AWS API
```

The IAM role should contain only the AWS actions required by the application.

**Practice:** Compare:

```text
A. Client ID + client secret
B. Managed/workload identity
C. Developer credentials
```

For each, identify credential lifetime, rotation effort, blast radius and failure mode.

---

## Part 5 — Secrets: What They Are and Where They Leak

1. Secrets are sensitive values such as database passwords, API keys, certificates, private keys and tokens. Secret management is therefore a lifecycle problem, not simply a storage problem. You must consider creation, storage, access, transmission, consumption, rotation, expiration, revocation and logging. A secret stored securely but printed into application logs is still compromised.

2. The unsafe lifecycle often looks like:

```text
Developer creates password
        ↓
.env file
        ↓
Git
        ↓
CI variable
        ↓
Docker build
        ↓
Helm values
        ↓
Kubernetes
        ↓
Application
```

Every additional system becomes another potential exposure point. Git history is particularly dangerous because deleting a secret from the current file does not necessarily remove it from historical commits.

3. A better lifecycle is:

```text
Secret Manager
      ↓
Workload Identity
      ↓
Authorized retrieval
      ↓
Application runtime
```

For Azure this could involve Key Vault. For AWS it could involve Secrets Manager. Kubernetes can then receive or consume the secret through an approved integration rather than making the source repository the authoritative secret store.

4. Docker images deserve special attention. Never do this:

```dockerfile
ENV DB_PASSWORD=supersecret
```

and do not do this:

```dockerfile
COPY .env /app/.env
```

Even if the final application no longer exposes the value, build layers or image history may retain sensitive information. A container image should contain application code and non-sensitive defaults, not production credentials.

5. Helm values also require discipline. This is acceptable for non-secret configuration:

```yaml
database:
  host: postgres.internal
  port: 5432
```

but a production password should not normally be committed as:

```yaml
database:
  password: supersecret
```

Instead, represent the reference to the secret and let the approved secret-management mechanism provide the value.

6. Secret exposure can happen through:

```text
Git history
CI/CD logs
Dockerfile
Image layers
Helm values
Shell history
Application logs
Crash dumps
Debug output
```

The Senior question is therefore:

> **Where can this secret exist throughout its entire lifecycle?**

**Implementation example — Git detection:** Add secret-scanning to the repository/CI process and deliberately create a harmless test credential pattern in a test branch to understand how your chosen scanner detects it. Never use a real production credential for the exercise.

**Practice:** Take one database password and draw every system it would touch under your current architecture. Redesign the flow to minimize those locations.

---

## Part 6 — Kubernetes Secrets and External Secret Management

1. Kubernetes Secrets provide a native way for workloads to consume sensitive configuration. A Secret can be referenced through environment variables or mounted as a file. However, access to Secrets is controlled through Kubernetes permissions, and administrators or identities with sufficient permissions may be able to retrieve their contents. Treating a Kubernetes Secret as automatically secure simply because its value is encoded rather than shown in plain text is a common misconception.

2. Create a test Secret:

```bash
kubectl create secret generic db-secret \
  --from-literal=username=appuser \
  --from-literal=password=test-password
```

Inspect it:

```bash
kubectl get secret db-secret
kubectl describe secret db-secret
```

Kubernetes commonly displays the data as encoded values rather than exposing the literal secret through `get` output. Encoding is not encryption.

3. A Pod can consume the Secret:

```yaml
env:
  - name: DB_USERNAME
    valueFrom:
      secretKeyRef:
        name: db-secret
        key: username

  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: db-secret
        key: password
```

The application receives the values at runtime without the password being hard-coded into the Deployment manifest.

4. For a production architecture, you may instead use an external secret manager:

```text
Azure Key Vault / AWS Secrets Manager
              ↓
       Secret integration
              ↓
        Kubernetes Pod
              ↓
          Application
```

Common implementation patterns include external-secret controllers or CSI-based integrations. The exact tool should be selected according to your organization's platform standard.

5. Encryption at rest matters. Kubernetes stores cluster state in etcd, and Secret protection depends on the cluster's configuration, including encryption-at-rest and access controls. Managed Kubernetes services provide some platform-managed protections, but you should still understand who can read Secrets and how your cluster protects stored data.

6. Rotation creates another operational problem. Suppose:

```text
Old DB password → New DB password
```

The application must eventually consume the new credential. If the secret is loaded only at process startup, simply changing the external value may not change the already-running process. Your application architecture therefore needs a deliberate rotation strategy, such as reload support, restart/redeployment or another mechanism.

**Implementation practice:** Create the test Secret, consume it from a Pod, then update the Secret:

```bash
kubectl create secret generic db-secret \
  --from-literal=username=appuser \
  --from-literal=password=new-test-password \
  --dry-run=client -o yaml | kubectl apply -f -
```

Then determine whether your running application sees the new value immediately. This teaches the difference between **secret rotation** and **application consumption of rotated secrets**.

**Practice:** Design a production secret-rotation flow and explicitly identify who owns creation, storage, authorization, rotation and application reload.

---

## Part 7 — Least Privilege and Blast Radius

1. Least privilege means giving an identity only the permissions required for its intended task. The objective is to reduce unnecessary access and therefore reduce the potential impact of credential theft, application compromise or operator mistakes. Least privilege applies to humans, CI systems, GitOps controllers, Kubernetes ServiceAccounts and cloud workloads. It is not simply an IAM setting; it is an architectural discipline.

2. Compare:

```text
CI Identity
    ↓
Subscription / Account Administrator
```

with:

```text
CI Identity
    ↓
Deployment Role
    ↓
Required Resource Scope
```

The second model can reduce blast radius because compromising the CI identity does not automatically grant unrestricted control over unrelated resources.

3. Least privilege must be evaluated across both **action** and **scope**. “Read access” to every production database may still be too broad. “Contributor” over one resource group may be reasonable for a specific infrastructure deployment but excessive for an application pipeline. Always ask what exact operation is needed and where it needs to operate.

4. Kubernetes has the same principle. A ServiceAccount that only needs to read ConfigMaps should not be granted cluster-admin. A monitoring identity may need read-only access to telemetry but should not be able to delete workloads. A GitOps controller should have permissions appropriate to the resources it manages rather than unrestricted cluster administration when the architecture permits narrower access.

5. Blast radius is the practical question:

```text
If this credential leaks,
what can it change?

If this Pod is compromised,
what can it access?

If this pipeline is compromised,
what can it deploy?

If this ServiceAccount is compromised,
what Kubernetes resources can it modify?
```

This is one of the strongest ways to explain least privilege in an interview because it connects permissions directly to incident impact.

**Implementation example — Kubernetes:** Use `kubectl auth can-i` to test a ServiceAccount:

```bash
kubectl auth can-i get pods \
  --as=system:serviceaccount:default:app-reader

kubectl auth can-i delete pods \
  --as=system:serviceaccount:default:app-reader

kubectl auth can-i create deployments \
  --as=system:serviceaccount:default:app-reader
```

You should be able to explain every `yes` and every `no`.

**Practice:** Build a permission matrix:

```text
Identity          Required access          Must NOT have
Developer         Dev resources            Prod admin
CI                Build + deploy          Account admin
GitOps             Managed K8s resources   Unrestricted cloud admin
Application       Required cloud API      Subscription admin
Monitoring        Read telemetry           Write workloads
```

Then challenge each permission.

---

## Part 8 — Network Security: Cloud Controls + Kubernetes Controls

1. Identity controls who can perform actions, while network security controls where traffic can flow. These controls complement each other. A database may authorize the correct application identity but still be unreachable because routing or firewall rules block traffic. Conversely, a network path may be completely open while the database correctly rejects unauthorized credentials.

2. A production request can therefore pass through several controls:

```text
Internet
   ↓
WAF / Load Balancer
   ↓
Cloud Network Controls
   ↓
Ingress
   ↓
NetworkPolicy
   ↓
Service
   ↓
Pod
   ↓
Application Authentication
   ↓
Database Authorization
```

Not every application requires every layer, but the architecture should make the responsibility of each layer clear.

3. Azure commonly uses VNets, subnets, NSGs, private endpoints and Azure firewall-related services. AWS commonly uses VPCs, subnets, route tables, security groups, network ACLs and private connectivity mechanisms. Kubernetes adds its own workload-level networking controls such as NetworkPolicy. A secure platform often uses controls at both the cloud and Kubernetes layers.

4. Consider a Spring Boot Pod accessing PostgreSQL:

```text
Pod
 ↓
Pod network
 ↓
Node / VNet / VPC
 ↓
Route
 ↓
Cloud security controls
 ↓
Private database endpoint
 ↓
Database authentication
```

A failure can therefore be caused by DNS, routing, NetworkPolicy, NSG/security group, port, database listener, TLS or credentials. The security model is inseparable from the networking model you learned on Day 15.

5. Private connectivity reduces unnecessary public exposure, but private does not mean trusted. A private database should still require authentication and authorization. Likewise, placing all workloads in a private subnet does not automatically prevent one compromised workload from attacking another.

6. The simplest rule to remember is:

> **Network security answers “Can traffic reach it?” Identity and authorization answer “Is this caller allowed to use it?”**

**Implementation practice:** Build a small Kubernetes lab with:

```text
frontend → backend
debug Pod → backend
```

Apply a NetworkPolicy that permits only the frontend. Test both paths and inspect the policy. Then relate the result to cloud-level controls such as NSGs/security groups.

**Practice:** Take a database connectivity incident and separate the investigation into:

```text
Network problem?
Identity problem?
Authorization problem?
Application problem?
```

---

## Part 9 — Secure CI/CD and Software Supply Chain

1. CI/CD systems are security-sensitive because they can build software and often influence production. A compromised pipeline can potentially modify source, inject malicious dependencies, publish a malicious image or deploy unauthorized infrastructure. Security therefore has to cover the entire chain from source code to production workload.

2. A practical supply-chain flow is:

```text
Source
 ↓
Code Review
 ↓
Build
 ↓
Unit / Integration Tests
 ↓
Dependency Scan
 ↓
SAST / Security Checks
 ↓
Container Build
 ↓
Image Scan
 ↓
Registry
 ↓
Deployment Policy
 ↓
Production
```

The exact tools can differ, but each stage exists to catch a different category of risk.

3. Container image provenance matters. If CI builds `myapp:1.5.0`, you should be able to establish which source commit produced it, which build ran, which dependencies were used, which security checks passed and which exact image content was deployed. Tags are useful human identifiers, but a digest identifies the exact image content.

4. A secure pipeline should avoid long-lived credentials where possible. Federated or short-lived credentials can reduce the risk associated with leaked CI secrets. Production deployment identities should also be narrowly scoped, and pipeline logs should be reviewed to ensure secrets are not accidentally printed.

5. Software supply-chain security also includes dependencies. A Spring Boot application may depend on hundreds of transitive packages. A vulnerability in one dependency can become a production risk even when your application code itself is secure. Dependency scanning, controlled build environments, trusted registries and patch processes therefore belong in the DevOps security model.

6. The Senior question is:

> **Can we prove what we built, where it came from, what checks it passed, and exactly what artifact reached production?**

**Implementation example — image identity:**

```bash
docker build -t myapp:1.0.0 .
docker images myapp
docker inspect myapp:1.0.0
```

After pushing to a registry, record the image digest and understand how your deployment system references the image.

**Practice:** Extend your Day 6/CI pipeline with:

```text
Build
 ↓
Test
 ↓
Dependency scan
 ↓
Docker build
 ↓
Image scan
 ↓
Push
 ↓
Approval / policy
 ↓
Deploy
```

For each stage, write the specific risk it reduces.

---

## Part 10 — Security Troubleshooting

1. Security troubleshooting should preserve the existing security boundary while narrowing the problem. If a request is denied, do not immediately grant administrator permissions. First identify the caller, confirm the identity being used, determine whether authentication succeeded, inspect the applicable authorization policy, verify scope and then check the resource. This approach gives you evidence without weakening the environment unnecessarily.

2. Use this decision tree:

```text
Request fails
    ↓
Can the caller reach the target?
    ├── No
    │    ↓
    │  DNS / Route / Firewall / NetworkPolicy / Port
    │
    └── Yes
         ↓
     Is caller authenticated?
         ├── No
         │    ↓
         │  Identity / Credential / Token
         │
         └── Yes
              ↓
       Is caller authorized?
         ├── No
         │    ↓
         │  Role / Policy / Scope
         │
         └── Yes
              ↓
         Is resource healthy?
              ↓
          Application
```

3. Consider:

```text
Spring Boot Pod
     ↓
Azure Key Vault / AWS Secrets Manager
     ↓
403 Access Denied
```

Investigate:

```text
1. Which Pod is making the request?
2. Which ServiceAccount/workload identity is it using?
3. Was a cloud token obtained?
4. Which cloud identity does that token represent?
5. Which role/policy is assigned?
6. What is the role scope?
7. Does the requested secret/resource exist?
8. Is the resource reachable?
9. Is the application requesting the correct resource?
```

Do not skip directly to “assign Owner” or “Administrator.”

4. Compare that with:

```text
Connection timed out
```

A timeout generally deserves network investigation first:

```text
DNS
 ↓
IP
 ↓
Route
 ↓
Firewall / NSG / Security Group
 ↓
NetworkPolicy
 ↓
Port
 ↓
Service
```

Only after network reachability is established should you move deeper into authentication and authorization.

5. Audit logs provide another critical layer. During an incident, you want evidence about who attempted an action, what resource was targeted, whether the request was allowed or denied and what changed afterward. Security without detection and auditability leaves you with little ability to investigate a compromise.

**Implementation practice:** For Kubernetes authorization, use:

```bash
kubectl auth can-i get secrets \
  --as=system:serviceaccount:default:app-reader

kubectl auth can-i create deployments \
  --as=system:serviceaccount:default:app-reader
```

For cloud IAM, inspect role assignments/policies and their scope before changing them.

**Practice:** Work through three incidents:

```text
A. DNS failure
B. 403 Access Denied
C. Connection timeout
```

For each, explain why the first investigation step should be different.

---

## Part 11 — Senior/Lead Security Architecture Exercise

1. Design the security model for the Spring Boot application you have been using throughout this course. Assume it runs on AKS or EKS, uses a private database, is deployed through CI/CD and needs access to a cloud secret store. Do not begin by selecting products. First identify the identities, trust boundaries, network paths, secrets and required permissions.

2. Your architecture should conceptually look like:

```text
Developer
   ↓
Git
   ↓
CI Identity
   ↓
Container Registry
   ↓
GitOps / Deployment Identity
   ↓
AKS / EKS
   ↓
Kubernetes RBAC
   ↓
Spring Boot Pod
   ↓
Workload Identity
   ↓
Cloud Secret Store
   ↓
Application
   ↓
Private Database
```

Around this path:

```text
Cloud Network Security
Kubernetes NetworkPolicy
Image Security
Secret Management
Audit Logging
Monitoring
Least Privilege
```

3. Now apply failure and compromise scenarios:

```text
CI credential leaks
Application Pod is compromised
Developer account is compromised
Database password leaks
Malicious image reaches registry
Kubernetes ServiceAccount is over-privileged
NetworkPolicy is misconfigured
Cloud role is assigned at subscription/account scope
```

For each scenario, answer:

```text
What can the attacker access?
What is the blast radius?
Which control limits the impact?
How would we detect it?
How would we revoke access?
How would we recover?
```

4. Finally, produce a one-page security architecture for both AKS and EKS. Keep the application architecture identical and map only the cloud-specific identity, secret, network and monitoring components. This exercise is more valuable than memorizing individual security products because it forces you to reason across the complete platform.

**Practice:** Explain your architecture aloud in this order:

```text
Identity
 ↓
Authentication
 ↓
Authorization
 ↓
Network
 ↓
Secrets
 ↓
Workload Security
 ↓
CI/CD Security
 ↓
Monitoring / Audit
 ↓
Incident Response
```

If you cannot explain why a control exists, revisit the concept before adding another product.

---

## Part 12 — 5-Minute Recall

Without looking at the notes, explain these in your own words:

1. What is the difference between identity, authentication and authorization?

2. Why should human, CI/CD and application identities normally be separate?

3. What is the difference between Azure RBAC, AWS IAM and Kubernetes RBAC?

4. What is a service principal?

5. What problem does a managed identity solve?

6. What is workload identity?

7. Why are long-lived cloud credentials inside containers risky?

8. Why is a private Git repository not an appropriate secret store?

9. Why is Base64 encoding not equivalent to encryption?

10. What is the difference between a Kubernetes Secret and an external secret manager?

11. What happens operationally when a secret is rotated?

12. What is least privilege?

13. What is blast radius?

14. Why should a CI identity not automatically be a cloud administrator?

15. What is the difference between NetworkPolicy and cloud network security controls?

16. What is the difference between a network timeout and `403 Forbidden`?

17. How would you troubleshoot a Pod that cannot access Key Vault or Secrets Manager?

18. Why are image digests useful for software supply-chain security?

19. What does a secure CI/CD supply chain attempt to prove about an artifact?

20. If an application Pod is compromised, which identity determines what cloud resources it can access?

21. Why should a Kubernetes ServiceAccount not automatically receive `cluster-admin`?

22. What evidence would you look for during a security incident?

23. What is the difference between preventing an attack and detecting an attack?

24. Why does private networking not eliminate the need for authentication and authorization?

25. Explain the complete security model of your Spring Boot application in five minutes.

**Core mental model:**

> **Identity tells you who. Authentication proves who. Authorization determines what they may do. Network security determines where traffic can flow. Secrets provide sensitive values without unnecessarily exposing them.**

**Security investigation model:**

```text
WHO?
 ↓
AUTHENTICATED?
 ↓
AUTHORIZED?
 ↓
NETWORK REACHABLE?
 ↓
RESOURCE AVAILABLE?
 ↓
APPLICATION HEALTHY?
```

**Senior/Lead question to remember:**

> **Who is accessing what, from where, using which identity, with which permissions, and what is the blast radius if that identity or workload is compromised?**

---

## Part 13 — Cleanup

Remove test Kubernetes resources created during the lab:

```bash
kubectl delete secret db-secret --ignore-not-found
kubectl delete serviceaccount app-reader --ignore-not-found
kubectl delete role pod-reader --ignore-not-found
kubectl delete rolebinding app-reader-binding --ignore-not-found
```

If you created test Deployments or Services:

```bash
kubectl delete deployment <test-deployment> --ignore-not-found
kubectl delete service <test-service> --ignore-not-found
```

For cloud IAM exercises, remove only the test role assignments, test identities and credentials you created for the lab. Verify that no production workload, pipeline or automation depends on them before deletion.

For any test secret-scanning credentials, revoke or delete them even if they were created only for the exercise.

Finally verify:

```bash
kubectl get secrets
kubectl get serviceaccounts
kubectl get roles
kubectl get rolebindings
```

The operational habit remains:

**Create → Authenticate → Authorize → Test → Audit → Break → Diagnose → Revoke/Clean Up → Verify**

**Next: Day 19 — Secure CI/CD & Software Supply Chain**
