# DevOps-Prep

Day-by-day lessons for Senior / Lead DevOps preparation. Simple English, mental models, Azure and AWS side by side.

## Start here

1. **New to the material?** Open [Day-01/01-concepts.md](Day-01/01-concepts.md), then follow Day-01 through Day-41 in order.
2. **Preparing for interviews?** Open [jd-insights/README.md](jd-insights/README.md). Short pattern cards built from real job descriptions, each linking back to the Day lessons that teach it.
3. **Hands-on track?** Copy the ShopSphere capstone (see below). Each `Day-NN/03-implementation.md` adds one stage to **that** repository. Do not restart the product in `/tmp`.
4. **Two files for the same Day?** Days 8, 9, 10, and 24 still have extra copies at the repo root. Study these folders first: [Day-08](Day-08/01-concepts.md), [Day-09](Day-09/01-concepts.md), [Day-10](Day-10/01-concepts.md), and [Day-24](Day-24/01-concepts.md) (the files the [INDEX](jd-insights/INDEX.md) links). The other copies remain for reference.

## How to use a Day folder

Each `Day-NN/` folder has three files. Use them in this order.

1. **01-concepts.md** — the lesson. Read the mental model, explanations, diagrams, and Remember / Understand / Look-up callouts.
2. **02-questions-and-answers.md** — practice items, exercises, exit checks, and interview questions. Write your own answer first. Then open the Answer block.
3. **03-implementation.md** — a 30 to 90 minute lab. Follow the steps. Check Verify. Do Break and fix. Then Clean up so you do not leave paid resources.

Read the concepts. Answer the questions. Do the lab. That is one Day.

> **Remember:** The Day lessons are the curriculum. jd-insights tells you what employers ask and where to study it.

## Hands-on track

The concepts files teach the model. The labs build **one product**: ShopSphere. You own that Git repository. This course clone stays the lesson.

### How to use the capstone

1. Open [capstone/README.md](capstone/README.md). If that folder is not on `main` yet, it is the ShopSphere scaffold PR. Copy `capstone/shopsphere-starter/` into a repository you own, for example `~/src/shopsphere`.
2. Pin tools from [capstone/VERSIONS.md](capstone/VERSIONS.md). Terraform **1.16.5** and `hashicorp/azurerm` **5.9.0** are the Azure pins.
3. Read [capstone/STAGE-MAP.md](capstone/STAGE-MAP.md). Each Day row names the ShopSphere path, the cloud SKU, the USD estimate, and the local fallback.
4. Open that Day's `03-implementation.md`. The **Capstone stage** table is the file list. Work in ShopSphere. Commit when Verify passes.

Duplicate lesson pairs are **progression**, not copies. Day 23 is harder than Day 13 (Dockerfile → golden image / Azure Container Apps). Day 33 is harder than Day 29 (OIDC backend → same-digest GitOps promotion). Day 36 is harder than Day 10. Day 35 is harder than Day 20. Day 38 is harder than Day 9.

### Cost rules

Read [capstone/COST.md](capstone/COST.md) before any cloud command.

1. Create a **budget alert first**. Do not apply AKS, EKS, or a load balancer before the budget exists.
2. Stay **under USD 5 per session** on the smallest SKU the Day names. Destroy before you walk away.
3. **No NAT Gateways** in these labs. If a plan would create one, stop and change the code.
4. Never write "cost stays at INR 0" (or ₹0) on a path that can bill. Storage, nodes, public IPs, Container Apps, and Private Endpoints cost money.
5. If you have no cloud account, or you cannot destroy within two hours, use the **local fallback** (`kind`, Docker, Terraform `mock_provider`, Azurite, LocalStack). Write the limit in your notes. `kind` is not AKS.

### Drills

Timed packs sit next to the Days. Use them after the matching lab, not instead of it.

| Pack | Use after |
|:--|:--|
| `drills/kubernetes-broken-cluster/` | Days 14–17, 34, 41 |
| `drills/system-design/` | Days 21, 30, 40 |
| `drills/scripting/` | Days 2, 4 |
| `drills/behavioral/` | Days 21, 40 |
| `drills/tf-live-debug/` | Days 8–10, 25, 36 |

### Lab shape

Every rewritten lab uses the same headings: Goal, Capstone stage, What you need, Cost, Steps (real commands, pinned versions), Verify, Break and fix (at least two failures), Stretch, Clean up, Interview story (STAR), Self-score checklist. Commands the author ran say **Executed**. The rest say **Not executed**.

If you have little time, finish the current Day cleanly. Do not skip Clean up.

## Days

| Day | Open |
|:--|:--|
| 01 | [Day-01/01-concepts.md](Day-01/01-concepts.md) |
| 02 | [Day-02/01-concepts.md](Day-02/01-concepts.md) |
| 03 | [Day-03/01-concepts.md](Day-03/01-concepts.md) |
| 04 | [Day-04/01-concepts.md](Day-04/01-concepts.md) |
| 05 | [Day-05/01-concepts.md](Day-05/01-concepts.md) |
| 06 | [Day-06/01-concepts.md](Day-06/01-concepts.md) |
| 07 | [Day-07/01-concepts.md](Day-07/01-concepts.md) |
| 08 | [Day-08/01-concepts.md](Day-08/01-concepts.md) |
| 09 | [Day-09/01-concepts.md](Day-09/01-concepts.md) |
| 10 | [Day-10/01-concepts.md](Day-10/01-concepts.md) |
| 11 | [Day-11/01-concepts.md](Day-11/01-concepts.md) |
| 12 | [Day-12/01-concepts.md](Day-12/01-concepts.md) |
| 13 | [Day-13/01-concepts.md](Day-13/01-concepts.md) |
| 14 | [Day-14/01-concepts.md](Day-14/01-concepts.md) |
| 15 | [Day-15/01-concepts.md](Day-15/01-concepts.md) |
| 16 | [Day-16/01-concepts.md](Day-16/01-concepts.md) |
| 17 | [Day-17/01-concepts.md](Day-17/01-concepts.md) |
| 18 | [Day-18/01-concepts.md](Day-18/01-concepts.md) |
| 19 | [Day-19/01-concepts.md](Day-19/01-concepts.md) |
| 20 | [Day-20/01-concepts.md](Day-20/01-concepts.md) |
| 21 | [Day-21/01-concepts.md](Day-21/01-concepts.md) |
| 22 | [Day-22/01-concepts.md](Day-22/01-concepts.md) |
| 23 | [Day-23/01-concepts.md](Day-23/01-concepts.md) |
| 24 | [Day-24/01-concepts.md](Day-24/01-concepts.md) |
| 25 | [Day-25/01-concepts.md](Day-25/01-concepts.md) |
| 26 | [Day-26/01-concepts.md](Day-26/01-concepts.md) |
| 27 | [Day-27/01-concepts.md](Day-27/01-concepts.md) |
| 28 | [Day-28/01-concepts.md](Day-28/01-concepts.md) |
| 29 | [Day-29/01-concepts.md](Day-29/01-concepts.md) |
| 30 | [Day-30/01-concepts.md](Day-30/01-concepts.md) |
| 31 | [Day-31/01-concepts.md](Day-31/01-concepts.md) |
| 32 | [Day-32/01-concepts.md](Day-32/01-concepts.md) |
| 33 | [Day-33/01-concepts.md](Day-33/01-concepts.md) |
| 34 | [Day-34/01-concepts.md](Day-34/01-concepts.md) |
| 35 | [Day-35/01-concepts.md](Day-35/01-concepts.md) |
| 36 | [Day-36/01-concepts.md](Day-36/01-concepts.md) |
| 37 | [Day-37/01-concepts.md](Day-37/01-concepts.md) |
| 38 | [Day-38/01-concepts.md](Day-38/01-concepts.md) |
| 39 | [Day-39/01-concepts.md](Day-39/01-concepts.md) |
| 40 | [Day-40/01-concepts.md](Day-40/01-concepts.md) |
| 41 | [Day-41/01-concepts.md](Day-41/01-concepts.md) |
