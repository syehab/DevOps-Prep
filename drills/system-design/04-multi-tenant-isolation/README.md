# 04 — Multi-tenant isolation

**Timer:** 25 minutes.

## Prompt

A second retailer wants ShopSphere as a tenant. Legal says tenant A must not read tenant B orders. A platform engineer says "we will use namespaces." A security engineer says "we will use accounts."

Pick the blast-radius unit. Design v1 for **two tenants** plus your platform.

Write `docs/design/04-multi-tenant-isolation.md`.

## Constraints

- You may share a control plane (Terraform modules, Argo CD).
- You may not share a Production database schema for both tenants in v1.
- Namespaces are not a compliance boundary by themselves. Say what they do and what they do not do.
- Cost must stay honest. Two AKS clusters cost about two control planes.

## Capacity

If each tenant peaks at 2000 RPS catalog reads at 20 ms service time, what is in-flight per tenant? Use `inflight_2000rps_20ms`.

## Hints

1. Azure: management group → subscription → resource group. AWS: Organization → OU → account.
2. A namespace plus NetworkPolicy plus Kyverno is a **soft** wall. An account plus separate state is a **hard** wall.
3. Shared modules, separate state keys: `tenanta/prod/terraform.tfstate`.

## Solution

<details>
<summary>Open after the timer or after you tried the hints.</summary>

**v1 decision:** one Azure subscription (AWS account) per tenant Production. Shared modules. Separate Terraform state. Separate Postgres. Separate Key Vault / KMS keys. Shared platform subscription for log archive and identity.

Namespaces stay useful **inside** a tenant (dev tools vs catalog vs jobs). They do not satisfy "tenant A cannot read tenant B" when one RBAC mistake is cluster-admin.

**In-flight:** `2000 × 0.020 = 40` per tenant. Capacity plans stay per tenant so a noisy neighbor does not steal the other pool.

**Trade-off:** two control planes (AKS/EKS) cost more than one shared cluster. You buy isolation. A pool cluster plus strong policy is a later optimization, not v1, unless the JD is cost-first and legal accepts it in writing.

**Refuse:** row-level security in one shared Postgres as the only wall.

**Lab cost:** paper **USD 0.00**. Two small clusters would be about **USD 4–10 / session** if you applied them. Do not apply them for this drill.

</details>
