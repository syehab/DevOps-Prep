# Day 26 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 26 teaches AWS enterprise structure as Organization, Organizational Units, and accounts. An AWS account is the isolation unit. It is the counterpart of an Azure subscription. This lab produces a markdown design document for ShopSphere. You name the Organization, the OUs, Production and NonProduction accounts, a security and logging account, and a network hub. You do not create AWS accounts, VPCs, or billable resources.

Do not run `aws organizations create-account`. Do not create a VPC, Transit Gateway, or IAM user. Cost stays at ₹0. Work in a temporary directory. Do not write the document inside the DevOps-Prep course repository.

---

## Goal

Write one AWS Organization design document for ShopSphere. The document must name one Organization, OUs for Production, NonProduction, Security, and Infrastructure, separate Production and NonProduction workload accounts, a security or log-archive account, and a network hub in a network account.

Include one table that maps an Azure subscription to an AWS account. Map the other Azure layers that this Day already taught. Then break the design on purpose: put Dev and Production in the same AWS account. Rewrite the document so they are separate again, and write why the shared account grew the blast radius.

Time box: 45 to 75 minutes. Cost stays at ₹0. Stop when the document has every required section, the break-and-fix note explains blast radius, and you can present the Organization in the Lead sentences from this Day.

---

## What you need

You need a text editor and a shell. You do not need an AWS account, an Azure subscription, Terraform, or cloud credentials. This is a concept-only lab. The lesson is enterprise structure, not the AWS console.

AWS CLI is optional and read-only. If `aws organizations describe-organization` already works in your shell, you may inspect the current Organization and list accounts. If the command fails, write `aws not logged in` in your notes and skip every AWS CLI step. Do not guess flags. Do not create accounts, OUs, VPCs, or IAM users.

Create the lab under `/tmp`, not under this course clone. The design document is ordinary markdown. You must be able to delete the directory when you clean up.

Keep the document named `shopsphere-aws-org.md`. Record decisions in that file. Do not paste account IDs you must not share, access keys, or secrets. This lab should not create any.

Use only these AWS CLI commands, and only if describe-organization already succeeded. Both commands already appear in this Day. They do not create resources:

```bash
aws organizations describe-organization
aws organizations list-accounts
```

---

## Steps

1. Create a throwaway directory and enter it. Use a unique folder name so you do not collide with another lab. Confirm the path is under `/tmp`.

```bash
LAB_DIR="/tmp/day-26-aws-org-lab-$$"
mkdir -p "$LAB_DIR"
cd "$LAB_DIR"
pwd
```

2. Create the empty design document. You will fill it in the next steps. Confirm the file exists before you write the architecture.

```bash
touch shopsphere-aws-org.md
ls
```

3. Write the company and Organization section. ShopSphere is one company. On AWS, that identity and governance envelope is one AWS Organization. The management account owns Organizations, billing, and organization controls. It is not a workload account. Say who authenticates: humans through IAM Identity Center and a corporate identity provider, workloads through IAM roles. Say that an Organization is not an account, and an account is not a VPC.

Write at least one short paragraph. Name the fictional Organization. Do not leave identity as a heading with no text. Do not place an internet-facing production application in the management account.

4. Write the OU section. Place four OUs under the Organization: Production, NonProduction, Security, and Infrastructure. An OU groups accounts so you can attach Service Control Policies. An OU is not a network boundary. It is not a VPC.

List five central guardrails at OU scope: approved Regions, a ban on public RDS, mandatory CloudTrail, who may create accounts, and stronger human access in Production than in Dev. Leave instance size and inner workload layout to application teams.

Copy this block into the notes, then add one sentence in your own words that says why you did not make one OU per team:

```text
Organization
 ├── Security OU
 ├── Infrastructure OU
 ├── Production OU
 └── NonProduction OU
```

5. Write the account section. Accounts are the isolation units. Place a Production workload account under Production. Place Dev and UAT workload accounts under NonProduction. Place a Security account and a Log Archive account under Security. Place a Network account and a Shared Services account under Infrastructure.

State that Production gets stronger access control and change process than Dev. Separate Production and NonProduction accounts so IAM, billing, quotas, and blast radius do not sit in one place. Do not use three VPCs in one account as the Production boundary for this design.

6. Write the network hub. The Network account holds Transit Gateway. Production, UAT, Shared Services, and Security VPCs attach to that hub. This is the same hub idea as Azure hub-and-spoke. Workloads stay in their own VPCs. Public entry for internet-facing apps is an Application Load Balancer in public subnets. Application and database subnets stay private.

Write one short paragraph that names the hub owner. The network team owns Transit Gateway. Application teams do not peer every VPC to every other VPC.

7. Add the Azure versus AWS mapping table. Keep the same jobs on both sides. An Azure subscription maps to an AWS account. That is the isolation unit this lab must show.

```markdown
| Job | Azure | AWS |
|:--|:--|:--|
| Identity boundary | Entra ID tenant | Organization |
| Governance grouping | Management groups | Organizational Units |
| Guardrails | Azure Policy | Service Control Policies |
| Isolation unit | Subscription | Account |
| Lifecycle grouping | Resource group | Tags and accounts (no exact RG equivalent) |
| Central connectivity | Hub-spoke / Virtual WAN | Transit Gateway |
| Workload | Resource | Resource |
```

Write two sentences under the table. A subscription and an account are equivalent isolation units. They are not identical services. Azure Policy is not identical to a Service Control Policy.

8. Add an ownership and access paragraph. Network owns the hub. Platform owns shared services. Security owns Log Archive and organization detective controls. ShopSphere application teams own workload accounts. Developers write in Dev. They do not hold unrestricted Production administration. Security gets read on logs across environments so they can audit. CI/CD assumes an IAM role in the target account. It does not store long-lived access keys.

9. Optional AWS CLI path. Run this step only if `aws organizations describe-organization` already succeeded. List accounts. Record that you inspected an existing Organization. Do not create an OU, account, or VPC.

```bash
aws organizations describe-organization
aws organizations list-accounts
```

If the command fails, write `aws not logged in` and continue. The markdown design is the required deliverable.

10. Add the Lead close. Use this sentence pattern from this Day: this is the Organization, these are the OUs, these are the account boundaries, this is the network hub, this is the security and logging account, this Azure subscription maps to this AWS account, these pipelines may change these accounts.

---

## Verify

Read `shopsphere-aws-org.md` as if you are on a call with a Lead Architect. You should name the Organization, the Production versus NonProduction account split, the security and logging account, and the network hub without opening the lesson notes.

Check these points:

- The document names one AWS Organization. The management account is not a workload account.
- OUs include Production, NonProduction, Security, and Infrastructure. The text says an OU is not a VPC.
- Production and NonProduction are separate AWS accounts, not two VPCs in one account.
- A Security or Log Archive account holds audit logs. Workload admins cannot delete that archive.
- A Network account holds Transit Gateway as the hub.
- The Azure versus AWS table maps subscription to account. The note under it says the mapping is equivalent, not identical.
- The close uses the Lead sentences.
- If AWS CLI ran, you only described the Organization and listed accounts. You created nothing.
- If AWS CLI did not run, the notes say `aws not logged in` and the sketch is still complete.

If a section is only a heading, fill it before you stop. An Organization design with empty headings is not a design.

---

## Break and fix

Copy the finished document to a broken variant so you can compare the two. Keep the good design. Do not overwrite it until you have written the blast-radius note.

```bash
cp shopsphere-aws-org.md shopsphere-aws-org-broken.md
```

Open `shopsphere-aws-org-broken.md`. Put Dev and Production in one AWS account. Keep UAT separate if you want, or fold it in. Leave subnet names as `subnet-app-dev` and `subnet-app-prod` so the labels still look tidy. Labels are not the isolation boundary. One account still shares IAM, quotas, billing, and CloudTrail administration.

Write a short section at the bottom of the broken file titled `Blast radius`. Answer these questions in prose, not as a checklist:

- Who can delete a Production database if their identity already has write on the shared account?
- What happens to Production quotas and bills when a Dev experiment runs away?
- If one Terraform state now holds Dev and Production, how far does one apply reach?
- If that shared account is compromised, can an attacker erase the only copy of CloudTrail?

Then rewrite the account section in `shopsphere-aws-org.md` so Dev and Production are separate AWS accounts again. Add a paragraph that states why the shared account grew the blast radius. A Dev mistake could reach Production resources. Role assignments mixed. Cost reports mixed. One apply could plan against both environments. Separate accounts keep the failure inside one environment. Log Archive stays in its own account so evidence survives.

Do not leave the broken design as the main document. The main file must keep Dev, UAT, and Production apart. Keep `shopsphere-aws-org-broken.md` as the evidence of the mistake.

---

## Clean up

This lab created markdown only. There is no cloud resource to destroy. There is no Terraform state file. You did not create an AWS account.

If you want to keep the design, copy `shopsphere-aws-org.md` out of the temp directory first. Then leave the lab directory and delete it.

```bash
cd /tmp
rm -rf "$LAB_DIR"
```

Do not copy the files into the course repository unless you are submitting homework through a path your instructor named. Do not run `aws organizations create-account`, `aws ec2 create-vpc`, or `aws iam create-user`. You created no accounts, OUs, or VPCs in AWS.

---

## Interview story

I design the AWS Organization before I place a VPC. ShopSphere gets one Organization, OUs for Production, NonProduction, Security, and Infrastructure, and separate Dev, UAT, and Production accounts. A Security or Log Archive account holds CloudTrail so a compromised workload account cannot erase evidence. A Network account holds Transit Gateway as the hub. An Azure subscription maps to an AWS account as the isolation unit. I then put Dev and Production in one AWS account on purpose. Blast radius grew because access, billing, quotas, and one Terraform apply could all reach Production from a Dev change. I split them again so a mistake stays inside one environment. I did not create AWS resources, so cost stayed at zero.
