# Agentic AI in DevOps (the new ask)

## In one sentence

Newer JDs (Sezzle, EPAM GenAI-flavoured roles) expect you to use AI tools and agents to speed up DevOps work, and to talk about it honestly.

## What employers ask for

- Use AI assistants for IaC, pipeline, and script writing (Copilot-style)
- Use agents to speed up ops loops: triage, runbook drafting, log summarising
- Judge AI output: review it like a junior engineer's PR, never auto-trust
- Keep guardrails: AI suggests, pipelines and humans still gate production
- Comfort experimenting with new AI tooling as it appears

## Mental model

AI slots into the loops you already run. It does not replace them:

```text
Write    → AI drafts Terraform / YAML / scripts
              ↓ you review, test, and own it
Ship     → pipeline still gates: plan, scan, approve
              ↓
Operate  → AI summarises logs, drafts incident timelines,
           suggests runbook steps
              ↓ human decides and acts
Improve  → AI drafts the RCA, you verify the facts
```

The safety rule is the same as GitOps: every change still goes through review, tests, and an approval gate. AI shortens the writing, not the checking.

## Remember

> **Treat AI output like a fast junior engineer: great first drafts, zero accountability. Review stays human, gates stay in the pipeline.**

## Study these days first

AI assists existing loops, so study the loops:

1. [Day-4-L04-CICD-Mental-Model.md](../../Day-4-L04-CICD-Mental-Model.md) - the delivery loop AI plugs into
2. [Day-19-L19-Secure-CICD-Software-Supply-Chain.md](../../Day-19-L19-Secure-CICD-Software-Supply-Chain.md) - the gates that stay human-owned
3. [Day-20-L20-Observability-Production-Incident.md](../../Day-20-L20-Observability-Production-Incident.md) - the ops loop AI can summarise

## Common interview question

**Q: How do you use AI in your DevOps work today?**

Outline:
1. Concrete and modest: drafting IaC modules, pipeline YAML, and scripts, then reviewing and testing before merge.
2. Ops side: summarising logs and drafting runbooks or RCA timelines during incidents.
3. The guardrail sentence: AI never applies to production, pipelines and reviews still gate everything.
4. Attitude: tools change fast, the review-and-gate habit does not.

## Honest gap note

This is the easiest area to over-claim and get caught. Do not invent product names or "built an AI platform" stories. Generic, honest wording (AI-assisted checks, delivery loops, runbooks) matches what these JDs actually ask and survives follow-up questions.

## Source tags

Sezzle SRE (AI tooling expected) · EPAM Azure AI/GenAI DevOps themes
