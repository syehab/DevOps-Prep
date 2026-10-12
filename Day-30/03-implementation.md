# Day 30 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 30 is the Senior/Lead final assessment. You connect compute, network, identity, CI/CD, Terraform, secrets, reliability, deployment, observability, cost, and governance into one ShopSphere design. This lab produces `Senior-DevOps-Production-Architecture.md` with the twenty sections this Day names. You then break the design on purpose: Dev, UAT, and Production share one account. You add separate Dev, UAT, and Prod accounts and explain the blast radius.

Do not create Azure or AWS resources. Do not run `az`, `aws`, Terraform, Docker, or kubectl. The deliverable is a design document. Work in a temporary directory. Do not write the document inside the DevOps-Prep course repository.

---

## Goal

Write one architecture document named `Senior-DevOps-Production-Architecture.md` for ShopSphere. ShopSphere is the e-commerce system from this Day: an Angular frontend, a Spring Boot backend, a relational database, and a need for Dev, UAT, and Production. Production needs high availability, controlled promotion, secrets outside Git, and traceable changes.

The document must contain the twenty sections listed in this Day: business requirements, architecture diagram, Azure implementation, AWS implementation, network design, identity model, security model, Terraform structure, CI/CD architecture, deployment strategy, secrets architecture, observability architecture, high-availability design, disaster-recovery approach, cost controls, governance model, failure scenarios, troubleshooting workflows, architecture decisions and trade-offs, and future scaling considerations. Write each section as prose. Use the interview pattern from this Day: requirement, decision, reason, trade-off, alternative. Then copy the file, put Dev, UAT, and Production in one account, write the blast radius, and restore separate Dev, UAT, and Prod accounts in the main file.

Time box: 60 to 90 minutes. Cost stays at ₹0. Stop when the main document has all twenty sections, Dev/UAT/Prod are separate accounts again, the blast-radius note explains what one shared account can reach, and you can present the design without opening the lesson.

---

## What you need

You need a text editor and a shell. You do not need an Azure subscription, an AWS account, a Kubernetes cluster, Terraform, or cloud credentials. This is a concept-only lab. The lesson is architecture judgment, not portal clicks.

Create the lab under `/tmp`, not under this course clone. The design document is ordinary markdown. You must be able to delete the directory when you clean up.

Keep the document named `Senior-DevOps-Production-Architecture.md`. Record decisions in that file. Do not paste secrets. This lab should not create any. Do not copy the lesson text. Build the document from your own understanding.

---

## Steps

1. Create a throwaway directory and enter it. Use a unique folder name so you do not collide with another lab. Confirm the path is under `/tmp`.

```bash
LAB_DIR="/tmp/day-30-architecture-lab-$$"
mkdir -p "$LAB_DIR"
cd "$LAB_DIR"
pwd
```

2. Create the empty design document. You will fill it in the next steps. Confirm the file exists before you write the architecture.

```bash
touch Senior-DevOps-Production-Architecture.md
ls
```

3. Write **business requirements**. ShopSphere must support Dev, UAT, and Production. Production must stay available when one application instance fails. Deployments must have zero or minimal downtime. Infrastructure must be code. Secrets must not live in Git. Developers must not change Production infrastructure directly. CI/CD must build and test automatically. Production deploy needs controlled promotion. Changes must be traceable. Monitoring, alerting, and incident investigation are required. Cloud cost must stay controlled. The design must map onto both Azure and AWS concepts.

Write at least one short paragraph. Do not leave this as a heading with no text. Place Dev, UAT, and Prod in three accounts. Say who may deploy Production. Say that Terraform state is per environment, not one global file. An account is an isolation unit for blast radius, billing, quotas, and access. It is not a folder name and not a region. Azure uses a subscription for the same job. Name both so the later Azure and AWS sections stay consistent.

4. Write the **architecture diagram** as a text flow. Start from users. Do not start from a product catalog. Keep the core path small.

```text
Users
 ↓
DNS / Traffic Management
 ↓
Frontend
 ↓
Load Balancing
 ↓
Application Runtime
 ↓
Private Database

Around the system:
Identity
Security
Secrets
CI/CD
IaC
Observability
Governance
Cost
```

Do not add Kubernetes, a service mesh, Kafka, or microservices unless a requirement needs them. Every extra box is a failure mode and an operational cost.

5. Add a five-line template reminder. Use the same chain this Day teaches. Repeat it in the decision section later.

```markdown
Template for every decision:

Requirement
→ Decision
→ Reason
→ Trade-off
→ Alternative
```

6. Write **Azure implementation** and **AWS implementation**. Same design, different products. Azure: Entra tenant, management groups, Dev/UAT/Prod subscriptions, VNet with public or ingress, application, and private database paths, Key Vault, Azure Pipelines, ACR, and a managed container platform or AKS only if Kubernetes is required. AWS: Organization, OUs, Dev/UAT/Prod accounts, VPC with public, private application, and private database subnets, Secrets Manager, CodePipeline and CodeBuild, ECR, and a managed container platform or EKS only if Kubernetes is required.

State the compute decision in both sections. ShopSphere is a containerized Spring Boot app with long-running processes. Choose a managed container platform when you do not need Kubernetes-specific APIs. Choose AKS or EKS when the organization already operates Kubernetes or needs that ecosystem. A VM gives more control and more operational work. The Senior/Lead answer is not “Kubernetes is better.” Choose the runtime from workload needs, team capability, and cost.

7. Write **network design**. Requirement: users reach the frontend and API on a controlled public path, and the API reaches the database on a private path. Decision: design from flows. User to frontend. User to API through a load balancer. API to the private database. API to the payment dependency. Runtime to the registry and secret store. Reason: every hop is a failure and security boundary. Alternative: put every component on the public internet. Trade-off: private endpoints, private DNS, and security rules add routing work. They shrink the public attack surface.

Name the troubleshooting chain: DNS, destination IP, route, security, port, service, application. Azure uses a VNet. AWS uses a VPC. Same job, different knobs. The database is not a public internet endpoint.

8. Write **identity model** and **security model**. Split four identities: developer, pipeline, application runtime, and Terraform. Developers use source and CI. They do not hold standing Production infrastructure access. The pipeline identity builds, pushes, and deploys. The application identity reaches runtime resources only. The Terraform identity changes infrastructure. Prefer workload identity or roles over long-lived access keys. Ask what damage follows if that identity is compromised.

Protect `main`. Review changes. Scan the image. Pin a digest. Approve Production. Do not give the Spring Boot runtime permission to change the cluster or the account. Authentication proves who the principal is. Authorization decides what that principal may do.

9. Write **Terraform structure**. Separate the application pipeline from the infrastructure pipeline. Application path: code, build, test, image, deploy. Infrastructure path: format, validate, policy, plan, review, apply, verify. Use one module set and environment folders `dev/`, `uat/`, and `prod/` with separate backends. Remote state, locking, encryption, versioning, and per-environment access are required. Two engineers must not apply the same state at the same time.

10. Write **CI/CD architecture** and **deployment strategy**. Build once. Promote the same artifact Dev → UAT → Production. Pin the image digest. Trace Git SHA → pipeline run → build → digest → running workload. Production needs approval and health verification. Deployment success is not application success.

For a bad `2.0` release: detect, stop further exposure, decide whether rollback is safe, restore the known-good version if it is, keep evidence, then fix the cause. Application rollback and database rollback are different problems. An irreversible schema change can make Application v1 unsafe. Plan backward-compatible migrations before you ship.

11. Write **secrets architecture**. Store database credentials, JWT material, and third-party API credentials in a central secret store. Runtime identity reads them. Do not commit secrets to Git. Do not copy them into image layers. Do not print them in build logs. Azure commonly uses Key Vault. AWS commonly uses Secrets Manager. The product name is not the principle.

12. Write **observability architecture**. Metrics show what is happening. Logs show what happened. Traces show where the request went. Watch request rate, error rate, latency, saturation, database connections, dependency failures, and deployment changes. Use a correlation ID. Alerts must name an action. Page on user symptoms, not on CPU alone. The chain is metrics and logs and traces → alert → incident → investigation → recovery → RCA → improvement.

13. Write **high-availability design** and **disaster-recovery approach**. Two instances on one failed node are not high availability. Place redundancy across process, container, node, availability zone, region, and external dependency. Distinguish availability, durability, scalability, and recoverability. For DR, name backup of the database, who restores it, and how you prove the restore. A diagram without a restore test is not a recovery plan.

14. Write **cost controls** and **governance model**. Find the cost driver before you cut instance size. Typical drivers are compute, databases, NAT, load balancers, data transfer, storage, logging, and idle non-prod. Right-size. Schedule Dev. Cap log retention. Do not drop Production HA to save money. For fifty teams, Azure uses management groups, Policy, RBAC, tags, and budgets. AWS uses OUs, SCPs, IAM, Config, tags, and budgets. The platform sets guardrails. Teams still own their applications.

15. Write **failure scenarios** and **troubleshooting workflows**. Cover a post-deploy partial 5xx with normal CPU, a pipeline-success 503, and unexpected Terraform drift. Do not restart everything. Start with evidence. Walk load balancer → target health → instance or Pod → process → logs → digest versus Git SHA. When logs show `UnknownHostException: payments.internal`, switch to DNS → private DNS → route → security → payments service. For drift: detect, investigate, reconcile or codify, prevent recurrence. Do not auto-apply.

16. Close with **architecture decisions and trade-offs** and **future scaling considerations**. Repeat requirement, decision, reason, trade-off, and alternative for compute, network, identity, Terraform, CI/CD, and observability. For 10× traffic, say what you would change first: more replicas, a larger database, another region, or Kubernetes if the managed container platform is no longer enough. Do not add a mesh because it is fashionable.

---

## Verify

Read `Senior-DevOps-Production-Architecture.md` as if you are on a Senior/Lead interview. You should name the twenty sections and the Dev/UAT/Prod account split without opening the lesson notes.

Check these points:

- The file name is `Senior-DevOps-Production-Architecture.md`.
- All twenty sections have prose, not empty headings.
- Dev, UAT, and Production are separate accounts. Azure subscriptions appear as the matching isolation unit.
- Compute starts from workload needs. Kubernetes is a choice, not a default.
- The database path is private. The troubleshooting chain is DNS, IP, route, security, port, service, application.
- Identity splits developer, pipeline, runtime, and Terraform. Secrets are not in Git.
- Terraform state is remote, locked, and per environment.
- CI/CD builds once and promotes a digest. Production needs approval.
- Observability pages on user symptoms. Cost sits beside reliability.
- You created no cloud resources. `az` and `aws` were not required.

If a section is only a heading, fill it before you stop. An architecture document with empty headings is not a design.

```bash
grep -c '^#' Senior-DevOps-Production-Architecture.md
wc -l Senior-DevOps-Production-Architecture.md
```

You should see a heading for each of the twenty sections and enough lines that the file is a document, not an outline.

---

## Break and fix

You chose one account for everything. Copy the finished document so you can compare the two. Keep the good design. Do not overwrite it until you have written the blast-radius note.

```bash
cp Senior-DevOps-Production-Architecture.md Senior-DevOps-Production-Architecture-broken.md
```

Open `Senior-DevOps-Production-Architecture-broken.md`. Put Dev, UAT, and Production in one account. Keep tidy names such as `shopsphere-dev` and `shopsphere-prod` so the labels still look organized. Labels are not the isolation boundary. Keep one Terraform state file for that shared account. Keep one pipeline identity that can change Dev and Production.

Write a short section at the bottom of the broken file titled `Blast radius`. Answer these questions in prose, not as a checklist:

- Who can delete the Production database if their identity already has write on the shared account?
- What happens to Production quotas and bills when a Dev experiment runs away?
- If one Terraform state now holds Dev and Production, how far does one apply reach?
- If the CI identity for Dev lives in that same account, what else can a leaked CI credential change?

The broken file is missing environment isolation. That is the failure. Fix the main document. Rewrite the isolation section in `Senior-DevOps-Production-Architecture.md` so Dev, UAT, and Production are separate accounts again. Add a paragraph that states why the shared account grew the blast radius. A Dev mistake could reach Production resources. Role assignments mixed. Cost reports mixed. One apply could plan against both environments. Separate accounts keep the failure inside one environment. Azure subscriptions do the same job when the implementation is Azure.

Do not leave the broken design as the main document. The main file must keep Dev, UAT, and Production apart. Keep `Senior-DevOps-Production-Architecture-broken.md` as the evidence of the mistake.

---

## Clean up

This lab created markdown only. There is no cloud resource to destroy. There is no Terraform state file.

If you want to keep the design, copy `Senior-DevOps-Production-Architecture.md` out of the temp directory first. Then leave the lab directory and delete it.

```bash
cd /tmp
rm -rf "$LAB_DIR"
```

Do not copy the files into the course repository unless you are submitting homework through a path your instructor named. Do not run `az group delete` or `aws organizations` commands. You created no subscriptions, accounts, or resource groups in a cloud.

---

## Interview story

I design ShopSphere from requirements, not from a service list. Users reach a load balancer. The Spring Boot API runs on a managed container platform unless Kubernetes is a real need. The database stays private. Identity is split so the pipeline cannot use the app role and developers cannot change Production by hand. Terraform uses remote state, locking, and one state file per environment. CI/CD builds one digest and promotes it. Observability pages on errors and latency, not on CPU. I then put Dev, UAT, and Prod in one account on purpose. Blast radius grew because access, billing, quotas, and one Terraform apply could all reach Production from a Dev change. I added separate Dev, UAT, and Prod accounts so a mistake stays inside one environment.
