# Day 27 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 27 teaches AWS compute. The old lab was a decision table plus `python3 -m http.server`. This lab writes **EKS via Terraform**: `aws_eks_cluster` plus a one-node `t3.small` node group. You apply only after a budget alert, and you destroy the same session. `kind` plus IRSA annotations is the required path when you have no AWS account.

---

## Goal

Add `infra/aws/modules/eks` with cluster name `shopsphere-dev` and `instance_types = ["t3.small"]`. Cover both with `terraform test`. Write the IRSA ServiceAccount annotation. Fill a short EC2 / Fargate / EKS / Lambda table so the lesson choice stays.

Time box: 70 to 90 minutes. Destroy before you walk away.

---

## Capstone stage

| Path | Adds |
|:--|:--|
| `infra/aws/modules/eks/` | Cluster + node group |
| `k8s/identity/irsa-sa.yaml` | IRSA annotation |
| `docs/day-27-eks.md` | Test output + cost decision |

---

## What you need

```bash
terraform version
aws sts get-caller-identity
kind get clusters
```

`hashicorp/aws` `5.100.0`. AWS login is optional.

---

## Cost

| Path | Estimated USD (1–2 hours) |
|:--|:--|
| `terraform test` + kind YAML | **0.00** |
| EKS control plane + 1 × `t3.small` + gp3 disk | **2.00–5.00** |
| NAT Gateway | **Do not create** |

Budget first. Control plane bills about USD 0.10/hour even with zero Pods. Do not write "INR 0" if you apply.

---

## Steps

1. Write `infra/aws/modules/eks/main.tf`. This block **validates** on aws 5.100.0.

```hcl
variable "subnet_ids" { type = list(string) }
variable "role_arn" { type = string }
variable "node_role_arn" { type = string }

resource "aws_eks_cluster" "this" {
  name     = "shopsphere-dev"
  role_arn = var.role_arn

  vpc_config {
    subnet_ids = var.subnet_ids
  }
}

resource "aws_eks_node_group" "sys" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "sys"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.subnet_ids
  instance_types  = ["t3.small"]

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }
}
```

IAM roles for EKS and nodes are required on apply. Day 28 can add the role documents. For the test, pass fake ARNs.

2. `infra/aws/modules/eks/tests/eks.tftest.hcl`:

```hcl
mock_provider "aws" {}

run "sku" {
  command = plan

  variables {
    subnet_ids    = ["subnet-aaa", "subnet-bbb"]
    role_arn      = "arn:aws:iam::123456789012:role/eks"
    node_role_arn = "arn:aws:iam::123456789012:role/node"
  }

  assert {
    condition     = aws_eks_cluster.this.name == "shopsphere-dev"
    error_message = "cluster name"
  }

  assert {
    condition     = aws_eks_node_group.sys.instance_types[0] == "t3.small"
    error_message = "lab node must be t3.small"
  }
}
```

```bash
cd infra/aws/modules/eks
terraform init
terraform validate
terraform test
```

Expected: `1 passed`. Executed on Terraform 1.16.5 / aws 5.100.0.

3. IRSA YAML. `k8s/identity/irsa-sa.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: catalog
  namespace: shopsphere
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/shopsphere-catalog
```

EKS Pod Identity is the newer attach API. IRSA is the OIDC annotation above. Write one sentence: both avoid long-lived access keys in the Pod. On `kind` the annotation does nothing.

4. Decision table (short). In `docs/day-27-eks.md`: EC2 (you patch the VM), Fargate (you ship a task), EKS (you own nodes or Fargate profiles), Lambda (you own the function and cold start). ShopSphere v1 on AWS is EKS to match AKS.

5. Optional apply from `infra/aws/environments/dev` after Day 28 gives subnets. Destroy:

```bash
terraform destroy
aws eks describe-cluster --name shopsphere-dev
```

Expected after destroy: `ResourceNotFoundException`.

---

## Verify

- `terraform test` passed on name and `t3.small`.
- IRSA annotation is in Git.
- Notes name the USD estimate if you applied.
- You did not run `eksctl` as a hidden extra (it is a real tool; this lab uses Terraform).

---

## Break and fix

### Failure 1 — default to `m5.large`

Change `instance_types` to `["m5.large"]`. Run `terraform test`. Expected: assert fails. Restore `t3.small`. That is how a lab exceeds USD 5.

### Failure 2 — access key in the Pod

Add `env.value` with a fake `AKIA...` in the ServiceAccount notes. Delete it. The fix is the IRSA annotation, not a Kubernetes Secret of the key.

---

## Stretch

- Add `aws_iam_role` + `AmazonEKSClusterPolicy` / `AmazonEKSWorkerNodePolicy` documents.
- Write the AKS twin from Day 17 next to this module.

---

## Clean up

Destroy EKS the same session if you applied. Keep `kind` cluster `shopsphere`.

---

## Interview story

**Situation:** The AWS overlay asked for EKS, but the old homework only ran Python on a laptop. **Task:** Describe EKS in Terraform at lab SKU and show IRSA. **Action:** I wrote `aws_eks_cluster` and a one-node `t3.small` group on hashicorp/aws 5.100.0, covered both with `terraform test`, and committed `eks.amazonaws.com/role-arn`. I did not apply without a budget, because the control plane bills per hour. **Result:** I can compare AKS Workload Identity to IRSA and I can say why `kind` is not EKS.

---

## Self-score checklist

- [ ] EKS module validates and tests pass.
- [ ] Node type is `t3.small`.
- [ ] IRSA YAML exists.
- [ ] I destroyed any cluster I created.

**Executed:** EKS `validate` + `terraform test`. **Not executed:** live `aws eks create`, `eksctl`, NAT, node IAM apply.
