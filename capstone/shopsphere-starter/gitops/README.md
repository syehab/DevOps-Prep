# Argo CD app-of-apps (Days 16, 33, 37)

```text
gitops/
  bootstrap/          # Application that points at apps/
  apps/
    shopsphere-dev.yaml
    shopsphere-prod.yaml
```

Install Argo CD on `kind` first (USD 0.00). Move the same manifests to AKS or EKS on Day 17 or Day 37.

The image digest in Dev and Prod must match on Day 33. Rebuild is not promotion.
