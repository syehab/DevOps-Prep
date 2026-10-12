# Day 18 — Questions and answers

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Then answer each item below before you open the Answer block. After that, do the lab in [03-implementation.md](03-implementation.md).

Write your own answer first. Open the Answer block only after you try. Keep the original numbering.

---

## 1. Trace every identity from source code to production

**Practice:** Take one real deployment flow and trace every identity from source code to production. If two unrelated components are using the same credential, ask whether they genuinely need the same permissions.

<details>
<summary>Answer</summary>

Walk Developer → Git → CI identity → container registry → GitOps or deploy identity → Kubernetes → application workload identity → cloud service or database. Give each actor its own identity. The developer must not give personal credentials to the application. CI must not use the developer. The application must not use the CI identity.

Add a “must NOT access” column. If two unrelated components share one credential, they share blast radius. Split them unless they truly need the same permissions.

</details>

---

## 2. Ask Kubernetes whether the identity can do ungranted actions

**Practice:** Deliberately ask Kubernetes whether the identity can perform actions it was not granted. Explain why “authentication succeeded” does not imply “authorization succeeded.”

<details>
<summary>Answer</summary>

Apply the read-only ServiceAccount, Role, and RoleBinding. Run `kubectl auth can-i get pods --as=system:serviceaccount:default:app-reader`. Expect `yes`. Run `kubectl auth can-i delete pods --as=system:serviceaccount:default:app-reader`. Expect `no`.

Authentication succeeded: Kubernetes knows the ServiceAccount. Authorization failed for delete because the Role only allows get, list, and watch. A valid identity is not permission.

</details>

---

## 3. Smallest practical scope for a deployment identity, then blast radius

**Practice:** Take a deployment identity and design its permissions at the smallest practical scope. Then ask: **If this identity is compromised, what is the maximum damage it can cause?**

<details>
<summary>Answer</summary>

Assign the deploy identity only the actions it needs, at resource-group or namespace scope, not subscription Owner. On Azure, check real scope with `az role assignment list --assignee <IDENTITY-ID> --all`. On AWS, attach a narrow IAM policy and prove an unrelated action is denied.

If this identity is compromised, maximum damage is that scope: it can change those deploy targets, not the whole account. Broad Contributor at subscription scope makes every resource in the subscription the blast radius.

</details>

---

## 4. Compare client secret, managed/workload identity, and developer credentials

**Practice:** Compare:

```text
A. Client ID + client secret
B. Managed/workload identity
C. Developer credentials
```

For each, identify credential lifetime, rotation effort, blast radius and failure mode.

<details>
<summary>Answer</summary>

A. Client ID plus client secret: long-lived secret, you rotate it, it leaks through Git and logs, blast radius is whatever the app registration can do. Failure mode is leaked or expired secret.

B. Managed or workload identity: short-lived token, platform rotates it, no password in the container, blast radius is the assigned role. Failure mode is a broken federation or missing role.

C. Developer credentials in the app: lifetime follows the person, terrible rotation, blast radius is the developer’s permissions. The app breaks when the person leaves. Never use this.

</details>

---

## 5. Draw every system a database password would touch, then shrink the path

**Practice:** Take one database password and draw every system it would touch under your current architecture. Redesign the flow to minimize those locations.

<details>
<summary>Answer</summary>

Unsafe path: developer creates password → `.env` → Git → CI variable → Docker build → Helm values → Kubernetes → application. Git history keeps the secret even after you delete the file. Image layers can keep it too.

Safer path: Secret Manager → workload identity → authorized retrieval → application runtime. Azure uses Key Vault. AWS uses Secrets Manager. The chart stores a reference, not the password. Ask where the secret can exist across its whole lifecycle.

</details>

---

## 6. Production secret-rotation flow and who owns each step

**Practice:** Design a production secret-rotation flow and explicitly identify who owns creation, storage, authorization, rotation and application reload.

<details>
<summary>Answer</summary>

Create and store the secret in Key Vault or Secrets Manager (platform or security team). Authorize the workload identity to read only that secret (IAM or Azure RBAC). Rotate on a schedule or after a leak (secret owner). Reload or restart the application so it consumes the new value (application team).

Updating the Kubernetes Secret is not enough if the process read the password at startup. Prove that with `kubectl apply` of a new Secret and a running Pod. Rotation and consumption are different jobs.

</details>

---

## 7. Permission matrix, then challenge each grant

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

<details>
<summary>Answer</summary>

Developer: Dev resources only, not Prod admin. CI: build, push, and limited deploy, not account admin. GitOps: managed Kubernetes resources, not unrestricted cloud admin. Application: required cloud API only, not subscription admin. Monitoring: read telemetry, not write workloads.

Challenge every `yes`. Prove with `kubectl auth can-i` for the ServiceAccount. Least privilege is action plus scope. “Read” on every production database is still too broad.

</details>

---

## 8. NetworkPolicy lab: frontend allowed, debug Pod denied

**Implementation practice:** Build a small Kubernetes lab with:

```text
frontend → backend
debug Pod → backend
```

Apply a NetworkPolicy that permits only the frontend. Test both paths and inspect the policy. Then relate the result to cloud-level controls such as NSGs/security groups.

<details>
<summary>Answer</summary>

Allow `frontend → backend` and deny `debug Pod → backend` with a NetworkPolicy on the backend Pods. Test both paths. Inspect the policy. Then relate the result to NSGs or Security Groups at the cloud edge.

Identity answers who may use the database. Network answers whether packets can reach it. You often need both. Private is not trusted.

</details>

---

## 9. Database connectivity: network, identity, authorization, or application

**Practice:** Take a database connectivity incident and separate the investigation into:

```text
Network problem?
Identity problem?
Authorization problem?
Application problem?
```

<details>
<summary>Answer</summary>

Network: DNS, route, NSG or Security Group, NetworkPolicy, port. Symptom is often timeout. Identity: which workload identity or database user is presented. Authorization: 403 or AccessDenied, or database permission denied. Application: wrong hostname, wrong secret key, or a bug.

Do not treat every failure as IAM. A timeout is usually reachability first. A 403 is usually authorization after authentication succeeded.

</details>

---

## 10. Extend the CI pipeline and name the risk each stage reduces

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

<details>
<summary>Answer</summary>

Build reduces “we shipped uncompiled code.” Test reduces functional defects. Dependency scan reduces known library CVEs. Docker build produces the runnable artifact. Image scan reduces vulnerable OS packages and secrets in layers. Push stores a known artifact in a trusted registry. Approval or policy reduces unauthorized production deploys.

Record the image digest after push. Tags are human names. A digest identifies exact content. The Senior question is: can we prove what we built, where it came from, what checks it passed, and what reached production.

</details>

---

## 11. Three incidents: DNS failure, 403, connection timeout

**Practice:** Work through three incidents:

```text
A. DNS failure
B. 403 Access Denied
C. Connection timeout
```

For each, explain why the first investigation step should be different.

<details>
<summary>Answer</summary>

A. DNS failure: first prove name resolution. Do not grant IAM roles. The caller never found an IP.

B. 403 Access Denied: authentication likely succeeded. Inspect role, policy, and scope. Do not assign Owner. Ask which identity, which role, which secret.

C. Connection timeout: first walk DNS → IP → route → firewall → NetworkPolicy → port → Service. Only then inspect tokens. Reachability failed before permission mattered.

</details>

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

---

## 12. Architecture walk: Identity through Incident Response

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

<details>
<summary>Answer</summary>

Identity: separate human, CI, GitOps, and workload identities. Authentication: Entra ID or IAM, plus workload federation. Authorization: Azure RBAC or IAM plus Kubernetes RBAC at narrow scope. Network: VNet or VPC, private database, NetworkPolicy. Secrets: Key Vault or Secrets Manager, not Git.

Workload security: non-root image, least-privilege ServiceAccount. CI/CD: scans, digest, approval. Monitoring and audit: who did what. Incident response: revoke the identity, rotate secrets, redeploy a known digest. If you cannot explain why a control exists, do not add another product.

</details>

---

## 13. Compromise — CI credential leaks

**Senior/Lead exercise**

Compromise scenario: CI credential leaks

For each scenario, answer:

```text
What can the attacker access?
What is the blast radius?
Which control limits the impact?
How would we detect it?
How would we revoke access?
How would we recover?
```

<details>
<summary>Answer</summary>

Attacker can build, push, and maybe deploy, up to the CI role scope. Blast radius is every environment that identity can touch. Limit with separate build versus deploy identities and no account admin. Detect with CI logs and cloud audit. Revoke the credential or federation. Recover by rotating secrets and reviewing recent images and deploys.

</details>

---

## 14. Compromise — application Pod is compromised

**Senior/Lead exercise**

Compromise scenario: Application Pod is compromised

For each scenario, answer:

```text
What can the attacker access?
What is the blast radius?
Which control limits the impact?
How would we detect it?
How would we revoke access?
How would we recover?
```

<details>
<summary>Answer</summary>

The attacker inherits the Pod’s ServiceAccount and workload identity. Blast radius is that cloud role plus in-cluster RBAC, plus whatever NetworkPolicy allows. Limit with least privilege, NetworkPolicy, and no cluster-admin on the app. Detect with runtime logs and unusual API calls. Revoke the cloud role mapping. Recover by rotating secrets the Pod could read and replacing Pods.

</details>

---

## 15. Compromise — developer account is compromised

**Senior/Lead exercise**

Compromise scenario: Developer account is compromised

For each scenario, answer:

```text
What can the attacker access?
What is the blast radius?
Which control limits the impact?
How would we detect it?
How would we revoke access?
How would we recover?
```

<details>
<summary>Answer</summary>

The attacker can change source and open pull requests, possibly merge if branch protection is weak. Blast radius is code and pipeline YAML, not automatically production, if deploy is separate. Limit with PR review and protected `main`. Detect with Git audit. Revoke the account. Recover by reviewing recent commits and rotating any secrets that person could see.

</details>

---

## 16. Compromise — database password leaks

**Senior/Lead exercise**

Compromise scenario: Database password leaks

For each scenario, answer:

```text
What can the attacker access?
What is the blast radius?
Which control limits the impact?
How would we detect it?
How would we revoke access?
How would we recover?
```

<details>
<summary>Answer</summary>

Anyone with network reach can try the password. Blast radius is the database data. Limit with private networking plus a unique app user. Detect with database auth logs. Revoke by rotating the password in the secret manager and reloading the app. Recover by checking audit for data access.

</details>

---

## 17. Compromise — malicious image reaches the registry

**Senior/Lead exercise**

Compromise scenario: Malicious image reaches registry

For each scenario, answer:

```text
What can the attacker access?
What is the blast radius?
Which control limits the impact?
How would we detect it?
How would we revoke access?
How would we recover?
```

<details>
<summary>Answer</summary>

The image can run if a deploy identity can pull and apply it. Blast radius is every cluster that trusts that registry path. Limit with image scan, digest pinning, and deploy approval. Detect with registry and pipeline logs. Revoke by deleting or untagging the image and blocking the digest. Recover by redeploying a known-good digest and rotating runtime credentials.

</details>

---

## 18. Compromise — over-privileged ServiceAccount

**Senior/Lead exercise**

Compromise scenario: Kubernetes ServiceAccount is over-privileged

For each scenario, answer:

```text
What can the attacker access?
What is the blast radius?
Which control limits the impact?
How would we detect it?
How would we revoke access?
How would we recover?
```

<details>
<summary>Answer</summary>

A compromised Pod can modify many Kubernetes objects, maybe the whole cluster if it has `cluster-admin`. Limit with a Role that matches the job. Detect with API audit. Revoke by deleting bindings and rotating the ServiceAccount. Recover by inspecting cluster changes that identity made.

</details>

---

## 19. Compromise — NetworkPolicy misconfigured

**Senior/Lead exercise**

Compromise scenario: NetworkPolicy is misconfigured

For each scenario, answer:

```text
What can the attacker access?
What is the blast radius?
Which control limits the impact?
How would we detect it?
How would we revoke access?
How would we recover?
```

<details>
<summary>Answer</summary>

Traffic that should be denied is allowed, or required traffic is blocked. Blast radius is extra east-west paths, including to the database. Limit by testing from the real source Pod. Detect with connection metrics and policy tests. Recover by restoring the intended policy. Cloud NSGs do not replace this in-cluster control.

</details>

---

## 20. Compromise — cloud role at subscription or account scope

**Senior/Lead exercise**

Compromise scenario: Cloud role is assigned at subscription/account scope

For each scenario, answer:

```text
What can the attacker access?
What is the blast radius?
Which control limits the impact?
How would we detect it?
How would we revoke access?
How would we recover?
```

<details>
<summary>Answer</summary>

A leak of that identity can change unrelated resources across the subscription or account. Limit by assigning at resource-group or resource scope. Detect with Azure activity logs or CloudTrail. Revoke the assignment. Recover by reviewing changes in that scope. Scope is part of least privilege, not only the role name.

</details>

---

**5-Minute Interview Recall**

Without looking at the notes, explain these in your own words:

---

## 21. Recall — Identity versus authentication versus authorization

**5-Minute Recall**

1. What is the difference between identity, authentication and authorization?

<details>
<summary>Answer</summary>

Identity is who or what is requesting access. Authentication proves that identity. Authorization decides what that identity may do to a resource.

A valid token is not permission. “Authentication means permission” is the interview mistake.

</details>

---

## 22. Recall — Why human, CI/CD, and application identities stay separate

**5-Minute Recall**

2. Why should human, CI/CD and application identities normally be separate?

<details>
<summary>Answer</summary>

They have different jobs and different required permissions. Sharing one credential makes audit useless and enlarges blast radius.

The developer must not become the app. CI must not become the database user. Split them.

</details>

---

## 23. Recall — Azure RBAC versus AWS IAM versus Kubernetes RBAC

**5-Minute Recall**

3. What is the difference between Azure RBAC, AWS IAM and Kubernetes RBAC?

<details>
<summary>Answer</summary>

Azure RBAC assigns a principal a role at a scope on Azure resources. AWS IAM uses policies on roles and resources. Kubernetes RBAC authorizes verbs on Kubernetes objects.

They answer the same design question on different planes. Cloud admin is not cluster-admin.

</details>

---

## 24. Recall — What is a service principal?

**5-Minute Recall**

4. What is a service principal?

<details>
<summary>Answer</summary>

A service principal is an Azure application identity. It authenticates with a client secret or certificate. Automation and apps use it instead of a human.

You must create, store, rotate, and revoke that secret. Prefer managed or workload identity when the platform supports it.

</details>

---

## 25. Recall — What problem does a managed identity solve?

**5-Minute Recall**

5. What problem does a managed identity solve?

<details>
<summary>Answer</summary>

It associates Azure-managed credentials with a supported resource. You do not embed and rotate an application password for that identity.

The platform issues short-lived tokens. That reduces Git, CI, and image leaks of client secrets.

</details>

---

## 26. Recall — What is workload identity?

**5-Minute Recall**

6. What is workload identity?

<details>
<summary>Answer</summary>

Workload identity extends managed identity to Kubernetes workloads. A ServiceAccount maps to a cloud identity. The Pod obtains a token to call Azure or AWS APIs.

Azure: Workload Identity. AWS: IRSA or EKS Pod Identity. No access keys live in the Pod.

</details>

---

## 27. Recall — Why long-lived cloud credentials inside containers are risky

**5-Minute Recall**

7. Why are long-lived cloud credentials inside containers risky?

<details>
<summary>Answer</summary>

They live as long as you forget to rotate them. They leak through images, logs, and `kubectl` Secret reads. Compromise lasts until you revoke them.

Short-lived tokens expire on their own. Prefer federation.

</details>

---

## 28. Recall — Why a private Git repository is not a secret store

**5-Minute Recall**

8. Why is a private Git repository not an appropriate secret store?

<details>
<summary>Answer</summary>

Anyone with repo access sees the secret. Clones and CI logs copy it. Deleting it from HEAD does not remove Git history.

Use a secret manager. Rotate anything that ever entered Git.

</details>

---

## 29. Recall — Why Base64 is not encryption

**5-Minute Recall**

9. Why is Base64 encoding not equivalent to encryption?

<details>
<summary>Answer</summary>

Kubernetes often shows Secret data encoded. Encoding is reversible without a key. Anyone who can `get` the Secret can decode it.

Encryption at rest and RBAC are separate controls. Do not treat encoded as secure.

</details>

---

## 30. Recall — Kubernetes Secret versus external secret manager

**5-Minute Recall**

10. What is the difference between a Kubernetes Secret and an external secret manager?

<details>
<summary>Answer</summary>

A Kubernetes Secret is a cluster object the Pod mounts or injects. Identities with permission can read it. An external manager such as Key Vault or Secrets Manager is the authoritative store.

Integrations copy or mount values at runtime. The chart should reference the secret, not own the password in Git.

</details>

---

## 31. Recall — What happens operationally when a secret is rotated

**5-Minute Recall**

11. What happens operationally when a secret is rotated?

<details>
<summary>Answer</summary>

The store holds a new value. Running processes may still hold the old value until reload or restart. You must plan consumption, not only storage.

Prove it in the lab: update `db-secret` and see whether the app sees `new-test-password` without a restart.

</details>

---

## 32. Recall — What is least privilege?

**5-Minute Recall**

12. What is least privilege?

<details>
<summary>Answer</summary>

Give an identity only the permissions required for its task, at the smallest practical scope. Apply it to humans, CI, GitOps, ServiceAccounts, and cloud workloads.

It is an architecture discipline, not one IAM checkbox.

</details>

---

## 33. Recall — What is blast radius?

**5-Minute Recall**

13. What is blast radius?

<details>
<summary>Answer</summary>

Blast radius is what an attacker can change if this credential, Pod, pipeline, or ServiceAccount is compromised. Ask that question for every identity.

Least privilege exists to shrink that radius.

</details>

---

## 34. Recall — Why a CI identity must not automatically be cloud administrator

**5-Minute Recall**

14. Why should a CI identity not automatically be a cloud administrator?

<details>
<summary>Answer</summary>

CI can build and often deploy. Administrator on the account lets a leaked pipeline credential change unrelated resources. Give a deployment role at required scope only.

Compromising CI then does not grant the whole cloud.

</details>

---

## 35. Recall — NetworkPolicy versus cloud network controls

**5-Minute Recall**

15. What is the difference between NetworkPolicy and cloud network security controls?

<details>
<summary>Answer</summary>

NSGs and Security Groups sit at VNet or VPC and subnet or NIC boundaries. NetworkPolicy sits around Pod traffic using Kubernetes identity.

They are not copies of each other. Production often needs both. Kubernetes defines the API. The CNI must enforce it.

</details>

---

## 36. Recall — Network timeout versus `403 Forbidden`

**5-Minute Recall**

16. What is the difference between a network timeout and `403 Forbidden`?

<details>
<summary>Answer</summary>

A timeout usually means the packet did not complete: DNS, route, firewall, NetworkPolicy, or port. `403` usually means the caller authenticated and was denied by policy.

Treating both as “IAM problems” leads to dangerous permission escalation.

</details>

---

## 37. Recall — Troubleshoot a Pod that cannot access Key Vault or Secrets Manager

**5-Minute Recall**

17. How would you troubleshoot a Pod that cannot access Key Vault or Secrets Manager?

<details>
<summary>Answer</summary>

Identify the Pod and ServiceAccount. Check whether a cloud token was obtained. Map that token to a cloud identity. Inspect role, scope, secret existence, network reachability, and the requested resource name.

Do not assign Owner. Follow who → authenticated → authorized → reachable → healthy.

</details>

---

## 38. Recall — Why image digests help supply-chain security

**5-Minute Recall**

18. Why are image digests useful for software supply-chain security?

<details>
<summary>Answer</summary>

A digest identifies exact image content. A tag can move. Deploy by digest so you know what ran.

Provenance then ties Git commit → build → digest → deployment.

</details>

---

## 39. Recall — What a secure CI/CD supply chain tries to prove

**5-Minute Recall**

19. What does a secure CI/CD supply chain attempt to prove about an artifact?

<details>
<summary>Answer</summary>

What we built, where it came from, which checks it passed, and exactly which artifact reached production.

Without that, a scanner result does not describe what actually runs.

</details>

---

## 40. Recall — If a Pod is compromised, which identity sets cloud access?

**5-Minute Recall**

20. If an application Pod is compromised, which identity determines what cloud resources it can access?

<details>
<summary>Answer</summary>

The workload identity mapped to that Pod’s ServiceAccount. Not the developer. Not the CI role, unless you wrongly reused it.

That is why the runtime role must be narrow.

</details>

---

## 41. Recall — Why a ServiceAccount should not automatically get `cluster-admin`

**5-Minute Recall**

21. Why should a Kubernetes ServiceAccount not automatically receive `cluster-admin`?

<details>
<summary>Answer</summary>

`cluster-admin` can change every Kubernetes object. A compromised Pod then owns the cluster. Bind a Role that matches the job, such as read Pods.

Prove with `kubectl auth can-i`. Explain every `yes`.

</details>

---

## 42. Recall — Evidence during a security incident

**5-Minute Recall**

22. What evidence would you look for during a security incident?

<details>
<summary>Answer</summary>

Look for who attempted the action, which resource, pass or fail, and what changed afterward. Use Kubernetes audit, Azure activity logs or CloudTrail, pipeline logs, and application logs.

Security without detection leaves you unable to investigate.

</details>

---

## 43. Recall — Preventing an attack versus detecting an attack

**5-Minute Recall**

23. What is the difference between preventing an attack and detecting an attack?

<details>
<summary>Answer</summary>

Prevention blocks or shrinks access: least privilege, NetworkPolicy, private endpoints, scans. Detection records and alerts on abuse: audit logs, unusual API calls, failed logins.

You need both. Private networking does not replace logs.

</details>

---

## 44. Recall — Why private networking does not remove authentication

**5-Minute Recall**

24. Why does private networking not eliminate the need for authentication and authorization?

<details>
<summary>Answer</summary>

Private answers “can traffic reach it from the public internet?” A compromised Pod on the same network can still connect. The database must still authenticate and authorize the caller.

Private is not trusted.

</details>

---

## 45. Recall — Five-minute Spring Boot security model

**5-Minute Recall**

25. Explain the complete security model of your Spring Boot application in five minutes.

<details>
<summary>Answer</summary>

Humans, CI, GitOps, and the Pod use separate identities. Entra ID or IAM authenticates. Azure RBAC or IAM plus Kubernetes RBAC authorize at narrow scope. The Pod uses Workload Identity or IRSA or EKS Pod Identity to read one secret from Key Vault or Secrets Manager.

The database is private and still requires credentials. NetworkPolicy limits Pod traffic. The pipeline scans, pins a digest, and needs approval to deploy. Audit logs support response. Ask always: who is accessing what, from where, with which identity, and what is the blast radius.

</details>
