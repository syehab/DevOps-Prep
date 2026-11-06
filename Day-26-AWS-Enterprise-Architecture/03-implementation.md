# Day 26 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 26 teaches AWS Organizations. The old lab was a markdown file in `/tmp` and forbade every AWS write. This lab still writes the design in **ShopSphere**, then adds a real **SCP** as Terraform (`aws_organizations_policy`) and `terraform test`. You apply the SCP only in a sandbox Organization you own.

---

## Goal

Write `docs/aws-org.md` with OUs, accounts, and an Azure mapping. Add `infra/aws/org/` with a DenyLeaveOrganization SCP. Run `terraform test`. If you have no Organization, the test is the required path. LocalStack does **not** replace Organizations. Write that limit.

Time box: 60 to 80 minutes.

---

## Capstone stage

| Path | Adds |
|:--|:--|
| `docs/aws-org.md` | Org, OUs, accounts, Azure map |
| `infra/aws/org/scp.tf` | `aws_organizations_policy` |
| `infra/aws/org/tests/scp.tftest.hcl` | Name and type asserts |
| `docs/day-26-aws.md` | Test output |

---

## What you need

```bash
terraform version
aws sts get-caller-identity
```

Terraform 1.16.5 and `hashicorp/aws` `5.100.0` are the pins this lab tested. AWS login is optional.

---

## Cost

| Path | Estimated USD |
|:--|:--|
| Design + `terraform test` | **0.00** |
| Create SCP in an existing Organization | **0.00** (SCP is a policy document) |
| `organizations create-account` | **Do not run** in this lab |

An empty SCP does not bill. A new account can. Stay on the test path unless this is a throwaway sandbox.

---

## Steps

1. Write `docs/aws-org.md` in ShopSphere.

Required sections:

- One Organization name
- OUs: Security, Infrastructure, Production, NonProduction
- Accounts: log-archive, security, network, shop-dev, shop-prod
- Table: Azure subscription ↔ AWS account, management group ↔ OU, Azure Policy ↔ SCP
- One paragraph: the account is the blast-radius unit

2. Write `infra/aws/org/versions.tf` (providers only, no `provider` block in the reusable file if you prefer; a root may include the provider).

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

resource "aws_organizations_policy" "deny_leave" {
  name        = "DenyLeaveOrganization"
  type        = "SERVICE_CONTROL_POLICY"
  description = "ShopSphere lab SCP"
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "DenyLeave"
      Effect   = "Deny"
      Action   = ["organizations:LeaveOrganization"]
      Resource = "*"
    }]
  })
}
```

`DenyLeaveOrganization` is a real Organizations action. It is a common first SCP. It is not a replacement for a full guardrail set.

3. Write `infra/aws/org/tests/scp.tftest.hcl`.

```hcl
mock_provider "aws" {}

run "name" {
  command = plan

  assert {
    condition     = aws_organizations_policy.deny_leave.name == "DenyLeaveOrganization"
    error_message = "name"
  }

  assert {
    condition     = aws_organizations_policy.deny_leave.type == "SERVICE_CONTROL_POLICY"
    error_message = "type must be SERVICE_CONTROL_POLICY"
  }
}
```

```bash
cd infra/aws/org
terraform init
terraform validate
terraform test
```

Expected: `1 passed, 0 failed`. Executed on Terraform 1.16.5 / aws 5.100.0.

4. Optional attach (sandbox only):

```bash
aws organizations list-roots
aws organizations attach-policy --policy-id <id> --target-id <ou-id>
```

Do not attach this SCP to the management account in a way that locks you out of later labs. Prefer a Sandbox OU.

5. If `aws` is missing, keep the JSON in Git. LocalStack can stub some Organizations APIs. It is not your company Organization. Write `localstack is a stub`.

---

## Verify

- `docs/aws-org.md` has four OUs and separate shop-dev / shop-prod accounts.
- `terraform test` passed.
- SCP type is `SERVICE_CONTROL_POLICY`.
- Notes do not claim you created accounts.

---

## Break and fix

### Failure 1 — Dev and Prod in one account

Edit the doc so shop-dev and shop-prod share one account. Write the blast radius: an IAM admin in Dev is an admin in Prod. Restore two accounts. This is the same break as Day 11 on Azure.

### Failure 2 — SCP type typo

Set `type = "SERVICE_CONTROL_POLICY"` to `"AISERVICES_OPT_OUT_POLICY"` in a copy, run `terraform test`. The type assert fails. Restore the lab type.

---

## Stretch

- Add a second statement that denies `s3:PutBucketPublicAccessBlock` being deleted, or `ec2:AcceptVpcPeeringConnection` without a condition. Keep it in Git as JSON. Do not attach it blindly.
- Map this file to Azure Policy from Day 38.

---

## Clean up

If you attached a policy, detach it, then destroy:

```bash
terraform destroy
```

Keep the `.tf` and the design doc.

---

## Interview story

**Situation:** ShopSphere Azure landing zone existed, but the AWS interview asked for Organizations and SCPs. **Task:** Show the same isolation model with an account boundary and one real SCP. **Action:** I wrote OUs and separate Dev/Prod accounts, then `aws_organizations_policy` `DenyLeaveOrganization` with `terraform test` on hashicorp/aws 5.100.0. I did not create accounts. I documented that LocalStack is a stub. **Result:** I can map subscription↔account and Azure Policy↔SCP, and I can say why one shared account is the blast-radius bug.

---

## Self-score checklist

- [ ] Design names separate Dev and Prod accounts.
- [ ] `terraform test` passed.
- [ ] I rewrote the shared-account break.
- [ ] I did not create billable accounts.

**Executed:** SCP `validate` + `terraform test`. **Not executed:** `organizations attach-policy`, LocalStack.
