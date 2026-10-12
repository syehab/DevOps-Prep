# Day 25 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 25 teaches Azure DevOps and IaC as one delivery architecture. An application change and an infrastructure change are related. They are not the same pipeline. This lab makes that split real on disk. You create `shopsphere-app/` and `shopsphere-infra/`. Each folder gets its own `azure-pipelines.yml`. The app pipeline builds, tests, and publishes. The infra pipeline formats, validates, and plans. You do not apply Production and you do not push a container image.

Work in a temporary directory. Do not run this lab inside the DevOps-Prep course repository. You do not need an Azure DevOps organization, an Azure subscription, Maven, or Docker. If Terraform is on your `PATH`, you run `terraform init` and `terraform validate` against a local file. If Terraform is missing, the YAML files still complete the lab.

---

## Goal

Create two repository folders that match the lesson: `shopsphere-app` for software delivery, and `shopsphere-infra` for platform delivery. Put a real Azure Pipelines file in each folder. The app file uses stages named Build, Test, and Publish. The infra file uses stages named Fmt, Validate, and Plan. Those names map to the two mental models from the lesson.

When you finish, you can open both YAML files and say which change belongs in which repository. You can also explain why one pipeline identity must not both apply Production and push images. You write that split on paper, or in a notes file, before you clean up.

Time box: 45 to 75 minutes. Cost stays at ₹0. Stop when both YAML files exist, the optional Terraform check has run or you recorded that Terraform is absent, and the identity break is written down.

---

## What you need

You need a shell and Git. Check them first:

```bash
git --version
```

Check for Terraform. The command below prints a version if Terraform is installed. If the command fails, continue with YAML only. Do not install Terraform for this lab unless you already planned to.

```bash
terraform version
```

You do not need Azure, ACR, AKS, Key Vault, or a hosted agent. Azure Pipelines reads `azure-pipelines.yml` when a repository is connected. A file on disk is still valid YAML if Azure never runs it. The `hashicorp/local` provider writes a file on this machine. It does not create a resource group.

Create the lab under `/tmp`, not under this course clone. Confirm you left the course repository:

```bash
LAB_DIR="/tmp/day-25-ado-iac-lab-$$"
mkdir -p "$LAB_DIR"
cd "$LAB_DIR"
pwd
```

Keep a notes file named `day-25-ado-iac-lab.md` in `$LAB_DIR`. Record command output and the identity split. Do not put passwords, keys, or organization names in the files.

---

## Steps

1. Draw the two repositories in your notes. Use this exact layout so it matches the lesson. Application code does not live next to Terraform modules in one tree for this lab.

```text
day-25-ado-iac-lab/
├── shopsphere-app/
│   └── azure-pipelines.yml
└── shopsphere-infra/
    └── azure-pipelines.yml
```

Write one sentence under the tree: a Java bugfix belongs in `shopsphere-app`. An AKS node-pool change belongs in `shopsphere-infra`. A small application change must not run `terraform apply`.

2. Create the two folders.

```bash
mkdir -p shopsphere-app shopsphere-infra
ls -d shopsphere-app shopsphere-infra
```

3. Put a tiny application in `shopsphere-app`. This stands in for the Spring Boot JAR in the lesson. You are not building a product. You are creating one file that Build can copy and Test can import.

```bash
cat > shopsphere-app/app.py << 'EOF'
def greeting():
    return "ok"


if __name__ == "__main__":
    print(greeting())
EOF

cat > shopsphere-app/test_app.py << 'EOF'
import unittest
from app import greeting


class TestGreeting(unittest.TestCase):
    def test_greeting(self):
        self.assertEqual(greeting(), "ok")


if __name__ == "__main__":
    unittest.main()
EOF
```

Run the same test the pipeline will name. You should see `test_greeting` pass.

```bash
cd shopsphere-app
python3 -m unittest test_app.py -v
cd "$LAB_DIR"
```

4. Write `shopsphere-app/azure-pipelines.yml`. The keys below are real Azure Pipelines keys: `trigger`, `pool`, `stages`, `stage`, `jobs`, `job`, `steps`, `script`, `displayName`, `dependsOn`, `publish`, and `artifact`. Build copies the app into `dist`. Test runs `python3 -m unittest`. Publish names `dist` as pipeline artifact `app`. There is no Dev, UAT, or Production stage on purpose. Those stages consume this artifact. They do not rebuild it.

```yaml
trigger:
- main

pool:
  vmImage: ubuntu-latest

stages:
- stage: Build
  jobs:
  - job: BuildApp
    steps:
    - script: |
        python3 -m compileall app.py
        mkdir -p dist
        cp app.py dist/app.py
      displayName: Build application

- stage: Test
  dependsOn: Build
  jobs:
  - job: TestApp
    steps:
    - script: python3 -m unittest test_app.py -v
      displayName: Run tests

- stage: Publish
  dependsOn: Test
  jobs:
  - job: PublishArtifact
    steps:
    - script: |
        mkdir -p dist
        cp app.py dist/app.py
      displayName: Stage artifact files
    - publish: dist
      artifact: app
```

Write the file with that content:

```bash
cat > shopsphere-app/azure-pipelines.yml << 'EOF'
trigger:
- main

pool:
  vmImage: ubuntu-latest

stages:
- stage: Build
  jobs:
  - job: BuildApp
    steps:
    - script: |
        python3 -m compileall app.py
        mkdir -p dist
        cp app.py dist/app.py
      displayName: Build application

- stage: Test
  dependsOn: Build
  jobs:
  - job: TestApp
    steps:
    - script: python3 -m unittest test_app.py -v
      displayName: Run tests

- stage: Publish
  dependsOn: Test
  jobs:
  - job: PublishArtifact
    steps:
    - script: |
        mkdir -p dist
        cp app.py dist/app.py
      displayName: Stage artifact files
    - publish: dist
      artifact: app
EOF
```

Read the file once. `trigger` is the Git event. Each `stage` is a major stop. `publish` is the hand-off. This pipeline does not call `terraform apply`. It does not push an image. Record that in your notes.

5. Put a tiny Terraform configuration in `shopsphere-infra`. The `local` provider writes a marker file on disk. It does not create Azure resources. Leave spacing slightly uneven so `terraform fmt` has work to do if Terraform is present.

```bash
cat > shopsphere-infra/main.tf << 'EOF'
terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

resource "local_file" "marker" {
    content  = "shopsphere-infra lab\n"
filename = "${path.module}/marker.txt"
}
EOF
```

This file is the stand-in for `backend.tf` and modules in a real infra repo. Remote state on Azure Storage stays a design note. Do not create a storage account.

6. Write `shopsphere-infra/azure-pipelines.yml`. Stages are Fmt, Validate, and Plan. The scripts match the lesson: `terraform fmt -check -recursive`, `terraform validate`, and `terraform plan -out=tfplan`. There is no Apply stage. Production apply needs review and a separate identity.

```bash
cat > shopsphere-infra/azure-pipelines.yml << 'EOF'
trigger:
- main

pool:
  vmImage: ubuntu-latest

stages:
- stage: Fmt
  jobs:
  - job: TerraformFmt
    steps:
    - script: terraform fmt -check -recursive
      displayName: Terraform format check

- stage: Validate
  dependsOn: Fmt
  jobs:
  - job: TerraformValidate
    steps:
    - script: |
        terraform init
        terraform validate
      displayName: Terraform init and validate

- stage: Plan
  dependsOn: Validate
  jobs:
  - job: TerraformPlan
    steps:
    - script: |
        terraform init
        terraform plan -out=tfplan
      displayName: Terraform plan
EOF
```

Each Azure Pipelines job starts from a fresh checkout. That is why Validate and Plan both run `terraform init`. Fmt does not need the provider. Validate and Plan do. Read the file once. Fmt is the style gate. Validate is the syntax gate. Plan is the review artifact. Apply is not in this YAML. An application pipeline must not gain that plan stage by copy-paste.

7. If `terraform version` worked, run the local check in `shopsphere-infra`. `init` downloads the `hashicorp/local` provider. `fmt` rewrites spacing. `validate` checks the configuration. Do not apply. Do not destroy, because you never created the marker file through apply.

```bash
cd shopsphere-infra
terraform init
terraform fmt -recursive
terraform validate
cd "$LAB_DIR"
```

If `terraform` is not on your `PATH`, skip those commands. Write one line in the notes: Terraform is absent, so this lab stops at the two YAML files. The infra pipeline on disk still describes fmt, validate, and plan.

8. Confirm the tree. You should see one `azure-pipelines.yml` under each folder.

```bash
find shopsphere-app shopsphere-infra -type f | sort
```

Paste that list into `day-25-ado-iac-lab.md`. Map one application change and one infrastructure change to those paths.

---

## Verify

Read both YAML files out loud as if you are on a call. Start at `trigger` in `shopsphere-app`. Stop at `publish`. Then start at `trigger` in `shopsphere-infra`. Stop at `terraform plan`. You should not need the Azure portal.

Check these points:

- `shopsphere-app/azure-pipelines.yml` has stages Build, Test, and Publish. Test depends on Build. Publish depends on Test.
- `shopsphere-infra/azure-pipelines.yml` has stages Fmt, Validate, and Plan. There is no Apply stage.
- `python3 -m unittest test_app.py -v` passed from `shopsphere-app`.
- If Terraform exists, `terraform init` and `terraform validate` succeeded in `shopsphere-infra`. If it does not exist, the notes say YAML only.
- The notes name which repository owns a Java change and which repository owns an AKS node-pool change.

If a YAML key appears that you cannot explain, remove it. A short pipeline that you understand is better than a copied template.

---

## Break and fix

The break for this Day is identity, not a failed unit test. Imagine one service connection named `PipelineIdentity`. That identity can `terraform apply` against Production and can `docker push` to ACR. Write that design in your notes first. Label it broken.

```text
Broken
------
PipelineIdentity
  → terraform apply Production
  → docker push to ACR
```

Ask what happens if that identity is stolen. The attacker can change the platform and can push a new image in the same blast radius. Federation does not fix that. Azure RBAC still grants both actions to one principal.

Split the identity on paper. Use the names from the lesson. `InfraPipelineIdentity` applies Terraform or Bicep at the platform resource groups. `AppBuildIdentity` builds, tests, and pushes the image. Do not give either identity subscription Owner. Do not give the app identity `terraform apply` on Production.

```text
Fixed
-----
InfraPipelineIdentity
  → terraform fmt / validate / plan
  → terraform apply only after approval, at infra resource groups

AppBuildIdentity
  → build, test, publish artifact
  → docker push to ACR
```

Copy those two blocks into `day-25-ado-iac-lab.md`. Add one more line: a third identity, `AppDeploymentIdentity`, updates Container Apps or AKS and still cannot apply Terraform. Build, deploy, and infra stay separate. That is the blast-radius test from the lesson.

Do not add an Apply stage to `shopsphere-app/azure-pipelines.yml` to “fix” the break. The fix is two identities and two pipelines, not more YAML in the app repo.

---

## Clean up

You created no Azure resource group, no ACR, and no Azure DevOps organization. There is nothing to delete in the cloud.

If you ran `terraform init`, the provider files sit under `shopsphere-infra/.terraform`. You did not apply, so there is no managed `marker.txt` to destroy. Leave the lab directory and delete it.

```bash
cd /tmp
rm -rf "$LAB_DIR"
```

If you copied notes you want to keep, move `day-25-ado-iac-lab.md` out before `rm -rf`. Strip any pasted SHA that you do not want to keep. Do not copy `.terraform` or `terraform.tfstate` into the course repository. This lab must not contain passwords, keys, or account IDs.

---

## Interview story

I keep application delivery and infrastructure delivery in two repositories. `shopsphere-app` has a pipeline that builds, tests, and publishes one artifact. `shopsphere-infra` has a pipeline that runs `terraform fmt`, `terraform validate`, and `terraform plan`. I do not put Apply on the app pipeline, and I do not rebuild the app inside the infra pipeline. I also refuse one pipeline identity that can apply Production and push images. I split that into `InfraPipelineIdentity` and `AppBuildIdentity`, and I scope Azure RBAC to the resource group each identity actually needs.
