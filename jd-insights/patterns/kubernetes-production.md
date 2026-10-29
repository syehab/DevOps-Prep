# Kubernetes in Production (almost every senior JD)

## In one sentence

Nearly every Senior or Lead DevOps JD expects you to run Kubernetes day 2: deploy safely, debug fast, and keep the cluster healthy, not just write YAML.

## What employers ask for

- Production operations on AKS or EKS (day-2, not demos)
- Debugging: pods crashing, DNS failing, traffic not arriving
- Safe deployments: rolling updates, probes, resource limits
- Upgrades, scaling, and node lifecycle
- Securing workloads: identities, secrets, network policies
- AKS day 2 extras: add-ons (ingress, cert-manager, external-dns, monitoring, policy) and onboarding new namespaces or tenants
- Node autoscaling: Cluster Autoscaler scales the node groups you already defined. Karpenter provisions the right node just in time and does not need a pre-sized group for every shape. Product knobs are Look-up. Know the difference.
- Hosted SaaS instances: a Kubernetes operator watches a Custom Resource (CRD) per customer instance, then creates, upgrades, and deletes that stack. Zero-downtime upgrades still use rolling updates, probes, and PodDisruptionBudgets

## Mental model

The interview version of Kubernetes is a request path plus a repair loop:

```text
User
 ↓
Ingress
 ↓
Service
 ↓
Pod (your app)
 ↓
Downstream (DB, APIs)
```

When something breaks, walk the path with evidence:

```text
Is the pod running?        → kubectl get pods
Why not?                   → kubectl describe / logs
Can the service find it?   → endpoints, labels
Can traffic get in?        → ingress, DNS
Can the pod get out?       → network policy, DNS, creds
```

## Remember

> **In production Kubernetes, the skill is not writing YAML. It is walking the request path with evidence until you find the broken hop.**

## Hosted SaaS instances: operators, not one-off YAML

```text
Tenant CR  →  Operator (controller)  →  create / upgrade / delete the instance
```

A Custom Resource Definition (CRD) is a new API kind you add to the cluster (for example `Tenant`). An operator is a controller that watches that kind and reconciles it, the same loop a Deployment uses for Pods. Product teams that host one SaaS instance per customer use this to stamp, upgrade, and retire instances without a human `kubectl`. Zero-downtime upgrades still use rolling updates, probes, and PodDisruptionBudgets (Day-17, Day-34). The operator sequences those per instance.

The in-cluster operator is the sibling of the Terraform module-per-tenant factory on the AWS card. Pick one control plane. Do not let both fight over the same instance.

> **Remember:** An operator is the desired-state loop applied to your own API. A CRD is that API.

**Look-up:** Operator SDK. Crossplane is already on the GitOps card. Do not invent a SaaS operator lab.

## Study these days first

1. [Day-13/01-concepts.md](../../Day-13/01-concepts.md) - containers first
2. [Day-14/01-concepts.md](../../Day-14/01-concepts.md) - the core model
3. [Day-15/01-concepts.md](../../Day-15/01-concepts.md) - debugging the path
4. [Day-17/01-concepts.md](../../Day-17/01-concepts.md) - managed clusters
5. [Day-37/01-concepts.md](../../Day-37/01-concepts.md) - a real migration
6. [Day-34/01-concepts.md](../../Day-34/01-concepts.md) - safe deployments

## Common interview question

**Q: A deployment rolled out and now users get 503 errors. What do you do?**

Outline:
1. Check pod status and recent events (crash loops, failed probes).
2. Check readiness: are pods in the service endpoints?
3. Check logs of the new version, compare with the old one.
4. If the new version is the cause, roll back first, investigate second.
5. Afterwards: add the missing probe, limit, or alert that let this ship.

**Q: How would you upgrade 50 hosted SaaS instances on EKS with no downtime?**

Outline:
1. Each instance is a Custom Resource. An operator reconciles it (same loop as a Deployment).
2. Per instance: rolling update, readiness probe, PodDisruptionBudget. Do not restart all 50 at once.
3. Wave the upgrade (canary tenants first). Roll back the last good instance spec.
4. Honest: say if you have not written an operator. Transfer the reconcile loop from Day-14. Do not invent Operator SDK flags.

## Honest gap note

JDs name many add-ons (service mesh, specific CNIs, cluster autoscalers). You do not need daily experience with each. Know the core path and failure drill cold, then say honestly which add-ons you have used and which you would learn on the job. The course does not run a SaaS operator. Transfer Day-14's reconcile loop. Look up Operator SDK when a JD names it.

## Source tags

EPAM Azure Lead · EPAM Senior Azure DevOps · EPAM AWS DevOps · EPAM Lead Cloud (AKS add-ons) · EPAM Senior Azure Cloud (KZ, AKS ops) · Sezzle SRE · Fundraise Up DevOps · 2026-10-13 market (Karpenter vs Cluster Autoscaler) · 2026-10-29 market (operators, CRDs, SaaS instance lifecycle, zero-downtime upgrades)
