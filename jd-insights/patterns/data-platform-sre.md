# Data-Platform SRE

## In one sentence

Data and platform JDs now ask you to watch query engines, Hadoop-style stores, databases, and Kubernetes as one estate, and to assess that estate before you put ML on it.

## What employers ask for

- Health dashboards for data services next to Kubernetes, not a separate team with a separate picture
- Treat Trino, Hadoop or Apache Ozone, and the databases as one estate
- Alert on failed queries, stale data, and job backlog, not only on CPU
- Assess an enterprise data platform before ML workloads (MLflow or Airflow on Kubernetes via GitOps)
- The readiness question matches an Operational Readiness Review (ORR): can this platform see, act, and survive an ML job tonight?
- Azure-first teams now also name GCP, with Snowflake as a plus. Snowflake is another warehouse name. The estate picture does not change

## Mental model

A data platform is a warehouse. You do not add a new packing line (ML) until the lights, the forklifts, and the fire exits already work.

```text
One estate, one health picture
  ├── Query engine (Trino)      → can a user get an answer?
  ├── Object / Hadoop store     → are the bytes there and readable?
  ├── Databases                 → replication, lag, connections
  └── Kubernetes                → are the jobs and services scheduled?
           ↓
     Dashboards + SLIs users feel
     (failed queries · stale data · job backlog)
           ↓
     Assess before ML
     (storage · compute · GitOps · secrets · restore)
           ↓
     Then put MLflow / Airflow on the paved road
```

The SRE card already teaches SLIs, dashboards, and ORR. This card changes the subject, not the method. A green cluster with a stuck query engine is still an incident. Day-20 already says a healthy cluster with zero payments is an incident. The same rule applies to a warehouse that cannot serve a query.

Work a small example first. Analysts run a Trino query over objects in Hadoop or Ozone. Kubernetes runs the coordinator and the workers. A dashboard that only shows Pod restarts will miss a full store, a replica that lags, or a queue that never drains. Put those four hops on one screen. Then decide whether the platform can take an Airflow DAG that trains a model.

Before ML, walk the ORR from Day-20. SEE: a dashboard that shows query success, data freshness, and job lag. ACT: a runbook and a named owner for a failed DAG. SURVIVE: a restore you have timed (Day-39) and enough compute that a training job does not evict the warehouse. If any of those proofs is missing, fix the platform first. Do not install MLflow on a hope.

> **Remember:** One estate, one health picture. Assess the warehouse before you add the packing line.

**Understand:** Trino, Hadoop, Ozone, MLflow, and Airflow are product names. The skill is the path: query, store, schedule, then prove readiness.

**Look-up:** the engine and the store the JD names. Do not invent a Hadoop or Trino lab.

**Exit check:** Name the four hops on the data-estate dashboard. Then say what you refuse to install until the ORR passes.

## Remember

> **A green Kubernetes cluster with a stuck query engine is still an incident. Fix the warehouse before you add ML.**

## Study these days first

1. [Day-20/01-concepts.md](../../Day-20/01-concepts.md) - SLIs, dashboards, ORR (read this first)
2. [Day-17/01-concepts.md](../../Day-17/01-concepts.md) - Kubernetes plus GPU and ML hosting
3. [Day-27/01-concepts.md](../../Day-27/01-concepts.md) - data stores stay private
4. [Day-16/01-concepts.md](../../Day-16/01-concepts.md) - GitOps for Airflow or MLflow
5. [Day-39/01-concepts.md](../../Day-39/01-concepts.md) - restore drills, RTO and RPO
6. [Day-35/01-concepts.md](../../Day-35/01-concepts.md) - observability project

Also: the [SRE card](sre-slos-observability.md) for the parent SLI and ORR model, and the [GitOps card](gitops-platform.md) for the paved road those ML tools sit on.

## Common interview question

**Q: How do you watch Trino, Hadoop, and Kubernetes as one estate? Then how do you decide the platform is ready for ML?**

Outline:
1. One dashboard. Query success and freshness, store health, database lag, and whether jobs schedule. Alert on user pain, not on every CPU blip.
2. Walk the path with evidence, the same drill as Day-15 and Day-20. A green cluster is not a green warehouse.
3. ORR before ML: SEE, ACT, SURVIVE. Timed restore. Named owner. Enough compute that training does not evict queries.
4. Then put MLflow or Airflow on the GitOps road (Day-16). Honest: say if you have not run Trino. Transfer the dashboard and the ORR. Do not invent engine flags.

## Honest gap note

The course does not run Trino, Hadoop, Ozone, MLflow, or Airflow. Transfer Day-20 (one picture, ORR) and Day-27 (private data). Look up the product the JD names. Do not claim a data-platform you have not operated.

## Source tags

ETG data platform · Veltris Hadoop / EMR · EPAM enterprise data platform · 2026-11-03 market (data-estate dashboards, EDP readiness before ML) · 2026-11-05 market (Snowflake as a warehouse plus on Azure-first / GCP teams)
