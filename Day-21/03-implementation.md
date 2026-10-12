# Day 21 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 21 is the Senior/Lead capstone. You combine network, identity, IaC, CI/CD, Kubernetes, and observability into one ShopSphere architecture. This lab produces a markdown one-pager. For each of those six areas you write requirement, decision, why, alternative, and trade-off. You then break the design on purpose: one subscription for everything. You rewrite it to separate Dev, UAT, and Prod, and you state the blast radius.

Do not create Azure or AWS resources. Do not run `az`, `aws`, Terraform, Docker, or kubectl. The deliverable is a design document. Work in a temporary directory. Do not write the document inside the DevOps-Prep course repository.

---

## Goal

Write one architecture one-pager named `shopsphere-architecture.md` for ShopSphere. ShopSphere is the e-commerce system from this Day: Angular frontend, Spring Boot API, PostgreSQL, a payment API, and object storage for product images.

The document must record six architecture decisions with the same five-line template from Part 20: requirement, decision, why, alternative, trade-off. Cover network, identity, IaC, CI/CD, Kubernetes, and observability. Then copy the file, put Dev, UAT, and Prod in one subscription, write the blast radius, and restore separate Dev, UAT, and Prod isolation in the main file.

Time box: 45 to 75 minutes. Cost stays at ₹0. Stop when the main document has all six decisions, Dev/UAT/Prod are separate again, the blast-radius note explains what one shared subscription can reach, and you can present the design without opening the lesson.

---

## What you need

You need a text editor and a shell. You do not need an Azure subscription, an AWS account, a Kubernetes cluster, Terraform, or cloud credentials. This is a concept-only lab. The lesson is architecture judgment, not portal clicks.

Create the lab under `/tmp`, not under this course clone. The design document is ordinary markdown. You must be able to delete the directory when you clean up.

Keep the document named `shopsphere-architecture.md`. Record decisions in that file. Do not paste secrets. This lab should not create any.

---

## Steps

1. Create a throwaway directory and enter it. Use a unique folder name so you do not collide with another lab. Confirm the path is under `/tmp`.

```bash
LAB_DIR="/tmp/day-21-shopsphere-lab-$$"
mkdir -p "$LAB_DIR"
cd "$LAB_DIR"
pwd
```

2. Create the empty design document. You will fill it in the next steps. Confirm the file exists before you write the architecture.

```bash
touch shopsphere-architecture.md
ls
```

3. Write the business and isolation header. ShopSphere must support Dev, UAT, and Production. Name one Entra tenant as the identity boundary. Place Dev, UAT, and Prod in three subscriptions. Say who may deploy Production. Say that Terraform state is per environment, not one global file.

Write at least one short paragraph. Do not leave this as a heading with no text. State that a subscription is an isolation unit for blast radius, billing, and access. It is not a resource group and not a region.

4. Add a five-line template reminder at the top of the decision list. Use the same chain this Day teaches. You will repeat it six times.

```markdown
Template for every decision:

Requirement
→ Decision
→ Why
→ Alternative
→ Trade-off
```

5. Write the **network** decision. Requirement: the API must reach PostgreSQL on a private path, and users must reach the frontend and API on a controlled public path. Decision: design from flows. User to frontend. User to API through Ingress or a load balancer. API to PostgreSQL through a private endpoint. API to the payment API. AKS to the registry and Key Vault. Why: every hop is a failure and security boundary. Alternative: put every component on the public internet. Trade-off: private endpoints and NSGs add DNS and routing work. They shrink the public attack surface.

Write this as prose, not a checklist. Name the troubleshooting chain: DNS, IP, route, security, port, service, application.

6. Write the **identity** decision. Requirement: secrets must not live in source or in Pod env files. Decision: split Developer, CI, Terraform, runtime, and human Production-operator identities. Runtime uses workload identity to get named Key Vault secrets. Why: one Contributor identity is a blast-radius problem. Alternative: one pipeline service principal with Owner. Trade-off: more identities to manage. A leak of CI then cannot wipe Key Vault or rewrite the VNet.

State how you revoke access: disable the assignment or the federation. Name one permission you refuse: CI must not read Production secrets.

7. Write the **IaC** decision. Requirement: infrastructure must be reviewable and repeatable. Decision: reusable modules for network, AKS, database, registry, and monitoring. Environment folders pass CIDR ranges, node size, and database SKU. Separate state per environment. Why: modules hold design. Environments hold values. Alternative: copy the whole stack three times, or put Prod CIDRs inside the module. Trade-off: more repository structure. Plans stay smaller and Prod apply stays controlled.

Name the Production pipeline checks: `terraform fmt -check`, `terraform validate`, `terraform plan`, then authorized apply. Do not run those commands in this lab.

8. Write the **CI/CD** decision. Requirement: only approved Production changes ship, and you can trace a running image to Git. Decision: build once. Promote the same image digest through UAT to Production. Change config, not the artifact. Split build identity from deploy identity. Approve Production. Why: a rebuild per environment can produce a different binary than you tested. Alternative: rebuild on each environment and deploy from `latest`. Trade-off: you must keep config outside the image. Traceability and rollback become real.

Record the path: Git commit, build ID, image tag, digest, deployment.

9. Write the **Kubernetes** decision. Requirement: the API must survive a Pod failure and must not take traffic while unready. Decision: a Deployment with three replicas, requests and limits, a readiness probe on `/actuator/health/readiness`, and a Service to ready Endpoints. Pin the image by digest. Why: a standalone Pod does not self-heal. `Running` is not traffic eligibility. Alternative: one VM with restart. Trade-off: more compute cost. Instance failure impact falls.

State what happens if one Pod dies, if one Pod is unready, and if a node fails. ReplicaSet replaces. Service skips unready Endpoints. Spread replicas so one node is not the whole shop.

10. Write the **observability** decision. Requirement: operations must know if users are affected, which service failed, and whether a release caused it. Decision: metrics, structured logs, traces, and three alerts that name an action. Page on error rate, p95 above SLO, and replica loss. Why: Kubernetes health is not application health. Alternative: CPU dashboards only. Trade-off: log ingestion costs money. Shorter retention saves cost and cuts forensics.

Each alert must name the first action. Dashboards hold CPU. Alerts page on user symptoms.

11. Close with the Lead presentation order from this Day. Write one short paragraph that you could say on a call: business, enterprise structure, network, compute, Kubernetes, database, identity, secrets, IaC, CI/CD, supply chain, deploy strategy, observability, incident response, cost, and governance. Every major decision already has a reason in the six sections above.

---

## Verify

Read `shopsphere-architecture.md` as if you are on a Senior/Lead interview. You should name the six decisions and the Dev/UAT/Prod split without opening the lesson notes.

Check these points:

- The document names ShopSphere, one tenant, and three environment subscriptions.
- Network, identity, IaC, CI/CD, Kubernetes, and observability each use requirement, decision, why, alternative, and trade-off.
- Network names the private database path and the DNS-to-application chain.
- Identity splits CI from runtime and from the Production operator.
- IaC keeps environment values out of modules and splits state.
- CI/CD builds once and promotes a digest.
- Kubernetes uses a Deployment, a Service, readiness, and three replicas.
- Observability pages on user symptoms, not on CPU alone.
- You created no cloud resources. `az` and `aws` were not required.

If a section is only a heading, fill it before you stop. An architecture one-pager with empty headings is not a design.

---

## Break and fix

You chose one subscription for everything. Copy the finished document so you can compare the two. Keep the good design. Do not overwrite it until you have written the blast-radius note.

```bash
cp shopsphere-architecture.md shopsphere-architecture-broken.md
```

Open `shopsphere-architecture-broken.md`. Put Dev, UAT, and Production in one subscription. Keep resource group names such as `rg-shopsphere-dev` and `rg-shopsphere-prod` so the labels still look tidy. Labels are not the isolation boundary. Keep one Terraform state file for that shared subscription.

Write a short section at the bottom of the broken file titled `Blast radius`. Answer these questions in prose, not as a checklist:

- Who can delete the Production database if their identity already has write on the shared subscription?
- What happens to Production quotas and bills when a Dev experiment runs away?
- If one Terraform state now holds Dev and Production, how far does one apply reach?
- If the CI identity for Dev lives in that same subscription, what else can a leaked CI credential change?

Then rewrite the isolation section in `shopsphere-architecture.md` so Dev, UAT, and Production are separate subscriptions again. Add a paragraph that states why the shared subscription grew the blast radius. A Dev mistake could reach Production resources. Role assignments mixed. Cost reports mixed. One apply could plan against both environments. Separate isolation units keep the failure inside one environment.

Do not leave the broken design as the main document. The main file must keep Dev, UAT, and Production apart. Keep `shopsphere-architecture-broken.md` as the evidence of the mistake.

---

## Clean up

This lab created markdown only. There is no cloud resource to destroy. There is no Terraform state file.

If you want to keep the design, copy `shopsphere-architecture.md` out of the temp directory first. Then leave the lab directory and delete it.

```bash
cd /tmp
rm -rf "$LAB_DIR"
```

Do not copy the files into the course repository unless you are submitting homework through a path your instructor named. Do not run `az group delete` or `aws organizations` commands. You created no subscriptions, accounts, or resource groups in a cloud.

---

## Interview story

I design ShopSphere from requirements, not from a service list. The network follows real flows and keeps PostgreSQL private. Identity is split so CI cannot read Production secrets and runtime uses workload identity. IaC uses modules plus environment values and a state file per environment. CI/CD builds one digest and promotes it. Kubernetes runs three replicas behind a Service and a readiness probe. Observability pages on error rate and latency, not on CPU. I then put Dev, UAT, and Prod in one subscription on purpose. Blast radius grew because access, billing, quotas, and one Terraform apply could all reach Production from a Dev change. I split them again so a mistake stays inside one environment.
