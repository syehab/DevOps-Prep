# Azure DevOps to GitHub

## In one sentence

Senior JDs now ask you to move Azure DevOps pipelines to GitHub Actions and keep the same templates, branch protection, owners, and environment approvals.

## What employers ask for

- Reusable pipeline templates: Azure Pipelines YAML templates map to GitHub Actions reusable workflows
- Repo governance: branch protection, CODEOWNERS, and required reviews before merge to `main`
- Environments and approvals: GitHub Environments with required reviewers map to Azure DevOps Environments and checks
- The delivery loop stays: build once, promote the same artifact, gate production

## Mental model

The tool names change. The loop does not.

```text
Azure DevOps                     GitHub
YAML template           →        reusable workflow
Branch policy           →        branch protection
Required reviewers      →        CODEOWNERS + required reviews
Environment + check     →        Environment + required reviewer
Variable group          →        Environment variables / secrets
Service connection      →        OIDC to the cloud
```

You still build once, review the change, approve production, and promote the same artifact. Day-25 already teaches YAML templates as the way to reuse pipeline logic. GitHub calls the same idea a reusable workflow.

A team that copies a 200-line workflow into every repo will drift. Centralize the guarded steps (scan, identity, deploy) in one template. Let app repos pass parameters.

Day-19 already teaches branch protection. Changes reach `main` through a pull request, review, and checks. CODEOWNERS is a GitHub file that names who must review a path. It does not replace branch protection. It names the reviewers that protection then requires.

Day-06 already teaches a Production approval. GitHub Environments hold that approval as a required reviewer. Day-25's lab already creates a GitHub Environment named `azure-dev` with a required reviewer before apply.

> **Remember:** Move the loop, not the YAML. Templates, protected branches, owners, and environment approvals are the same controls with new names.

**Understand:** Governance is who can change `main` and who can ship to production. Branch protection plus CODEOWNERS answers the first. Environments plus approvals answer the second.

**Look-up:** `workflow_call` syntax, GitHub Environment deployment branches, and CODEOWNERS pattern grammar. Do not memorise YAML.

## Study these days first

1. [Day-04/01-concepts.md](../../Day-04/01-concepts.md) - the delivery loop (Azure Pipelines and GitHub are names on the same flow)
2. [Day-05/01-concepts.md](../../Day-05/01-concepts.md) - branches and environments
3. [Day-06/01-concepts.md](../../Day-06/01-concepts.md) - Azure DevOps pipeline and production approval
4. [Day-19/01-concepts.md](../../Day-19/01-concepts.md) - branch protection and the supply chain
5. [Day-25/01-concepts.md](../../Day-25/01-concepts.md) - YAML templates; the lab already uses GitHub Actions and a GitHub Environment

Also: [Day-25/03-implementation.md](../../Day-25/03-implementation.md) for the GitHub Actions plus Environment path, and [Day-06/03-implementation.md](../../Day-06/03-implementation.md) for the same artifact on both GitHub Actions and Azure Pipelines.

## Common interview question

**Q: We are moving from Azure DevOps to GitHub. What do you keep, and what do you rename?**

Outline:
1. Keep the loop: build once, scan, approve, promote the same artifact.
2. Rename: YAML templates become reusable workflows. Branch policies become branch protection. Environments stay Environments.
3. CODEOWNERS names path owners. Required reviews still gate `main`.
4. Identity: OIDC to Azure, no long-lived secret in GitHub. Day-25 already uses this on GitHub.

## Honest gap note

The course teaches Azure DevOps YAML in depth. GitHub Actions appears in the Day-04, Day-06, and Day-25 labs. CODEOWNERS is not a Day lesson. Explain it as named reviewers per path, then look up the file format. Do not claim a large Azure DevOps to GitHub migration you have not run.

## Source tags

2026-10-28 market (Azure DevOps to GitHub: templates, branch protection, CODEOWNERS, environments)
