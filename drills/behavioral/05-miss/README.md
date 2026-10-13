# 05 — A change that went wrong

**Timer:** 8 minutes write, 3 minutes speak.

## Prompt

"Tell me about a mistake you made in production or in a lab you treated as production."

## Constraints

- You are the actor. "The pipeline failed" is not a story.
- Name the miss, the detect, the revert, the permanent fix.
- Prefer a real ShopSphere lab miss: overlapping CIDR, `latest` tag, skipped lock, NAT left on.

## Hints

1. Detect must be a signal (plan, test, page), not a user tweet only.
2. Revert is a digest or a `terraform apply` of the last good plan, not "we fixed it forward" with no story.
3. Permanent fix is a test or a policy.

## Solution

<details>
<summary>Open after the timer or after you tried the hints.</summary>

**Situation:** I set `aws_subnet.app_a` to `10.50.1.0/24`, the same as public-a. `terraform validate` passed. I almost applied.

**Task:** I owned the network module.

**Action:** `terraform test` failed only after I kept the CIDR assert. I restored `10.50.11.0/24`. I added a sentence to the Day 28 notes: overlap is worse than a failed apply because peering later fails in silence.

**Result:** No apply of the overlap. The test is the gate. I still say this story because validate is not enough.

</details>
