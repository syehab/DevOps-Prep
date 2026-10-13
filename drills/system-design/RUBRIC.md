# System-design rubric

Score each drill from 0 to 5. A Senior pass is **4**. A Lead pass is **5** on at least one drill.

| Score | Meaning |
|:--|:--|
| 0 | Product list only. No path. No number. |
| 1 | User path exists. Isolation is missing. Math is guessed. |
| 2 | Isolation named. One decision has a why. Math is incomplete. |
| 3 | Five-line decisions for the main hops. One correct capacity figure. One failure mode. |
| 4 | Decisions + alternatives + trade-offs. Capacity script numbers match. Blast radius is explicit. Rollback is named. |
| 5 | Same as 4, plus you refuse one popular extra (second region, service mesh, Kafka) with a reason.

## Required sections in `docs/design/<id>.md`

1. One-sentence context (who, what, SLO or RPO).
2. Text diagram of the user or event path.
3. At least four decisions in the template: requirement → decision → why → alternative → trade-off.
4. Capacity: show the formula and the result. Run `capacity.py` if the drill names it.
5. One failure and the first three checks.
6. Cost note: USD estimate if the design would create cloud resources. Write **0.00** only when the drill stays on paper.

## Common misses (do not do these)

- Rebuild the image per environment.
- One subscription or one AWS account for Dev and Prod.
- Public database "for the lab."
- "INR 0" on a NAT Gateway, AKS, or EKS path.
- Skip the number and say "we will scale later."
