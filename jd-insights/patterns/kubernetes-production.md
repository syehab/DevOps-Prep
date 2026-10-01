# Kubernetes in Production (almost every senior JD)

## In one sentence

Nearly every Senior or Lead DevOps JD expects you to run Kubernetes day 2: deploy safely, debug fast, and keep the cluster healthy, not just write YAML.

## What employers ask for

- Production operations on AKS or EKS (day-2, not demos)
- Debugging: pods crashing, DNS failing, traffic not arriving
- Safe deployments: rolling updates, probes, resource limits
- Upgrades, scaling, and node lifecycle
- Securing workloads: identities, secrets, network policies

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

## Study these days first

1. [Day-13-L13-Docker-Container-Fundamentals-v3.md](../../Day-13-L13-Docker-Container-Fundamentals-v3.md) - containers first
2. [Day-14-L14-Kubernetes-Mental-Model.md](../../Day-14-L14-Kubernetes-Mental-Model.md) - the core model
3. [Day-15-L15-Kubernetes-Networking-Troubleshooting-v2.md](../../Day-15-L15-Kubernetes-Networking-Troubleshooting-v2.md) - debugging the path
4. [Day-17-L17-AKS-EKS-Managed-Kubernetes-Architecture.md](../../Day-17-L17-AKS-EKS-Managed-Kubernetes-Architecture.md) - managed clusters
5. [Day-37-Production-Project-07-Kubernetes-Migration-Clean-Style.md](../../Day-37-Production-Project-07-Kubernetes-Migration-Clean-Style.md) - a real migration
6. [Day-34-Production-Project-04-Reliability-Safe-Deployments-Failure-Containment.md](../../Day-34-Production-Project-04-Reliability-Safe-Deployments-Failure-Containment.md) - safe deployments

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

EPAM Azure Lead · EPAM Senior Azure DevOps · EPAM AWS DevOps · Sezzle SRE · Fundraise Up DevOps
