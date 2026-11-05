# AWS + EKS + Terraform

## In one sentence

AWS senior roles ask for the same loop as Azure ones (Terraform plus a managed Kubernetes cluster plus CI/CD), just with AWS names.

## What employers ask for

- Terraform for AWS infrastructure (VPC, IAM, EKS, data stores)
- "Everything as Code": some JDs say Terraform or OpenTofu. OpenTofu is the open-source fork of Terraform with the same workflow, so your Terraform skills transfer as they are
- Running production workloads on EKS
- CI/CD that builds images and deploys to the cluster
- AWS account and network structure (who can reach what)
- Networking fundamentals: senior platform interviews still ask OSI-layer basics, so keep Day-3 fresh. Trading and broker roles also name L2 / L3, VLANs, overlay networks (SDN, VXLAN), and network automation with Ansible. Those names are Look-up. The request path is still Day-3
- Payments platforms add a serverless path next to EKS: ECS, Lambda, API Gateway, SQS, EventBridge, KMS. The extra ask is PCI network segmentation and audit evidence. See the [landing-zone card](landing-zone-multi-account.md). Day-27 already teaches those compute names
- Observability on top of the cluster (often Prometheus, Grafana, or Datadog)
- Lead roles add advisor work: explain and defend a design choice (accounts, IAM, network, security, cost) and its trade-offs to a client, not just build it
- Data and messaging operations: RDS (PostgreSQL), ElastiCache (Redis), MSK (Kafka). JDs ask backups, replication, failover, and DR with RTO and RPO. Multi-region is a plus. Service knobs are Look-up
- PostgreSQL reliability for SREs: read a query plan (`EXPLAIN`), watch `pg_stat_*` views, change large tables without a long exclusive lock, and stream row changes with CDC
- MySQL administration inside a DevOps role: the same loop (replication, backups, recovery, tuning). The engine name changes. Status views have different names. Backups still count only after a restore drill
- Backups count only after a restore drill on a schedule. An untested backup is a hope
- Close public SSH. Use AWS Systems Manager Session Manager (or Azure Bastion). The instance stays private
- Change data capture (CDC): Debezium (or equivalent) reads the database change log and publishes row changes as events on Kafka / Amazon MSK. The application writes to the database once. Downstream services consume events. They do not need a second write from the app (a dual-write that drifts)
- Some product roles want a Terraform module per tenant, applied only by a pipeline, with a check after apply
- Hosted SaaS on EKS: each customer instance is a lifecycle (create, upgrade, delete). An in-cluster operator with a CRD is the Kubernetes version of that factory. Zero-downtime upgrades still use rolling updates and PodDisruptionBudgets. See the Kubernetes production card
- Some JDs now ask you to move a managed database (RDS) onto an operator-run database on EKS. That is a data cutover: replicate, switch writes, keep rollback, and prove PITR. It is not "install Postgres in a Deployment." See the Kubernetes card for the operator loop. Day-27 and Day-39 stay the data and restore lessons

## Mental model

```text
Terraform
   ├── VPC (network)
   ├── IAM (identity)
   ├── EKS (cluster)
   └── RDS / S3 (data)
        ↓
CI/CD builds image → pushes to registry
        ↓
Deploy to EKS (Helm or GitOps)
        ↓
Observe → fix → repeat
```

If you know AKS, you already know most of EKS. Translate the names. A third cloud uses the same shape:

| Concept | Azure | AWS | GCP |
|:--|:--|:--|:--|
| Managed Kubernetes | AKS | EKS | GKE |
| Network | VNet | VPC | VPC |
| Identity for pods | Workload Identity | IRSA / Pod Identity | Workload Identity |
| Image registry | ACR | ECR | Artifact Registry |
| Monitoring | Azure Monitor | CloudWatch | Cloud Monitoring |

Anthos is Google's multi-cluster and hybrid layer. Look it up when a JD names it. Do not invent a GKE lab. Day-17 is the name map.

RPO is how much recent data you can afford to lose. RTO is how quickly the service must return. Think of a shop fire: RPO is how many days of receipts you can lose. RTO is how many hours until the shop opens again. Backups, replicas, and failover exist to meet those two numbers. They are not the same control. A backup counts only when you restore it on a schedule and write down the measured RTO and RPO. Day 27 places the stores. Day 39 teaches the recovery numbers.

## PostgreSQL is an SRE skill

Senior SRE JDs now ask you to run PostgreSQL, not only to provision RDS.

```text
Slow query     → read the plan (EXPLAIN)
Hot activity   → pg_stat_statements · pg_stat_activity
Large table    → expand, backfill in batches, then contract
Row changes    → CDC from the write-ahead log (Debezium → Kafka / MSK)
```

`EXPLAIN` shows how the engine will run the query (seq scan, index, join). `pg_stat_statements` shows which statements burn time. `pg_stat_activity` shows what is running now, including blocked sessions. Look-up the exact view columns when a JD names them.

The same loop shows up for MySQL. Some DevOps contracts name MySQL administration: replication, backups, recovery, and tuning. The engine name changes. `EXPLAIN` still reads the plan. The status views have different names (Look-up `performance_schema` when a JD says MySQL). Day-27 already lists MySQL next to PostgreSQL on RDS. Backups still count only after a restore drill.

A rewrite of a large table under an exclusive lock is an outage. Use the same expand-and-contract shape Day-34 teaches for schema: add the new form, backfill in small batches, switch reads, drop the old form later. CDC stays the "write once, consume events" rule already on this card.

Access follows the same private path. Do not open SSH on a public IP. Session Manager opens a shell through the AWS API, so the instance needs no inbound SSH. Azure Bastion is the usual Azure control that keeps the VM off a public SSH port. Day-29 already names Parameter Store. Session Manager is the shell, not the secret store.

> **Remember:** A backup you have never restored is a hope. A public SSH port is a hope of a different kind.

## Remember

> **Clouds change the names, not the shape. Learn the shape once (network, identity, cluster, pipeline) and map the names.**

## Study these days first

1. [Day-26/01-concepts.md](../../Day-26/01-concepts.md) - AWS big picture
2. [Day-27/01-concepts.md](../../Day-27/01-concepts.md) - compute choices
3. [Day-28/01-concepts.md](../../Day-28/01-concepts.md) - VPC and routing
4. [Day-29/01-concepts.md](../../Day-29/01-concepts.md) - AWS delivery
5. [Day-17/01-concepts.md](../../Day-17/01-concepts.md) - AKS vs EKS side by side
6. [Day-14/01-concepts.md](../../Day-14/01-concepts.md) and [Day-15/01-concepts.md](../../Day-15/01-concepts.md) - the Kubernetes core
7. [Day-03/01-concepts.md](../../Day-03/01-concepts.md) - the OSI basics that still show up in senior platform interviews
8. [Day-39/01-concepts.md](../../Day-39/01-concepts.md) - RTO, RPO, backup, replication, and failover
9. [Day-34/01-concepts.md](../../Day-34/01-concepts.md) - expand-and-contract so a schema change does not lock a large table

## Common interview question

**Q: Walk me through deploying a new service to EKS from scratch.**

Outline:
1. Terraform: VPC, EKS cluster, node group, IAM roles, ECR repo.
2. Pipeline: build image, scan, push to ECR.
3. Deploy with Helm or GitOps, service and ingress for traffic.
4. Add metrics, logs, and an alert before calling it done.
5. If the service has a database (PostgreSQL or MySQL): prove a restore drill, keep the instance off public SSH, and say how you would read a slow query plan.

## Honest gap note

If your daily cloud is Azure, say that, then prove the mapping: "I run AKS in production; EKS differs mainly in identity (IRSA) and networking (VPC CNI), and here is how I would close that gap." That is stronger than pretending equal depth.

## Source tags

EPAM Senior AWS DevOps · Sezzle SRE · EPAM Lead AWS DevOps · Turkey product co Senior Platform (AWS) · Turkey / Central Asia Senior DevOps (MSK, RDS, ElastiCache DR) · Turkey / Central Asia Platform (module per tenant) · 2026-10-13 market (CDC: Debezium to Kafka / MSK) · 2026-10-27 market (PostgreSQL SRE, restore drills, Session Manager) · 2026-10-29 market (SaaS instance lifecycle on EKS, operators / CRDs) · 2026-11-02 market (RDS to operator-run DB on EKS, PITR cutover) · 2026-11-03 market (MySQL admin inside DevOps) · 2026-11-04 market (map Azure / AWS names to GKE / Anthos) · 2026-11-05 market (payments serverless + PCI pointer, L2 / L3 / VLAN / overlay Look-up)
