# AWS + EKS + Terraform

## In one sentence

AWS senior roles ask for the same loop as Azure ones (Terraform plus a managed Kubernetes cluster plus CI/CD), just with AWS names.

## What employers ask for

- Terraform for AWS infrastructure (VPC, IAM, EKS, data stores)
- Running production workloads on EKS
- CI/CD that builds images and deploys to the cluster
- AWS account and network structure (who can reach what)
- Observability on top of the cluster (often Prometheus or Datadog)

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

## Remember

> **Clouds change the names, not the shape. Learn the shape once (network, identity, cluster, pipeline) and map the names.**

## Study these days first

1. [Day-26-AWS-01-AWS-Enterprise-Architecture-Clean-Style.md](../../Day-26-AWS-01-AWS-Enterprise-Architecture-Clean-Style.md) - AWS big picture
2. [Day-27-AWS-02-AWS-Compute-Clean-Style.md](../../Day-27-AWS-02-AWS-Compute-Clean-Style.md) - compute choices
3. [Day-28-AWS-03-AWS-Networking-Clean-Style.md](../../Day-28-AWS-03-AWS-Networking-Clean-Style.md) - VPC and routing
4. [Day-29-AWS-04-AWS-DevOps-Architecture-Clean-Style.md](../../Day-29-AWS-04-AWS-DevOps-Architecture-Clean-Style.md) - AWS delivery
5. [Day-17-L17-AKS-EKS-Managed-Kubernetes-Architecture.md](../../Day-17-L17-AKS-EKS-Managed-Kubernetes-Architecture.md) - AKS vs EKS side by side
6. [Day-14-L14-Kubernetes-Mental-Model.md](../../Day-14-L14-Kubernetes-Mental-Model.md) and [Day-15-L15-Kubernetes-Networking-Troubleshooting-v2.md](../../Day-15-L15-Kubernetes-Networking-Troubleshooting-v2.md) - the Kubernetes core

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

EPAM Senior AWS DevOps · Sezzle SRE
