# Golden Images (the Image Factory)

## In one sentence

Two 2026 EPAM Kazakhstan JDs want an "image factory": pipelines that build hardened, pre-approved VM and container images, so every machine starts from the same known-good template instead of being fixed by hand.

## What employers ask for

- Pipelines that build golden images for both VMs and containers
- Linux and Windows baselines (cloudbase-init is named for Windows first boot)
- CIS hardening baked into the image, not applied later by hand
- Image scanning before the image is published
- Configuration as code: Ansible for VM post-provisioning and the golden-image handoff
- Publishing VM images to a Shared Image Gallery (Azure Compute Gallery) as a nice-to-have
- Container image lifecycle in a registry (ACR, also ECR): build, scan, tag, then a retention policy so untagged and unused tags do not live forever
- Bottlerocket appears on hybrid EKS JDs as an AWS container OS. Same bake-and-replace loop. Look-up the AMI. Do not invent a Bottlerocket lab. See the [Kubernetes card](kubernetes-production.md) for Hybrid Nodes

## Mental model

A golden image is a baked cake, not a recipe someone follows on each server:

```text
Base OS
  ↓
Configure (Ansible: packages, agents, settings)
  ↓
Harden (CIS baseline)
  ↓
Scan (fail the build on bad findings)
  ↓
Publish (gallery for VM images, registry for containers)
  ↓
VMs / VMSS / pods launch from the image
  ↓
Patch needed? Rebuild and replace. Never SSH in to fix one machine.
```

The same loop you already know from containers (build, scan, push, deploy) applied to VM images too. One pipeline is the factory; everything downstream just consumes its output.

The registry side of that loop has a keep-and-delete policy. You build, you scan, you tag (semver plus git SHA), and you set retention. Untagged manifests and old feature tags can expire. Production digests stay until you retire that release. Day-19 already treats the registry as a trusted distribution point. This card names the lifecycle, not only the lock.

Bottlerocket is AWS's container OS for worker nodes. It is small and you do not SSH in to patch it. A telco hybrid JD that names Bottlerocket next to EKS is still asking for this factory: bake, scan, publish, replace. Day-27 Part 3 already teaches that immutable loop. The [Kubernetes card](kubernetes-production.md) places Hybrid Nodes. Do not claim Bottlerocket flags you have not used.

## Remember

> **Bake, do not patch in place. If a running machine needs a fix, you rebuild the image and replace the machine. Hand-fixed servers drift apart; baked images stay identical.**

## Study these days first

1. [Day-27-AWS-Compute/01-concepts.md](../../Day-27-AWS-Compute/01-concepts.md) - Part 3: machine images and the immutable loop (build image, test, launch new, replace old)
2. [Day-23-Azure-Compute-and-PaaS/01-concepts.md](../../Day-23-Azure-Compute-and-PaaS/01-concepts.md) - Part 3: VM Scale Sets, where an image or model update rolls across instances
3. [Day-13-Docker-and-Container-Fundamentals/01-concepts.md](../../Day-13-Docker-and-Container-Fundamentals/01-concepts.md) - how container images are built from layers
4. [Day-19-Secure-CI-CD-and-Supply-Chain/01-concepts.md](../../Day-19-Secure-CI-CD-and-Supply-Chain/01-concepts.md) - image scanning, digests, and provenance (the "scan and publish" steps)

## Common interview question

**Q: How would you design a pipeline that produces hardened VM images for many teams?**

Outline:
1. Start from a vendor base OS image, one pipeline per OS family (Linux, Windows).
2. Configuration as code applies packages, agents, and settings (Ansible), so the image content is reviewable in Git.
3. Apply a CIS hardening baseline inside the build, then scan the result; failures block publishing.
4. Publish versioned images to a central gallery; teams launch VMs and scale sets from them.
5. Patching is a rebuild: new image version, rolling replace, old version kept for rollback.

## Honest gap note

Do not claim hands-on time with a specific image-build tool or scanner you have not used. It is honest and strong to explain the immutable idea (bake, do not patch in place), the container version of the same loop you do know, and Ansible as configuration code concepts. These JDs name the pattern, cloudbase-init, CIS, and Ansible; they do not require one specific build tool.

## Source tags

EPAM Senior DevOps (Unified Automation) · EPAM Lead Cloud (KZ) · 2026-11-04 market (ACR image lifecycle: build, scan, tag, retention) · 2026-11-06 market (Bottlerocket as AWS immutable node OS)
