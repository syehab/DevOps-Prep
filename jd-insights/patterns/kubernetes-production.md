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
- Node autoscaling: Cluster Autoscaler scales the node groups you already defined. Karpenter provisions the right node just in time, can mix On-Demand and Spot, and later consolidates idle or half-empty nodes. Choose Cluster Autoscaler when groups are already stable. Choose Karpenter when Pods need many shapes or you want faster scale and less waste. Neither replaces HPA. Product knobs stay Look-up.
- Hosted SaaS instances: a Kubernetes operator watches a Custom Resource (CRD) per customer instance, then creates, upgrades, and deletes that stack. Zero-downtime upgrades still use rolling updates, probes, and PodDisruptionBudgets
- Stateful databases on the cluster: an operator (not a Deployment) runs the engine, replication, backups, and point-in-time recovery (PITR). A managed database (RDS) to an operator-run database is a data migration: replicate, cut over, keep a rollback, and prove a restore. An ephemeral container is still not a production database
- Bare-metal and self-managed basics: CRI starts containers, CNI gives each Pod an IP. Know what AKS and EKS hide (control plane, etcd, default networking, control-plane upgrades)
- GPU and ML hosting: a tainted GPU node pool, the NVIDIA device plugin, and a scheduler that only places Pods that request a GPU. Idle GPUs still cost money

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

## What AKS and EKS hide

```text
You still own
  ├── Worker nodes / node pools
  ├── Workloads and node upgrades
  ├── Network design (VNet / VPC)
  └── The CNI and NetworkPolicy that actually run

The provider owns (managed control plane)
  ├── API server
  ├── etcd
  └── Control-plane upgrades
```

CRI is the interface the kubelet uses to start containers. The usual runtime is containerd. CNI is the plugin that gives each Pod an IP and connects it to the node network. On bare metal, or on VMs you run yourself, you pick both and you operate both. AKS and EKS hide the control plane. They run the API server and etcd. They give you a default CNI. They upgrade that control plane on a schedule you still have to plan around.

They do not hide node upgrades, a broken CNI, or a NetworkPolicy that the CNI does not enforce. Day-14 names etcd and the container runtime. Day-15 names CNI as the Pod network. Day-17 draws the ownership line for AKS and EKS.

> **Remember:** Managed Kubernetes hides the control plane. It does not hide CRI, CNI, node upgrades, or your workloads.

**Look-up:** the CNI your cluster actually runs (Azure CNI, AWS VPC CNI, Calico, Cilium). Do not memorise product knobs.

## GPU and ML workloads

```text
tainted GPU pool → NVIDIA device plugin → Pod requests GPU + toleration → scheduler
```

JDs now ask you to host GPU and ML jobs on Kubernetes, not only to reserve GPU capacity in the cloud. A GPU node pool is a dedicated pool. You taint it so ordinary Pods stay off those machines. Only a Pod with the matching toleration and a GPU resource request lands there.

The NVIDIA device plugin is the agent that tells Kubernetes a node has GPUs. Without it, the scheduler sees a normal CPU node. GPU SKUs are scarce and they bill even when idle, so keep general workloads off the pool. The [FinOps card](finops-cost.md) covers capacity reservations and quotas. Day-17 already teaches GPU pools, taints, and tolerations.

> **Remember:** Taint the GPU pool. Only GPU work lands there. An idle GPU still costs money.

**Look-up:** NVIDIA device plugin flags and MIG. Do not invent a lab.
The pod itself has a security bar. The image sets a non-root `USER`. The pod spec sets `runAsNonRoot`. A container that runs as root turns one application bug into a host-level incident. Day-13 shows `USER 10001`. Day-19 calls a non-root user part of a safer Dockerfile.

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

## Stateful databases: an operator, not a Deployment

```text
Managed DB (RDS)
        ↓  replicate + verify
Operator CR on EKS (engine, replica, backup, PITR)
        ↓  cut over writes
App uses the new endpoint
        ↓  keep the old DB until rollback is retired
```

A Deployment replaces Pods and throws the filesystem away. A production database needs a PersistentVolume, a replica, backups you have restored, and a point in time you can return to. An operator watches a Custom Resource for that database and reconciles those pieces. That is the same loop as a Tenant CR, applied to data.

Moving off a managed database is a data migration, not a YAML swap. Replicate until lag is safe. Cut writes in a window. Keep the old endpoint as rollback. Prove PITR on a copy before you trust the new backups. Day-27 places RDS and says an ephemeral container is not a database. Day-39 measures RTO and RPO. This card adds the operator as the in-cluster control plane.

> **Remember:** An operator-run database is still a database. Replicate, cut over, keep a rollback, and prove a restore. A Pod with a disk is not a plan.

**Look-up:** the operator the JD names. Do not invent a CloudNativePG lab.

## Study these days first

1. [Day-13/01-concepts.md](../../Day-13/01-concepts.md) - containers first
2. [Day-14/01-concepts.md](../../Day-14/01-concepts.md) - the core model and operators
3. [Day-15/01-concepts.md](../../Day-15/01-concepts.md) - debugging the path
4. [Day-17/01-concepts.md](../../Day-17/01-concepts.md) - managed clusters, GPU pools, taints
5. [Day-27/01-concepts.md](../../Day-27/01-concepts.md) - RDS versus an operator-run database
6. [Day-37/01-concepts.md](../../Day-37/01-concepts.md) - Karpenter versus Cluster Autoscaler
7. [Day-34/01-concepts.md](../../Day-34/01-concepts.md) - safe deployments
8. [Day-39/01-concepts.md](../../Day-39/01-concepts.md) - PITR, restore drills, RTO and RPO
9. [Day-19/01-concepts.md](../../Day-19/01-concepts.md) - non-root image, scan, and digest

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

**Q: What does AKS hide, and how would you place a GPU training job?**

Outline:
1. AKS runs the API server and etcd. You still own node pools, CNI behavior, node upgrades, and workloads.
2. CRI (usually containerd) starts containers. CNI gives each Pod an IP.
3. GPU: a tainted pool, NVIDIA device plugin, Pod requests a GPU and tolerates the taint. Idle GPUs still bill.
4. Honest: say if you have not run the device plugin. Transfer Day-17 scheduling. Do not invent MIG settings.

**Q: When do you pick Karpenter instead of Cluster Autoscaler?**

Outline:
1. Cluster Autoscaler grows a group you already defined. It will not invent a missing instance type.
2. Karpenter creates a node that fits the Pending Pod, can use Spot, and consolidates waste later.
3. Pick Cluster Autoscaler for stable, few shapes. Pick Karpenter for mixed shapes, faster scale, or consolidation.
4. HPA still adds Pods. These tools add nodes. Day-37 already records that split.

**Q: How would you move a managed PostgreSQL (RDS) onto an operator on EKS?**

Outline:
1. The operator reconciles a database CR: disk, replica, backup, PITR. That is not a Deployment.
2. Replicate from the managed database. Watch lag. Cut writes in a window. Point the app at the new endpoint.
3. Keep the old database until rollback is retired. Prove a restore to a point in time on a copy first.
4. Honest: say if you have not run that operator. Transfer Day-27 (state outside the container) and Day-39 (restore drills).

## Honest gap note

JDs name many add-ons (service mesh, specific CNIs, cluster autoscalers, database operators). You do not need daily experience with each. Know the core path and failure drill cold, then say honestly which add-ons you have used and which you would learn on the job. The course does not run a SaaS operator, a database operator, a bare-metal control plane, or the NVIDIA device plugin. Transfer Day-14, Day-17, Day-27, and Day-39. Look up the operator, CNI, plugin, and MIG when a JD names them.

## Source tags

EPAM Azure Lead · EPAM Senior Azure DevOps · EPAM AWS DevOps · EPAM Lead Cloud (AKS add-ons) · EPAM Senior Azure Cloud (KZ, AKS ops) · Sezzle SRE · Fundraise Up DevOps · 2026-10-13 market (Karpenter vs Cluster Autoscaler) · 2026-10-27 market (non-root containers) · 2026-10-28 market (CRI / CNI, what AKS/EKS hide, GPU hosting) · 2026-10-29 market (operators, CRDs, SaaS instance lifecycle) · 2026-11-02 market (stateful DB operators, PITR cutover, Karpenter consolidation / Spot)
