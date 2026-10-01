# GitOps + Platform Paved Roads

## In one sentence

Platform and Lead roles want Git to be the source of truth for deployments (GitOps, often Argo CD) and want you to build "paved roads" so product teams ship without tickets.

## What employers ask for

- GitOps delivery: desired state in Git, a controller (Argo CD) syncs the cluster
- Helm charts or templates that teams reuse
- Golden paths: a new service gets repo, pipeline, deploy, and monitoring by default
- Internal Developer Platform thinking, sometimes Backstage by name
- Promotion flow: the same artifact moves dev → test → prod via Git changes

## Mental model

```text
App repo                 Config repo (desired state)
   │                          │
CI: build + test          PR changes image tag
   │                          │
Push image ───────────────────┘
                              ↓
                      GitOps controller
                      (Argo CD syncs)
                              ↓
                         Cluster matches Git
```

Two loops to say out loud in interviews:

```text
CI loop: code → image           (builds things)
CD loop: Git state → cluster    (applies things)
```

The platform idea is the same loop, offered as a product: teams get a template, a pipeline, and a deploy path that already works.

## Remember

> **GitOps means nobody pushes to the cluster. The cluster pulls from Git, so every change has a diff, an author, and an undo.**

## Study these days first

1. [Day-16-L16-Helm-GitOps-Mental-Model.md](../../Day-16-L16-Helm-GitOps-Mental-Model.md) - Helm and GitOps core
2. [Day-5-L05-Branches-Environments-Deployment-Flow.md](../../Day-5-L05-Branches-Environments-Deployment-Flow.md) - branches and environments
3. [Day-33-Production-Project-03-CICD-Artifact-Promotion-Release-Control.md](../../Day-33-Production-Project-03-CICD-Artifact-Promotion-Release-Control.md) - artifact promotion
4. [Day-19-L19-Secure-CICD-Software-Supply-Chain.md](../../Day-19-L19-Secure-CICD-Software-Supply-Chain.md) - securing the chain

## Common interview question

**Q: Why GitOps instead of letting the pipeline run kubectl apply?**

Outline:
1. Audit: every change is a Git commit with review.
2. Drift: the controller keeps correcting the cluster back to Git.
3. Rollback: revert the commit, the cluster follows.
4. Access: CI needs no cluster credentials; the controller pulls.
5. Trade-off to admit: more moving parts, and secrets need their own path.

## Honest gap note

Backstage appears in EPAM platform JDs. If you have not run Backstage, do not claim plugins or ownership. Explain the paved-road idea (templates, catalogs, golden paths) and show your GitOps and Helm experience, which is the engine under any IDP.

## Source tags

EPAM Lead Platform / Unified Automation (Backstage) · EPAM Senior DevOps Azure · RedCloud Platform
