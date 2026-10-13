# 03 — GitOps control plane

**Timer:** 25 minutes.

## Prompt

Design how a commit becomes a running ShopSphere revision.

You already have: a catalog image, Terraform for Azure (AWS overlay optional), Argo CD, and GitHub Actions. A Lead asks: "Show me the control plane. Who can apply Production?"

Write `docs/design/03-gitops-control-plane.md`.

## Constraints

- Two pipelines: app and infra. They do not share one identity.
- Infra: `fmt`, `validate`, `tflint`, Checkov, `terraform test`, plan on the pull request, apply after an environment approval.
- App: test, build, push by **digest**, never by a floating `latest` as the promotion key.
- Runtime: Argo CD app-of-apps. Argo CD is the deployer. The human approves the Git change.
- Identity: GitHub OIDC to Entra (or to AWS STS). No `AZURE_CLIENT_SECRET`. No `AWS_ACCESS_KEY_ID`.

## Capacity

Skip RPS. Name the **approval count**: how many humans must approve a Production apply, and how many identities exist (CI plan, CD apply, runtime Workload Identity / IRSA, human break-glass).

## Hints

1. Day 25 is the infra pipeline. Day 16 is app-of-apps. Day 18 / Day 29 are OIDC.
2. Argo CD syncs Git. It does not build images.
3. `terraform apply` from a laptop against Prod is the failure mode, not the design.

## Solution

<details>
<summary>Open after the timer or after you tried the hints.</summary>

```text
Developer
  → Git pull request
     → app CI: test, build, push digest
     → infra CI: fmt validate tflint checkov terraform test plan
  → Reviewer approves
  → Merge to env branch or env folder
     → Argo CD syncs k8s (same digest)
     → GHA apply job (OIDC, environment approval) for Terraform
```

**Identities (four):** (1) GitHub Actions plan role, read-only on cloud. (2) GitHub Actions apply role, scoped to one environment, environment protection on. (3) Workload Identity / IRSA for the catalog Pod to Key Vault / Secrets Manager. (4) Human break-glass, time-bound, audited.

**Approvals:** at least one required reviewer on the Prod GitHub Environment plus the pull-request review. Two humans is a Lead-friendly default. One identity that plans and applies Prod is a fail.

**Refuse:** store apply keys in GitHub Secrets. Rebuild the image in the Prod job.

**Lab cost:** GitHub minutes **USD 0.00** on a free private account until the cap. This drill is paper.

</details>
