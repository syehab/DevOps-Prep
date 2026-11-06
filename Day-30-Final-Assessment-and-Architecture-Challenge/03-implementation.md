# Day 30 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 30 is the Senior/Lead assessment. The old lab wrote twenty sections in `/tmp`. This lab writes the same twenty sections in **your ShopSphere repository**, adds two numbers you can defend, and scores the pack with the Day 21 rubric. Do not apply cloud resources.

---

## Goal

Write `docs/Senior-DevOps-Production-Architecture.md` with all twenty sections this Day names. Use requirement → decision → reason → trade-off → alternative. Compute (1) 99.9% monthly error budget in minutes and (2) in-flight catalog requests at 500 RPS × 50 ms. Then break: Dev, UAT, and Production share one account. Restore three accounts and write the blast radius.

Time box: 60 to 90 minutes. Cost is **USD 0.00**.

---

## Capstone stage

| Path | Adds |
|:--|:--|
| `docs/Senior-DevOps-Production-Architecture.md` | Twenty sections |
| `docs/Senior-DevOps-Production-Architecture-broken.md` | Shared-account blast radius |
| `docs/day-30-score.md` | Rubric + the two numbers |

Day 21 was the one-pager. This Day is the full pack. Day 40 is the Lead defense of the same system. `drills/system-design/` is timed practice for the same muscle.

---

## What you need

```bash
python3 --version
```

No Azure, AWS, Terraform, Docker, or kubectl. Do not copy the lesson text. Write from the map you already built.

---

## Cost

| Path | Estimated USD |
|:--|:--|
| Markdown + two Python lines | **0.00** |
| If you later applied this design at lab SKU | **2.00–5.00 / session** for one small cluster; NAT extra — do not apply today |

Do not write "INR 0" on the later cloud path.

---

## Steps

1. Open ShopSphere.

```bash
mkdir -p docs
```

2. Compute the two numbers.

```bash
python3 -c 'print("budget_min", 30*24*60*0.001); print("inflight", 500*0.050)'
```

Expected: `budget_min 43.2` and `inflight 25.0`. Copy both into the observability and HA sections.

3. Write the twenty sections in `docs/Senior-DevOps-Production-Architecture.md`. Each section is prose, not an empty heading.

1. Business requirements — Dev / UAT / Prod in three accounts (Azure: subscriptions). Who applies Prod. State per environment.
2. Architecture diagram — start at users. Refuse mesh / Kafka unless a requirement needs them.
3. Azure implementation — Entra, management groups, subscriptions, VNet, Key Vault, pipeline, ACR, Container Apps or AKS if you need Kubernetes.
4. AWS implementation — Organization, OUs, accounts, VPC, Secrets Manager, CodePipeline or GitHub Actions, ECR, ECS or EKS if you need Kubernetes.
5. Network design — public user path, private database. Chain: DNS, IP, route, security, port, service, application.
6. Identity model — developer, pipeline, runtime, Terraform. Workload Identity / IRSA. No standing Prod admin for developers.
7. Security model — protect `main`, scan the image, pin a digest, approve Prod. AuthN vs AuthZ.
8. Terraform structure — app pipeline ≠ infra pipeline. Modules + `dev/` `uat/` `prod/` + remote lock (`use_lockfile` on S3; Azure Storage + lease on Azure).
9. CI/CD architecture — build once, promote the digest. Git SHA → run → digest → workload.
10. Deployment strategy — approval + health. Rollback of app ≠ rollback of schema.
11. Secrets architecture — Key Vault / Secrets Manager. Not Git, not the image, not the log.
12. Observability architecture — RED + 43.2-minute budget + page on user symptoms. Day 20 / 35.
13. High-availability design — two replicas on one node is not HA. Process, node, zone. In-flight 25 is concurrency, not replica count.
14. Disaster-recovery approach — RPO and RTO named. A restore test, not only a diagram. Day 39.
15. Cost controls — name NAT, idle non-prod, log retention. Right-size. Do not drop Prod HA to save a few dollars.
16. Governance model — management groups / OUs, Policy / SCP, tags, budgets. Day 11 / 26.
17. Failure scenarios — post-deploy 5xx, pipeline-success 503, Terraform drift. Evidence first.
18. Troubleshooting workflows — LB → target → Pod → process → digest vs SHA. `UnknownHostException` → DNS.
19. Architecture decisions and trade-offs — at least four full templates.
20. Future scaling — what you refuse now (second region, Kafka) and the trigger that would add it.

4. Score in `docs/day-30-score.md`. Senior pass is **4** on the Day 21 table. Lead-flavored **5** if you refuse one popular extra with a reason.

---

## Verify

- All twenty headings have prose.
- `43.2` and `25.0` appear.
- Azure and AWS sections are the same design, different names.
- Compute choice is from workload and team, not "Kubernetes is better."
- Main file keeps three accounts.

---

## Break and fix

```bash
cp docs/Senior-DevOps-Production-Architecture.md docs/Senior-DevOps-Production-Architecture-broken.md
```

Put Dev, UAT, and Prod in one account. Write blast radius: delete Prod data, Dev runaway bills, one apply against both states. Restore three accounts in the main file.

Second break: set replica count = 25 because in-flight is 25. Restore: 25 is concurrency. Replicas start at two (or three) and scale on RPS and CPU, not on Little's law alone.

---

## Stretch

- Time yourself on `drills/system-design/02-multi-region-dr/` (RPO 15 / RTO 60).
- Add `14.4 * 0.001 = 0.0144` as the fast burn-rate page threshold.

---

## Clean up

Keep the markdown. You created no cloud resources.

---

## Interview story

**Situation:** The assessment asked for a production ShopSphere I could defend on Azure and AWS. **Task:** Twenty sections, two numbers, one blast-radius break. **Action:** I wrote the pack in Git, used 43.2 minutes of 99.9% budget and 25 in-flight at 500 RPS, chose a managed container platform unless the org already runs Kubernetes, and split accounts so a Dev apply cannot touch Prod state. **Result:** I can map subscription ↔ account and say why a rebuild in Prod is not a promotion.

---

## Self-score checklist

- [ ] Twenty sections are filled.
- [ ] 43.2 and 25.0 are in the file.
- [ ] Broken file shows the shared-account blast radius.
- [ ] Self-score is 4 or I wrote the gap.

**Executed:** `python3 -c` budget and in-flight. **Not executed:** cloud apply, live assessment interview.
