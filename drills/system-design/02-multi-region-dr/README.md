# 02 — Multi-region active-passive

**Timer:** 25 minutes.

## Prompt

ShopSphere Prod must survive a region loss.

- RPO: 15 minutes.
- RTO: 60 minutes.
- Primary: `eastus` / `us-east-1`.
- Standby: `westus` / `us-west-2`.
- You may lose up to 15 minutes of orders. You may not lose the catalog schema.

Write `docs/design/02-multi-region-dr.md`.

## Constraints

- Active-passive. Do not design active-active for v1.
- Database is the hard part. Object storage is versioned.
- DNS failover is a health check plus a TTL you can defend.
- Cost the standby. A hot standby that runs a full AKS/EKS cluster is not free. Say the USD shape (idle control plane vs data only).

## Capacity

A 99.9% monthly SLO has how many minutes of error budget? A 99.95% SLO? Use `budget_99_9_30d_min` and `budget_99_95_30d_min`.

A 60-minute regional failover **consumes the entire 99.9% budget** if it happens once in 30 days (43.2 minutes). Write that sentence. Then say what you do: raise the SLO only if failover is faster, or accept 99.9% and treat a region loss as a budget burn.

## Hints

1. RPO is data. RTO is service. Do not swap them.
2. Postgres: async replica or backup + restore. Sync cross-region adds latency.
3. Terraform state stays in the primary region's backend plus versioning. A second copy of state is a Stretch, not a requirement.
4. Warm standby (data replica, no full cluster) is the usual Senior answer for this RTO.

## Solution

<details>
<summary>Open after the timer or after you tried the hints.</summary>

**RPO 15 min:** Postgres automated backups plus WAL/PITR, or an async replica with lag alerts under 15 minutes. Object storage: cross-region replication or versioned copy. Terraform state: versioned Azure Storage / S3 (`use_lockfile`).

**RTO 60 min:** Warm standby. Keep the data replica and the images. Do **not** keep a second billed AKS/EKS control plane unless the business pays for it. On failover: change DNS (TTL 60 seconds is a trade-off vs cache), apply the Prod stack in the standby region from the same modules, point the API at the promoted replica.

**Budget:** `30 × 24 × 60 × 0.001 = 43.2` minutes at 99.9%. `21.6` minutes at 99.95%. One 60-minute region event blows 99.9% (43.2) and 99.95% (21.6). Either shorten RTO (hot standby, more USD) or keep 99.9% and call a region loss a declared burn.

**Refuse:** Active-active writes for v1. Dual-write order IDs without a story for conflict.

**Lab cost:** paper **USD 0.00**. A real warm replica is the database bill, not a second NAT per AZ until you fail over.

</details>
