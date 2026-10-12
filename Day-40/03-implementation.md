# Day 40 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 40 is the Lead architecture review for ShopSphere. You do not add a new cloud service. You defend the platform that the earlier project days already designed. This lab produces a filled architecture review checklist. You write why AWS, why separate accounts, why EKS, why multi-AZ, why a private database, how identities split, and how observability proves user impact. You then break the design on purpose: Terraform state has no owner. You add an owner and write the blast radius.

Do not create Azure or AWS resources. Do not run `az`, `aws`, Terraform, Docker, or kubectl. The deliverable is a design document. Work in a temporary directory. Do not write the document inside the DevOps-Prep course repository.

---

## Goal

Write one architecture review named `shopsphere-architecture-review.md` for ShopSphere. ShopSphere is the e-commerce system from this Day: customer registration, product browsing, order creation, payment processing, order status, and administrative operations. The exercise sets cloud to AWS. Production needs 99.9% availability, a 15-minute RPO, a 60-minute RTO, Dev / UAT / Prod, and no public database.

The document must answer seven review questions in prose: why AWS, why separate accounts, why EKS, why multi-AZ, why a private database, which identities exist, and how you observe the shop. Use the same template this Day teaches: decision, why, alternative, trade-off. Then copy the file, remove the owner of Terraform state, write the blast radius, and restore an owner in the main file.

Time box: 45 to 75 minutes. Cost stays at ₹0. Stop when the main document has all seven answers, Terraform state has a named owner again, the blast-radius note explains what unowned state can reach, and you can defend the design without opening the lesson.

---

## What you need

You need a text editor and a shell. You do not need an Azure subscription, an AWS account, a Kubernetes cluster, Terraform, or cloud credentials. This is a concept-only lab. The lesson is architecture judgment, not portal clicks.

Create the lab under `/tmp`, not under this course clone. The review document is ordinary markdown. You must be able to delete the directory when you clean up.

Keep the document named `shopsphere-architecture-review.md`. Record decisions in that file. Do not paste secrets. This lab should not create any.

---

## Steps

1. Create a throwaway directory and enter it. Use a unique folder name so you do not collide with another lab. Confirm the path is under `/tmp`.

```bash
LAB_DIR="/tmp/day-40-architecture-review-$$"
mkdir -p "$LAB_DIR"
cd "$LAB_DIR"
pwd
```

2. Create the empty review document. You will fill it in the next steps. Confirm the file exists before you write the architecture.

```bash
touch shopsphere-architecture-review.md
ls
```

3. Write the business and NFR header. ShopSphere must support orders, payments, and authentication as critical paths. Product browsing is important. Analytics is lower criticality. Name the example targets from this Day: 99.9% availability, RPO 15 minutes, RTO 60 minutes, Dev / UAT / Prod, AWS, no public database, least privilege, and metrics plus logs plus traces.

Write at least one short paragraph. Do not leave this as a heading with no text. State that every later decision must trace back to one of these requirements. Architecture follows business criticality. Do not start with a service list.

4. Add a four-line template reminder at the top of the review list. You will repeat it seven times.

```markdown
Template for every review item:

Decision
→ Why
→ Alternative
→ Trade-off
```

5. Write **why AWS**. Decision: use AWS because this project already set cloud = AWS and the org already runs IAM, VPC, and EKS skills there. Why: pick the cloud from skills, compliance, and existing accounts. Alternative: Azure can express the same boundaries with subscriptions and AKS. Trade-off: a second cloud adds cost and operational load. It does not by itself improve ShopSphere.

Name the real selection rule. Do not defend AWS as a brand. Defend the fit to the stated NFRs.

6. Write **why separate accounts**. Decision: one AWS Organization with a Security account, an Infrastructure / Shared Services account, and workload accounts for Dev, UAT, and Prod. Why: accounts isolate security, IAM, billing, quotas, and blast radius. Alternative: fewer accounts, or one shared account with tidy resource group names. Trade-off: more accounts to operate. Dev must not modify Prod.

State that fewer accounts can work. Shared boundaries must still meet the security and business rules. That is the trade-off, not a slogan.

7. Write **why EKS**. Decision: run the Spring Boot API on EKS because ShopSphere needs a Kubernetes platform, standard tooling, and a path that later days already built. Why: the requirement is a Kubernetes platform, not a cluster for its own sake. Alternative: ECS covered v1 if those Kubernetes needs were absent. Trade-off: you still own nodes, workloads, and platform config. The control plane is managed. Record the capability you accepted.

Do not write “we use EKS because it is production-grade.” Write the platform need.

8. Write **why multi-AZ**. Decision: place public / edge, private app, and private data subnets, plus EKS nodes, in at least two Availability Zones. Why: 99.9% availability needs more than one AZ. Alternative: one AZ. Trade-off: extra NAT, nodes, and data-path cost. One AZ is one failure domain. Multi-AZ is not multi-region.

Name what still dies in a region failure. Multi-AZ does not satisfy a 60-minute regional RTO by itself.

9. Write **why a private database**. Decision: PostgreSQL lives in private data subnets. No internet gateway route to 5432. The application security group may reach the database on 5432. Why: orders and payments sit on that database. Alternative: a public database endpoint. Trade-off: you must design DNS, routing, and security groups on purpose. Public database access fails the security NFR.

Walk the request path in one sentence: user → DNS → load balancer / Ingress → Service → ready endpoints → Pod → Spring Boot → private database.

10. Write **identities**. Decision: split human access, Terraform, deployment, runtime, and Kubernetes API identities. Runtime uses workload identity: Service Account → IAM role → AWS API. No long-lived keys in the Pod. Why: one identity with wide Production rights is a blast-radius problem. Alternative: one pipeline role that applies infrastructure, deploys the app, and reads Production secrets. Trade-off: more identities to manage. A leaked CI credential then cannot rewrite the VPC or empty the secret store.

Answer who can modify Production infrastructure, who can deploy applications, who can read Production secrets, who can access Kubernetes, and who can assume the Terraform role. Apply least privilege, separation of duties, and environment isolation.

11. Write **observability**. Decision: metrics, logs, and traces feed dashboards, alerts, incident response, and RCA. Watch traffic, errors, latency, and saturation. Add business signals: orders, payments, checkout, authentication. Why: Kubernetes health is not business health. Alternative: CPU dashboards only. Trade-off: log ingestion costs money. Shorter retention saves cost and cuts forensics.

The architecture must let you answer this question quickly: are users failing because the application, Kubernetes, network, database, or an external dependency is unhealthy? Page on user symptoms. Do not page on CPU alone.

12. Add a **Terraform state** line so the later break has something to change. State must be remote, protected, locked, versioned, access-controlled, and recoverable. Split `prod/network`, `prod/eks`, and `prod/data`. Name the owner now: the Prod Terraform role in the infrastructure pipeline after format, validate, policy, plan review, and approval. Developers do not apply Production from a laptop. Treat state as Production infrastructure.

Write one short paragraph. Do not leave owner as “the team” with no role. Name who may read state, who may modify it, who may apply, and how you recover a version.

---

## Verify

Read `shopsphere-architecture-review.md` as if you are on a Lead architecture review. You should name the seven decisions and the Terraform state owner without opening the lesson notes.

Check these points:

- The document names ShopSphere, AWS, Dev / UAT / Prod, 99.9%, RPO 15 minutes, and RTO 60 minutes.
- Why AWS, accounts, EKS, multi-AZ, private database, identities, and observability each use decision, why, alternative, and trade-off.
- Accounts isolate blast radius. EKS exists because of a Kubernetes platform need. Multi-AZ is not multi-region.
- The database has no public path. Runtime uses workload identity, not keys in the Pod.
- Observability pages on golden signals and checkout, not on CPU alone.
- Terraform state has a named owner and split `prod/network`, `prod/eks`, and `prod/data`.
- You created no cloud resources. `az` and `aws` were not required.

If a section is only a heading, fill it before you stop. An architecture review with empty headings is not a review.

---

## Break and fix

You shipped a design with no owner for Terraform state. Copy the finished document so you can compare the two. Keep the good design. Do not overwrite it until you have written the blast-radius note.

```bash
cp shopsphere-architecture-review.md shopsphere-architecture-review-broken.md
```

Open `shopsphere-architecture-review-broken.md`. Remove the Terraform state owner. Keep remote state, locking, and versioning as slogans if you want. Do not name who may read state, who may apply, or who recovers it. Keep one combined state file for network, EKS, and data if that makes the gap clearer. Labels such as `prod/network` without an owner are not control.

Write a short section at the bottom of the broken file titled `Blast radius`. Answer these questions in prose, not as a checklist:

- Who can delete or rewrite Production state if any engineer with broad AWS rights can touch the bucket?
- If one apply now holds network, EKS, and the database, how far does one bad apply reach?
- If a leaked CI identity can assume the unowned Terraform role, what else can it change?
- If nobody owns recovery, how long does a corrupted state file block Production changes?

Then rewrite the Terraform state section in `shopsphere-architecture-review.md` so an owner exists again. The Prod Terraform role in the infrastructure pipeline is the only identity that applies Production. Developers cannot apply from a laptop. Split `prod/network`, `prod/eks`, and `prod/data` so one apply is not the whole shop. Add a paragraph that states why missing ownership grew the blast radius. Anyone who could write the bucket could change live infrastructure. One apply could plan against the database and the VPC together. Recovery had no named person. Named ownership keeps the failure inside one state boundary and one role.

Do not leave the broken design as the main document. The main file must keep a Terraform state owner. Keep `shopsphere-architecture-review-broken.md` as the evidence of the mistake.

---

## Clean up

This lab created markdown only. There is no cloud resource to destroy. There is no Terraform state file.

If you want to keep the review, copy `shopsphere-architecture-review.md` out of the temp directory first. Then leave the lab directory and delete it.

```bash
cd /tmp
rm -rf "$LAB_DIR"
```

Do not copy the files into the course repository unless you are submitting homework through a path your instructor named. Do not run `az group delete` or `aws organizations` commands. You created no accounts, clusters, or databases in a cloud.

---

## Interview story

I review ShopSphere from requirements, not from a service list. AWS is the cloud this org already runs. Separate accounts isolate Dev from Prod. EKS exists because we need a Kubernetes platform. Multi-AZ meets 99.9% inside one region. PostgreSQL stays private. Identities split Terraform, deploy, and runtime, and runtime uses workload identity. Observability pages on errors, latency, and checkout, not on CPU. I then shipped state with no owner on purpose. Blast radius grew because any writer of the bucket could change Production, one apply could reach network and data together, and nobody owned recovery. I named the Prod Terraform role, split state, and kept the failure inside one boundary.
