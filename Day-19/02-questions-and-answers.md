# Day 19 — Questions and answers

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Then answer each item below before you open the Answer block. After that, do the lab in [03-implementation.md](03-implementation.md).

Write your own answer first. Open the Answer block only after you try. Keep the original numbering.

---

## 1. List what the AKS pipeline can access and split build from deploy

**Practice**

Take a Spring Boot application deployed to AKS. List everything the pipeline can access and ask which permissions are actually required at each stage. Separate permissions needed to build from permissions needed to deploy.

<details>
<summary>Answer</summary>

A typical pipeline can read Git, run builds, push to ACR, maybe apply Terraform, deploy to AKS, and read Key Vault. List each permission. Build needs compile, test, and registry push. Deploy needs Kubernetes apply and maybe secret read. Those are different identities.

Compromising the pipeline can be as serious as compromising production. Do not give the build job production deploy plus account admin. Separate stages. Ask which permissions are actually required at each stage.

</details>

---

## 2. Senior scenario — PR that changes only `azure-pipelines.yml`

**Senior scenario**

A developer opens a pull request that changes only `azure-pipelines.yml`. The application code is unchanged. Treat the pipeline change as an infrastructure/security change because the YAML can alter commands, credentials usage, artifact handling, and deployment behavior.

<details>
<summary>Answer</summary>

Treat it as an infrastructure and security change, not as a normal app PR. Pipeline YAML can alter commands, credentials, artifacts, and deploy targets. Inspect with `git show --stat` and `git diff` on `azure-pipelines.yml`, Dockerfile, Terraform, Helm, and Kubernetes files.

Branch protection still requires review. Application security scans do not replace this. The pipeline trusts whatever the repository gives it.

</details>

---

## 3. Search the repo for secret patterns and inspect leak paths

**Practice**

Search a repository for obvious secret patterns:

```bash
git grep -n -i "password"
git grep -n -i "client_secret"
git grep -n -i "access_key"
git grep -n -i "private_key"
```

Then inspect pipeline logs and ask: “Could this value appear in logs, artifacts, Docker layers, Terraform state, or temporary files?”

<details>
<summary>Answer</summary>

Run `git grep -n -i "password"`, and the same for `client_secret`, `access_key`, and `private_key`. Then inspect pipeline logs. Ask whether the value could appear in logs, artifacts, Docker layers, Terraform state, or temp files.

Removing a secret from the latest commit does not make it safe. If it was committed before, assume Git history has it and rotate it. Supply the secret at runtime, smallest scope, shortest time.

</details>

---

## 4. Add a dependency scan and record fail versus warn versus exception

**Practice**

Add a dependency scan to your pipeline after compilation/tests and before publishing the release artifact. Record what happened when the scanner found a vulnerability: Did the pipeline fail? Did it warn? Who could approve an exception?

<details>
<summary>Answer</summary>

Place SCA after compile and tests, before you publish the release artifact. Run `mvn dependency:tree` so you see direct and transitive libraries. Record whether a finding failed the pipeline, warned, or needed an exception owner.

Finding a CVE is not controlling it. Policy must say which severity blocks production and how an exception is audited. Severity alone is not operational risk. Reachability and compensating controls matter.

</details>

---

## 5. Senior interview — critical CVE, do you always stop production?

**Senior interview question**

“If your dependency scanner reports a critical CVE, do you always stop production?”

<details>
<summary>Answer</summary>

The organization should have a defined risk policy: blocking thresholds and an auditable exception process. Critical findings normally block until you patch, mitigate, or accept with a named owner.

An ad-hoc decision inside each pipeline is the weak answer. Always-stop with no exception path can freeze the business. Always-ship is worse.

</details>

---

## 6. Add an unnecessary package or root user, scan, then fix

**Practice**

Deliberately add an unnecessary package or run the image as root, scan it, inspect the result, then fix the Dockerfile and compare the findings.

<details>
<summary>Answer</summary>

Build with `docker build -t myapp:1.0.0 .`. Inspect with `docker history myapp:1.0.0` and `docker inspect myapp:1.0.0`. Run as root or add extra packages. Scan. Then use a multi-stage Dockerfile, a JRE runtime, `USER appuser`, and only the JAR.

Compare findings. A working image is not a secure image. `EXPOSE` documents a port. It does not publish the port.

</details>

---

## 7. Record commit SHA, tag, and digest, then rebuild

**Practice**

Build an image from a known Git commit and record the commit SHA, image tag, and image digest in your release notes. Then rebuild the same source and observe what changes.

<details>
<summary>Answer</summary>

Build from a known Git commit. Record commit SHA, `myapp:1.0.0`, and the digest from `docker image inspect myapp:1.0.0`. Push, then record the registry digest. Rebuild the same source.

The tag can stay `1.0.0` while the digest changes if the build is not bit-for-bit reproducible. Production identity should use the digest. Trace Git SHA → build ID → artifact → digest → deployment → running workload.

</details>

---

## 8. ImageBuilder versus ImagePuller least privilege

**Practice**

Write down two identities:

```text
ImageBuilder
ImagePuller
```

For each, list the minimum operations it needs. This is a practical least-privilege exercise.

<details>
<summary>Answer</summary>

ImageBuilder is the CI identity. It needs push (and maybe scan) on the application repository in ACR or ECR. It must not need Kubernetes deploy or Key Vault read.

ImagePuller is the node or workload pull identity. It needs pull only. It must not push. Different trust relationships. Do not give every pipeline broad registry permissions.

</details>

---

## 9. Draw pipeline authentication and answer the five questions

**Practice**

Draw the authentication path for your pipeline:

```text
Pipeline → Identity Provider → Cloud Role → Resource
```

Then ask:

1. What proves the pipeline's identity?
2. What permissions does it receive?
3. How long does the credential live?
4. Can the pipeline access production from a developer branch?
5. Can one compromised pipeline identity affect every environment?

<details>
<summary>Answer</summary>

Draw Pipeline → Identity Provider → Cloud Role → Resource. What proves identity is federation or a service connection, not a password in YAML. Permissions are the role at a narrow scope. Credential lifetime should be short.

A developer branch must not deploy production. One compromised pipeline identity must not span every environment. Prefer federated short-lived tokens over a permanent client secret in variables.

</details>

---

## 10. One sentence per gate: what attack or failure it catches

**Practice**

For each gate, write one sentence answering “What attack or failure is this control intended to catch?”

<details>
<summary>Answer</summary>

SAST catches coding weaknesses in your source. SCA catches known vulnerabilities in third-party dependencies. Image scanning catches vulnerable OS packages, app libraries, and bad image config. Secrets scanning catches credentials in code, config, and history.

DAST catches issues in the running app from the outside. IaC scanning catches public resources, privileged containers, and excessive permissions before apply. Define what blocks, what warns, and what needs an exception. Do not add every scanner blindly.

</details>

---

## 11. Introduce a risky Deployment setting and detect it before deploy

**Practice**

Take a Kubernetes Deployment and deliberately introduce one risky setting, such as running as root or requesting privileged access. Add a security check that detects it before deployment.

<details>
<summary>Answer</summary>

Set the container to run as root or request privileged. Render with `helm template myapp ./chart`. Run the approved policy or security check on that YAML. The gate should fail before Kubernetes applies it.

Validation checks whether YAML is structurally valid. Security policy checks whether it is acceptable. Runtime controls check the live workload. You need all three. `terraform validate` is not a security policy.

</details>

---

## 12. Supply-chain scenario — malicious dependency in `pom.xml`

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

<details>
<summary>Answer</summary>

The app still compiles. Tests may pass. The pipeline downloads the package, boxes it in an image, pushes, and deploys. Without SCA, image scan, and deploy authorization, later stages trust the artifact.

Defense in depth: branch protection, review of `pom.xml`, SCA, isolated build, image scan, registry controls, deploy approval, runtime monitoring. One control failing must not equal production compromise.

</details>

---

## 13. Senior exercise — malicious image already in the registry

**Senior exercise**

Assume a malicious image has reached the registry. Ask:

1. Can the attacker deploy it directly to production?
2. Can the production cluster pull any image from the registry?
3. Are image digests recorded?
4. Is there an approval/policy gate?
5. Can the runtime identity access unrelated cloud resources?
6. Would monitoring detect unexpected behavior?
7. How would you identify which commit produced the image?
8. How would you stop further deployments and rotate affected credentials?

<details>
<summary>Answer</summary>

1. The attacker deploys it only if they have production deploy authorization. 2. The cluster should not pull any image; pin registry, repo, and digest. 3. Record digests so you know what ran. 4. Keep an approval or admission policy. 5. Runtime identity must not push images or access unrelated cloud APIs. 6. Monitoring should flag unexpected process or network behavior. 7. Trace digest → build ID → Git commit. 8. Stop deploys, block the digest, rotate credentials the image could use.

Reason about the whole path and blast radius, not only the scanner.

</details>

---

## 14. Inspect the build agent as a security boundary

**Practice**

Inspect your pipeline and identify:

- Which machine executes the build?
- Which identity does it use?
- Where are credentials available?
- Can a build access the host?
- Is the workspace cleaned between jobs?
- Can the same agent build unrelated projects?

<details>
<summary>Answer</summary>

Ask which machine runs the job and which identity it uses. Ask where credentials appear and whether the build can reach the host Docker socket. Ask whether the workspace is cleaned and whether the same agent builds unrelated projects.

A pipeline is code execution infrastructure. Hosted agents give a fresh machine per run. Self-hosted agents make you own patching, isolation, and credential hygiene. Do not install production credentials permanently on the agent.

</details>

---

## 15. Troubleshooting — do not disable the security control

When a secure pipeline fails, do not immediately disable the security control. First determine which trust boundary is failing.

If an Azure DevOps pipeline suddenly cannot push to ACR, walk this sequence:

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

<details>
<summary>Answer</summary>

Walk Source → Identity → Permission → Dependency → Build → Scan → Artifact → Registry → Deployment → Runtime. If ACR push fails, check service connection auth, identity existence, push permission, registry reachability, registry policy, then image name.

If admission rejects an image, check build, push, digest, scanner block, and admission policy. Then read the Pod image with `kubectl describe pod` and `kubectl get pod <pod> -o jsonpath='{.spec.containers[*].image}'`. Grant only the missing permission. Do not make the identity Owner so the pipeline “just works.”

</details>

---

## 16. Senior/Lead architecture questions for the AKS delivery platform

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

<details>
<summary>Answer</summary>

Trust begins at protected Git. Identities are developer, CI, Terraform, deploy, and runtime. Only the production deploy identity plus approval can ship prod. Only the workload identity reads Key Vault. A developer branch cannot deploy production. The build system must not apply production Terraform.

The runtime identity must not push images. Tie image to Git via digest and build metadata. Vulnerable images fail scan or admission. False positives use an audited exception. CI compromise is limited by split roles. Revoke federation and service connections quickly. Do not make one identity powerful enough to do everything.

</details>

---

## 17. Mini pipeline — Git through approval, then break one control

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

<details>
<summary>Answer</summary>

1. Store the app in Git. 2. Protect `main` with PR review. 3. Build and test. 4. Run SCA. 5. `docker build`. 6. Scan the image. 7. Push to the registry. 8. Record the digest. 9. Deploy that same image to non-prod Kubernetes. 10. Use a Secret or external secret for DB config. 11. Use a dedicated ServiceAccount or workload identity. 12. Require approval before production. 13. Record Git commit, build ID, tag or digest, and deploy version. 14. Break one control, such as a missing pull permission, and fix the exact permission.

Final record must answer: what source, which build, which artifact, which digest, which deployment, which environment, which identity.

</details>

---

## 18. Recall — What is the CI/CD software supply chain?

What is the CI/CD software supply chain?

<details>
<summary>Answer</summary>

It is the trusted path from source code through dependencies, build, security verification, artifact and image creation, storage, deployment, and runtime.

A weakness anywhere undermines later controls. If an attacker changes what gets built, careful deploy does not save you.

</details>

---

## 19. Recall — Why the pipeline itself is a security boundary

Why is the pipeline itself a security boundary?

<details>
<summary>Answer</summary>

It executes code and often can publish artifacts, deploy apps, change infrastructure, and read secrets. Compromising it can be as serious as compromising production.

Secure the delivery path, not only the application.

</details>

---

## 20. Recall — Why avoid long-lived credentials

Why should long-lived credentials be avoided?

<details>
<summary>Answer</summary>

A leaked long-lived secret works until you rotate it. Federated short-lived identity expires on its own and is easier to audit.

The pipeline should prove who it is rather than carry a permanent password.

</details>

---

## 21. Recall — SAST, SCA, image scanning, secrets scanning, DAST

What is the difference between SAST, SCA, image scanning, secrets scanning, and DAST?

<details>
<summary>Answer</summary>

SAST examines your source or compiled code. SCA examines third-party dependencies. Image scanning examines container contents and config. Secrets scanning looks for exposed credentials. DAST tests the running application from the outside.

Each gate answers a different question. Do not treat them as one “security scan.”

</details>

---

## 22. Recall — Why image digests matter

Why are image digests important?

<details>
<summary>Answer</summary>

A digest is content-addressed identity for that image. A tag such as `1.4.2` can move if registry policy allows.

Pin production to `myregistry/myapp@sha256:<digest>`.

</details>

---

## 23. Recall — Why separate build, deploy, and runtime identities

Why should build, deploy, and runtime identities be separated?

<details>
<summary>Answer</summary>

Each stage has a different job. Separation shrinks blast radius if one identity leaks. Build pushes images. Deploy applies workloads. Runtime reads one secret.

Do not let the runtime identity push images or apply Terraform.

</details>

---

## 24. Recall — Purpose of branch protection

What is the purpose of branch protection?

<details>
<summary>Answer</summary>

It controls how changes enter trusted branches such as `main`. Changes arrive through pull request, review, and checks.

It protects the introduction path. You still need scans, identity, and deploy controls.

</details>

---

## 25. Recall — What happens when a scanner finds a vulnerability

What should happen when a security scanner finds a vulnerability?

<details>
<summary>Answer</summary>

Apply the organization’s severity and blocking policy. Block when required. Use a documented, auditable exception when you accept the risk.

Do not disable the gate to “get the pipeline green.”

</details>

---

## 26. Recall — Senior/Lead security troubleshooting model

What is the Senior/Lead security troubleshooting model?

<details>
<summary>Answer</summary>

Trace Source → Identity → Permission → Dependency → Build → Scan → Artifact → Registry → Deployment → Runtime. Identify the failing trust boundary.

Never solve a security failure by broadly granting permissions until the pipeline works.

</details>
