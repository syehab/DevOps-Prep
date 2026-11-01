# Kubernetes in Production (almost every senior JD)

## In one sentence

Nearly every Senior or Lead DevOps JD expects you to run Kubernetes day 2: deploy safely, debug fast, and keep the cluster healthy, not just write YAML.

## What employers ask for

- Production operations on AKS or EKS (day-2, not demos)
- Debugging: pods crashing, DNS failing, traffic not arriving
- Safe deployments: rolling updates, probes, resource limits
- Upgrades, scaling, and node lifecycle
- Securing workloads: identities, secrets, network policies. Containers do not run as root (`USER` in the image, `runAsNonRoot` on the pod)
- AKS day 2 extras: add-ons (ingress, cert-manager, external-dns, monitoring, policy) and onboarding new namespaces or tenants
- Node autoscaling: Cluster Autoscaler scales the node groups you already defined. Karpenter provisions the right node just in time and does not need a pre-sized group for every shape. Product knobs are Look-up. Know the difference.

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

The pod itself has a security bar. The image sets a non-root `USER`. The pod spec sets `runAsNonRoot`. A container that runs as root turns one application bug into a host-level incident. Day-13 shows `USER 10001`. Day-19 calls a non-root user part of a safer Dockerfile.

## Remember

> **In production Kubernetes, the skill is not writing YAML. It is walking the request path with evidence until you find the broken hop.**

## Study these days first

1. [Day-13/01-concepts.md](../../Day-13/01-concepts.md) - containers first
2. [Day-14/01-concepts.md](../../Day-14/01-concepts.md) - the core model
3. [Day-15/01-concepts.md](../../Day-15/01-concepts.md) - debugging the path
4. [Day-17/01-concepts.md](../../Day-17/01-concepts.md) - managed clusters
5. [Day-37/01-concepts.md](../../Day-37/01-concepts.md) - a real migration
6. [Day-34/01-concepts.md](../../Day-34/01-concepts.md) - safe deployments
7. [Day-19/01-concepts.md](../../Day-19/01-concepts.md) - non-root image, scan, and digest

## Common interview question

**Q: A deployment rolled out and now users get 503 errors. What do you do?**

Outline:
1. Check pod status and recent events (crash loops, failed probes).
2. Check readiness: are pods in the service endpoints?
3. Check logs of the new version, compare with the old one.
4. If the new version is the cause, roll back first, investigate second.
5. Afterwards: add the missing probe, limit, or alert that let this ship.

## Honest gap note

JDs name many add-ons (service mesh, specific CNIs, cluster autoscalers). You do not need daily experience with each. Know the core path and failure drill cold, then say honestly which add-ons you have used and which you would learn on the job.

## Source tags

EPAM Azure Lead · EPAM Senior Azure DevOps · EPAM AWS DevOps · EPAM Lead Cloud (AKS add-ons) · EPAM Senior Azure Cloud (KZ, AKS ops) · Sezzle SRE · Fundraise Up DevOps · 2026-10-13 market (Karpenter vs Cluster Autoscaler) · 2026-10-27 market (non-root containers)
