# Day 23 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 23 teaches Azure compute as a management-responsibility choice. Day 13 already built a multi-stage non-root catalog image. This Day is the **harder sibling**: you **bake** that image (Packer) or you **publish** the same digest to **Azure Container Apps**. You do not patch a running VM with SSH. You do not rebuild the image "for Production."

Work in **your ShopSphere repository**. Finish [Day-13/03-implementation.md](../Day-13/03-implementation.md) first if `app/Dockerfile` is still one stage.

---

## Goal

1. Write `packer/catalog.pkr.hcl` with a Docker source (local) and an `azure-arm` source (cloud, apply optional).
2. Write `infra/azure/modules/container-app` that runs the catalog at **0.25 vCPU / 0.5Gi**, `revision_mode = "Single"`, `min_replicas = 1`. Run `terraform test`.
3. Record the image digest you would pin. Do not rebuild it for the Container App.

Time box: 75 to 90 minutes. Destroy Container Apps the same session if you apply.

---

## Capstone stage

| Path in ShopSphere | What it adds |
|:--|:--|
| `packer/catalog.pkr.hcl` | Golden-image bake (Docker locally, Azure ARM in cloud) |
| `infra/azure/modules/container-app/` | Azure Container Apps environment + app |
| `infra/azure/modules/container-app/tests/aca.tftest.hcl` | CPU, memory, replica asserts |
| `compose.yaml` | Local fallback: the Day 13 image |
| `docs/day-23-compute.md` | Digest, size, bake-don't-patch note |

Day 17 is AKS. Do not create AKS today. Do not create a Virtual Machine Scale Set. A `Standard_B2s` VM plus a gallery image can exceed USD 5.

---

## What you need

```bash
terraform version
command -v packer && packer version
command -v docker && docker version
az account show --query name -o tsv
```

Terraform 1.16.5 and azurerm 5.9.0 are required for the module. Packer 1.11+ is preferred for the bake. Docker is the local Packer builder and the Compose fallback. Azure is optional.

If Packer is missing, still write the HCL. Record `packer not executed`. If Docker is missing, still write `compose.yaml` and the ACA module. `terraform test` completes the Day.

---

## Cost

| Path | Estimated USD (1–2 hours, then destroy) | Why it is not always zero |
|:--|:--|:--|
| Packer Docker builder + Compose + `terraform test` | **0.00** | Laptop CPU |
| Azure Container Apps 0.25 vCPU / 0.5Gi, 1 replica, ~1 hour | **0.20–1.00** | vCPU-seconds and memory-seconds |
| Packer `azure-arm` on `Standard_B2s` + gallery publish | **1.00–4.00** | Build VM time. Destroy the builder. Do not leave the VM. |
| VMSS, NAT Gateway, or ACA CPU above 0.25 | **Stop. Change the code.** | |

Create a budget first ([../capstone/COST.md](../capstone/COST.md)). Do not write "INR 0" if ACA or a build VM ran.

---

## Steps

1. Open ShopSphere. Create folders.

```bash
mkdir -p packer infra/azure/modules/container-app/tests docs
```

Record the Day 13 digest if you have it:

```bash
docker image inspect shopsphere-catalog:1.0.0 --format '{{.Id}}'
```

If the image is missing, build it from Day 13 first, or use `nginx:1.27` as a stand-in and write that limit in the notes.

2. Write `packer/catalog.pkr.hcl`. Packer 1.11 HCL2. Two sources: Docker for the laptop, `azure-arm` for a gallery bake you probably will **not** apply.

```hcl
packer {
  required_version = ">= 1.11.0"

  required_plugins {
    docker = {
      source  = "github.com/hashicorp/docker"
      version = ">= 1.0.9, < 2.0.0"
    }
    azure = {
      source  = "github.com/hashicorp/azure"
      version = ">= 2.2.1, < 3.0.0"
    }
  }
}

variable "catalog_image" {
  type    = string
  default = "shopsphere-catalog:1.0.0"
}

source "docker" "catalog" {
  image  = var.catalog_image
  commit = true
  changes = [
    "USER 10001",
    "EXPOSE 8080",
  ]
}

source "azure-arm" "linux" {
  use_azure_cli_auth = true
  location           = "eastus"
  vm_size            = "Standard_B2s"
  os_type            = "Linux"
  image_publisher    = "Canonical"
  image_offer        = "0001-com-ubuntu-server-jammy"
  image_sku          = "22_04-lts-gen2"
  managed_image_resource_group_name = "rg-shopsphere-images"
  managed_image_name                = "img-shopsphere-golden"
}

build {
  name    = "catalog-docker"
  sources = ["source.docker.catalog"]

  provisioner "shell" {
    inline = [
      "id",
      "python --version || python3 --version",
    ]
  }

  post-processor "docker-tag" {
    repository = "shopsphere-catalog"
    tags       = ["golden-1.0.0"]
  }
}

build {
  name    = "catalog-azure"
  sources = ["source.azure-arm.linux"]

  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y ca-certificates",
    ]
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E sh '{{ .Path }}'"
  }
}
```

The Docker build is the required bake on a laptop. It does not replace a CIS-hardened Ubuntu image. Write that limit. The Azure ARM build is the interview story: bake, scan, publish, roll. Do **not** run `catalog-azure` unless a budget exists and you will destroy `rg-shopsphere-images` the same session.

```bash
packer init packer/catalog.pkr.hcl
packer fmt packer/catalog.pkr.hcl
packer validate -only=catalog-docker.docker.catalog packer/catalog.pkr.hcl
```

If Packer is missing, copy the expected commands into the notes. **Not executed** in the authoring environment (no Packer binary).

3. Local fallback: Compose the Day 13 image. `compose.yaml` at the ShopSphere root:

```yaml
services:
  catalog:
    image: shopsphere-catalog:1.0.0
    ports:
      - "8080:8080"
    read_only: true
    user: "10001"
    tmpfs:
      - /tmp
```

```bash
docker compose up -d
curl -sS http://127.0.0.1:8080/health
docker compose down
```

Expected health: `{"status": "ok"}`. This is PaaS-shaped locally: you run a container, you do not SSH a VM. **Not executed** here (no Docker).

4. Write the Container Apps module. `infra/azure/modules/container-app/versions.tf`:

```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "5.9.0"
    }
  }
}
```

`infra/azure/modules/container-app/variables.tf`:

```hcl
variable "name" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "image" {
  type        = string
  description = "Catalog image including digest, for example myacr.azurecr.io/catalog@sha256:..."
}
```

`infra/azure/modules/container-app/main.tf`. These arguments are valid on azurerm 5.9.0. `template.container` requires `cpu`, `image`, `memory`, and `name`. `ingress` requires `target_port`. Include `traffic_weight` because Azure still wants a 100 percent latest revision.

```hcl
resource "azurerm_container_app_environment" "this" {
  name                = "${var.name}-env"
  location            = var.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_container_app" "this" {
  name                         = var.name
  container_app_environment_id = azurerm_container_app_environment.this.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"

  template {
    min_replicas = 1
    max_replicas = 1

    container {
      name   = "catalog"
      image  = var.image
      cpu    = 0.25
      memory = "0.5Gi"
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8080
    transport        = "http"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }
}
```

`min_replicas = 1` avoids a cold start in the lab. Scale-to-zero is a product choice, not a free lunch.

5. Write `infra/azure/modules/container-app/tests/aca.tftest.hcl`.

```hcl
mock_provider "azurerm" {}

run "sku" {
  command = plan

  variables {
    name                = "ca-shopsphere-dev"
    location            = "eastus"
    resource_group_name = "rg-shopsphere-aca-dev"
    image               = "nginx:1.27"
  }

  assert {
    condition     = azurerm_container_app.this.revision_mode == "Single"
    error_message = "revision_mode must be Single"
  }

  assert {
    condition     = azurerm_container_app.this.template[0].min_replicas == 1
    error_message = "lab must not scale to zero"
  }

  assert {
    condition     = azurerm_container_app.this.template[0].container[0].cpu == 0.25
    error_message = "cpu must be 0.25"
  }

  assert {
    condition     = azurerm_container_app.this.template[0].container[0].memory == "0.5Gi"
    error_message = "memory must be 0.5Gi"
  }
}
```

```bash
cd infra/azure/modules/container-app
terraform init
terraform fmt
terraform validate
terraform test
```

Expected: `1 passed`. This was executed on Terraform 1.16.5 / azurerm 5.9.0 in the authoring environment.

6. Optional ACA apply. Dedicated root `infra/azure/environments/aca-dev/`. Reuse Day 22 platform RG or create `rg-shopsphere-aca-dev`. Pin the image by **digest**, not `latest`.

```bash
terraform -chdir=infra/azure/environments/aca-dev init
terraform -chdir=infra/azure/environments/aca-dev plan
```

Read the plan. One environment, one app, 0.25 CPU, no NAT Gateway. If the estimate would exceed USD 5, stop. Use Compose.

7. Decision table in `docs/day-23-compute.md`.

```text
Workload          You manage              Azure manages           Roll back
VM / VMSS         OS, agent, golden image Host, disk, fabric      New image version
App Service       App bits                OS, patch, HTTP         Deployment slot
Container Apps    Image digest, scale     K8s machinery           Previous revision
AKS (Day 17)      Nodes, addons, YAML     Control plane           GitOps / rollout
```

Write one paragraph: bake, don't patch in place. Day 13 produced the image. This Day publishes it. Day 33 promotes the **same digest**.

---

## Verify

- Packer HCL exists with a Docker source and an `azure-arm` source.
- ACA module validates and `terraform test` passed.
- CPU is 0.25 and memory is 0.5Gi. `min_replicas` is 1.
- Notes name bake-don't-patch and the image digest (or `nginx:1.27` stand-in).
- You did not apply a VMSS.
- Notes do **not** say ACA is free if it ran.

---

## Break and fix

Do both failures.

### Failure 1 — scale to zero as the default

Set `min_replicas = 0`. Run `terraform test`. Expected: the replica assert fails. Restore `1`. Write why: a catalog API with a 99.9 percent SLO should not pay a cold start on the first request of the day. Scale-to-zero is for async or internal tools.

### Failure 2 — patch in place

On paper, SSH to a VM and `apt-get upgrade`. Write the blast: the next scale-out boots the old image and undoes the patch. The fix is a new Packer build and a rolling replace. Restore the bake path. Do not add a VM to this lab to prove SSH.

---

## Stretch

- Publish the Azure ARM image to Azure Compute Gallery (`azurerm_shared_image_version`). Destroy it.
- Add an ACA revision and split traffic 90/10. That is the PaaS analog of canary.

---

## Clean up

```bash
docker compose down
docker image rm shopsphere-catalog:golden-1.0.0 || true
terraform -chdir=infra/azure/environments/aca-dev destroy
az containerapp show --resource-group rg-shopsphere-aca-dev --name ca-shopsphere-dev
```

Expected after destroy: the show command fails. If you ran Packer `azure-arm`, delete `rg-shopsphere-images` as well.

---

## Interview story

**Situation:** Day 13 gave ShopSphere a container image, but production JDs asked how that image becomes a golden artifact or a PaaS revision. **Task:** Bake the catalog and show Azure Container Apps as the path that does not need a cluster. **Action:** I wrote Packer HCL with a Docker source for the laptop and `azure-arm` on `Standard_B2s` for a gallery bake I did not have to apply. I added `azurerm_container_app` at 0.25 vCPU / 0.5Gi with `min_replicas = 1` and covered CPU, memory, and replicas with `terraform test` on azurerm 5.9.0. I refused SSH patching and I refused scale-to-zero as the lab default. **Result:** I can explain bake-don't-patch, why ACA is not AKS, and why Day 33 must promote this digest instead of rebuilding it.

---

## Self-score checklist

- [ ] Packer HCL exists with Docker and Azure sources.
- [ ] ACA module `terraform test` passed.
- [ ] I can say why min_replicas is 1 in the lab.
- [ ] I wrote the patch-in-place blast.
- [ ] I destroyed ACA, or I never applied.
- [ ] Files live in ShopSphere.

**Executed:** ACA module `terraform fmt`, `validate`, `terraform test` on Terraform 1.16.5 / azurerm 5.9.0 (authoring VM). **Not executed:** Packer, Docker Compose, ACA apply, azure-arm build VM.
