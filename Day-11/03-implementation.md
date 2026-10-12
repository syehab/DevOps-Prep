# Day 11 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 11 teaches the structure above individual resources. A landing zone is that ready foundation: identity, governance, environment isolation, and ownership that workloads deploy into. This lab produces a markdown design document for a fictional company. You name the tenant or Organization, the governance layer, three environment subscriptions or accounts, resource groups, and Terraform state boundaries. You also fill an Azure versus AWS table so the same design maps across clouds.

Do not create Azure or AWS resources. Do not run `az`, `aws`, or Terraform. The deliverable is a design document. Work in a temporary directory. Do not write the document inside the DevOps-Prep course repository.

---

## Goal

Write one landing-zone design document for HarborMart, a fictional grocery retailer. The document must identify the identity boundary, the governance hierarchy, three environment isolation units (Dev, UAT, Production), resource groups for one application, and Terraform state files that follow those same lines.

Include one table that maps each Azure object to its AWS equivalent. Then break the design on purpose: put Dev and Production in the same subscription or account. Rewrite the document so they are separate again, and write why the shared isolation unit grew the blast radius.

Time box: 45 to 75 minutes. Cost stays at ₹0. Stop when the document has every required section, the break-and-fix note explains blast radius, and you can present the design in the Lead Architect sentences from this Day.

---

## What you need

You need a text editor and a shell. You do not need an Azure subscription, an AWS account, Terraform, or cloud credentials. This is a concept-only lab. The lesson is enterprise structure, not portal clicks.

Create the lab under `/tmp`, not under this course clone. The design document is ordinary markdown. You must be able to delete the directory when you clean up.

Keep the document named `harbormart-landing-zone.md`. Record decisions in that file. Do not paste secrets. This lab should not create any.

---

## Steps

1. Create a throwaway directory and enter it. Use a unique folder name so you do not collide with another lab. Confirm the path is under `/tmp`.

```bash
LAB_DIR="/tmp/day-11-landing-zone-lab-$$"
mkdir -p "$LAB_DIR"
cd "$LAB_DIR"
pwd
```

2. Create the empty design document. You will fill it in the next steps. Confirm the file exists before you write the architecture.

```bash
touch harbormart-landing-zone.md
ls
```

3. Write the company and identity section. HarborMart is one company. On Azure, that identity boundary is one Microsoft Entra ID tenant. On AWS, it is one AWS Organization. Say who authenticates: users, groups, applications, and service principals or IAM principals. Say that a tenant is not a subscription, and an Organization is not an account.

Write at least one short paragraph. Name the fictional tenant or Organization. Do not leave identity as a heading with no text.

4. Write the governance section. On Azure, place a root management group for HarborMart. Under it, create Production, Non-Production, and Security branches. On AWS, use Organizational Units for the same branches. List five central guardrails: allowed regions, required tags, mandatory logging, who may create subscriptions or accounts, and a ban on risky public exposure. Leave instance size and inner workload layout to application teams.

5. Write the environment isolation section. Give HarborMart three isolation units: Dev, UAT, and Production. On Azure those units are subscriptions. On AWS those units are accounts. Place Dev and UAT under the Non-Production governance branch. Place Production under the Production branch. Put a Security or logging subscription or account under Security. State that Production gets stronger access control and change process than Dev.

6. Write resource groups for one application. HarborMart runs a catalog API. Place the App Service or compute, the database, the storage account or bucket wrapper, and monitoring in one application resource group when they share a lifecycle. Say that a resource group organizes resources. It is not a subscription-level security boundary. It is not a region.

Choose a primary region for users in India. Record latency, data residency, service availability, and cost as the reasons. Place Production compute across more than one availability zone.

7. Write Terraform state boundaries that match ownership. Give Network its own project and state. Give Platform its own project and state. Give the catalog API its own project and state. Split Production state from Dev and UAT state. A Dev pipeline identity must not write Production state. Do not put the whole company in one state file.

8. Add the Azure versus AWS mapping table. Keep the same jobs on both sides. Isolation, governance grouping, and guardrails must each have one row.

```markdown
| Job | Azure | AWS |
|:--|:--|:--|
| Identity boundary | Entra ID tenant | Organization |
| Governance grouping | Management groups | Organizational Units |
| Guardrails | Azure Policy | Service Control Policies |
| Isolation unit | Subscription | Account |
| Lifecycle grouping | Resource group | Tags and accounts (no exact RG equivalent) |
| Workload | Resource | Resource |
```

Write two sentences under the table. A subscription and an account are equivalent isolation units. They are not identical services. Azure Policy is not identical to a Service Control Policy.

9. Add an ownership and access paragraph. Network owns hub connectivity. Platform owns shared compute. Security owns policy and logging. The catalog team owns the catalog resources. Developers write in Dev. They do not hold unrestricted Production administration. Security gets read across environments so they can audit.

10. Add the Lead Architect close. Use the sentence pattern from this Day: this is the hierarchy, these are the governance boundaries, these are the environment boundaries, these teams own these resources, these Terraform states match those lines, these pipelines may change these environments.

---

## Verify

Read `harbormart-landing-zone.md` as if you are on a call with a Lead Architect. You should name the identity boundary, the three environment isolation units, and the Terraform state split without opening the lesson notes.

Check these points:

- The document names one tenant or one Organization for HarborMart.
- Governance has Production, Non-Production, and Security branches, plus five central rules.
- Dev, UAT, and Production each have their own subscription or account.
- One application resource group lists resources that share a lifecycle. The text says a resource group is not a region.
- Terraform state is split by Network, Platform, application, and environment.
- The Azure versus AWS table is complete. The note under it says the mapping is equivalent, not identical.
- The close uses the Lead Architect sentences.

If a section is only a heading, fill it before you stop. A landing zone design with empty headings is not a design.

---

## Break and fix

Copy the finished document to a broken variant so you can compare the two. Keep the good design. Do not overwrite it until you have written the blast-radius note.

```bash
cp harbormart-landing-zone.md harbormart-landing-zone-broken.md
```

Open `harbormart-landing-zone-broken.md`. Put Dev and Production in one subscription or one account. Keep UAT separate if you want, or fold it in. Leave resource group names as `rg-catalog-dev` and `rg-catalog-prod` so the labels still look tidy. Labels are not the isolation boundary.

Write a short section at the bottom of the broken file titled `Blast radius`. Answer these questions in prose, not as a checklist:

- Who can delete a Production database if their identity already has write on the shared subscription or account?
- What happens to Production quotas and bills when a Dev experiment runs away?
- If one Terraform state now holds Dev and Production, how far does one apply reach?

Then rewrite the isolation section in `harbormart-landing-zone.md` so Dev and Production are separate again. Add a paragraph that states why the shared subscription or account grew the blast radius. A Dev mistake could reach Production resources. Role assignments mixed. Cost reports mixed. One apply could plan against both environments. Separate isolation units keep the failure inside one environment.

Do not leave the broken design as the main document. The main file must keep Dev, UAT, and Production apart. Keep `harbormart-landing-zone-broken.md` as the evidence of the mistake.

---

## Clean up

This lab created markdown only. There is no cloud resource to destroy. There is no Terraform state file.

If you want to keep the design, copy `harbormart-landing-zone.md` out of the temp directory first. Then leave the lab directory and delete it.

```bash
cd /tmp
rm -rf "$LAB_DIR"
```

Do not copy the files into the course repository unless you are submitting homework through a path your instructor named. Do not run `az group delete` or `aws organizations` commands. You created no subscriptions, accounts, or resource groups in a cloud.

---

## Interview story

I design the landing zone before I place a VM. HarborMart gets one identity boundary, a governance layer with Production and Non-Production branches, and separate Dev, UAT, and Production subscriptions or accounts. Resource groups hold resources that share a lifecycle. They are not a region and not the isolation unit. Terraform state follows those same ownership and environment lines, so a Dev pipeline cannot write Production state. I mapped Azure management groups, subscriptions, and Policy to AWS OUs, accounts, and SCPs as equivalent jobs, not identical services. I then put Dev and Production in one subscription on purpose. Blast radius grew because access, billing, quotas, and one Terraform apply could all reach Production from a Dev change. I split them again so a mistake stays inside one environment.
