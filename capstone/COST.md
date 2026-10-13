# Cost and teardown policy

This policy applies to every cloud lab in the hands-on track. A Day file that creates cloud resources must repeat these rules in **What you need** and **Clean up**.

---

## Rules

1. **Budget first.** Create an Azure Budget (or AWS Budget) with an email alert at 80 percent and 100 percent of a small cap (USD 10 to 20 for the month is enough for this course). Do this before `az aks create`, `aws eks create-cluster`, or any Terraform apply that builds a cluster.
2. **Name the estimate.** Every cloud lab states an estimated USD cost for one session of 1 to 2 hours on the smallest SKU. The target is **under USD 5 per session**.
3. **Do not claim free when it is not.** Azure Storage, public IPs, AKS node VMs, EKS control planes, NAT gateways, and Container Apps all bill. The Azure free account and the AWS free tier reduce some of that bill. They do not make AKS or EKS free.
4. **Smallest SKU.** Use the size the Day names. Do not "just pick Standard_D4s_v5". Default Azure compute for this track is `Standard_B2s` or `Standard_B2pls_v2`. Default AWS compute is `t3.small` or `t3.micro`.
5. **Destroy before you walk away.** Run `make destroy` or `terraform destroy`. Read the destroy plan. Type `yes` only when the names match this lab. Then prove the resource group, VPC, or EKS cluster is gone.
6. **Local fallback is mandatory.** If you have no cloud account, or the estimate would exceed USD 5, use the local path in that Day. `kind`, Docker, Azurite, and LocalStack are valid. They are not AKS, EKS, or Organizations. Write that limit in your notes.
7. **One lab, one billable set.** Do not leave yesterday's AKS cluster running so today is "faster". That is how a weekend costs USD 40.

---

## Estimated session costs (smallest SKU, destroy at the end)

Prices move. Treat these as planning numbers for 2026 study sessions, not quotes.

| Resource | Typical session | Why it is not zero |
|:--|:--|:--|
| Azure Storage account + blob container (state) | USD 0.05-0.40 | Capacity and operations. Soft-delete keeps data after a delete. |
| Azure Budget + Action Group | USD 0.00 | Budget alerts do not bill. The resources they watch do. |
| Resource group with no compute | USD 0.00-0.10 | The group is free. Nested resources may not be. |
| Bicep `what-if` | USD 0.00 | Preview only. `create` is the billable step. |
| AKS: 1 × `Standard_B2s`, 1 to 2 hours | USD 1.50-4.50 | Node VM, disk, load balancer or public IP if you create one. Control plane SKU can add more. |
| Azure Key Vault (standard) + few ops | USD 0.10-0.30 | Operations and soft-delete retention. |
| Azure Container Apps (0.5 vCPU, 1 hour) | USD 0.20-1.00 | vCPU-seconds and memory-seconds. |
| AWS S3 + DynamoDB lock table | USD 0.05-0.40 | Requests and a few MB. |
| EKS: control plane + 1 × `t3.small`, 1 to 2 hours | USD 2.00-5.00 | Control plane is billed per hour. Nodes and EBS add more. |
| NAT Gateway (either cloud) | Avoid in labs | Often more than USD 5 if left on. Use a public node or local fallback. |
| `kind` + Docker + Terraform local | USD 0.00 | Laptop CPU only. |

If a plan would create a NAT Gateway, an Application Gateway, or more than one node, stop. Change the code. The lab does not need those SKUs.

---

## Budget alert first (Azure)

Use a resource group that already exists, or create `rg-shopsphere-finops` only for the budget. Estimated extra cost: **USD 0.00** for the budget itself.

```bash
# Pin your subscription. Do not paste the GUID into a public gist.
az account show --query id -o tsv

az consumption budget create \
  --budget-name shopsphere-lab \
  --amount 15 \
  --category Cost \
  --time-grain Monthly \
  --time-period start-date="$(date -u +%Y-%m-01)" \
  --resource-group rg-shopsphere-finops
```

If `az consumption budget create` is missing in your CLI version, use `az rest` against the Consumption Budgets API, or create the budget in the portal. The rule does not change: the alert exists before the cluster.

Confirm the budget:

```bash
az consumption budget list --resource-group rg-shopsphere-finops \
  --query "[].{name:name,amount:amount}" -o table
```

Expected: a row named `shopsphere-lab` with amount `15`.

---

## Budget alert first (AWS)

```bash
aws budgets create-budget \
  --account-id "$(aws sts get-caller-identity --query Account --output text)" \
  --budget file://infra/aws/finops/budget.json \
  --notifications-with-subscribers file://infra/aws/finops/budget-notify.json
```

Keep `budget.json` in Git. Do not commit account IDs. Use a variable or a local file that Git ignores.

---

## Teardown commands

From the ShopSphere repo (after you copy the starter):

```bash
make destroy          # terraform destroy in the active environment
make destroy-kind     # kind delete cluster --name shopsphere
make destroy-azure    # az group delete --name "$SHOPSPHERE_RG" --yes --no-wait
make destroy-aws      # terraform -chdir=infra/aws/environments/dev destroy
```

After destroy, prove the gap:

```bash
az group show --name "$SHOPSPHERE_RG"          # expect ResourceGroupNotFound
aws eks describe-cluster --name shopsphere     # expect ResourceNotFoundException
kind get clusters                              # shopsphere must be absent
terraform state list                           # empty, or backend unreachable after destroy
```

Do not use `-target` as your cleanup method. Destroy the whole configuration.

---

## Soft-delete and leftover cost

Azure Storage, Key Vault, and Recovery Services keep deleted objects for a retention period. Those objects can still bill. After `terraform destroy`, purge only lab resources you created, and only if your policy allows purge.

```bash
# Example: list soft-deleted vaults. Do not purge a company vault.
az keyvault list-deleted --query "[].name" -o tsv
```

If you are not sure a name belongs to this lab, do not purge it.

---

## When to stay local

Stay on the local fallback when any of these is true:

- You have no Azure subscription and no AWS account.
- You cannot create a budget alert.
- You will not be at the keyboard to destroy within two hours.
- The plan shows a NAT Gateway, a multi-node pool, or a SKU the Day did not name.

> **Remember:** A Senior engineer can run the lab on `kind` and still tell the AKS story. A running cluster you forgot to destroy is a junior story.
