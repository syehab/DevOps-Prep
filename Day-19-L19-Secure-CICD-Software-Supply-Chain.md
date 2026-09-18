# Day 19 — Secure CI/CD & Software Supply Chain

## Part 1 — Why CI/CD Security Is Different

A CI/CD pipeline is not just a tool that builds software; it is a trusted path into your environments, so compromising the pipeline can be as serious as compromising production directly. A normal application may have access to a database or API, while a deployment pipeline may have permission to create infrastructure, publish images, deploy workloads, and access production secrets. That makes the pipeline itself part of the production security boundary. Senior DevOps engineers therefore secure the entire chain: source code → dependency resolution → build → tests → security checks → artifact/image → registry → deployment → runtime identity. The key question is not only “is the application secure?” but also “can an attacker change what we build or where we deploy it?”

A useful mental model is **Trust → Build → Verify → Sign/Store → Deploy → Run**. Trust covers identities, branch protections, repository permissions, and pipeline authorization; Build covers the compiler, package manager, Docker build, and build agent; Verify covers tests and security scans; Sign/Store covers artifact integrity and registry controls; Deploy covers environment permissions and approvals; Run covers runtime identity, secrets, network controls, and monitoring. A weakness anywhere in this chain can undermine the controls after it.

**Remember:** securing the application without securing the delivery path leaves a major attack path open.

Practice: Take a Spring Boot application deployed to AKS. List everything the pipeline can access and ask which permissions are actually required at each stage. Separate permissions needed to build from permissions needed to deploy.

---

## Part 2 — Source Code Security and Branch Protection

Source control is the starting point of the software supply chain because the pipeline normally trusts code from a repository. A secure workflow protects important branches such as `main` and requires pull requests, review, successful checks, and controlled merge permissions before production-bound code can enter the branch. This reduces the chance that one compromised developer account, leaked token, or malicious commit can directly change production code or pipeline definitions. Pipeline YAML is especially sensitive because changing it can change what the pipeline is allowed to execute.

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

Senior scenario: A developer opens a pull request that changes only `azure-pipelines.yml`. The application code is unchanged. Treat the pipeline change as an infrastructure/security change because the YAML can alter commands, credentials usage, artifact handling, and deployment behavior.

---

## Part 3 — Secrets in CI/CD

Secrets are one of the most common places where CI/CD security fails because pipelines frequently need credentials for registries, cloud APIs, databases, signing systems, and deployment targets. The secure principle is that a secret should be supplied at runtime to the smallest possible scope rather than committed to Git, embedded in source code, written into Docker images, or printed into logs. Secret storage and secret usage are separate concerns: a vault protects the value at rest, while the pipeline identity determines whether the pipeline is allowed to retrieve it.

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

A better Azure DevOps pattern is to retrieve secrets from a controlled secret store and expose them only to the step that needs them. The exact implementation depends on the chosen authentication model and task, but the security principle stays the same: **the pipeline should prove who it is rather than carrying a permanent password around.**

Practice: Search a repository for obvious secret patterns:

```bash
git grep -n -i "password"
git grep -n -i "client_secret"
git grep -n -i "access_key"
git grep -n -i "private_key"
```

Then inspect pipeline logs and ask: “Could this value appear in logs, artifacts, Docker layers, Terraform state, or temporary files?”

**Important:** Removing a secret from the latest commit does not automatically make the secret safe. If it was committed previously, assume it may exist in Git history and rotate it.

---

## Part 4 — Dependency and Software Composition Security

Modern applications rarely consist only of code written by the development team. A Spring Boot application may pull hundreds of direct and transitive dependencies from Maven Central, npm packages may pull additional packages, and container images may contain operating-system libraries. This creates a software supply chain in which a vulnerability or compromised package can enter the application without anyone intentionally writing the vulnerable code.

For a Java application, inspect dependencies with:

```bash
mvn dependency:tree
```

You can also inspect outdated dependencies:

```bash
mvn versions:display-dependency-updates
```

The pipeline should ideally perform dependency analysis before an artifact is promoted. Typical controls include Software Composition Analysis (SCA), dependency vulnerability scanning, license checks where required, and policies that prevent critical known vulnerabilities from reaching production without an approved exception.

The important distinction is between **finding** a vulnerability and **controlling** it. A scanner may report that a library has a CVE, but the organization still needs a policy such as “critical vulnerabilities block production” or “high severity requires documented exception.” Severity alone also does not tell the complete operational risk; exploitability, exposure, compensating controls, and whether the vulnerable code path is actually reachable may matter.

Practice: Add a dependency scan to your pipeline after compilation/tests and before publishing the release artifact. Record what happened when the scanner found a vulnerability: Did the pipeline fail? Did it warn? Who could approve an exception?

Senior interview question: “If your dependency scanner reports a critical CVE, do you always stop production?” A strong answer explains that the organization should have a defined risk policy, with blocking thresholds and an auditable exception process rather than an ad-hoc decision inside each pipeline.

---

## Part 5 — Container Image Security

A container image is another software artifact and must be treated as part of the supply chain. Building an image successfully does not mean the image is secure: the base image may contain vulnerable packages, the application may contain vulnerable dependencies, the image may run as root, unnecessary tools may be installed, or secrets may have been copied into image layers. Security therefore needs to happen both during image construction and before deployment.

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

Practice: Deliberately add an unnecessary package or run the image as root, scan it, inspect the result, then fix the Dockerfile and compare the findings.

---

## Part 6 — Artifact Integrity and Image Provenance

A secure pipeline should be able to answer a basic production question: **“Exactly what source code produced this artifact?”** This is why immutable build artifacts, versioning, checksums/digests, build metadata, and provenance matter. If an artifact can be silently replaced after testing, the security checks may no longer describe what actually reached production.

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

Practice: Build an image from a known Git commit and record the commit SHA, image tag, and image digest in your release notes. Then rebuild the same source and observe what changes.

---

## Part 7 — Container Registry Security

The registry is not simply a file server for Docker images. It is a trusted distribution point for software that will run in your environments, so access control, encryption, vulnerability scanning, retention, and image immutability are important controls. Azure Container Registry (ACR) and Amazon Elastic Container Registry (ECR) integrate with their respective cloud identity systems, allowing access to be controlled through cloud IAM rather than distributing registry passwords everywhere.

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

Practice: Write down two identities:

```text
ImageBuilder
ImagePuller
```

For each, list the minimum operations it needs. This is a practical least-privilege exercise.

---

## Part 8 — Pipeline Identity and Federated Authentication

A pipeline needs an identity when it talks to Azure, AWS, a registry, Key Vault, Terraform backend, or another protected service. The dangerous pattern is a permanent credential stored in a pipeline variable and reused everywhere. A stronger architecture uses short-lived, federated authentication where supported, so the pipeline establishes trust with the cloud provider without maintaining a long-lived secret.

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

Practice: Draw the authentication path for your pipeline:

```text
Pipeline → Identity Provider → Cloud Role → Resource
```

Then ask:

1. What proves the pipeline's identity?
2. What permissions does it receive?
3. How long does the credential live?
4. Can the pipeline access production from a developer branch?
5. Can one compromised pipeline identity affect every environment?

---

## Part 9 — Security Gates in the Pipeline

Security should be integrated into the delivery flow instead of being a final manual activity performed after deployment. A practical pipeline might look like:

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

Different controls answer different questions. SAST examines source or compiled code for certain classes of coding weaknesses. SCA examines third-party dependencies. Image scanning examines container contents. Secrets scanning looks for credentials and sensitive material. DAST tests a running application from the outside. Infrastructure-as-code scanning checks Terraform, Bicep, Kubernetes manifests, or other configuration before deployment.

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

Practice: For each gate, write one sentence answering “What attack or failure is this control intended to catch?”

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

Practice: Take a Kubernetes Deployment and deliberately introduce one risky setting, such as running as root or requesting privileged access. Add a security check that detects it before deployment.

---

## Part 11 — Supply Chain Attack Scenario

Imagine an attacker compromises a developer account and changes a dependency in `pom.xml`. The application still compiles and unit tests pass. The dependency is downloaded during the pipeline build, included in the application, packaged into a container, pushed to the registry, and deployed to production. If the pipeline has no dependency verification or security gate, every later stage may treat the malicious artifact as trusted.

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

Senior exercise: Assume a malicious image has reached the registry. Ask:

1. Can the attacker deploy it directly to production?
2. Can the production cluster pull any image from the registry?
3. Are image digests recorded?
4. Is there an approval/policy gate?
5. Can the runtime identity access unrelated cloud resources?
6. Would monitoring detect unexpected behavior?
7. How would you identify which commit produced the image?
8. How would you stop further deployments and rotate affected credentials?

This is the kind of reasoning expected at Senior/Lead level: do not focus only on the scanner; reason about the entire attack path and blast radius.

---

## Part 12 — Secure Build Agents and Pipeline Isolation

The build agent is part of the trust boundary because it executes source code, dependency installation, scripts, Docker builds, and deployment commands. If a malicious build can access credentials or files left by another job, one compromised repository may affect other workloads. Hosted agents provide useful isolation characteristics, while self-hosted agents require careful patching, hardening, access control, cleanup, and job isolation.

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

Practice: Inspect your pipeline and identify:

- Which machine executes the build?
- Which identity does it use?
- Where are credentials available?
- Can a build access the host?
- Is the workspace cleaned between jobs?
- Can the same agent build unrelated projects?

Senior interview point: **a pipeline is code execution infrastructure**, so the build worker must be treated as a security-sensitive system.

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

## Part 14 — Senior/Lead Security Architecture Exercise

Design a secure delivery platform for a Spring Boot application running on AKS.

The requirements are:

- Developers use Git.
- Production requires pull-request review.
- The application is built once and promoted across environments.
- Images are stored in ACR.
- Production secrets are stored in Azure Key Vault.
- AKS workloads use workload identity where supported.
- Terraform manages infrastructure.
- Helm manages Kubernetes application configuration.
- Security scans run before production.
- Production deployment requires controlled authorization.
- Every production workload must be traceable to source code.

Your architecture should look conceptually like:

```text
Developer
   ↓
Git Repository
   ↓
PR + Review + Branch Protection
   ↓
CI
   ├── Unit Tests
   ├── SAST
   ├── Dependency Scan
   ├── Secret Scan
   └── IaC Scan
   ↓
Container Build
   ↓
Image Scan
   ↓
ACR
   ↓
Artifact/Image Identity
   ↓
UAT
   ↓
Production Approval / Policy
   ↓
AKS
   ├── Workload Identity
   ├── Key Vault access
   ├── NetworkPolicy
   ├── Runtime security
   └── Monitoring
```

Now add the infrastructure path:

```text
Terraform
   ↓
Validate
   ↓
Security/Policy Scan
   ↓
Plan
   ↓
Review
   ↓
Controlled Apply
```

The key Senior/Lead questions are:

- Where does trust begin?
- Which identities exist?
- Which identity can deploy production?
- Which identity can read production secrets?
- Can a developer branch deploy directly to production?
- Can the build system modify infrastructure?
- Can the runtime identity push images?
- How is an image tied to a Git commit?
- What prevents a vulnerable image from reaching production?
- What happens when a security scanner has a false positive?
- How are exceptions approved and audited?
- What is the blast radius if the CI identity is compromised?
- How would you revoke access quickly?

Do not try to make one identity powerful enough to do everything. Separate build, deployment, infrastructure, and runtime responsibilities wherever practical.

---

## Part 15 — Practice: Build a Secure Mini Pipeline

Create a small Spring Boot application and implement the following sequence:

1. Store the application in Git.
2. Protect `main` with pull-request review.
3. Build and test the application.
4. Run a dependency/security scan.
5. Build a Docker image.
6. Scan the image.
7. Push the image to a registry.
8. Record the image digest.
9. Deploy the same image to a non-production Kubernetes environment.
10. Use Kubernetes Secret or an external secret mechanism for sensitive configuration.
11. Use a dedicated service account/workload identity rather than broad credentials.
12. Add an approval before production.
13. Record the Git commit, build ID, image tag/digest, and deployment version.
14. Deliberately break one security control and troubleshoot it without disabling the entire security model.

Your final release record should let you answer:

```text
What source code?
        ↓
Which build?
        ↓
Which artifact?
        ↓
Which image digest?
        ↓
Which deployment?
        ↓
Which environment?
        ↓
Which identity?
```

That traceability is one of the most useful practical outcomes of this lesson.

---

## Part 16 — 5-Minute Recall

What is the CI/CD software supply chain?

It is the complete trusted path from source code through dependency resolution, build, security verification, artifact/image creation, storage, deployment, and runtime.

Why is the pipeline itself a security boundary?

Because it can execute code and often has permissions to publish artifacts, deploy applications, modify infrastructure, and access sensitive systems.

Why should long-lived credentials be avoided?

Because compromise of the credential can provide persistent access until the credential is manually revoked or rotated. Federated/short-lived identity reduces that exposure.

What is the difference between SAST, SCA, image scanning, secrets scanning, and DAST?

SAST examines code; SCA examines third-party dependencies; image scanning examines container contents/configuration; secrets scanning looks for exposed credentials; DAST tests the running application from the outside.

Why are image digests important?

A digest identifies exact image content, giving stronger artifact identity than a mutable tag.

Why should build, deploy, and runtime identities be separated?

Because each stage has different responsibilities. Separation reduces blast radius if one identity is compromised.

What is the purpose of branch protection?

To control how changes enter trusted branches and prevent unauthorized direct changes to production-bound code or pipeline definitions.

What should happen when a security scanner finds a vulnerability?

Apply the organization's defined severity/blocking policy. Block when required, or use a documented, auditable exception process when risk is accepted.

What is the Senior/Lead security troubleshooting model?

Trace the failure through the chain:

**Source → Identity → Permission → Dependency → Build → Scan → Artifact → Registry → Deployment → Runtime**

**Final mental model:**

> **Secure CI/CD is not “add a security scan.” It is securing the entire path that turns source code into production software.**

---

## Part 17 — Cleanup

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
