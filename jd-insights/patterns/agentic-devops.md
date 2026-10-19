# Agentic AI in DevOps (the new ask)

## In one sentence

Newer JDs (Sezzle, EPAM GenAI-flavoured roles) expect you to use AI tools in DevOps work, and some now expect you to ship AI agents the same way you ship any other service.

## What employers ask for

- Use AI assistants daily for IaC, pipeline, and script writing. JDs now name the tools (Claude Code, Cursor, Copilot), not only "AI tooling"
- One Lead JD lists AI-assisted Terraform and Ansible authoring with GitHub Copilot as standard project practice (human review still owns the result)
- Use agents to speed up ops loops: triage, runbook drafting, log summarising
- Judge AI output: review it like a junior engineer's PR, never auto-trust
- Keep guardrails: AI suggests, pipelines and humans still gate production
- Comfort experimenting with new AI tooling as it appears
- Senior roles that build an Enterprise Agent Development Platform now require agent-specific CI/CD: register each version, scan for prompt-injection and PII leakage, then promote the same bundle

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

## Shipping an agent like software

An agent you run in production is not a chat window. Treat it as a release artifact, the same way you treat a container image in a CI/CD pipeline.

```text
Build ARM64 agent container
        ↓
  security scan
    ├── CVE / secrets (normal)
    └── prompt-injection / PII leakage (agent-specific)
        ↓
  push to AWS ECR (semver tag + git SHA tag)
        ↓
  Agent Registry (phone book)
    version · git SHA · eval pass/fail · promotion status
        ↓
  register a runtime version (for example AgentCore Runtime)
        ↓
  automated evals (quality gates)
        ↓
  promote: dev → qa → prod  (same bundle)
        ↓
  tested rollback (last good bundle)
```

The pipeline still owns promotion. Automated evals are the quality gate, like tests before you promote an image. Rollback is a known-good bundle, not a prompt edit in production.

After a successful build, the pipeline registers that agent version in an Agent Registry. The registry is the phone book: which versions exist, which git SHA built them, whether evals passed, and whether they may promote. The container registry (ECR) stores the image. The Agent Registry stores the release record. Traceability is the image digest plus the git SHA plus the eval result.

Employers also ask for agent-specific scans in GitHub Actions (matrix builds): prompt-injection checks and PII-leakage checks. Those are quality gates for the agent bundle. They sit next to unit tests, not instead of them. A generic container pipeline that only scans for CVEs and secrets does not cover this ask.

> **Remember:** Ship the agent as a versioned bundle. Register it. Eval gates promote it. A tested rollback path brings the last good bundle back.

## Platform teams now also run AI traffic (emerging, seen in a few JDs)

A newer ask, so treat it as an early signal, not a core requirement:

- Some Lead roles run an AI gateway (Azure API Management AI gateway, LiteLLM). It is a normal API gateway with model-aware rules: route requests across model providers, rate-limit by tokens not just calls, enforce policies like PII redaction, and log usage for cost and debugging.
- Others support GenAI / RAG apps on AKS with Azure AI Search, private networking, and a WAF. The platform work is the usual work: networking, security, observability, resilience. The app behind it just happens to call models.
- Some SRE-flavoured roles run LLM and RAG apps in production end to end: CI/CD for the model and the app, scaling, on-call with SLOs. The plain model: an AI service is still a service, same pipeline, same SLOs, plus one extra thing to watch, is the model's output still good? JDs name MLOps lifecycle tools (Kubeflow, MLflow, TFX) as examples. Look them up when a JD asks, do not memorise them.
- A few Principal or AI Solution roles list model and LLM evaluation as its own discipline. That is not the same as running a gateway. It asks whether the model's answers are still good, not only whether the service is up. Emerging only. Do not start a study track yet.

If you have not run one of these gateways, say so. Describe it as gateway skills (routing, limits, policy, logging) applied to model traffic. The same honesty works for MLOps: pipeline and SLO skills transfer, the model-quality signal is the new part.

## Study these days first

AI assists existing loops, so study the loops:

1. [Day-04/01-concepts.md](../../Day-04/01-concepts.md) - the delivery loop AI plugs into
2. [Day-19/01-concepts.md](../../Day-19/01-concepts.md) - the gates that stay human-owned
3. [Day-20/01-concepts.md](../../Day-20/01-concepts.md) - the ops loop AI can summarise
4. [Day-33/01-concepts.md](../../Day-33/01-concepts.md) - build once, promote the same artifact
5. [Day-34/01-concepts.md](../../Day-34/01-concepts.md) - health gates and a tested rollback

## Common interview question

**Q: How do you use AI in your DevOps work today?**

Outline:
1. Concrete and modest: drafting IaC modules, pipeline YAML, and scripts, then reviewing and testing before merge.
2. Ops side: summarising logs and drafting runbooks or RCA timelines during incidents.
3. The guardrail sentence: AI never applies to production, pipelines and reviews still gate everything.
4. Attitude: tools change fast, the review-and-gate habit does not.

**Q: How would you ship an agent through CI/CD?**

Outline:
1. Build an ARM64 agent image, scan it (CVE, secrets, prompt-injection, PII), push it to ECR with a semver tag and a git SHA tag.
2. Register the version in the Agent Registry (SHA, eval result, promotion status).
3. Promote the same bundle. Roll back the last good bundle.
4. Honest: name what you have not run (AgentCore, LangGraph packaging). Transfer the discipline. Do not invent the product.

## Honest gap note

This is the easiest area to over-claim and get caught. Do not invent product names or "built an AI platform" stories. Generic, honest wording (AI-assisted checks, delivery loops, runbooks) matches what these JDs actually ask and survives follow-up questions.

Agent CI/CD bar: generic containerized CI/CD experience without agent or runtime-versioning context does not meet this ask. Transfer the release discipline you already have (immutable artifact, gates, promote the same bundle, roll back the last good one). Then say clearly what you have not run (AgentCore, LangGraph packaging). Do not invent it.

Emerging note: some Azure cloud JDs now name Azure AI or RAG next to the usual cloud skills. Your answer stays the loop above: AI assists, humans review and approve.

## Source tags

Sezzle SRE (AI tooling expected) · EPAM Azure AI/GenAI DevOps themes · EPAM Lead Azure (AI gateway) · EPAM Senior Azure (GenAI/RAG on AKS) · EPAM Lead Cloud (Copilot standard) · EPAM Azure Cloud (KZ, Azure AI / RAG named) · EPAM Senior AI DevOps/SRE (LLM + RAG in production) · Turkey / Central Asia Senior DevOps (daily AI assistants) · Turkey / Central Asia Principal / AI Solution (LLM evaluation, emerging) · 2026-10-13 market (agent as a versioned bundle) · EPAM Senior DevOps (Agent CI/CD & Registry, 2026-10-14)
