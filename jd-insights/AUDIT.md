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
| 11 | edited | Model was buried at file end; moved up, added Azure to AWS table and card link. |
| 12 | strong | Path model first, Remember anchors present. Left alone. |
| 13 | strong | Long but well staged, practice throughout. Left alone. |
| 14 | strong | Desired-state model, break-and-fix practice, big recall list. Left alone. |
| 15 | strong | Layered failure-boundary model. Left alone. |
| 16 | edited | Dense opening, Remember anchors arrived too late; fixed, added card link. |
| 17 | strong | Ownership-boundary model, AKS to EKS tables. Left alone. |
| 18 | strong | Identity chain model up front. Left alone. |
| 19 | needs clarity | No goal line; opening paragraph very dense. Deferred, on watch list. |
| 20 | edited | No goal line, sticky alerting rule missing; fixed, added card link. |
| 21 | edited | Excellent capstone; one-line Lead-vs-Senior card link only. |
| 22-25 (Azure track) | strong | Model-first openings, hierarchy diagrams, recall. Duplicate Day-24 files on watch list. |
| 26-29 (AWS track) | strong | Explicit Azure-mapping openings, tables. Left alone. |
| 30 | strong | Assessment format fits progressive difficulty. Left alone. |
| 31-41 (projects) | strong | Consistent build-verify-break-recover loop. Day-32 and Day-35 lack an explicit exit-check section, on watch list. |

## What confuses a new learner (watch list, not fixed now)

Duplicate files are the biggest remaining source of doubt. Day 8, 9, and 10 each exist twice (a lesson version and an Interview-Ready v2 version) and Day 24 exists twice (plain and Expanded), so a new learner cannot tell which file to open first. The INDEX already points at the right ones, but a one-line "start with this file" note in the README would remove the doubt entirely. This was deferred because resolving it properly involves rename or merge decisions the repo owner should make.

Two smaller items stay on the list. Day-19 would benefit from the same goal-line treatment Day-20 received, and Day-32 and Day-35 are the only project Days without an explicit recall section, which breaks the retrieval-practice habit the rest of the repo teaches. All three are small, mechanical fixes for a future pass; they were left out of this one to keep the change set reviewable.

## Priority fixes applied in this pass

1. Day-11: model-first opening, Azure to AWS table up top, parking-lot Remember, landing-zone card link.
2. Day-16: simpler opening sentences, two-loop Remember at the GitOps introduction, GitOps card link.
3. Day-20: goal line, symptoms-vs-causes Remember, error-budget ladder, SRE card link.
4. Day-4: short AI-in-the-loop note plus agentic card link (closes the only true content gap).
5. Day-6 and Day-21: one-line cross-links only; both already clear enough.

Everything else was left alone on purpose. Clear enough is a valid audit result, and the cap of six touched Day files was kept. Each edited Day ships in its own small PR so every change stays easy to review on its own.

> **Remember:** The repo's bottleneck is not missing content. It is how fast a learner can load the one model each lesson is built on.
