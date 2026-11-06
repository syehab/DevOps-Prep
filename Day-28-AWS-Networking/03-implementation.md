# Day 28 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 28 teaches AWS networking as a path. A VPC holds the address space. Subnets sit in Availability Zones. A route table answers where the packet goes. A Security Group answers whether the packet is allowed. An Internet Gateway makes a subnet public. A NAT Gateway lets a private subnet start outbound internet traffic. A VPC endpoint lets a private subnet reach an AWS service without the internet.

The old lab stayed on paper in `/tmp`. This lab writes a real **VPC module** in ShopSphere: `10.50.0.0/16`, six `/24` subnets, an Internet Gateway, and the EKS OIDC provider that IRSA needs. You **do not apply a NAT Gateway**. NAT plus an Elastic IP bills even when the app is idle.

Work in **your ShopSphere repository**. `kind` plus this Terraform plan is the required path when you have no AWS account.

---

## Goal

Add `infra/aws/modules/network` with VPC `10.50.0.0/16`, public / private-app / private-db subnets in two Availability Zones, and `enable_nat = false` by default. Cover CIDR and NAT-off with `terraform test`. Write the IRSA OIDC provider and a short Pod Identity note. Draw the packet path so you can say it on a call.

Time box: 70 to 90 minutes. Destroy the same session if you apply.

---

## Capstone stage

| Path | Adds |
|:--|:--|
| `infra/aws/modules/network/` | VPC, six subnets, IGW, optional NAT |
| `infra/aws/modules/network/tests/vpc.tftest.hcl` | CIDR and NAT-off asserts |
| `k8s/identity/irsa-sa.yaml` | IRSA annotation (reuse Day 27 if present) |
| `docs/day-28-network.md` | CIDR plan, routes, Security Groups, test output |

Day 27 already added `infra/aws/modules/eks`. This Day gives that cluster its subnets and its OIDC issuer.

---

## What you need

```bash
terraform version
aws sts get-caller-identity
kind get clusters
```

Terraform 1.16.5 and `hashicorp/aws` `5.100.0` are the pins this lab tested. AWS login is optional. `kind` is optional. `terraform test` does not need AWS.

---

## Cost

| Path | Estimated USD (1–2 hours) |
|:--|:--|
| `terraform test` + YAML + notes | **0.00** |
| VPC + subnets + IGW only | **0.00** (these resources do not bill by themselves) |
| NAT Gateway + Elastic IP | **Do not create** (about USD 0.045/hour plus data) |
| EKS from Day 27 | reuse that Day’s table; do not stack a second cluster |

Create a budget alert before you apply anything in a real account. See [../capstone/COST.md](../capstone/COST.md). Do not write "INR 0" or "cost stays at ₹0" if you applied NAT or EKS.

A subnet is public because of its route, not because of its name. NAT is the expensive hop. Leave `enable_nat = false` unless you have a reason and a budget.

---

## Steps

1. Open ShopSphere. Create the module folder.

```bash
mkdir -p infra/aws/modules/network/tests
mkdir -p k8s/identity docs
```

2. Write `infra/aws/modules/network/main.tf`. These resource types and arguments are valid on **aws 5.100.0**. This block **validates** on that provider line.

```hcl
terraform {
  required_version = ">= 1.9.0, < 2.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.100.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

variable "enable_nat" {
  type    = bool
  default = false
}

variable "oidc_issuer_url" {
  type    = string
  default = "https://oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE"
}

resource "aws_vpc" "this" {
  cidr_block           = "10.50.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name    = "shopsphere-dev"
    project = "shopsphere"
    day     = "28"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "shopsphere-dev-igw" }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.50.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags                    = { Name = "shopsphere-dev-public-a" }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.50.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags                    = { Name = "shopsphere-dev-public-b" }
}

resource "aws_subnet" "app_a" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.50.11.0/24"
  availability_zone = "us-east-1a"
  tags              = { Name = "shopsphere-dev-app-a" }
}

resource "aws_subnet" "app_b" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.50.12.0/24"
  availability_zone = "us-east-1b"
  tags              = { Name = "shopsphere-dev-app-b" }
}

resource "aws_subnet" "db_a" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.50.21.0/24"
  availability_zone = "us-east-1a"
  tags              = { Name = "shopsphere-dev-db-a" }
}

resource "aws_subnet" "db_b" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.50.22.0/24"
  availability_zone = "us-east-1b"
  tags              = { Name = "shopsphere-dev-db-b" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = { Name = "shopsphere-dev-public" }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "app" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "shopsphere-dev-app" }
}

resource "aws_route_table_association" "app_a" {
  subnet_id      = aws_subnet.app_a.id
  route_table_id = aws_route_table.app.id
}

resource "aws_route_table_association" "app_b" {
  subnet_id      = aws_subnet.app_b.id
  route_table_id = aws_route_table.app.id
}

resource "aws_eip" "nat" {
  count  = var.enable_nat ? 1 : 0
  domain = "vpc"
}

resource "aws_nat_gateway" "this" {
  count         = var.enable_nat ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public_a.id
}

resource "aws_iam_openid_connect_provider" "eks" {
  url             = var.oidc_issuer_url
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]
}
```

`client_id_list` is a set on this resource. Tests must use `contains(...)`, not `[0]`. The EXAMPLE issuer URL is for `terraform test` only. On a real cluster, Terraform reads the issuer from `aws_eks_cluster.this.identity[0].oidc[0].issuer`.

The thumbprint `9e99a48a9960b14926bb7f3b02e22da2b0ab7280` is the historical root CA value many labs still show. AWS now often accepts an empty `thumbprint_list` because it pins the current Amazon CA. Keep the explicit list in this lab so the plan is stable.

3. Write `infra/aws/modules/network/tests/vpc.tftest.hcl`.

```hcl
mock_provider "aws" {}

run "cidr_and_sku" {
  command = plan

  assert {
    condition     = aws_vpc.this.cidr_block == "10.50.0.0/16"
    error_message = "vpc cidr must be 10.50.0.0/16"
  }

  assert {
    condition     = aws_subnet.app_a.cidr_block == "10.50.11.0/24"
    error_message = "app-a cidr"
  }

  assert {
    condition     = aws_subnet.db_b.cidr_block == "10.50.22.0/24"
    error_message = "db-b cidr"
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 0
    error_message = "NAT must stay off for the lab path"
  }

  assert {
    condition     = contains(aws_iam_openid_connect_provider.eks.client_id_list, "sts.amazonaws.com")
    error_message = "IRSA audience is sts.amazonaws.com"
  }
}

run "nat_off_by_default" {
  command = plan

  variables {
    enable_nat = false
  }

  assert {
    condition     = length(aws_eip.nat) == 0
    error_message = "EIP for NAT must not be planned when enable_nat is false"
  }
}
```

4. Test the module. This does not create AWS resources.

```bash
cd infra/aws/modules/network
terraform init
terraform fmt
terraform validate
terraform test
```

Expected: `Success! 2 passed, 0 failed.` Executed on Terraform 1.16.5 / aws 5.100.0. Copy that line into `docs/day-28-network.md`.

5. Write the address plan and the packet path into the same notes file. Use this layout. Do not overlap the six `/24` ranges.

```text
VPC              10.50.0.0/16

AZ-a public      10.50.1.0/24
AZ-a private-app 10.50.11.0/24
AZ-a private-db  10.50.21.0/24

AZ-b public      10.50.2.0/24
AZ-b private-app 10.50.12.0/24
AZ-b private-db  10.50.22.0/24

                         Internet
                            |
                           IGW
                            |
          +-----------------+-----------------+
          |         VPC 10.50.0.0/16          |
          |  AZ-a             AZ-b            |
          |  10.50.1.0/24     10.50.2.0/24    |  public (ALB; NAT only if enabled)
          |  10.50.11.0/24    10.50.12.0/24   |  private-app
          |  10.50.21.0/24    10.50.22.0/24   |  private-db
          +-----------------------------------+

Public:       10.50.0.0/16 → local ; 0.0.0.0/0 → Internet Gateway
Private-app:  10.50.0.0/16 → local ; 0.0.0.0/0 → NAT Gateway (only if enable_nat)
Private-db:   10.50.0.0/16 → local

Internet → ALB SG : TCP 443 allow
ALB SG   → App SG : TCP 8080 allow
App SG   → DB SG  : TCP 5432 allow
Internet → DB SG  : no inbound rule

Inbound:  User → DNS → ALB (public) → App (private-app) → RDS (private-db)
Outbound: App → NAT → IGW → internet   (skipped in this lab)
S3:       App → S3 gateway endpoint (no NAT) when you add that endpoint
```

Write one sentence: a subnet is public because of its route and addressing, not because of its name. Write a second sentence: the NAT Gateway needs the public subnet and an Elastic IP, because NAT itself must reach the Internet Gateway.

Leave the rest of `10.50.0.0/16` free for later subnets such as VPC endpoints. Write that these ranges do not overlap on-premises, VPN, Direct Connect, or other VPCs. Overlap makes later connectivity fail.

6. IRSA and Pod Identity. If Day 27 already wrote `k8s/identity/irsa-sa.yaml`, keep it. If it is missing, write it now:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: catalog
  namespace: shopsphere
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/shopsphere-catalog
```

Write two sentences in the notes:

- **IRSA** trusts the cluster OIDC issuer. The ServiceAccount annotation names the IAM role. The Pod assumes that role through STS. The OIDC provider resource in this module is that trust.
- **EKS Pod Identity** is the newer attach API. An association maps a ServiceAccount to an IAM role without the OIDC annotation. Both avoid a long-lived access key in the Pod.

On `kind` the annotation does nothing. That is the local fallback. You still commit the YAML so the AWS path is in Git.

7. Optional apply of the VPC only, after a budget alert. Do **not** pass `-var='enable_nat=true'`.

```bash
terraform plan -out=network.tfplan
# terraform apply network.tfplan    # only if you own the account
```

If you apply, pass the live EKS issuer URL into `oidc_issuer_url`. Destroy the same session unless Day 29 will reuse this VPC.

---

## Verify

- `terraform test` printed `2 passed`.
- VPC CIDR is `10.50.0.0/16`. App-a is `10.50.11.0/24`. Db-b is `10.50.22.0/24`.
- `enable_nat` defaults to `false`. The plan does not include `aws_nat_gateway` or `aws_eip.nat`.
- Notes name IGW for public `0.0.0.0/0`, no internet route for private-db, and Security Group sources (ALB → App 8080, App → RDS 5432).
- IRSA YAML is in Git. Notes name IRSA versus Pod Identity.
- You did not run `aws ec2 create-nat-gateway`.
- If you applied, notes name the USD estimate. You did not write "INR 0".

If AWS CLI is missing, the test plus the notes still complete the Day. Do not invent a LocalStack NAT to "make it real." LocalStack can stand in for a VPC plan. It does **not** replace a billed NAT Gateway.

---

## Break and fix

### Failure 1 — overlap the app CIDR

Change `aws_subnet.app_a.cidr_block` to `"10.50.1.0/24"` (same as public-a). Run `terraform validate`. The file can still be valid HCL. `terraform test` still passes the `app_a` assert only if you also change the expected CIDR. Keep the test. Restore `10.50.11.0/24`. Write why overlap is worse than a failed apply: two subnets cannot share one CIDR, and a later peering or VPN with the same range fails in silence until packets vanish.

### Failure 2 — turn NAT on to "fix" private egress

Set `enable_nat = true` in the second test run, or change the default. The NAT assert fails. That is the point. Restore `false`. If a private Pod needs S3, add an S3 gateway endpoint later. Do not give the app a public IP. Do not attach the private-app route table to the Internet Gateway. That would make the subnet public.

---

## Stretch

- Add `aws_security_group` resources for ALB, app, and db with the three allow rules above.
- Add `aws_vpc_endpoint` of type `Gateway` for S3 so private-app can reach S3 with `enable_nat = false`.
- Wire `subnet_ids` from this module into the Day 27 EKS module.
- On `kind`, create an extra network as a stand-in only. Do not treat it as a VPC.

---

## Clean up

If you applied, destroy the same session.

```bash
terraform destroy
aws ec2 describe-vpcs --filters Name=tag:Name,Values=shopsphere-dev
```

Expected after destroy: no VPC with that tag. NAT must not exist. Keep the `kind` cluster `shopsphere` if you use it for later Days.

If you never applied, delete only local Terraform files you do not want (`.terraform/` is safe to remove). Keep the module in Git.

---

## Interview story

**Situation:** The AWS overlay asked for a production VPC, but the old homework only drew CIDRs in `/tmp` and forbade every AWS write. **Task:** Show a real `10.50.0.0/16` module, keep NAT off for cost, and name how EKS Pods get IAM. **Action:** I wrote six `/24` subnets across two AZs, an Internet Gateway on the public route table, and `aws_iam_openid_connect_provider` with audience `sts.amazonaws.com`. I covered CIDR and `enable_nat = false` with `terraform test` on hashicorp/aws 5.100.0. I did not apply a NAT Gateway, because it bills per hour plus data. **Result:** I can trace User → ALB 443 → App 8080 → RDS 5432, and I can compare IRSA (OIDC annotation) to EKS Pod Identity (association API) without putting an access key in the Pod.

---

## Self-score checklist

- [ ] Network module validates and `terraform test` prints 2 passed.
- [ ] VPC is `10.50.0.0/16` and the six `/24` ranges do not overlap.
- [ ] NAT stays off on the lab path.
- [ ] IRSA YAML exists. Notes name IRSA versus Pod Identity.
- [ ] I destroyed any VPC I created.

**Executed:** VPC `validate` + `terraform test` (2 passed) on Terraform 1.16.5 / aws 5.100.0. **Not executed:** live `aws ec2 create-vpc`, NAT Gateway, Elastic IP, `kind` extra networks, Security Group apply.
