# 06 — Azure resource-group inventory

**Timer:** 15 minutes.

## Symptom

Same Lead question as drill 05, on Azure. `azure-identity` may be missing. The ARM list shape is still a fixture you can parse.

## Task

Write `list_groups.py --fixture` that prints resource group names from the ARM `value[]` array.

```bash
python3 drills/scripting/06-azure-rg/list_groups.py \
  --fixture drills/scripting/06-azure-rg/groups.json
```

Expected: `rg-shopsphere-dev` then `rg-shopsphere-tfstate`.

## Hints

1. `az group list -o json` uses a top-level array. This fixture uses `{ "value": [ ... ] }` like REST. Handle the shape you document.
2. Do not install the Azure SDK only to finish the drill.
3. A later Stretch: `ResourceManagementClient` after `az login`.

## Solution

<details>
<summary>Open after the timer or after you tried the hints.</summary>

Parse `value[].name`. The authoring VM had **no** `azure` Python package. The fixture path is the lab.

</details>
