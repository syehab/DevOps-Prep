# Lead vs Senior: What Changes in the JD

## In one sentence

Senior JDs grade your hands-on depth; Lead JDs add ownership of outcomes, standards, and people interaction, often with as little as one year of leading asked.

## What employers ask for

Senior signals:

- Deep hands-on: Terraform, Kubernetes, pipelines, debugging under pressure
- Own a system end to end and keep it reliable
- Explain decisions clearly in English (B2+ appears in JDs)

Lead signals (added on top):

- Technical ownership: set standards, review designs, raise the bar
- Stakeholder work: align with architects, product, and client teams
- Mentoring and pairing, without necessarily being a people manager
- "Reliable, scalable delivery" language: you answer for outcomes, not tickets
- Small-team lead (about four people): still hands-on. You own release management, who is on call, and how work is delegated. Interviewers want STAR stories, not a title

## Mental model

```text
Senior:  I built it, I run it, I can debug it at 3 AM.

Lead:    Everything above, plus:
         I decide how WE build it
         I review others' designs
         I explain trade-offs to non-engineers
         I grow the people around me
```

The jump is scope, not tools:

```text
Task → System → Team's way of working
```

A Lead JD that names a team of about four still wants you on the keyboard. You assign the release owner and the on-call primary. You keep the escalation. You do not do every deploy yourself.

```text
Small team of four
  ├── You still ship (hands-on)
  ├── You assign: who owns this release, who is primary on-call
  └── You keep the escalation (you own the outcome)
```

## Remember

> **Lead is still a hands-on role in these JDs. The difference is you are accountable for how the whole team ships, not only for your own work.**

## Study these days first

1. [Day-21/01-concepts.md](../../Day-21/01-concepts.md) - the capstone, senior-to-lead thinking
2. [Day-30/01-concepts.md](../../Day-30/01-concepts.md) - design under assessment
3. [Day-40/01-concepts.md](../../Day-40/01-concepts.md) - running an architecture review
4. [Day-34/01-concepts.md](../../Day-34/01-concepts.md) - the release you own even when someone else clicks deploy
5. [Day-41/01-concepts.md](../../Day-41/01-concepts.md) - on-call, incident, and the RCA you write after

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

## Honest gap note

Some Lead JDs ask for only about one year of leadership. Frame real experience (leading delivery, mentoring, owning client-facing technical calls) as technical leadership. Do not claim people-manager tenure you do not hold; interviewers verify this quickly.

## Source tags

EPAM Lead DevOps / Lead Azure Cloud / Lead Platform · EPAM Lead DevOps (KZ, module ownership + review bar + paved road) · RedCloud Head of Platform (stretch) · 2026-10-29 market (small-team lead, release management, delegation, on-call ownership)
