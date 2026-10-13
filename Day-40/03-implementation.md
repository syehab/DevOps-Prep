# Day 40 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 40 is the Lead architecture review. You do not add a new cloud service. You defend the ShopSphere platform the earlier Days already designed. The old lab wrote the review in `/tmp`. This lab writes it in **your ShopSphere repository** and adds a Lead-versus-Senior pass on the same facts.

Do not create Azure or AWS resources.

---

## Goal

Write `docs/shopsphere-architecture-review.md`. Answer seven review items with decision → why → alternative → trade-off: why AWS, why separate accounts, why EKS, why multi-AZ, why a private database, which identities exist, how you observe the shop. Name the Terraform state owner. Compute that a 60-minute regional failover **burns** a 99.9% monthly budget (43.2 minutes). Then break: state has no owner. Restore an owner and write the blast radius.

Time box: 45 to 75 minutes. Cost is **USD 0.00**.

---

## Capstone stage

| Path | Adds |
|:--|:--|
| `docs/shopsphere-architecture-review.md` | Seven items + state owner |
| `docs/shopsphere-architecture-review-broken.md` | Unowned-state blast radius |
| `docs/day-40-lead-vs-senior.md` | Same 503, two altitudes |

Day 30 is the pack. This Day is the defense. `drills/behavioral/04-lead-vs-senior/` is the spoken twin.

---

## What you need

```bash
python3 --version
```

No cloud CLI. If Day 30's document exists, reuse it. Do not start from a product list.

---

## Cost

| Path | Estimated USD |
|:--|:--|
| Markdown + one Python line | **0.00** |
| Hot standby EKS in a second region (if you later applied it) | **control-plane hours** — refuse unless the business pays |

Do not write "INR 0" on a dual-cluster path.

---

## Steps

1. Open ShopSphere.

```bash
mkdir -p docs
python3 -c 'print(30*24*60*0.001)'
```

Expected: `43.2`. A 60-minute region failover exceeds that budget. Write that sentence under multi-AZ.

2. Header in `docs/shopsphere-architecture-review.md`: orders and payments are critical; browse is important; analytics is lower. NFRs: 99.9% availability, RPO 15 minutes, RTO 60 minutes, Dev / UAT / Prod, AWS for this review, no public database, least privilege, metrics + logs + traces.

3. Seven items, each with the four-line template.

**Why AWS.** Fit to skills and existing accounts. Alternative: Azure subscriptions + AKS. A second cloud is cost, not a feature.

**Why separate accounts.** Security, infra, Dev, UAT, Prod. Alternative: one account with tidy names. Tidy names are not isolation.

**Why EKS.** Kubernetes platform need (Days 17 / 27). Alternative: ECS / Container Apps if those APIs are absent. "Production-grade" is not a reason.

**Why multi-AZ.** 99.9% needs two zones. Alternative: one AZ. Multi-AZ is **not** multi-region. A 60-minute regional RTO still needs the Day 39 / drill 02 story. 60 > 43.2, so one region event burns the month.

**Why a private database.** No IGW route to 5432. App Security Group only. Path: user → DNS → LB / Ingress → Service → Ready endpoints → Pod → API → private Postgres.

**Identities.** Human, Terraform, deploy, runtime, Kubernetes API. Runtime is IRSA / Pod Identity or Workload Identity. No keys in the Pod. Name who applies Prod, who deploys the app, who reads Prod secrets.

**Observability.** RED + checkout / payment. Page on user symptoms. CPU-only dashboards fail the review.

4. Terraform state: remote, locked (`use_lockfile` or Azure lease), versioned, split `prod/network`, `prod/eks`, `prod/data`. Owner: the Prod apply role in the infra pipeline after plan review. Developers do not apply Prod from a laptop.

5. Write `docs/day-40-lead-vs-senior.md`. Same catalog 503 as `drills/behavioral/04-lead-vs-senior/`. Senior: get, describe, logs, restore. Lead: the Git gate that stops the next bad command, keep the burn-rate page.

---

## Verify

- Seven items use the template.
- `43.2` and "60 minutes burns the month" appear.
- Multi-AZ is not called multi-region.
- State has a named owner and three keys.
- Lead vs Senior has both altitudes.

---

## Break and fix

```bash
cp docs/shopsphere-architecture-review.md docs/shopsphere-architecture-review-broken.md
```

Remove the state owner. Write blast radius: who can `state rm`, who can apply a destroy, how you recover a version if no one owns the backend. Restore the owner in the main file.

Second break: defend EKS with "it is production-grade." Replace with the platform need.

---

## Stretch

- Speak the Lead answer in 90 seconds (behavioral drill 04).
- Add Infracost / budget as the cost evidence Day 39 asks for.

---

## Clean up

Keep the markdown. You created no cloud resources.

---

## Interview story

**Situation:** A Lead review asked me to defend ShopSphere, not to add a product. **Task:** Seven decisions plus who owns state. **Action:** I kept AWS because the org already runs IAM and EKS, split accounts, placed nodes in two AZs, and said a 60-minute region failover burns the 43.2-minute 99.9% budget. I named the Prod apply role as the state owner and wrote a Senior restore plus a Lead Git gate for the same 503. **Result:** I can refuse a second cloud and a public database without sounding like a brand.

---

## Self-score checklist

- [ ] Seven items are complete.
- [ ] 43.2 and the RTO burn sentence are present.
- [ ] State owner is a role, not "the team."
- [ ] Lead vs Senior has both altitudes.

**Executed:** `python3 -c 'print(30*24*60*0.001)'` → `43.2`. **Not executed:** live Lead review, dual-region apply.
