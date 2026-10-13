# 01 — ShopSphere web, one region

**Timer:** 25 minutes.

## Prompt

Design ShopSphere v1 for one Azure region (AWS names in parentheses). Users browse a catalog and create orders.

- Frontend: static assets.
- API: catalog + orders, stateless.
- Database: PostgreSQL.
- Images: object storage.
- Target: 500 RPS catalog reads at p50 50 ms service time. 99.9% availability for HTTP 2xx/3xx on `/health` is **not** the user SLO. The user SLO is HTTP 2xx on `GET /catalog`.

Write `docs/design/01-shopsphere-web.md`.

## Constraints

- Three environments: Dev, UAT, Prod. Separate subscriptions (accounts).
- No public database.
- Build the image once. Promote the digest.
- Smallest SKUs. Name a USD range for one evening lab if you applied (do not apply here).
- You may use AKS or App Service (EKS or ECS). Pick one and keep it.

## Capacity

How many concurrent in-flight catalog requests at 500 RPS and 50 ms service time? Run:

```bash
python3 drills/system-design/capacity.py
```

Use `inflight_500rps_50ms`. Show Little's law: `L = λW`.

## Hints

1. Draw User → DNS → CDN/front door → load balancer → API → Postgres.
2. Images go to Blob / S3. The API does not proxy every byte.
3. 500 × 0.050 = 25 in-flight. That is concurrency, not Pod count.
4. Isolation is the subscription (account), not the namespace.

## Solution

<details>
<summary>Open after the timer or after you tried the hints.</summary>

**Path:** User → DNS → Front Door / CloudFront → App Gateway / ALB → ShopSphere API on AKS (or EKS) → Azure Database for PostgreSQL / RDS in a private subnet. Images: Browser → CDN → Blob / S3.

**In-flight:** `500 × 0.050 = 25`. You still run at least two API replicas across two zones so one node loss does not take the shop. Connection pool: if each replica opens 20 connections and you scale to 12 pods, you have 240 sessions. A `max_connections` of 100 then fails. That is the next bottleneck. See `db_conns_12x20=240` in `capacity.py`.

**Decisions (short):**

| Area | Decision | Why | Refuse |
|:--|:--|:--|:--|
| Isolation | Three subscriptions | Blast radius and billing | One shared subscription |
| Compute | AKS 1–3 nodes `Standard_B2s` (EKS `t3.small`) | Matches Days 17 and 27 | A 10-node "prod-like" cluster for a lab |
| Data | Private Postgres, no public IP | The API Security Group / NSG is the only source | Public 5432 "just for the demo" |
| Delivery | Same digest Dev → UAT → Prod | Rebuilds are not promotions | `latest` per environment |
| State | Remote Terraform state per env | Locks and history | Laptop `terraform.tfstate` |

**Failure:** API 502. First checks: DNS, listener health, Pod Ready, then `max_connections`. Do not restart Postgres first.

**Lab cost if applied later:** AKS/EKS one small node **USD 2–5 / session**. This drill itself is **USD 0.00**.

</details>
