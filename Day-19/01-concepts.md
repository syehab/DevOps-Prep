# Day 19 — Secure CI/CD & Software Supply Chain

This Day uses three files. Read them in this order.

1. [01-concepts.md](01-concepts.md) — lesson content (this file)
2. [02-questions-and-answers.md](02-questions-and-answers.md) — practice items, each with a model answer
3. [03-implementation.md](03-implementation.md) — hands-on lab

**Goal:** Understand the software supply chain — the full path that turns source code into running production software — and learn how to secure each step of it: code, dependencies, build, artifacts, registry, deployment, and runtime identity.

## Part 1 — Why CI/CD Security Is Different

A CI/CD pipeline is not just a tool that builds software. It is a trusted path into your environments. It can often create infrastructure, publish images, deploy workloads, and read production secrets — more power than most applications have. So compromising the pipeline can be as serious as compromising production directly, and the pipeline itself is part of the production security boundary. The key question is not only "is the application secure?" but also "can an attacker change what we build or where we deploy it?"

The mental model for the whole lesson is one chain with six stages:

```text
Trust → Build → Verify → Sign/Store → Deploy → Run

Trust      → identities, branch protection, repo and pipeline permissions
Build      → compiler, package manager, Docker build, build agent
Verify     → tests and security scans
Sign/Store → artifact integrity and registry controls
Deploy     → environment permissions and approvals
Run        → runtime identity, secrets, network, monitoring
```

Every part of this lesson secures one of these stages. A weakness anywhere in the chain can undermine the controls after it. If an attacker can change what gets built, it does not matter how carefully you deploy it.

**Remember:** securing the application without securing the delivery path leaves a major attack path open.

---

## Part 2 — Source Code Security and Branch Protection

Source control is the starting point of the supply chain because the pipeline trusts whatever code the repository gives it. A secure workflow protects important branches such as `main`: changes must arrive through a pull request, pass review and automated checks, and merge only with controlled permissions. This reduces the chance that one compromised developer account, leaked token, or malicious commit can directly change production code. Pipeline YAML deserves extra care, because changing it changes what the pipeline is allowed to execute.

For example, a repository may use this flow:

```text
Feature branch
      ↓
Pull Request
      ↓
Code review
      ↓
Build + Test + Security checks
      ↓
Protected main
      ↓
Release pipeline
      ↓
UAT / Production
```

The important idea is that branch protection is not the same thing as application security. It protects the path by which changes are introduced. You still need scanning, testing, identity controls, and deployment controls.

Implementation example — inspect the latest commit and changed files:

```bash
git log -1 --oneline
git show --stat --oneline HEAD
git diff HEAD~1 HEAD
```

Look specifically for changes to:

```text
azure-pipelines.yml
.github/workflows/*
Dockerfile
terraform/*
*.bicep
helm/*
k8s/*
```

A change to application code and a change to pipeline permissions should not automatically receive the same risk treatment.

---

## Part 3 — Secrets in CI/CD

Secrets are one of the most common places where CI/CD security fails, because pipelines need credentials for registries, cloud APIs, databases, and deployment targets. The rule is simple: supply a secret at runtime, to the smallest scope that needs it, for the shortest time possible. Never commit it to Git, bake it into source code or Docker images, or print it into logs. Also keep two concerns separate: a vault protects the secret's value at rest, while the pipeline's identity decides whether the pipeline may retrieve it at all.

A strong pattern is:

```text
Pipeline identity
      ↓
Authenticate without a long-lived password
      ↓
Secret store
      ↓
Retrieve only required secret
      ↓
Use during required step
      ↓
Do not print / persist
```

Examples include Azure Key Vault, AWS Secrets Manager, and equivalent enterprise secret-management systems. Where the platform supports workload identity or federated authentication, prefer short-lived identity-based access over permanent client secrets.

Bad example:

```yaml
variables:
  DB_PASSWORD: "SuperSecret123"
```

Also bad:

```dockerfile
ENV DB_PASSWORD=SuperSecret123
```

And dangerous:

```bash
echo "password=$DB_PASSWORD"
```

A better Azure DevOps pattern is to retrieve secrets from a controlled secret store and expose them only to the step that needs them. The exact implementation depends on the chosen authentication model and task. The security principle stays the same: **the pipeline should prove who it is rather than carry a permanent password around.**

**Important:** Removing a secret from the latest commit does not automatically make the secret safe. If it was committed previously, assume it may exist in Git history and rotate it.

---

## Part 4 — Dependency and Software Composition Security

Modern applications rarely consist only of code written by the development team. A Spring Boot application may pull hundreds of dependencies from Maven Central — both direct ones you chose and transitive ones (the dependencies of your dependencies). Container images add operating-system libraries on top. This means a vulnerability or compromised package can enter your application without anyone on the team writing the vulnerable code.

For a Java application, inspect dependencies with:

```bash
mvn dependency:tree
```

You can also inspect outdated dependencies:

```bash
mvn versions:display-dependency-updates
```

The pipeline should check dependencies before an artifact is promoted. The standard control is Software Composition Analysis (SCA) — a scan that lists your third-party dependencies and reports known vulnerabilities in them. Add license checks where required, and a policy that stops critical known vulnerabilities from reaching production without an approved exception.

The important distinction is between **finding** a vulnerability and **controlling** it. A scanner may report that a library has a CVE (a publicly catalogued known vulnerability). The organization still needs a policy such as “critical vulnerabilities block production” or “high severity requires a documented exception.” Severity alone does not tell the complete operational risk. Whether the vulnerable code path is actually reachable, how exposed the system is, and what compensating controls exist all change the real-world risk.

---

## Part 5 — Container Image Security

A container image is another software artifact and must be treated as part of the supply chain. Building an image successfully does not mean the image is secure. Common problems hide inside a "working" image:

- the base image contains vulnerable OS packages
- the application contains vulnerable dependencies
- the image runs as root
- unnecessary tools are installed
- secrets were copied into image layers

Security therefore needs to happen twice: while you build the image, and again before you deploy it.

Start with the image:

```bash
docker build -t myapp:1.0.0 .
docker history myapp:1.0.0
docker inspect myapp:1.0.0
```

Then scan it with the organization's approved scanner. Common categories of findings include OS-package vulnerabilities, application dependencies, configuration weaknesses, secrets, and risky permissions.

A safer Dockerfile generally uses a small runtime image, a multi-stage build, a non-root user, and only the files needed at runtime:

```dockerfile
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /build

COPY pom.xml .
RUN mvn dependency:go-offline

COPY src ./src
RUN mvn clean package -DskipTests

FROM eclipse-temurin:21-jre
WORKDIR /app

RUN useradd --create-home appuser
COPY --from=build /build/target/myapp.jar app.jar

USER appuser

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```

The exact image choice depends on the organization, but the principle is to minimize the runtime attack surface.

**Remember:** `EXPOSE` documents a container port; it does not publish the port to the outside world.

---

## Part 6 — Artifact Integrity and Image Provenance

A secure pipeline should be able to answer a basic production question: **“Exactly what source code produced this artifact?”** The record of where an artifact came from and how it was built is called its provenance. Immutable artifacts, versioning, checksums, and build metadata all exist to make that record trustworthy. If someone can silently replace an artifact after testing, your security checks no longer describe what actually reached production.

For container images, tags are human-friendly references:

```text
myregistry/myapp:1.4.2
```

while a digest identifies the image content:

```text
myregistry/myapp@sha256:<digest>
```

A tag such as `1.4.2` is useful, but its immutability depends on registry policy. A digest is content-addressed and therefore provides stronger identity for the exact image content.

Inspect the digest:

```bash
docker image inspect myapp:1.0.0
```

After pushing to a registry, retrieve and record the registry digest using the appropriate registry tooling.

A mature release process can connect:

```text
Git commit SHA
      ↓
Build ID
      ↓
Artifact version
      ↓
Container image digest
      ↓
Deployment record
      ↓
Running workload
```

This creates traceability. If production has a problem, you should be able to move backward from the running workload to the exact artifact and source revision that produced it.

---

## Part 7 — Container Registry Security

The registry is not simply a file server for Docker images. It is a trusted distribution point: whatever it serves will run in your environments. That is why access control, encryption, vulnerability scanning, retention, and image immutability matter here. Azure Container Registry (ACR) and Amazon Elastic Container Registry (ECR) integrate with their cloud identity systems, so cloud IAM controls access instead of registry passwords handed out everywhere.

The deployment path should look like:

```text
CI Build
   ↓
Security Scan
   ↓
Push to Trusted Registry
   ↓
Controlled Pull
   ↓
Kubernetes / Compute
```

A common mistake is giving every pipeline broad registry permissions. A build pipeline may need permission to push images, while a runtime identity may need only permission to pull images. These are different trust relationships and should normally use different identities or roles.

Azure mapping:

```text
Azure DevOps
     ↓
ACR
     ↓
AKS
```

AWS mapping:

```text
CI system
     ↓
ECR
     ↓
EKS
```

---

## Part 8 — Pipeline Identity and Federated Authentication

A pipeline needs an identity when it talks to Azure, AWS, a registry, Key Vault, a Terraform backend, or any other protected service. The dangerous pattern is a permanent credential stored in a pipeline variable and reused everywhere. A stronger architecture uses federated authentication where supported: the pipeline proves who it is to the cloud provider and receives a short-lived token in return. You then never have to store a long-lived password.

Conceptually:

```text
CI workload
    ↓
Federated identity proof
    ↓
Cloud identity provider
    ↓
Temporary credentials/token
    ↓
Target resource
```

For Azure, this can involve Microsoft Entra workload/federated identity mechanisms. For AWS, GitHub Actions and other supported CI systems can use OIDC federation with IAM roles. Azure DevOps can also use supported service connections and workload identity approaches depending on the setup.

The important interview concept is not memorizing one platform's configuration. It is understanding why federation is valuable: **reduce long-lived credentials, narrow trust, make access auditable, and allow credentials to expire automatically.**

---

## Part 9 — Security Gates in the Pipeline

Integrate security into the delivery flow; do not treat it as a final manual activity after deployment. A practical pipeline might look like:

```text
Commit
  ↓
Build
  ↓
Unit Tests
  ↓
SAST
  ↓
Dependency Scan
  ↓
Build Image
  ↓
Image Scan
  ↓
Publish Artifact
  ↓
Deploy Non-Prod
  ↓
Integration / Security Tests
  ↓
Approval / Policy
  ↓
Production
```

Each control answers a different question:

| Control | What it examines |
|:--|:--|
| SAST (static analysis) | Your source or compiled code, for coding weaknesses |
| SCA | Your third-party dependencies, for known vulnerabilities |
| Image scanning | Container contents: OS packages, app dependencies, config |
| Secrets scanning | Code, config, and history, for exposed credentials |
| DAST (dynamic analysis) | The running application, tested from the outside |
| IaC scanning | Terraform, Bicep, and Kubernetes manifests, before deployment |

Do not blindly add every possible scanner. Each control has cost, execution time, false positives, and maintenance overhead. A senior engineer designs gates around risk and defines what blocks a release, what produces a warning, and what requires an exception.

Implementation example — conceptual Azure DevOps stages:

```yaml
stages:
- stage: Build
  jobs:
  - job: Build
    steps:
    - script: mvn clean package

- stage: Security
  dependsOn: Build
  jobs:
  - job: Scan
    steps:
    - script: echo "Run SAST"
    - script: echo "Run dependency scan"
    - script: echo "Run secret scan"

- stage: Image
  dependsOn: Security
  jobs:
  - job: BuildImage
    steps:
    - script: docker build -t myapp:$(Build.BuildId) .

- stage: Deploy
  dependsOn: Image
  jobs:
  - deployment: DeployApp
    environment: UAT
```

The scan commands here are placeholders; use the organization's approved security tools and policies.

---

## Part 10 — Infrastructure-as-Code and Kubernetes Security in the Supply Chain

Infrastructure configuration is software too. A malicious or accidental change to Terraform, Bicep, Helm, or Kubernetes YAML can expose a network, grant excessive permissions, create a public resource, or weaken a production security boundary. This means infrastructure code should pass through the same controlled source, review, testing, and deployment process as application code.

A secure IaC flow can be:

```text
Terraform / Bicep change
        ↓
Format / Validate
        ↓
Security / Policy Scan
        ↓
Plan / What-if
        ↓
Review
        ↓
Approved Apply
```

For Terraform:

```bash
terraform fmt -check
terraform validate
terraform plan
```

For Kubernetes manifests, render and inspect Helm output before deployment:

```bash
helm template myapp ./chart
```

Then use approved policy/security tooling to check for issues such as privileged containers, host networking, public exposure, excessive permissions, missing resource limits, or insecure configurations.

The senior-level distinction is that **validation checks whether configuration is structurally valid; security policy checks whether the configuration is acceptable; runtime controls check whether the deployed workload remains safe.** You need all three.

---

## Part 11 — Supply Chain Attack Scenario

Imagine an attacker compromises a developer account and changes a dependency in `pom.xml`. The application still compiles and unit tests pass. The pipeline downloads the dependency during the build, includes it in the application, packages it into a container, pushes it to the registry, and deploys it to production. If the pipeline has no dependency verification or security gate, every later stage may treat the malicious artifact as trusted.

Now reason through the controls:

```text
Developer account
      ↓
Repository protection
      ↓
Dependency change review
      ↓
Dependency/SCA scan
      ↓
Build isolation
      ↓
Artifact/image scan
      ↓
Registry controls
      ↓
Deployment authorization
      ↓
Runtime monitoring
```

No single control guarantees safety. Defense in depth means that failure of one control does not automatically mean compromise of the production environment.

This is the kind of reasoning expected at Senior/Lead level: do not focus only on the scanner; reason about the entire attack path and blast radius.

---

## Part 12 — Secure Build Agents and Pipeline Isolation

The build agent is the machine that actually runs your builds, so it executes source code, installs dependencies, runs scripts, builds Docker images, and issues deployment commands. That makes it part of the trust boundary. If a malicious build can read credentials or files left behind by another job, one compromised repository may affect every workload that shares the agent. Hosted agents give you fresh, isolated machines per run; self-hosted agents put patching, hardening, cleanup, and job isolation on your shoulders.

A common operational mistake is to install powerful credentials permanently on a self-hosted agent. If that machine is compromised, the attacker may inherit every permission available to the agent.

For self-hosted agents, think about:

```text
OS patching
Agent patching
Network restrictions
Least-privilege identity
Ephemeral/clean workspaces
Credential isolation
Docker/socket exposure
Log protection
Monitoring
```

Senior interview point: **a pipeline is code execution infrastructure**, so treat the build worker as a security-sensitive system.

---

## Part 13 — Security Troubleshooting

When a secure pipeline fails, do not immediately disable the security control. First determine which trust boundary is failing. A useful troubleshooting sequence is:

```text
Source
  ↓
Identity
  ↓
Permissions
  ↓
Dependency
  ↓
Build
  ↓
Scan
  ↓
Artifact
  ↓
Registry
  ↓
Deployment
  ↓
Runtime
```

If an Azure DevOps pipeline suddenly cannot push to ACR, ask:

```text
Is the service connection authenticated?
        ↓
Does its identity still exist?
        ↓
Does it have push permission?
        ↓
Is the registry reachable?
        ↓
Did the registry policy change?
        ↓
Is the image name/tag valid?
```

If a Kubernetes deployment fails after an image security policy was introduced:

```text
Did the image build?
        ↓
Was it pushed?
        ↓
What is the image digest?
        ↓
Did the scanner find a blocking issue?
        ↓
Did admission policy reject it?
        ↓
Is the workload using the expected image?
```

Useful commands:

```bash
kubectl describe pod <pod>
kubectl get pod <pod> -o jsonpath='{.spec.containers[*].image}'
kubectl get events --sort-by=.lastTimestamp
```

For Azure DevOps, inspect the pipeline run, stage/job logs, service connection authorization, variable/secret references, and environment approvals. For AWS, inspect IAM role permissions, CloudTrail events, and ECR/EKS-related events as appropriate.

**Remember:** Never solve a security failure by broadly granting permissions until the pipeline works. Identify the exact missing permission and grant only that permission.

---

## Part 14 — Core mental model

**Final mental model:**

> **Secure CI/CD is not “add a security scan.” It is securing the entire path that turns source code into production software.**

---

## Part 15 — Cleanup

Remove the lab resources you created:

```bash
docker rm -f myapp 2>/dev/null || true
docker image rm myapp:1.0.0 2>/dev/null || true
```

Remove temporary Kubernetes resources:

```bash
kubectl delete deployment myapp --ignore-not-found
kubectl delete service myapp --ignore-not-found
kubectl delete secret db-secret --ignore-not-found
```

Remove temporary cloud resources according to the provider's normal cleanup process.

For production-like labs, verify that you have not left behind:

- Container registries/images
- Cloud resources
- Service connections
- IAM/RBAC assignments
- Secrets
- Storage
- Build agents
- Pipeline environments
- Test users or identities

**Do not delete shared or production resources just because they were used during the exercise. Identify ownership first.**

---

## Next

**Day 20 — Observability + Production Incident**

You will connect everything learned so far to the operational side of DevOps: metrics, logs, traces, alerting, dashboards, incident response, troubleshooting, and Root Cause Analysis (RCA).
