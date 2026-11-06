# Day 29 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 29 teaches AWS delivery as a controlled path from a Git commit to a running plan. The old lab built a local image in `/tmp` and mapped CodePipeline on paper. This lab still keeps that map. It then writes the Senior pieces in ShopSphere: an **S3 state backend** with versioning, encryption, and `use_lockfile = true`, plus **GitHub OIDC** so Actions can assume a role with no long-lived access key.

Work in **your ShopSphere repository**. Day 33 is the harder sibling. It promotes the **same image digest** across environments. This Day stops at remote state and federated identity.

---

## Goal

1. Add `infra/aws/backend` that would create the state bucket (versioning on, public access blocked, AES256).
2. Run `terraform test` on that module and on the GitHub OIDC provider plus `shopsphere-gha-terraform` role.
3. Write a partial `backend "s3"` block with `use_lockfile = true`. DynamoDB locking is the old path. Do not require a lock table.
4. Write a GitHub Actions workflow that assumes the role with `id-token: write` and runs `terraform plan`.
5. Keep a short CodePipeline → GitHub Actions stage map so the lesson names stay honest.

Time box: 70 to 90 minutes. Destroy the bucket the same session if you apply.

---

## Capstone stage

| Path | Adds |
|:--|:--|
| `infra/aws/backend/` | State bucket + GitHub OIDC + plan role |
| `infra/aws/backend/tests/backend.tftest.hcl` | Bucket, versioning, issuer asserts |
| `infra/aws/environments/dev/backend.hcl` | Partial S3 backend (`use_lockfile`) |
| `.github/workflows/aws-infra.yml` | OIDC plan job |
| `docs/day-29-aws-delivery.md` | Test output, lock note, stage map |

Day 10 already did Azure Storage state. This Day is the AWS twin. Do not put access keys in `backend.hcl`.

---

## What you need

```bash
terraform version
aws sts get-caller-identity
```

Terraform 1.16.5 and `hashicorp/aws` `5.100.0` are the pins this lab tested. AWS login is optional. `terraform test` does not need AWS. Docker is optional. You do not need CodePipeline, CodeBuild, or ECR to finish the Day.

---

## Cost

| Path | Estimated USD |
|:--|:--|
| `terraform test` + workflow file + notes | **0.00** |
| Empty versioned S3 bucket + a few PUT/GET | **0.05–0.40** |
| GitHub-hosted minutes | **0.00** on a private free account until the minute cap |
| DynamoDB `PAY_PER_REQUEST` lock table | **Do not create** (deprecated lock path) |

Create a budget alert before you apply the bucket. See [../capstone/COST.md](../capstone/COST.md). Do not write "INR 0" or "cost stays at ₹0" if you created the bucket. A leftover empty bucket is cheap. Say so in the notes if you keep it on purpose.

---

## Steps

1. Open ShopSphere. Create the folders.

```bash
mkdir -p infra/aws/backend/tests
mkdir -p infra/aws/environments/dev
mkdir -p .github/workflows docs
```

2. Write `infra/aws/backend/main.tf`. These resource types and arguments are valid on **aws 5.100.0**. This block **validates** on that provider line.

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

variable "bucket_name" {
  type = string
}

variable "github_org" {
  type    = string
  default = "EXAMPLE"
}

variable "github_repo" {
  type    = string
  default = "shopsphere"
}

resource "aws_s3_bucket" "state" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df2640cd",
  ]
}

data "aws_iam_policy_document" "gha_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_org}/${var.github_repo}:*"]
    }
  }
}

resource "aws_iam_role" "gha" {
  name               = "shopsphere-gha-terraform"
  assume_role_policy = data.aws_iam_policy_document.gha_assume.json
}
```

Bucket names are 3 to 63 characters, lowercase, globally unique. Pick a name you own, for example `shopsphere-tfstate-` plus six random digits. Do not commit a company secret in the name.

The issuer `https://token.actions.githubusercontent.com` is the real GitHub Actions OIDC issuer. The two thumbprints are the current GitHub CA values labs still pin. AWS may accept an empty `thumbprint_list` because it trusts the known CA. Keep the list so the plan is stable.

The `sub` condition uses `repo:ORG/REPO:*`. Tighten it later to `ref:refs/heads/main` or an environment name. A `*` subject is enough for this lab and too wide for Production.

3. Write `infra/aws/backend/tests/backend.tftest.hcl`.

```hcl
mock_provider "aws" {}

run "bucket_and_oidc" {
  command = plan

  variables {
    bucket_name = "shopsphere-tfstate-lab-example"
    github_org  = "EXAMPLE"
    github_repo = "shopsphere"
  }

  assert {
    condition     = aws_s3_bucket.state.bucket == "shopsphere-tfstate-lab-example"
    error_message = "bucket name"
  }

  assert {
    condition     = aws_s3_bucket_versioning.state.versioning_configuration[0].status == "Enabled"
    error_message = "versioning must be Enabled"
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.state.block_public_acls == true
    error_message = "block public ACLs"
  }

  assert {
    condition     = contains(aws_iam_openid_connect_provider.github.client_id_list, "sts.amazonaws.com")
    error_message = "GitHub OIDC audience"
  }

  assert {
    condition     = aws_iam_openid_connect_provider.github.url == "https://token.actions.githubusercontent.com"
    error_message = "GitHub OIDC issuer"
  }

  assert {
    condition     = aws_iam_role.gha.name == "shopsphere-gha-terraform"
    error_message = "role name"
  }
}
```

`client_id_list` is a set. Use `contains(...)`. Do not index with `[0]`.

4. Test the module. This does not create AWS resources.

```bash
cd infra/aws/backend
terraform init
terraform fmt
terraform validate
terraform test
```

Expected: `Success! 1 passed, 0 failed.` Executed on Terraform 1.16.5 / aws 5.100.0. Copy that line into `docs/day-29-aws-delivery.md`.

5. Write the partial backend. `infra/aws/environments/dev/backend.hcl`:

```hcl
bucket       = "shopsphere-tfstate-lab-example"
key          = "aws/dev/terraform.tfstate"
region       = "us-east-1"
use_lockfile = true
```

And a stub `infra/aws/environments/dev/backend.tf` (do not put the bucket name here):

```hcl
terraform {
  backend "s3" {}
}
```

Init later with `-backend-config=backend.hcl` after the bucket exists. Until then, stay on local state. `use_lockfile = true` is the current S3 lock. Terraform writes a `.tflock` object next to the state key. DynamoDB `dynamodb_table` locking is deprecated in current Terraform docs. Do not add a lock table for this lab.

If you still want to see the old table shape, this is the valid `attribute` block (newlines, no semicolons):

```hcl
resource "aws_dynamodb_table" "lock" {
  name         = "shopsphere-tf-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
}
```

Do not add that resource to the required module. A wrong `attribute { name = LockID; type = S }` line fails validate.

6. Local lock drill, so you feel the race without S3. In a scratch folder (not the course clone):

```bash
LOCK_DIR="/tmp/day-29-lock-$$"
mkdir -p "$LOCK_DIR"
cd "$LOCK_DIR"
cat > main.tf << 'EOF'
resource "terraform_data" "hold" {
  input = "shopsphere"
  provisioner "local-exec" {
    command = "sleep 20"
  }
}
EOF
terraform init
terraform apply -auto-approve &
sleep 2
terraform apply -auto-approve
```

Expected: the second apply waits or errors on the lock. Copy the lock message. Then wait for the first apply to finish. This is the same race `use_lockfile` prevents on S3. **Executed** with `terraform_data` + `sleep`. **Not executed** against a live bucket.

7. Write `.github/workflows/aws-infra.yml`. This file is valid YAML if GitHub never runs it.

```yaml
name: aws-infra
on:
  pull_request:
    paths:
      - "infra/aws/**"
      - ".github/workflows/aws-infra.yml"
permissions:
  id-token: write
  contents: read
jobs:
  plan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.16.5
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/shopsphere-gha-terraform
          aws-region: us-east-1
      - working-directory: infra/aws/environments/dev
        run: |
          terraform init -backend-config=backend.hcl -input=false
          terraform plan -input=false -no-color
```

`permissions.id-token: write` is required for OIDC. Without it, `configure-aws-credentials` cannot mint a token. Replace the account ID when you own the role. Do not put `AWS_ACCESS_KEY_ID` in GitHub Secrets for this workflow.

8. Stage map in the notes. Copy this table and keep the CodePipeline names from the lesson.

```text
Source  → checkout
Build   → terraform init + validate + test (this Day)
Deploy  → terraform apply after an environment approval (not this Day)
```

GitHub Actions is the runner you can own. CodePipeline is the AWS orchestrator the lesson names. The artifact rule is the same: build once, promote the same object. Day 33 makes that rule real for the catalog image digest.

---

## Verify

- `terraform test` printed `1 passed`.
- Versioning is `Enabled`. Public access is blocked. Encryption is AES256.
- OIDC issuer is `https://token.actions.githubusercontent.com`. Audience is `sts.amazonaws.com`. Role name is `shopsphere-gha-terraform`.
- `backend.hcl` has `use_lockfile = true` and no access key.
- The workflow has `id-token: write` and `aws-actions/configure-aws-credentials@v4`.
- Notes hold the CodePipeline map and the local lock message.
- You did not create a DynamoDB table. You did not create CodePipeline, ECR, or ECS.

If AWS CLI is missing, the test plus the files still complete the Day. LocalStack can stand in for a bucket plan. It does **not** replace OIDC to GitHub.

---

## Break and fix

### Failure 1 — access key in the workflow

Add `env.AWS_ACCESS_KEY_ID: AKIA...` to the plan job. Delete it. The fix is the OIDC role, not a secret of the key. `id-token: write` plus `role-to-assume` is the Senior path. A static key in Actions is the incident.

### Failure 2 — lock table syntax, or skip versioning

Add the DynamoDB table with `attribute { name = LockID; type = S }` on one line with semicolons. `terraform validate` fails. Restore: either omit the table (preferred) or use a multiline `attribute` block. Then comment out `aws_s3_bucket_versioning`. The versioning assert fails. Restore `Enabled`. Versioning is how you recover a deleted state object. The lock only stops a second apply. It does not replace versioning.

---

## Stretch

- Tighten `sub` to `repo:ORG/REPO:ref:refs/heads/main`.
- Add a GitHub Environment `aws-dev` with a required reviewer before any apply job.
- Grant the role `s3:GetObject`, `s3:PutObject`, and `s3:DeleteObject` on `arn:aws:s3:::BUCKET/aws/dev/*` only.
- Tag the same catalog image as `uat` without a second `docker build` (the old Day 29 image drill). Day 33 is the GitOps version of that rule.

---

## Clean up

If you applied the bucket, destroy the same session unless later Days will reuse it.

```bash
terraform destroy
aws s3api head-bucket --bucket shopsphere-tfstate-lab-example
```

Expected after destroy: the head-bucket call fails. Empty the bucket first if versioning left delete markers.

If you never applied, remove `/tmp/day-29-lock-*` and keep the module in Git.

```bash
rm -rf /tmp/day-29-lock-*
```

---

## Interview story

**Situation:** The AWS overlay asked for delivery and remote state, but the old homework only tagged a local image and forbade S3. **Task:** Show an S3 backend with a current lock and GitHub OIDC, not a static key. **Action:** I wrote a versioned, private, AES256 bucket and `use_lockfile = true` on Terraform 1.16.5 / aws 5.100.0. I added `aws_iam_openid_connect_provider` for `https://token.actions.githubusercontent.com` and a role `shopsphere-gha-terraform` whose `sub` is the ShopSphere repo. I proved the lock race with two local applies and `terraform_data`. I did not create a DynamoDB lock table, because current docs deprecate that path. **Result:** I can map CodePipeline Source/Build/Deploy to checkout, plan, and gated apply, and I can say why Day 33 must promote the same digest instead of rebuilding.

---

## Self-score checklist

- [ ] Backend module validates and `terraform test` prints 1 passed.
- [ ] `backend.hcl` uses `use_lockfile = true` and no keys.
- [ ] Workflow uses OIDC (`id-token: write`), not `AWS_ACCESS_KEY_ID`.
- [ ] Notes hold the stage map and the local lock result.
- [ ] I destroyed any bucket I created.

**Executed:** S3 + OIDC `validate` + `terraform test` (1 passed) on Terraform 1.16.5 / aws 5.100.0. Local `terraform_data` lock race is the intended drill. **Not executed:** live `aws s3 mb`, DynamoDB table, CodePipeline, ECR, ECS, GitHub-hosted OIDC assume, `docker build`.
