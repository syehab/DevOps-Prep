# Curriculum Audit vs JD Patterns

Date: 2026-10-01. Scope: every Day lesson was reviewed against the 9 JD pattern cards, graded for ease of learning per unit of effort. Days 1 to 21 were read in depth because JD demand hits them hardest; Days 22 to 41 were reviewed at structure level (opening, mental model placement, Remember anchors, exit checks). The grading lens is learning psychology: cognitive load (one model before details), dual coding (prose plus diagram), worked example then practice then recall, sticky Remember wording reused across files, and retrieval practice without scrolling.

---

## What is strong

The repo's biggest asset is that JD coverage is already complete, so this audit adds no new topics. Every one of the 9 patterns from real Senior and Lead JDs maps onto existing Day lessons, which means the work is polish, not construction. The top JD ask (Azure IaC plus pipelines) lands on Day-6, Day-8, Day-9, and Day-10, and those files are the best in the repo: a one-line goal, one mental model before any detail, timed sections that limit new ideas, and exit checks that force recall without scrolling. The Kubernetes core (Day-14, Day-15) uses the same build-break-fix loop the kubernetes-production card describes, which is exactly the worked-example-then-practice shape that transfers to interviews.

Retrieval practice is the repo's strongest habit and it is nearly universal: almost every Day ends with an "answer without looking" recall section. That habit was left untouched everywhere. The early Days (1 to 7) also keep a consistent voice (goal line, time boxes, Key idea and Senior thinking callouts), which lowers cognitive load because the learner never has to relearn the format.

## What was thin (fixed with small edits this pass)

Day-11 carries the landing zone theme, which is the signal Lead JDs grade hardest, but its one unifying mental model sat at the very bottom of the file. A learner met 19 numbered questions before seeing the picture they all fit into, and the file had no Azure to AWS table even though both hierarchies are its whole subject. The fix moves the model and the mapping table to the top (one model before details, dual coding), adds the paved-parking-lot Remember reused from the pattern card (spaced reuse), and links the card in one line.

Day-16 carries the GitOps and platform theme. Its content is senior-grade but its opening packed Helm, values, versioning, GitOps, and reconciliation into one long sentence, and the first Remember anchor did not appear until the final recall section, which is too late to help memory. The fix splits the opening into plain sentences and plants the two-loop Remember (CI loop builds things, CD loop applies things) at the exact point where GitOps is introduced, reusing the card's wording so the learner meets it twice in two places.

Day-20 carries the SRE and observability theme. It had good drills but no goal line, so the learner started in the middle of a dense paragraph, and its strongest alerting rule (symptoms page a human, causes go on dashboards) was implied across several paragraphs but never stated as one sticky line. The fix adds the goal, states that rule as a Remember reused from the card, and adds the small error-budget ladder to the SLO section so the SLI to SLO to budget chain is visible as a picture, not only as prose.

Agentic AI in DevOps, the newest JD theme, had no home in any Day at all; the pattern card could only point at generic loop lessons. The smallest honest fix was chosen: a short "where AI tools fit" note inside Day-4's pipeline-flow section with the fast-junior-engineer Remember from the card. No new section numbering, no topic dump, and the guardrail message matches what the JDs actually ask.

## Day-by-Day status

| Day | Status | Note |
|:--|:--|:--|
| 1 | strong | Concise map, tables, recall. Left alone. |
| 2 | strong | Layered runtime model, troubleshooting flow. Left alone. |
| 3 | strong | Request-journey model up front. Left alone. |
| 4 | edited | Strong base; added AI-in-the-loop note (agentic JD theme) plus card link. |
| 5 | strong | Branch and environment flow is clear. Left alone. |
| 6 | edited | Already clear; one-line JD cross-link only (top Azure ask). |
| 7 | strong | Risk-and-traffic framing, exercises. Left alone. |
| 8 | strong | Goal line, engine model, recently updated. Left alone. |
| 9 | strong | Module model up front, recently updated. Left alone. |
| 10 | strong | 7 Remember anchors, state workflow clear. Left alone. |
| 11 | edited | Model was buried at file end; moved up, added Azure to AWS table and card link. Second pass: unpacked the five-level hierarchy sentence into a level map. |
| 12 | edited | Second pass: goal line added, request-path model moved first, Azure to AWS mapping prose turned into a table. |
| 13 | edited | Second pass: goal line added, intro wall split into a list, Dockerfile instructions turned into a lookup table. |
| 14 | edited | Second pass: goal line stating the desired-state model, packed problem sentence unpacked into a list. Fourth pass: OOM defined in plain English at its first use in the course. Fifth pass: one-line link to the Kubernetes production card. |
| 15 | strong | Layered failure-boundary model. Left alone. |
| 16 | edited | Dense opening, Remember anchors arrived too late; fixed, added card link. |
| 17 | strong | Ownership-boundary model, AKS to EKS tables. Left alone. |
| 18 | strong | Identity chain model up front. Left alone. |
| 19 | edited | Second pass: goal line, six-stage chain as a diagram, mega-sentences split, jargon defined at first use, scanner table. |
| 20 | edited | No goal line, sticky alerting rule missing; fixed, added card link. |
| 21 | edited | Excellent capstone; one-line Lead-vs-Senior card link only. |
| 22-25 (Azure track) | edited | Third pass: full line audit. Goal lines added to 22 and 23; jargon defined in plain English at first use across all four (service principal, blast radius, SKU, PaaS, revision, cold start, CIDR, stateful, Layer 4, NVA, SAST/SCA, drift). Structure was already strong and left alone. |
| 26-29 (AWS track) | edited | Third pass: full line audit. Jargon defined at first use (ARN, instance profile, stateful, Transit Gateway, OIDC, AMI, CNI, ephemeral, EBS/EFS/S3, ENI, Elastic IP, PrivateLink, hosted zone, STS). Day-29 also had seven broken machine citation artifacts rendering as garbage mid-sentence; removed. Fifth pass: Day-26 gained a one-line link to the AWS + EKS + Terraform card. |
| 30 | strong | Assessment format fits progressive difficulty. Fourth pass: full line read confirmed it. Left alone. |
| 31-41 (projects) | strong | Consistent build-verify-break-recover loop. Second pass: Day-32 and Day-35 now have explicit recall sections matching their siblings. Fourth pass: full line read of 30, 31, 33, 34, 36 to 41; only two one-line jargon gaps found (bulkhead in Day-34, cold OOM in Day-37), both fixed. Fifth pass: Day-39 gained a one-line link to the FinOps card. |

## What confuses a new learner (watch list)

Duplicate files were the biggest remaining source of doubt. Day 8, 9, and 10 each exist twice (a lesson version and an Interview-Ready v2 version) and Day 24 exists twice (plain and Expanded), so a new learner could not tell which file to open first. The second pass added a one-line "which file to open" note to the README pointing at the INDEX-canonical files, which removes the doubt without any rename. Actually renaming or merging the duplicate files is still deferred, because that is a destructive decision the repo owner should make.

Canonical lessons now live in `Day-NN/01-concepts.md`. INDEX and pattern cards link to those paths. The Interview-Ready v2 copies for Days 8, 9, and 10, and the non-Expanded Day 24 file, stay at the repo root for reference.

The two smaller items from the first pass are now closed: Day-19 received the same goal-line and model-first treatment Day-20 got, and Day-32 and Day-35 received explicit recall sections, so retrieval practice is now universal across the project Days.

## Deeper language and learning pass (second pass, 2026-10-01)

After the JD-theme pass landed, every Day in the 1 to 21 core plus the watch-list project Days was re-read line by line for ease of learning: dense openings, jargon walls, packed mega-sentences, choppy one-line paragraphs, and missing model-first placement. Each change shipped as its own small PR, one Day per PR.

Fully line-audited and edited: Day-19 (goal line, six-stage chain diagram, split mega-sentences, jargon defined, scanner table), Day-32 (explicit recall framing, choppy one-liners merged), Day-35 (new recall section before completion criteria), Day-12 (goal line, path model first, Azure to AWS table), Day-13 (goal line, list opening, Dockerfile instruction table), Day-14 (goal line, problem list unpacked), Day-11 (hierarchy sentence unpacked).

Fully line-reviewed, no change needed: Days 1, 2, 3, 5, 7, 15, 17, 18 (all open with a goal or core-idea line, model before detail, short sentences), and Days 4, 6, 16, 20, 21 (prior-pass edits hold up; remaining long paragraphs are one idea per sentence and match each file's voice). Clear enough remains a valid audit result.

## Priority fixes applied in this pass

1. Day-11: model-first opening, Azure to AWS table up top, parking-lot Remember, landing-zone card link.
2. Day-16: simpler opening sentences, two-loop Remember at the GitOps introduction, GitOps card link.
3. Day-20: goal line, symptoms-vs-causes Remember, error-budget ladder, SRE card link.
4. Day-4: short AI-in-the-loop note plus agentic card link (closes the only true content gap).
5. Day-6 and Day-21: one-line cross-links only; both already clear enough.

Everything else was left alone on purpose. Clear enough is a valid audit result, and the cap of six touched Day files was kept. Each edited Day ships in its own small PR so every change stays easy to review on its own.

> **Remember:** The repo's bottleneck is not missing content. It is how fast a learner can load the one model each lesson is built on.

## Cloud-track language pass (third pass, 2026-10-01)

The third pass read Days 22 to 29 line by line — the Azure and AWS overlay tracks the first two passes had only reviewed at structure level. The structural verdict from pass one held up: every one of these files opens with a goal or model, uses diagrams next to prose, and ends with a real recall section. What the line-level read exposed was a consistent jargon gap: these lessons introduce the most provider-specific vocabulary in the whole course, and roughly two dozen terms were used without a plain-English definition at first use. Some of those terms (CIDR, CNI, SAST/SCA) are load-bearing across many Days yet were never defined anywhere in the curriculum, so each got one short definition at the point a learner first needs it, reusing Day-19 wording where it already existed.

Each Day shipped as its own small PR: Day-22 (goal line; service principal, blast radius, SKU), Day-23 (goal line; PaaS, revision, cold start), Day-24 Expanded only per the README canonical-file note (CIDR, stateful, Layer 4, NVA), Day-25 (SAST/SCA reminder reusing Day-19 wording, drift), Day-26 (ARN, instance profile, stateful, Transit Gateway linked back to Day-24 hub-and-spoke, OIDC linked back to Day-25 federation), Day-27 (AMI forward-gloss, CNI, ephemeral, plain EBS/EFS/S3 intuition, ENI), Day-28 (Elastic IP, PrivateLink, hosted zone), Day-29 (removed seven broken citation artifacts, defined STS). Day-29's November 2025 CodeCommit general-availability note was fact-checked against the AWS announcement and kept as written.

The optional project Days (30, 31, 33, 34, 36 to 41) were scanned for the same issues and showed none: clear goal openings, recall present, no artifacts. They remain untouched, and "reviewed, no change" stays a valid audit result.

## Deep project-Day and consistency pass (fourth pass, 2026-10-03)

The fourth pass finished the two areas earlier passes had only scanned. First, the canonical Day-8, Day-9, and Day-10 files (the ones the README and INDEX point at) got a full line read: all three open with a goal, put one model before detail, keep short sections, and end with real recall, so all three stay "reviewed, no change". Second, the project Days 30, 31, 33, 34, and 36 to 41 got the deeper line pass the previous round deferred. The earlier structural verdict held up completely: every file opens with a purpose and a central question, limits new ideas per part, uses diagrams beside prose, drills failures with evidence-first reasoning, and closes with recall plus completion criteria. No mega-sentences, buried models, or choppy prose were found; the short-line Clean-Style voice matches the already-audited Day-32.

The one real gap the line read exposed was cross-lesson term consistency, so each defined term a later Day uses was traced back to its first definition. Most were already safe: RCA is spelled out in Day-19 and taught in Day-20 before any project Day uses it, SLO/SLI/error budget, saturation, and p95 are defined in Day-20, high-cardinality is explained with the unbounded-label example in Day-35 before Day-39 reuses it, blast radius in Day-10, STS in Day-29, SAST/SCA in Day-19 and Day-25, and expand-and-contract is defined at its own first use in Day-34. Three gaps were fixed, one tiny PR each: OOM was never spelled out anywhere, so its first use in Day-14 now reads "OOM (out-of-memory) kills" with a half-line explanation; Day-37's cold reuse of OOM in a failure diagram got the same three-word reminder; and bulkhead, the one failure-containment term in Day-34 that no lesson ever defined, got a two-sentence plain-English gloss (separate resource pools per dependency, like ship compartments). JWT appears only inside a secrets list and an environment-variable name, where a learner is not blocked, so it was left alone.

The jd-insights section was also re-read against the Day voice: the nine pattern cards, README, INDEX, and HOW-WE-UPDATE are all short, plain, and no denser than the lessons they point at, so none were touched. The round's conclusion matches the first pass: the curriculum's content and structure are done; the remaining work, when any appears, is single-term first-use glosses, and "reviewed, no change" is now the normal outcome.

## JD-insights coverage pass (fifth pass, 2026-10-03)

The fifth pass reversed the audit direction. Earlier passes read the Days and checked language; this pass started from each of the nine pattern cards and asked whether the Days carrying that market theme actually deliver the card's JD-critical idea: the model arrives before detail, no jargon wall blocks the core idea, and the sticky anchor the card plants is either reused or stated in compatible words. Every card's "study these days first" list was walked file by file, and every relative link in the cards, INDEX, README, and this file was re-verified against real filenames (all resolve).

The coverage result, card by card:

| Pattern card | Days that teach it | Verdict |
|:--|:--|:--|
| Azure IaC + pipelines | 6, 8, 9, 10, 22, 25 | Covered, no change. Day-6 carries the card link; the plan-review-approve-apply loop is the spine of all six files. |
| AWS + EKS + Terraform | 26, 27, 28, 29, 17, 14, 15 | Covered. Day-26's opening already states the card's names-change-shape-stays idea in prose; it only lacked the card link (fixed, one line). |
| Kubernetes in production | 13, 14, 15, 17, 34, 37 | Covered. Day-15's failure-boundary walk is the card's evidence drill; Day-14 only lacked the card link (fixed, one line). |
| GitOps + platform paved roads | 5, 16, 19, 33 | Covered, no change. Day-16 carries the card link and the two-loop anchor; Day-33 teaches same-artifact promotion. |
| SRE, SLOs, observability | 20, 34, 35, 41 | Covered, no change. Day-20 carries the card link; Day-41's incident loop contains the mitigate-before-root-cause order the card anchors. |
| Landing zones + multi-account | 11, 12, 18, 22, 38 | Covered, no change. Day-11 carries the card link and the parking-lot anchor; Day-38 opens on the boundary question itself. |
| FinOps + cost awareness | 39, 11, 30 | Covered. Day-39 teaches the full loop including attribution (Part 27) and unit cost; it only lacked the card link (fixed, one line). |
| Agentic AI in DevOps | 4, 19, 20 | Covered, no change. Day-4's AI-in-the-loop note with the fast-junior anchor remains the right-sized home. |
| Lead vs Senior signals | 21, 30, 40 | Covered, no change. Day-21 carries the card link; Day-40 grades exactly the defend-every-decision behaviour the card describes. |
| Golden images / Image Factory | 27, 23, 13, 19 | New card added 2026-10-06 from two EPAM KZ JDs (bake-don't-patch loop, CIS hardening, image scanning, gallery publishing); the listed Days already teach each piece, no Day change needed. |

The instructional verdict is that no Day needed a content fix. Every theme lands on Days that open with the model, define jargon at first use (the third and fourth passes already closed those gaps), and end with recall. The one real gap this direction of reading exposed was navigational: six cards were reachable from their lead Day through the one-line JD note introduced in the first pass, but three (Kubernetes in production, AWS + EKS + Terraform, FinOps) were not, so a learner inside Day-14, Day-26, or Day-39 had no way to discover that a market pattern card existed for exactly what they were studying. Each of those three Days gained one JD-note line in its own small PR, matching the existing format, and nothing else was touched.

Remaining watch-list items carry over unchanged: the duplicate Day-8/9/10 and Day-24 files still await an owner decision on rename or merge (the README note keeps learners on the canonical files meanwhile), and JWT remains undefined but unblocking. New normal from here: when fresh JDs arrive, update the card first per HOW-WE-UPDATE, and only touch a Day if the card exposes a missing model or anchor, not to add length.

## Golden-image gap fix (2026-10-06)

Fresh Senior/Lead Azure JDs ask for "Image Factory" pipelines (golden images, CIS hardening, Ansible as code, publishing to Azure Compute Gallery), and Day-23 taught VMSS rolling updates without ever saying where the image comes from. Day-23 Part 3 gained one short golden-image block (plain-English definition, build-harden-scan-publish flow, a "bake, don't patch in place" Remember, and a Day-27 Part 3 cross-link to the AWS AMI version of the same idea) plus one Part 22 recall question. No other Day was touched.

## Simplified Technical English pass (sixth pass, 2026-10-09)

The sixth pass audited every canonical Day lesson (Day-1 to Day-41, using the README's canonical files for Days 8, 9, 10, and 24) against ASD-STE100 Simplified Technical English, applied about 80% of the way. The house rules now live in [STE-STYLE.md](STE-STYLE.md): short sentences (about 20 words for steps, about 25 for description), active voice with imperatives for steps, one term per meaning inside a Day, simple verbs over complex ones, one instruction per sentence, no long noun clusters, and warnings that carry their reason. The deliberate 20% deviation is also written down there: technical names stay, paragraphs stay flowing prose of 3 to 4 lines or more, teaching analogies and Remember anchors and diagrams stay, and code blocks are never touched.

The mechanics follow the established pattern: one PR per Day, each touching only that Day's file, with a skip (fewer than 5 meaningful edits) recorded as a valid result. A prose-only scan (code blocks excluded) ranked the Days first: the heaviest sentence-length and passive-voice signal sits in Days 12, 13, 18, 19, and 26, while Days 1, 7, 40, and 41 are already close to the STE target after the earlier passes. Each Day PR reports its own counts: sentences split, passive-to-active fixes, verb swaps, and term-consistency fixes, with before and after examples.

## JD coverage audit (2026-10-11)

Date: 2026-10-11. Scope: every pattern card in `patterns/` plus INDEX.md, HOW-WE-UPDATE.md, STE-STYLE.md (already on main), and the apply logs in `log/`. PR #82 (`cursor/jd-insights-2026-10-08-373d`) is already merged, so the 2026-10-08 Turkey platform and Lead AWS notes are on main. Canonical Day files follow the README (Days 8, 9, 10, and 24 Expanded). The latest applied role noted in this pass is letgo Senior Platform Engineer (Turkey): production AWS with EC2, EKS, S3, RDS, IAM, OpenSearch, and ElastiCache.

The lens is interview readiness with low cognitive load: one mental model before detail, jargon named at first use, Remember / Understand / Look-up split, and a retrieval exit check. Edits stay small and localized. Clear enough remains a valid result. STE PRs #43 to #81 are already on main, so this pass does not reformat whole Days.

### Theme coverage

| Theme | Days | Status |
|:--|:--|:--|
| Azure IaC + Pipelines | 6, 8, 9, 10, 22, 25, 37 | Fixed in [PR #83](https://github.com/syehab/DevOps-Prep/pull/83): Day-6 JD note mixed the application pipeline with the IaC plan-review-approve-apply loop. Days 8, 9, 10, 22, 25, and 37 already teach the IaC loop. |
| AWS + EKS + Terraform (incl. letgo stack) | 3, 14, 17, 26, 27, 28, 29 | Fixed in [PR #85](https://github.com/syehab/DevOps-Prep/pull/85) (Day-17 names IRSA / EKS Pod Identity), [PR #86](https://github.com/syehab/DevOps-Prep/pull/86) (Day-26 S3 as a production product), and [PR #87](https://github.com/syehab/DevOps-Prep/pull/87) (Day-27 RDS / S3 / ElastiCache / OpenSearch model). EC2, EKS, IAM, and RDS connectivity were already interview-ready. Day-3 OSI and Day-28 private paths stay covered. |
| Kubernetes in Production | 13, 14, 15, 17, 34, 37 | Covered. Day-15 walks the request path with evidence. Day-14 desired-state model and Day-17 ownership boundary stay as they are. |
| GitOps + Platform Paved Roads | 5, 16, 19, 33, 34 | Fixed in [PR #84](https://github.com/syehab/DevOps-Prep/pull/84): Day-16 promised paved roads in the JD note but never defined the term. Two-loop GitOps, Day-33 promotion, and Day-34 DORA stay covered. |
| SRE, SLOs, Observability | 20, 34, 35, 41 | Covered. Day-20 carries SLI / SLO / error budget and symptom alerting. Day-41 already includes the incident loop and synthetic checks. |
| Landing Zones + Multi-Account | 11, 12, 18, 22, 38 | Covered. Day-11 parking-lot model and Azure-to-AWS table sit first. Day-38 is the hands-on boundary project. |
| FinOps + Cost Awareness | 11, 30, 39 | Covered. Day-39 teaches attribution, unit cost, and the reliability-versus-cost trade-off. Day-30 asks cost in design review. |
| Agentic AI in DevOps | 4, 19, 20 | Covered. Day-4 "fast junior engineer" note is the right-sized home. Day-19 keeps human-owned gates. Emerging AI-gateway / RAG names stay on the card as an early signal, not a new Day section. |
| Lead vs Senior Signals | 21, 30, 40 | Covered. Day-21 points at the card. Day-40 grades defend-every-decision behaviour. |
| Golden Images | 13, 19, 23, 27 | Covered on Day-23 (factory loop). Day-27 Part 3 now reuses the bake-do-not-patch Remember in [PR #87](https://github.com/syehab/DevOps-Prep/pull/87). |

### Already well covered (no Day edit)

Kubernetes request-path debugging, landing-zone hierarchy, FinOps cost loop, agentic-AI guardrails, Lead-versus-Senior ownership, SRE error budgets, Azure IaC modules and remote state, GitOps reconciliation, EC2 / EKS / IAM core, and OSI fundamentals on Day-3.

### Gap noted (left alone)

- Secure defaults inside Azure modules (identity, Key Vault, private networking) live across Day-18 and Day-25, not as a dedicated Day-9 box. The plan-apply loop is already clear.
- Synthetic checks are taught in Day-41, not restated in Day-20. The core SLO lesson stays one idea per section.
- `cloudbase-init` (Windows first boot) is a Look-up name on the golden-images card. Do not invent a Windows image lab.
- No Terraform `aws_eks_cluster` resource sketch was added. The course teaches the shape (VPC, IAM, cluster, pipeline), not a new module.

> **Remember:** Fresh JDs update the card first. Touch a Day only when the card exposes a missing model or a name the interview will ask out loud.

## JD coverage audit (2026-10-13)

Date: 2026-10-13. Scope: five market themes merged into existing cards in the jd-insights PR, then only the Days those cards map to. Cards first, Days only when a model or an interview name was missing. STE house style kept. No vacancy IDs.

### Theme coverage

| Theme | Card | Days mapped | Status |
|:--|:--|:--|:--|
| Agent as a versioned bundle | agentic-devops | 4, 19, 33, 34 | Card carries the analog. Days already teach the loop, gates, promotion, and rollback. No Day edit. |
| Observability as code | sre-slos-observability | 8, 20, 35 | Fixed on Day-20 (dashboards/alerts in Git, cardinality at first teaching, token/cost metric). Day-8 and Day-35 already cover IaC and the cardinality drill. |
| Scarce GPU / quota lead time | finops-cost | 17, 22, 39 | Fixed on Day-39 (capacity reservation vs savings-plan discount). Day-17 GPU pools and Day-22 quota definition already hold. |
| Developer-portal catalog links | gitops-platform | 16, 33 | Card carries the catalog map. Day-16 already defines the paved road. No Day edit. |
| CDC (Debezium → Kafka / MSK) | aws-eks-terraform | 27 | Fixed on Day-27 next to the RDS / ElastiCache / OpenSearch model. |
| Karpenter vs Cluster Autoscaler | kubernetes-production | 17, 37 | Fixed on Day-37 Part 17. Day-17 already teaches HPA vs node capacity. |

### Already well covered (no Day edit)

Day-4 AI-in-the-loop note, Day-8 IaC desired-state model, Day-16 paved road, Day-17 GPU pools and node autoscaling, Day-19 supply-chain gates, Day-22 quota as platform capacity, Day-33 same-artifact promotion, Day-34 health gates and rollback, Day-35 high-cardinality drill.

### Gap noted (left on the card)

- Backstage plugin work and portal ownership stay a Look-up on the GitOps card. Day-16 already teaches the paved road underneath.
- GPU product knobs (Capacity Blocks instance types, reservation billing) stay Look-up. The lesson is the inventory-versus-discount split.
- Debezium connector settings and MSK topic design stay Look-up. The lesson is "the log is the source of events."

> **Remember:** Fresh themes update the card first. Touch a Day only when the card exposes a missing model or a name the interview will ask out loud.

## Hands-on lab rebuild (2026-10-13)

Date: 2026-10-13. Scope: `Day-NN/03-implementation.md` labs versus Senior/Lead interview depth. Concepts files were already strong (JD and STE passes). The bottleneck was the labs: paper sketches, `/tmp` throwaways, `local_file` stand-ins, and "cost stays at ₹0 / INR 0" on paths that can bill.

The rebuild uses one product repository (ShopSphere capstone), real Terraform modules with `terraform test` on **1.16.5 / azurerm 5.9.0**, pinned Docker/Helm/Argo/Trivy commands, USD estimates under USD 5 per session, budget-first, teardown, **no NAT Gateways**, and a local fallback (`kind`, Docker, `mock_provider`). Format is fixed: Goal, Capstone stage, Steps, Verify, Break and fix (≥2), Stretch, Clean up, STAR, Self-score.

**Before** the rebuild, a typical lab scored about **2.5 / 5** (runnable locally, not a platform story). **After**, a rewritten lab targets **5 / 5** when the learner commits the ShopSphere stage and destroys billed objects.

### Lab ratings (before → after)

Scale: 1 = read-only notes, 3 = real commands but throwaway/`/tmp`/no cost honesty, 5 = ShopSphere stage, pinned tools, verify + break/fix, USD + teardown, interview STAR.

| Day | Before | After | Why the delta |
|:--|:--|:--|:--|
| 01–07, 08–11, 14–21, 25–31, 34–38, 40 | ~2.5 | **5** (PRs #181–#219) | Capstone scaffold + per-Day rewrites already opened; merge those PRs with this track. |
| 12 | 2.0 | **5** | Paper CIDR + Docker ping → VNet/NSG module + `terraform test`, no NAT. |
| 13 | 2.5 | **5** | One-stage `/tmp` HTTP image → multi-stage non-root catalog, size, Trivy, `HOST=0.0.0.0`. |
| 22 | 2.5 | **5** | Paper tenant tree + empty RG → platform module (RG, LAW, USD 15 budget). |
| 23 | 2.0 | **5** | Decision table + same Dockerfile break as 13 → Packer bake + ACA 0.25 vCPU (harder than 13). |
| 24 | 2.5 | **5** | Paper NSG / optional `az network` → hub-spoke peering + Private DNS module. |
| 32 | 2.5 | **5** | Compose without DB ports → Key Vault Private Endpoint, public network off. |
| 33 | 2.5 | **5** | Local image tag copy → same `sha256` Dev→Prod through GitOps (harder than 29). |
| 39 | 2.5 | **5** | Single-dir tar → second-region restore with measured RTO/RPO + Geo vault module. |
| 41 | 2.5 | **5** | `/tmp` tabletop → game day on Day 20 burn-rate (`/products` 5xx, `/health` 200). |

Mean of the nine thin Days in this pass: **2.4 / 5 → 5 / 5** on the lab file. Interview readiness still depends on the learner running ShopSphere, not on markdown alone.

### What stayed out of this pass

- Concepts and Q&A files were not rewritten (STE and JD coverage already hold).
- Capstone, drills, and CI lint live in their own PRs (#181, #195, #198, #205–#208). Do not copy `capstone/` into a Day PR.
- Cloud apply of AKS, ACA, PE, and vaults remains **Not executed** in the authoring VMs. `terraform test`, Python, and bash were executed where the Day says so.

> **Remember:** A Senior story is one repo, a reviewed plan, a destroy, and a budget. A folder of `local_file` labs is not.
