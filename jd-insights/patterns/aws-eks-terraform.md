# AWS + EKS + Terraform

## In one sentence

AWS senior roles ask for the same loop as Azure ones (Terraform plus a managed Kubernetes cluster plus CI/CD), just with AWS names.

## What employers ask for

- Terraform for AWS infrastructure (VPC, IAM, EKS, data stores)
- "Everything as Code": some JDs say Terraform or OpenTofu. OpenTofu is the open-source fork of Terraform with the same workflow, so your Terraform skills transfer as they are
- Running production workloads on EKS
- CI/CD that builds images and deploys to the cluster
- AWS account and network structure (who can reach what)
- Networking fundamentals: senior platform interviews still ask OSI-layer basics, so keep Day-3 fresh
- Observability on top of the cluster (often Prometheus, Grafana, or Datadog)
- Lead roles add advisor work: explain and defend a design choice (accounts, IAM, network, security, cost) and its trade-offs to a client, not just build it
- Data and messaging operations: RDS (PostgreSQL), ElastiCache (Redis), MSK (Kafka). JDs ask backups, replication, failover, and DR with RTO and RPO. Multi-region is a plus. Service knobs are Look-up
- Some product roles want a Terraform module per tenant, applied only by a pipeline, with a check after apply

## Mental model

```text
Terraform
   ├── VPC (network)
   ├── IAM (identity)
   ├── EKS (cluster)
   └── RDS / S3 (data)
        ↓
CI/CD builds image → pushes to registry
        ↓
Deploy to EKS (Helm or GitOps)
        ↓
Observe → fix → repeat
```

If you know AKS, you already know most of EKS. Translate the names:

| Concept | Azure | AWS |
|:--|:--|:--|
| Managed Kubernetes | AKS | EKS |
| Network | VNet | VPC |
| Identity for pods | Workload Identity | IRSA / Pod Identity |
| Image registry | ACR | ECR |
| Monitoring | Azure Monitor | CloudWatch |

RPO is how much recent data you can afford to lose. RTO is how quickly the service must return. Think of a shop fire: RPO is how many days of receipts you can lose. RTO is how many hours until the shop opens again. Backups, replicas, and failover exist to meet those two numbers. They are not the same control. Day 27 places the stores. Day 39 teaches the recovery numbers.

## Remember

> **Clouds change the names, not the shape. Learn the shape once (network, identity, cluster, pipeline) and map the names.**

## Study these days first

1. [Day-26-AWS-01-AWS-Enterprise-Architecture-Clean-Style.md](../../Day-26-AWS-01-AWS-Enterprise-Architecture-Clean-Style.md) - AWS big picture
2. [Day-27-AWS-02-AWS-Compute-Clean-Style.md](../../Day-27-AWS-02-AWS-Compute-Clean-Style.md) - compute choices
3. [Day-28-AWS-03-AWS-Networking-Clean-Style.md](../../Day-28-AWS-03-AWS-Networking-Clean-Style.md) - VPC and routing
4. [Day-29-AWS-04-AWS-DevOps-Architecture-Clean-Style.md](../../Day-29-AWS-04-AWS-DevOps-Architecture-Clean-Style.md) - AWS delivery
5. [Day-17-L17-AKS-EKS-Managed-Kubernetes-Architecture.md](../../Day-17-L17-AKS-EKS-Managed-Kubernetes-Architecture.md) - AKS vs EKS side by side
6. [Day-14-L14-Kubernetes-Mental-Model.md](../../Day-14-L14-Kubernetes-Mental-Model.md) and [Day-15-L15-Kubernetes-Networking-Troubleshooting-v2.md](../../Day-15-L15-Kubernetes-Networking-Troubleshooting-v2.md) - the Kubernetes core
7. [Day-3-L03-Networking-Fundamentals.md](../../Day-3-L03-Networking-Fundamentals.md) - the OSI basics that still show up in senior platform interviews
8. [Day-39-Production-Project-09-Disaster-Recovery-Cost-Engineering-Clean-Style.md](../../Day-39-Production-Project-09-Disaster-Recovery-Cost-Engineering-Clean-Style.md) - RTO, RPO, backup, replication, and failover

## Common interview question

**Q: Walk me through deploying a new service to EKS from scratch.**

Outline:
1. Terraform: VPC, EKS cluster, node group, IAM roles, ECR repo.
2. Pipeline: build image, scan, push to ECR.
3. Deploy with Helm or GitOps, service and ingress for traffic.
4. Add metrics, logs, and an alert before calling it done.

## Honest gap note

If your daily cloud is Azure, say that, then prove the mapping: "I run AKS in production; EKS differs mainly in identity (IRSA) and networking (VPC CNI), and here is how I would close that gap." That is stronger than pretending equal depth.

## Source tags

EPAM Senior AWS DevOps · Sezzle SRE · EPAM Lead AWS DevOps · Turkey product co Senior Platform (AWS) · Turkey / Central Asia Senior DevOps (MSK, RDS, ElastiCache DR) · Turkey / Central Asia Platform (module per tenant)
