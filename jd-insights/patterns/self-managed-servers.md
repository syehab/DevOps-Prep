# Self-Managed and Bare-Metal Ownership

## In one sentence

Some Senior platform JDs still expect you to own leased or on-prem servers, and to run cloud-like services on them, because a managed cloud account alone is not enough.

## What employers ask for

- Own leased dedicated servers: LXC and VMs, config management (Puppet), hardening, and patching on a calendar
- "Managed cloud alone is not enough" is a real interview line. You still own the box
- On-prem cloud-like platform services: S3-compatible object storage (MinIO), Redis or Memcached as a shared cache
- Self-hosted software factory: GitLab (source and CI), Artifactory or Nexus (packages), Harbor (container registry)
- Private-cloud names next to Kubernetes: OpenStack (you run the IaaS) and OCI (another public cloud). Kubernetes security basics still apply on those clusters: RBAC, NetworkPolicies, secrets. Terragrunt for DRY Terraform lives on the [Azure IaC card](azure-iac-pipelines.md)

## Mental model

A managed cloud is a furnished apartment. A leased server is a house. You still fix the roof.

```text
You own the machine
  ├── Hardware / lease / hypervisor
  ├── OS + LXC / VMs
  ├── Config management (Puppet, or the tool the JD names)
  ├── Patch + harden on a calendar
  └── Platform services you run yourself
        ├── Object store   MinIO        ≈ S3
        ├── Cache          Redis / Memcached ≈ ElastiCache
        └── Factory        GitLab + artifacts + Harbor
                           ≈ GitHub + package feed + ACR / ECR
```

Day-02 already treats Linux as the environment the app runs in. Day-23 already says a VM puts patching, hardening, and replacement on you. Day-17 already draws what AKS and EKS hide. This card adds the house: you may also own the hypervisor, the lease, and the services that a cloud would have sold you.

Work a small example first. A team rents dedicated servers. You put VMs (or LXC) on them with Puppet. You patch on a calendar, the same bake-and-replace habit as the [golden-images card](golden-images.md). Then you offer three platform services: MinIO for objects, Redis for a shared cache, and Harbor next to GitLab for images. Product teams consume those services. They do not SSH to the box.

The Kubernetes card already covers CRI and CNI when you run the cluster yourself. This card is the layer under that cluster: the machines, the config tool, and the shared stores. Do not treat "we use AWS" as an answer when the JD also names leased servers.

OpenStack is the IaaS you run yourself (compute, network, storage APIs). OCI is Oracle's public cloud. Both appear next to Kubernetes on private-cloud JDs. The ownership line does not change: you still patch the box, you still run the factory, and you still lock the cluster with RBAC, NetworkPolicies, and secrets. Day-17 draws what a managed cluster hides. Day-15 already teaches NetworkPolicy. Do not invent an OpenStack lab.

> **Remember:** The cloud bill does not replace the server you still patch.

**Understand:** MinIO, Redis, Memcached, GitLab, Artifactory, Nexus, Harbor, Puppet, and LXC are product names. The skill is ownership: you run the store, the cache, and the factory.

**Look-up:** the config tool and the registry the JD names. Do not invent a Puppet or Harbor lab.

**Exit check:** Name three services you would run on-prem to replace S3, ElastiCache, and ACR. Then say what you still own after the VMs exist.

## Remember

> **A leased server is a house, not a furnished apartment. You own the roof, the patch calendar, and the services you put inside.**

## Study these days first

1. [Day-02/01-concepts.md](../../Day-02/01-concepts.md) - Linux, the process, and the box
2. [Day-23/01-concepts.md](../../Day-23/01-concepts.md) - VM operations: patch, harden, replace
3. [Day-17/01-concepts.md](../../Day-17/01-concepts.md) - what managed Kubernetes hides
4. [Day-27/01-concepts.md](../../Day-27/01-concepts.md) - S3 and ElastiCache, the cloud names for MinIO and Redis
5. [Day-19/01-concepts.md](../../Day-19/01-concepts.md) - registry, air-gap mirror, self-hosted agents
6. [Day-13/01-concepts.md](../../Day-13/01-concepts.md) - containers versus the host

Also: the [Kubernetes card](kubernetes-production.md) for CRI and CNI on bare metal, and the [GitOps card](gitops-platform.md) for the factory those self-hosted tools sit in.

## Common interview question

**Q: A team wants only managed cloud. What do you still own on a leased server? How would you offer S3 and Redis on-prem?**

Outline:
1. You own the lease, the hypervisor or LXC, the OS, config management, and the patch calendar. AKS does not patch that box.
2. Object store: MinIO speaks the S3 API. Cache: Redis or Memcached, the same job as ElastiCache. Day-27 already places both as private services.
3. Factory: GitLab for source and CI, Artifactory or Nexus for packages, Harbor for images. Same jobs as GitHub plus ACR. You operate them.
4. Honest: say if you have not run MinIO or Harbor. Transfer Day-02, Day-19, and Day-27. Do not invent product flags.

## Honest gap note

The course labs use cloud VMs and managed stores. There is no Puppet, LXC, MinIO, or Harbor lab. Transfer the ownership line from Day-17 and the private-data pattern from Day-27. Look up the product the JD names. Do not claim a bare-metal estate you have not operated.

## Source tags

Natoe AI (leased servers, hardening) · Group-IB (self-hosted GitLab / Artifactory / Nexus / Harbor) · Veltris (MinIO, Redis / Memcached) · 2026-11-03 market (self-managed ownership, on-prem platform services) · 2026-11-05 market (OpenStack / OCI private cloud, K8s security names)
