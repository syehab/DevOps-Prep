# Day 25 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 25 teaches Azure DevOps and IaC as one delivery architecture. An application change and an infrastructure change are related. They are not the same pipeline. This lab makes the **infra** pipeline real: format, validate, `tflint`, Checkov, `terraform test`, plan on a pull request, apply only after an approval. You also write the same stages as Azure Pipelines YAML so the lesson names stay honest.

Work in **your ShopSphere repository**. You need `infra/azure/environments/dev` from Days 8 to 10. If those folders are missing, create them from those Day files first.

---

## Goal

Add two pipeline files that run the same gates. GitHub Actions is the path you can run on a repo you own. Azure Pipelines is the path the lesson names. Locally you run the same commands without a hosted agent.

When you finish, you can say which identity plans, which identity applies, and why that identity is federated OIDC, not a password in GitHub Secrets.

Time box: 70 to 90 minutes.

---

## Capstone stage

| Path in ShopSphere | What it adds |
|:--|:--|
| `.github/workflows/infra.yml` | PR plan + gated apply |
| `infra/azure/azure-pipelines-infra.yml` | Same stages for Azure DevOps |
| `infra/azure/environments/dev/.tflint.hcl` | tflint config |
| `docs/day-25-pipeline-lab.md` | Command output and OIDC note |

Day 6 already added app CI. This Day is **only** the infra pipeline. Do not merge app publish and Prod apply into one job.

---

## What you need

```bash
terraform version
tflint --version
checkov --version
```

Install if missing:

- Terraform 1.16.5 from [releases.hashicorp.com/terraform/1.16.5](https://releases.hashicorp.com/terraform/1.16.5/)
- tflint v0.55.1 from [github.com/terraform-linters/tflint](https://github.com/terraform-linters/tflint/releases)
- Checkov 3.2.x: `python3 -m pip install --user 'checkov==3.2.447'`

Azure login is optional. `terraform test` and the linters do not need it. A live `terraform plan` against Azure needs OIDC or `az login`.

---

## Cost

| Path | Estimated USD |
|:--|:--|
| Local lint + `terraform test` | **0.00** |
| GitHub-hosted `ubuntu-latest` minutes | **0.00** on a private free account until the minute cap |
| Live `terraform plan` (no apply) | **0.00** |
| Live apply of only the Day 8 resource group | **0.00-0.10** |

Do not apply AKS from this pipeline. Create a GitHub Environment named `azure-dev` with a required reviewer before you enable the apply job. See [../capstone/COST.md](../capstone/COST.md).

---

## Steps

1. Open ShopSphere. Confirm the Dev root exists.

```bash
test -f infra/azure/environments/dev/main.tf && echo "dev root present"
```

2. Add tflint config. Put this in `infra/azure/environments/dev/.tflint.hcl`.

```hcl
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}
```

The `terraform` ruleset is bundled with tflint 0.55.1. `tflint --init` still succeeds when no extra plugin is declared.

```bash
cd infra/azure/environments/dev
tflint --init
tflint
```

Expected: no issues, exit code 0. If tflint reports unused variables, fix the file. Do not add `--force` to hide it.

3. Run Checkov on the backend module from Day 10. That module has a Storage account, so the scan has something real to say.

```bash
cd infra/azure/backend
checkov -d . --framework terraform
```

On Checkov 3.2.447 against the Day 10 account, `CKV_AZURE_3` (HTTPS only) **passes** when `https_traffic_only_enabled = true`. `CKV_AZURE_33` (queue logging) **fails** on a tiny lab account. That fail is useful. Write the check ID in the notes. Decide one: add queue logging, or skip that check with a comment you can defend.

Skip only with an explicit config, not by ignoring the command. Example `infra/azure/backend/.checkov.yml`:

```yaml
skip-check:
  - CKV_AZURE_33  # lab state account has no Queue workload; Day 36 reviews this skip
```

Re-run:

```bash
checkov -d . --framework terraform --config-file .checkov.yml
```

4. Run the Terraform gates in Dev.

```bash
cd infra/azure/environments/dev
terraform fmt -check
terraform init -input=false
terraform validate
terraform test
```

Expected: fmt check exits 0, validate succeeds, test passes. If fmt check fails, run `terraform fmt` and commit the spacing.

5. Write the GitHub Actions workflow. Put this in `.github/workflows/infra.yml`. Pins use tags here. In a company repo you also pin the commit SHA.

```yaml
name: shopsphere-infra

on:
  pull_request:
    paths:
      - "infra/azure/**"
      - ".github/workflows/infra.yml"
  push:
    branches: [main]
    paths:
      - "infra/azure/**"

permissions:
  contents: read
  id-token: write
  pull-requests: write

jobs:
  validate:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: infra/azure/environments/dev
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.16.5
      - uses: terraform-linters/setup-tflint@v4
        with:
          tflint_version: v0.55.1
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
      - run: pip install "checkov==3.2.447"
      - run: terraform fmt -check -recursive ../..
      - run: terraform init -input=false -backend=false
      - run: terraform validate
      - run: terraform test
      - run: tflint --init && tflint
      - run: checkov -d ../../backend --framework terraform

  plan:
    needs: validate
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    environment: azure-dev
    defaults:
      run:
        working-directory: infra/azure/environments/dev
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.16.5
      - uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      - run: terraform init -input=false -backend-config=backend.hcl
      - run: terraform plan -input=false -out=tfplan
      - run: terraform show -no-color tfplan

  apply:
    needs: validate
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    runs-on: ubuntu-latest
    environment: azure-dev
    defaults:
      run:
        working-directory: infra/azure/environments/dev
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.16.5
      - uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      - run: terraform init -input=false -backend-config=backend.hcl
      - run: terraform apply -input=false -auto-approve
```

`permissions.id-token: write` is required for OIDC. The secrets are **identifiers**, not passwords. You still create a federated credential on the Entra app (Day 18). If those values are missing, the `validate` job still runs. The `plan` and `apply` jobs fail on `azure/login`. That is expected until Day 18.

Create the GitHub Environment `azure-dev` in the repo settings. Add a required reviewer on apply. The `plan` job uses the same environment so you can add a wait timer later. You may split plan to a job without a reviewer if you want PR plans to be automatic.

6. Write the Azure Pipelines twin. Put this in `infra/azure/azure-pipelines-infra.yml`. The lesson uses Azure DevOps. The commands stay the same.

```yaml
trigger:
  branches:
    include: [main]
  paths:
    include:
      - infra/azure/*

pr:
  paths:
    include:
      - infra/azure/*

pool:
  vmImage: ubuntu-latest

stages:
  - stage: Validate
    jobs:
      - job: gates
        steps:
          - task: TerraformInstaller@1
            inputs:
              terraformVersion: 1.16.5
          - script: |
              terraform fmt -check -recursive
              terraform init -input=false -backend=false
              terraform validate
              terraform test
            workingDirectory: infra/azure/environments/dev
            displayName: fmt validate test
          - script: |
              curl -sSfL https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
              tflint --init
              tflint
            workingDirectory: infra/azure/environments/dev
            displayName: tflint
          - script: |
              pip install "checkov==3.2.447"
              checkov -d infra/azure/backend --framework terraform
            displayName: checkov

  - stage: Plan
    dependsOn: Validate
    condition: eq(variables['Build.Reason'], 'PullRequest')
    jobs:
      - job: plan
        steps:
          - script: echo "Run terraform plan here with an Azure Resource Manager service connection that uses workload identity federation. Do not store a client secret."
            displayName: plan placeholder

  - stage: Apply
    dependsOn: Validate
    condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
    jobs:
      - deployment: apply
        environment: azure-dev
        strategy:
          runOnce:
            deploy:
              steps:
                - script: echo "Apply only after the environment check. Same identity must not push app images."
                  displayName: apply placeholder
```

The Plan and Apply stages are placeholders on purpose if you have no Azure DevOps org. The YAML is still valid enough to read. Do not invent task names. `TerraformInstaller@1` is a real Microsoft DevLabs task. If your org does not install that task, use a script that downloads Terraform 1.16.5 the same way this course does.

7. Run the local equivalent of the validate job. Record the four exit codes.

```bash
cd infra/azure/environments/dev
terraform fmt -check -recursive ../..
echo fmt:$?
terraform validate
echo validate:$?
terraform test
echo test:$?
tflint
echo tflint:$?
checkov -d ../../backend --framework terraform --quiet
echo checkov:$?
```

8. Write the identity split in `docs/day-25-pipeline-lab.md`. Four lines:

- The validate job needs no Azure identity.
- The plan job uses OIDC to a Dev role that can read state and read Azure.
- The apply job uses OIDC to a Dev role that can write the resource group. It waits on the `azure-dev` environment.
- Neither job is the app pipeline identity that pushes images.

---

## Verify

- `.github/workflows/infra.yml` has separate `validate`, `plan`, and `apply` jobs.
- `permissions.id-token: write` is present. No `AZURE_CLIENT_SECRET` appears.
- Local `terraform fmt -check`, `validate`, `terraform test`, and `tflint` exited 0.
- Checkov ran. You recorded `CKV_AZURE_3` or another real check ID.
- `azure-pipelines-infra.yml` has stages named Validate, Plan, and Apply.
- You can say why app publish and Prod apply are different identities.

---

## Break and fix

### Failure 1 — fmt gate

Add extra spaces to `infra/azure/environments/dev/main.tf` on purpose. Run `terraform fmt -check`. Expected: exit code 1 and a list of files. Diagnose with that command. Run `terraform fmt`. Run `fmt -check` again. Expected: exit 0. The pipeline would have blocked the PR.

### Failure 2 — Checkov fails a check Terraform accepts

`terraform validate` does not enforce security policy. Checkov 3.2.447 against the Day 10 Storage account **fails** `CKV_AZURE_33` (Queue logging) even when the configuration is valid Terraform.

```bash
cd infra/azure/backend
terraform validate
checkov -d . --framework terraform --check CKV_AZURE_33
```

Expected: validate succeeds. Checkov prints **FAILED** for `CKV_AZURE_33`. Write the check ID in the notes.

Put the skip in `.checkov.yml` (step 3) or add the logging resource if you want a real fix. Re-run with `--config-file .checkov.yml`. Expected: the check is skipped and the skip reason is in Git. A silent ignore is not a fix.

---

## Stretch

- Pin `actions/checkout` and `azure/login` to a commit SHA.
- Upload `tfplan` as a workflow artifact and apply **that** file on main (`terraform apply tfplan`).
- Add `infracost breakdown` on the plan JSON. Day 39 makes cost a required story.

---

## Clean up

No Azure resource is required today. If a plan job created nothing, there is nothing to destroy.

If you enabled apply and it created `rg-shopsphere-dev`:

```bash
cd infra/azure/environments/dev
terraform destroy -input=false
```

Remove any client secret you created by mistake. Prefer deleting that secret and using federation.

Commit the workflow files, `.tflint.hcl`, optional `.checkov.yml`, and the notes.

---

## Interview story

**Situation:** ShopSphere could apply Terraform from a laptop after Day 10, so a review never saw the plan. **Task:** Put fmt, validate, test, tflint, and Checkov on every pull request, and apply only after a human approval, using OIDC instead of a stored password. **Action:** I added `.github/workflows/infra.yml` with `id-token: write` and an `azure-dev` environment. I ran the same gates locally: `terraform fmt -check`, `terraform test`, `tflint`, and Checkov 3.2.447, which failed `CKV_AZURE_33` on queue logging and passed `CKV_AZURE_3` when HTTPS-only was set. I wrote a matching Azure Pipelines file so I can tell either product story. **Result:** A PR cannot merge an unformatted or untested module, and apply is a different job with a different approval.

---

## Self-score checklist

- [ ] App pipeline and infra pipeline are different files.
- [ ] Local fmt, validate, test, and tflint passed.
- [ ] Checkov produced a real check ID.
- [ ] I broke `fmt -check` and I fixed it with `terraform fmt`.
- [ ] I saw `CKV_AZURE_33` fail while `terraform validate` passed, then I recorded a skip or a fix.
- [ ] The GitHub workflow has no client secret.
- [ ] I can explain OIDC in three sentences.
- [ ] Files live in ShopSphere.

Count the boxes. 7 or 8 is done.
