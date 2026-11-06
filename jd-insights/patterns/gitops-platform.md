# GitOps + Platform Paved Roads

## In one sentence

Platform and Lead roles want Git to be the source of truth for deployments (GitOps, often Argo CD) and want you to build "paved roads" so product teams ship without tickets.

## What employers ask for

- GitOps delivery: desired state in Git, a controller (Argo CD or Flux) syncs the cluster
- Helm charts or templates that teams reuse
- Golden paths: a new service gets repo, pipeline, deploy, and monitoring by default
- Internal Developer Platform thinking, sometimes Backstage by name, down to its pieces: Software Catalog, Scaffolder templates, TechDocs
- Developer-portal integration: a catalog entry links the service to its dashboards, Argo CD deploy status, ownership and access rules, and docs generated from IaC outputs. The portal is a map of the paved road, not a second deploy path
- Multi-tenancy: granular RBAC plus a repeatable way to onboard a new tenant or namespace
- Golden paths you can trust: generated infrastructure is tested end to end and watched for drift
- Promotion flow: the same artifact moves dev → test → prod via Git changes
- Release management with Argo CD plus an artifact repository (Artifactory, ACR, or ECR). The repository stores versions. Git records which version each environment should run. Promotion moves that pointer. It does not rebuild
- Policy-as-code on the IaC: OPA, Conftest, or Checkov fail the plan when a resource breaks a rule (public bucket, missing tag, open SSH). Look-up the tool the JD names
- Treat the platform as a product: backlog, paved-road SLOs, and DORA numbers. Teams consume the path. They do not file a ticket for each step
- Multi-cluster GitOps: one Git source, many clusters. Argo CD ApplicationSets use generators (list, cluster, git, matrix) to create one Application per cluster. Rancher Fleet ships a GitRepo bundle to cluster groups. Promotion still moves the same artifact. The generator or group is what changes
- One codebase to cloud and to a customer site (self-hosted, sovereign, or air-gapped): Docker Compose for small sites, Kubernetes plus Helm or an OCI bundle for larger ones. Mirror images into a private registry. Upgrade offline. Expect the customer version to lag the cloud version
- Self-hosted factory names: GitLab (source and CI), Artifactory or Nexus (packages), Harbor (container registry). Same jobs as GitHub, a package feed, and ACR or ECR. You operate them. See the [self-managed card](self-managed-servers.md)
- The same factory also builds mobile apps, desktop software, and device firmware. You still sign the artifact, version it, keep it, and roll it out in stages. The artifact type changes. The loop does not
- Ephemeral preview environments: a pipeline (often GitLab CI) creates a short-lived environment per change, then destroys it. The portal still maps the paved road. The preview is a temporary stop, not a second production
- Enablement of the first team: sit beside app owners, land Dev / UAT / Prod, then hand over so they self-serve. That engagement is the [env-acceleration card](env-acceleration.md). The paved road is what they inherit
- Staff and product-platform roles raise the bar further: you write the platform in Go or Rust and you write RFCs. See the [Lead vs Senior card](lead-vs-senior-signals.md)

## Mental model

```text
App repo                 Config repo (desired state)
   │                          │
CI: build + test          PR changes image tag
   │                          │
Push image ───────────────────┘
                              ↓
                      GitOps controller
                      (Argo CD or Flux syncs)
                              ↓
                         Cluster matches Git
```

Two loops to say out loud in interviews:

```text
CI loop: code → image           (builds things)
CD loop: Git state → cluster    (applies things)
```

The platform idea is the same loop, offered as a product: teams get a template, a pipeline, and a deploy path that already works. A product has a backlog, owners, and a quality bar. You measure that product with the DORA numbers below. Teams consume the path. They do not file a ticket for each step.

Policy-as-code is how the product enforces its own rules before apply. Day-36 already draws Terraform to policy evaluation to pass or fail to plan. Name OPA, Conftest, or Checkov when a JD does. The idea is one gate, not three tools.

The developer portal is the map of that product:

```text
Catalog entry (one service)
   ├── dashboards
   ├── Argo CD deploy status
   ├── owners / access
   └── docs from IaC outputs
```

The portal does not replace GitOps. It points at the paved road so a team can find it.

## Many clusters, one Git

```text
Git (desired state)
        ↓
ApplicationSet generator     or     Fleet cluster group
        ↓
cluster-a  cluster-b  cluster-c
```

App-of-apps (Day-16) is one root Application that points at more Applications. That works for a few clusters. When the cluster count grows, you do not copy YAML for each one.

Argo CD ApplicationSets create those Applications from a generator. A list generator names clusters. A cluster generator reads registered clusters. A git generator reads folders. A matrix generator combines two of those. Rancher Fleet takes a GitRepo and a cluster group and ships the same bundle. Product knobs are Look-up. The idea is one: Git is the source, a generator or group expands it, each cluster reconciles its copy.

Promotion is still Day-33: the same image digest. You change which cluster or group gets that revision. You do not rebuild.

> **Remember:** ApplicationSets and Fleet expand one Git source onto many clusters. They do not replace Helm, and they do not replace promotion of the same artifact.

**Look-up:** ApplicationSet generator YAML and Fleet GitRepo fields. Do not invent a 50-cluster lab.

## The artifact repository is the warehouse

```text
CI builds one artifact
        ↓
Push to Artifactory / ACR / ECR  (the warehouse)
        ↓
Git records the digest or version per environment
        ↓
Argo CD syncs the cluster to that Git state
```

JDs now name Argo CD and an artifact repository in the same sentence. The repository holds the bytes (image, Helm chart, or package). Git holds the desired version for Dev, test, and prod. Promotion is a Git change that points at a version that already exists. Artifactory can also mark a version as staged or released. That mark does not replace Git as the cluster's source of truth.

> **Remember:** The repository stores the artifact. Git says which artifact should run. Argo CD applies that. Do not rebuild for the next environment.

**Look-up:** Artifactory promotion versus a Git pointer. Do not invent an Artifactory lab.

## One codebase, two install sites

```text
Same repo
   ├── Cloud:  pipeline → registry → GitOps
   └── Site:   mirror images → private registry
               Helm chart or OCI bundle
               Docker Compose (small) or Kubernetes (large)
               offline upgrade, version may lag
```

Some products ship to the team's cloud and to a customer network that cannot pull from the public internet. Keep one codebase. Change the install path, not the application. Mirror the approved images and the chart (or an OCI bundle) into the site registry. An upgrade is a new bundle on media or a private path, not a live pull from Docker Hub.

Version skew is normal. The customer site often runs an older chart while cloud moved on. Support both until the site upgrades. Do not require the site to reach your CI.

> **Remember:** One codebase. Mirror what you already shipped. Offline means the site never pulls from the public internet.

**Look-up:** Helm OCI charts and air-gap bundle layout. Do not invent a sovereign-cloud product.

## How a platform proves it works (DORA metrics)

Platform JDs now ask you to measure the paved road, not just build it. The four DORA metrics:

- Deployment frequency: how often you ship to production
- Lead time for changes: how long a commit takes to reach production
- Change failure rate: what share of deploys cause a problem
- Time to restore: how fast users are OK again after a bad deploy

A good paved road pushes the first two up and the last two down. [Day-34-Reliability-and-Safe-Deployments/01-concepts.md](../../Day-34-Reliability-and-Safe-Deployments/01-concepts.md) walks through these four (it also calls them release metrics).

JDs now ask where each number comes from. Deployment frequency and lead time come from the pipeline (how often it shipped, when the commit became a production artifact). Change failure rate and time to restore come from incident tools (how many deploys needed a rollback or hotfix, how long until users were OK). Do not invent a fourth dashboard. Read the tools you already run.

**Exit check:** Name the four metrics. Then say which two you read from the pipeline and which two you read from incidents.

## A preview dies with the change

```text
Change opens
        ↓
Pipeline creates a preview
        ↓
Reviewers try the change
        ↓
Merge or close → destroy the preview
```

JDs now ask for preview environments next to the paved road. GitLab CI and in-house Go tooling are common names. On-prem, Windows / Hyper-V, and cloud are just where that preview runs. The preview is not production. It lives for the change, then it goes away. Day-05 already maps a change to an environment. Day-16 is the paved road. Day-33 still promotes the same signed artifact to the real environments.

The factory also signs and stores artifacts that are not web images: a mobile build, a desktop installer, or device firmware. Version it. Keep the bytes. Roll out in stages. Day-06 already says build once and keep the artifact. Day-19 is the sign-and-scan step.

> **Remember:** A preview is temporary. Production still takes the same signed artifact through the usual gates.

**Look-up:** GitLab review apps and Hyper-V lab hosts. Do not invent a preview-platform lab.

## Remember

> **GitOps means nobody pushes to the cluster. The cluster pulls from Git, so every change has a diff, an author, and an undo.**

## Study these days first

1. [Day-16-Helm-and-GitOps-Mental-Model/01-concepts.md](../../Day-16-Helm-and-GitOps-Mental-Model/01-concepts.md) - Helm and GitOps core
2. [Day-05-Branches-Environments-and-Deployment-Flow/01-concepts.md](../../Day-05-Branches-Environments-and-Deployment-Flow/01-concepts.md) - branches and environments
3. [Day-06-Azure-DevOps-Pipeline-in-Practice/01-concepts.md](../../Day-06-Azure-DevOps-Pipeline-in-Practice/01-concepts.md) - one artifact, kept and promoted
4. [Day-33-Artifact-Promotion-and-Release-Control/01-concepts.md](../../Day-33-Artifact-Promotion-and-Release-Control/01-concepts.md) - artifact promotion
5. [Day-19-Secure-CI-CD-and-Supply-Chain/01-concepts.md](../../Day-19-Secure-CI-CD-and-Supply-Chain/01-concepts.md) - securing the chain, registry, and the air-gap mirror
6. [Day-34-Reliability-and-Safe-Deployments/01-concepts.md](../../Day-34-Reliability-and-Safe-Deployments/01-concepts.md) - DORA numbers and where they come from
7. [Day-36-Terraform-Enterprise-Hardening/01-concepts.md](../../Day-36-Terraform-Enterprise-Hardening/01-concepts.md) - policy evaluation before plan (Part 14)

## Common interview question

**Q: Why GitOps instead of letting the pipeline run kubectl apply?**

Outline:
1. Audit: every change is a Git commit with review.
2. Drift: the controller keeps correcting the cluster back to Git.
3. Rollback: revert the commit, the cluster follows.
4. Access: CI needs no cluster credentials; the controller pulls.
5. Trade-off to admit: more moving parts, and secrets need their own path.

**Q: How do you GitOps 30 clusters without copying an Application for each one?**

Outline:
1. One Git source. An ApplicationSet generator (or a Fleet cluster group) creates the per-cluster Application.
2. Promote the same digest. Change which cluster or group gets that revision.
3. Honest: name app-of-apps if that is what you have run. Transfer the expand-from-Git idea. Do not invent generator YAML.

**Q: How do you ship the same product to cloud and to an air-gapped customer site?**

Outline:
1. One codebase. Cloud uses the normal registry and GitOps path.
2. Site: mirror images and the Helm or OCI bundle into a private registry. Upgrade offline.
3. Expect version skew. Support the older site chart until it upgrades.

**Q: How do Argo CD and an artifact repository share a promotion?**

Outline:
1. CI builds once and pushes the artifact to Artifactory, ACR, or ECR.
2. Git records that digest (or version) for the target environment. Argo CD syncs the cluster to Git.
3. Promotion moves the pointer. It does not rebuild. Artifactory stage marks are extra labels, not a second source of truth.

**Q: Where do the four DORA numbers come from, and what is a preview environment?**

Outline:
1. Frequency and lead time: the pipeline. Failure rate and time to restore: incident tools.
2. A preview is a short-lived environment for one change. Destroy it on merge or close.
3. The same factory can sign a mobile, desktop, or firmware artifact. Keep it. Roll out in stages.

## Honest gap note

Backstage appears in EPAM platform JDs, and newer ones also name Crossplane, Pulumi, Humanitec, and OpsLevel. If you have not run these, do not claim plugins or ownership. Explain the ideas (Crossplane provisions cloud resources from inside the cluster, Pulumi is IaC in a real programming language, Humanitec and OpsLevel are IDP products like Backstage) and show your GitOps and Helm experience, which is the engine under any IDP.

## Source tags

EPAM Lead Platform / Unified Automation (Backstage) · EPAM Lead Cloud (IDP) · EPAM Senior DevOps Azure · RedCloud Platform · EPAM Senior/Lead Platform Engineer · Turkey banking platform (Terraform account vending) · 2026-10-13 market (catalog links dashboards, Argo CD, owners, IaC docs) · 2026-10-27 market (policy-as-code, platform as product) · 2026-11-02 market (ApplicationSets vs Fleet, air-gapped / sovereign shipping) · 2026-11-03 market (self-hosted GitLab / Artifactory / Nexus / Harbor) · 2026-11-04 market (Argo CD plus Artifactory / ACR / ECR for promotion) · 2026-11-05 market (DORA data sources, preview environments, mobile / desktop / firmware artifacts) · 2026-11-06 market (first-team enablement pointer, Staff Go / Rust / RFC pointer)
