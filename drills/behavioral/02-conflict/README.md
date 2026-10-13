# 02 — Conflict with a peer

**Timer:** 8 minutes write, 3 minutes speak.

## Prompt

"Tell me about a time you disagreed with another engineer. How did you resolve it?"

## Constraints

- The disagreement is technical (NAT on, rebuild in Prod, shared account).
- You do not "win." You produce a decision someone can review.
- Name the artifact: ADR, PR comment, or pipeline gate.

## Hints

1. State their goal in one sentence they would accept.
2. State the risk in one number (USD, blast radius, RPO).
3. Offer a path that keeps their goal (egress, a new image, a cheaper SKU).

## Solution

<details>
<summary>Open after the timer or after you tried the hints.</summary>

**Situation:** A peer wanted `enable_nat = true` on the ShopSphere Day 28 lab VPC so private nodes could `apt update`.

**Task:** I owned the cost note and the network module.

**Action:** I agreed the nodes needed a path. I showed the NAT hourly rate plus data. I offered an S3 / Blob gateway endpoint for the real dependency, and a one-hour NAT with a destroy alarm if we still needed packages. I wrote that in `docs/day-28-network.md` and left `enable_nat` default `false`. The test asserts `length(aws_nat_gateway.this) == 0`.

**Result:** We did not create NAT. The peer got an endpoint story. The module still fails `terraform test` if someone flips the flag. The disagreement is in Git, not in Slack.

</details>
