# Day 21 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 21 is the Senior/Lead design mock. The old lab wrote a one-pager in `/tmp` and forbade every tool. This lab still forbids a cloud apply. It lands the one-pager in **your ShopSphere repository**, runs one capacity figure, and scores the result with a rubric you can reuse on Day 30 and in `drills/system-design/`.

---

## Goal

Write `docs/design-mock-21.md` for ShopSphere: Angular or static frontend, catalog API, PostgreSQL, payment API, object storage. Six decisions use the template requirement → decision → why → alternative → trade-off. Cover network, identity, IaC, CI/CD, Kubernetes, observability. Compute in-flight catalog requests at 500 RPS and 50 ms. Then break: one subscription for everything. Restore separate Dev, UAT, and Prod.

Time box: 45 to 75 minutes. Cost is **USD 0.00**.

---

## Capstone stage

| Path | Adds |
|:--|:--|
| `docs/design-mock-21.md` | Six decisions + diagram + capacity |
| `docs/design-mock-21-broken.md` | Shared-subscription blast radius |
| `docs/day-21-score.md` | Rubric 0–5 |

If `drills/system-design/01-shopsphere-web/` exists in your clone, treat this Day as the **graded** version of that drill.

---

## What you need

```bash
python3 --version
```

No Azure, AWS, Terraform, or kubectl. This is architecture judgment plus one local number.

---

## Cost

| Path | Estimated USD |
|:--|:--|
| Markdown + one Python line | **0.00** |
| AKS / EKS if you applied the design later | **2.00–5.00 / session** (do not apply today) |

Do not write "INR 0" on the later cloud path.

---

## Steps

1. Open ShopSphere.

```bash
mkdir -p docs
```

2. Compute the capacity figure. Little's law: `L = λW`.

```bash
python3 -c 'print(500 * 0.050)'
```

Expected: `25.0`. That is **in-flight requests**, not Pod count. You still run at least two replicas. Copy the command output into the design.

3. Write `docs/design-mock-21.md`. Header: one Entra tenant, three subscriptions (Dev, UAT, Prod), who may apply Production, Terraform state per environment.

Template for every decision:

```text
Requirement → Decision → Why → Alternative → Trade-off
```

**Network.** Private API → Postgres. Users enter through Front Door / App Gateway (or CloudFront / ALB). Troubleshooting chain: DNS, IP, route, security, port, service, application.

**Identity.** No secrets in Git. Split Developer, CI, Terraform, runtime, human Prod. Runtime uses Workload Identity / IRSA. CI must not read Production secrets.

**IaC.** Modules for network, cluster, database, registry, monitoring. Environment folders pass CIDR and SKU. Separate state. Checks: `fmt`, `validate`, `plan`, approved apply.

**CI/CD.** Build once. Promote the same digest. Split build identity from deploy identity. Approve Production.

**Kubernetes.** AKS (or EKS) for Prod if you need the API. `kind` for the lab. HPA + PDB later (Day 34). Do not design a 10-node cluster for v1.

**Observability.** RED on `GET /catalog`. 99.9% SLO. Day 20 / Day 35 for the stack. Do not page on CPU only.

4. Draw the path:

```text
User → DNS → Front Door → App Gateway / ALB → API (AKS/EKS) → private Postgres
Browser → CDN → Blob / S3
```

5. Score yourself in `docs/day-21-score.md` with this table (same idea as `drills/system-design/RUBRIC.md`):

| Score | Meaning |
|:--|:--|
| 0 | Product list |
| 3 | Four decisions + one number + one failure |
| 4 | Alternatives, trade-offs, blast radius, rollback |
| 5 | You refuse one popular extra (mesh, second region, Kafka) with a reason |

A Senior pass is **4**.

---

## Verify

- Six decisions use the five-line template.
- `python3 -c 'print(500 * 0.050)'` is in the notes as 25.
- Dev / UAT / Prod are separate subscriptions in the main file.
- You can present without opening the lesson.

---

## Break and fix

```bash
cp docs/design-mock-21.md docs/design-mock-21-broken.md
```

Put Dev, UAT, and Prod in one subscription. Write blast radius: who deletes Prod data, who pays for a Dev runaway, how far one apply reaches. Restore the main file to three subscriptions.

Second break: replace the 25 with "we will scale later." Put 25 back. A mock without a number is a slogan.

---

## Stretch

- Run `drills/system-design/01-shopsphere-web/` as a second timed pass.
- Add the 43.2-minute 99.9% monthly budget (`30*24*60*0.001`).

---

## Clean up

Keep the markdown. You created no cloud resources.

---

## Interview story

**Situation:** The Senior mock asked for ShopSphere in one sitting. The old homework never left `/tmp`. **Task:** Produce a one-pager I can defend. **Action:** I wrote six decisions with alternatives, used Little's law for 500 RPS at 50 ms (25 in-flight), and kept three subscriptions. I broke the design with one shared subscription and wrote the blast radius. **Result:** I can start at the user path, name the isolation unit, and refuse a service mesh for v1.

---

## Self-score checklist

- [ ] Six decisions are complete.
- [ ] Capacity 25 is in the file.
- [ ] Broken file shows the shared-subscription blast radius.
- [ ] Self-score is 4 or I wrote the gap.

**Executed:** `python3 -c 'print(500 * 0.050)'` → `25.0`. **Not executed:** cloud apply, live mock interview, `drills/system-design/` (separate pack).
