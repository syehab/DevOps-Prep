# Lead vs Senior: What Changes in the JD

## In one sentence

Senior JDs grade hands-on depth, Lead JDs add ownership of how the team ships, and Staff product-platform JDs add production Go or Rust, RFCs, and the pager.

## What employers ask for

Senior signals:

- Deep hands-on: Terraform, Kubernetes, pipelines, debugging under pressure
- Own a system end to end and keep it reliable
- Explain decisions clearly in English (B2+ appears in JDs). Some consulting houses now ask C1 together with Linux depth and Python automation

Lead signals (added on top):

- Technical ownership: set standards, review designs, raise the bar
- Stakeholder work: align with architects, product, and client teams
- Mentoring and pairing, without necessarily being a people manager
- "Reliable, scalable delivery" language: you answer for outcomes, not tickets
- Small-team lead (about four people): still hands-on. You own release management, who is on call, and how work is delegated. Interviewers want STAR stories, not a title

Staff / product-platform signals (added on top of Lead):

- Infra as software: you write production Go or Rust, not only YAML and Terraform
- RFC writing: a design doc others review before you build
- You still hold the pager and the SLO. A platform product company does not drop operations
- Open-source Postgres / BaaS roles use this bar. It is higher than generic DevOps ticket work. The PostgreSQL SRE loop stays on the [AWS card](aws-eks-terraform.md)

## Mental model

```text
Senior:  I built it, I run it, I can debug it at 3 AM.

Lead:    Everything above, plus:
         I decide how WE build it
         I review others' designs
         I explain trade-offs to non-engineers
         I grow the people around me

Staff / product platform:
         Everything above, plus:
         I write the platform as software (Go or Rust)
         I write the RFC before the build
         I still hold the pager
```

The jump is scope, not tools. Staff at a product company adds a software bar on top of that scope:

```text
Task → System → Team's way of working → Platform as a compiled product
```

An RFC is the written architecture review. Day-40 already asks you to defend every important decision. Staff JDs want that write-up before the first pull request, and they want production Go or Rust in the repo, not only Terraform. The [SRE card](sre-slos-observability.md) still owns SLOs and the pager. Do not treat "we write Go" as a reason to skip operations.

This bar is higher than generic DevOps. Do not lower it. If your daily language is Terraform and YAML, say that, then show the RFC shape from Day-40 and one service you could defend in Go. Do not invent years of Rust.

A Lead JD that names a team of about four still wants you on the keyboard. You assign the release owner and the on-call primary. You keep the escalation. You do not do every deploy yourself.

```text
Small team of four
  ├── You still ship (hands-on)
  ├── You assign: who owns this release, who is primary on-call
  └── You keep the escalation (you own the outcome)
```

## Remember

> **Lead is still a hands-on role in these JDs. The difference is you are accountable for how the whole team ships, not only for your own work.**

> **Staff platform at a product company still pages you. The extra bar is software you wrote and an RFC someone else reviewed.**

## Study these days first

1. [Day-21-Senior-Lead-DevOps-Capstone/01-concepts.md](../../Day-21-Senior-Lead-DevOps-Capstone/01-concepts.md) - the capstone, senior-to-lead thinking
2. [Day-30-Final-Assessment-and-Architecture-Challenge/01-concepts.md](../../Day-30-Final-Assessment-and-Architecture-Challenge/01-concepts.md) - design under assessment
3. [Day-40-Lead-DevOps-Architecture-Review/01-concepts.md](../../Day-40-Lead-DevOps-Architecture-Review/01-concepts.md) - running an architecture review
4. [Day-34-Reliability-and-Safe-Deployments/01-concepts.md](../../Day-34-Reliability-and-Safe-Deployments/01-concepts.md) - the release you own even when someone else clicks deploy
5. [Day-41-Production-Deployment-Incident/01-concepts.md](../../Day-41-Production-Deployment-Incident/01-concepts.md) - on-call, incident, and the RCA you write after
6. [Day-20-Observability-and-Production-Incident/01-concepts.md](../../Day-20-Observability-and-Production-Incident/01-concepts.md) - SLOs and the pager Staff still holds

## Common interview question

**Q: Tell me about a time you led without being the manager.**

Outline:
1. Pick a real technical ownership story: a standard you set, a review you drove, a migration you steered.
2. Structure: situation, what you decided, who you aligned, outcome.
3. Show the lead behaviours: trade-off talk, unblocking others, raising quality.
4. Do not inflate titles. "I owned the platform direction" is strong and checkable.

**Q: How did you lead a DevOps team of about four through a release?**

Outline:
1. Situation: a real release (or on-call week), not a title.
2. What you delegated: who cut the release, who was primary on-call, who wrote the runbook.
3. What you kept: the approval, the escalation, the story you tell after.
4. Outcome: the release landed, or the page was handled, and what you changed next time.

**Q: This Cloud Platform role wants production Go or Rust, RFCs, and pager duty. How do you map, and what do you not claim?**

Outline:
1. RFC: Day-40 is the written review. Situation, decision, trade-off, failure mode, how you know.
2. Pager: SLOs and a named on-call window (Day-20, Day-41). Infra as software does not drop operations.
3. Language: name the languages you have shipped. Transfer the engineering habits. Do not invent production Go or Rust years.
4. Postgres / BaaS: keep the SRE loop on the AWS card (EXPLAIN, restore, CDC). The product name is Look-up.

## Honest gap note

Some Lead JDs ask for only about one year of leadership. Frame real experience (leading delivery, mentoring, owning client-facing technical calls) as technical leadership. Do not claim people-manager tenure you do not hold; interviewers verify this quickly.

The course does not run a production Go or Rust platform. Transfer Day-40 (the RFC shape) and Day-20 (the pager). Do not lower the bar to YAML-only, and do not invent language years.

## Source tags

EPAM Lead DevOps / Lead Azure Cloud / Lead Platform · EPAM Lead DevOps (KZ, module ownership + review bar + paved road) · RedCloud Head of Platform (stretch) · 2026-10-29 market (small-team lead, release management, delegation, on-call ownership) · 2026-11-04 market (C1 English with Linux and Python) · 2026-11-06 market (Staff / product platform: Go or Rust, RFC, pager, Postgres BaaS)
