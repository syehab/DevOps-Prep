# System-design drills

Six timed designs for ShopSphere. Each drill is one prompt, 25 minutes, then hints, then a model answer in `<details>`. No gotchas. Write in **your ShopSphere repository** under `docs/design/`.

Cost: **USD 0.00**. These drills do not create cloud resources.

Use with Day 21 (one-pager), Day 30 (full design), and Day 40 (Lead review). Run the capacity script before you talk numbers.

```bash
python3 drills/system-design/capacity.py
```

## How to run one drill

1. Start a 25-minute timer.
2. Read only that folder's `README.md` **Prompt** and **Constraints**.
3. Write `docs/design/<id>.md` with: context, diagram, decisions (requirement → decision → why → alternative → trade-off), capacity math, failure modes.
4. Do not open Hints until you stick.
5. Score yourself with [RUBRIC.md](RUBRIC.md). Then open Solution.

Reset: keep the files. The next drill is a new file, not a rewrite of the last one.

## Scenarios

| # | Folder | What you design |
|:--|:--|:--|
| 01 | [01-shopsphere-web](01-shopsphere-web/) | Catalog API + Postgres + CDN, one region |
| 02 | [02-multi-region-dr](02-multi-region-dr/) | Active-passive, RPO 15 min, RTO 60 min |
| 03 | [03-gitops-control-plane](03-gitops-control-plane/) | Build once, promote digest, plan on PR |
| 04 | [04-multi-tenant-isolation](04-multi-tenant-isolation/) | Blast radius: account vs cluster vs namespace |
| 05 | [05-event-orders](05-event-orders/) | Order pipeline, at-least-once, idempotency |
| 06 | [06-slo-platform](06-slo-platform/) | 99.9% SLO, error budget, multi-window burn |

## Interview use

Pick two drills. Talk out loud. Start with the user path, then isolation, then the first number (RPS, budget, or RPO). That is the habit Days 21, 30, and 40 teach.

> **Remember:** Name the blast-radius unit before you name a product.

## Not executed in CI

The authoring VM ran `python3 drills/system-design/capacity.py`. It did not run a whiteboard session or a live design interview.
