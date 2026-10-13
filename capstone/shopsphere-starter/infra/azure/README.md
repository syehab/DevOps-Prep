# Azure Terraform

Days 8 to 10 create the first root module, then modules, then a remote backend.

```text
infra/azure/
  backend/              # bootstrap the storage account (Day 10)
  modules/network/
  modules/app/
  environments/dev/
  environments/prod/
```

Pin `hashicorp/azurerm` `5.9.0` and Terraform `1.16.5`. See [../../VERSIONS.md](../../VERSIONS.md).

Create the budget alert before the first apply that builds compute. See [../../COST.md](../../COST.md).

Local fallback: keep `backend "local" {}` until Day 10. Azurite can stand in for blob APIs. Azurite is not Azure Storage redundancy.
