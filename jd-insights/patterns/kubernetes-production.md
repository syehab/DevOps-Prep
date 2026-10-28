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

## Remember

> **In production Kubernetes, the skill is not writing YAML. It is walking the request path with evidence until you find the broken hop.**

## Study these days first

1. [Day-13/01-concepts.md](../../Day-13/01-concepts.md) - containers first
2. [Day-14/01-concepts.md](../../Day-14/01-concepts.md) - the core model
3. [Day-15/01-concepts.md](../../Day-15/01-concepts.md) - debugging the path
4. [Day-17/01-concepts.md](../../Day-17/01-concepts.md) - managed clusters, GPU pools, taints
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

**Q: What does AKS hide, and how would you place a GPU training job?**

Outline:
1. AKS runs the API server and etcd. You still own node pools, CNI behavior, node upgrades, and workloads.
2. CRI (usually containerd) starts containers. CNI gives each Pod an IP.
3. GPU: a tainted pool, NVIDIA device plugin, Pod requests a GPU and tolerates the taint. Idle GPUs still bill.
4. Honest: say if you have not run the device plugin. Transfer Day-17 scheduling. Do not invent MIG settings.

## Honest gap note

JDs name many add-ons (service mesh, specific CNIs, cluster autoscalers). You do not need daily experience with each. Know the core path and failure drill cold, then say honestly which add-ons you have used and which you would learn on the job. The course does not run a bare-metal control plane or the NVIDIA device plugin. Transfer Day-17. Look up the CNI, the plugin, and MIG when a JD names them.

## Source tags

EPAM Azure Lead · EPAM Senior Azure DevOps · EPAM AWS DevOps · EPAM Lead Cloud (AKS add-ons) · EPAM Senior Azure Cloud (KZ, AKS ops) · Sezzle SRE · Fundraise Up DevOps · 2026-10-13 market (Karpenter vs Cluster Autoscaler) · 2026-10-28 market (CRI / CNI, what AKS/EKS hide, GPU hosting)
