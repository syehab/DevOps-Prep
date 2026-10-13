# 03 — You refused an unsafe ask

**Timer:** 8 minutes write, 3 minutes speak.

## Prompt

"Tell me about a time you said no to a manager or a ticket."

## Constraints

- The no has a reason a Lead can reuse (secret in Git, apply from a laptop, skip the plan).
- You offered a slower safe path with a clock.
- You did not hide the risk to look helpful.

## Hints

1. Repeat the ask in their words.
2. Name the failure if you comply (leaked key, two applies, wrong digest).
3. Give the alternative with a time ("plan on the PR in 20 minutes").

## Solution

<details>
<summary>Open after the timer or after you tried the hints.</summary>

**Situation:** A ticket asked me to paste `AWS_ACCESS_KEY_ID` into GitHub Secrets so the Day 29 apply could run "today."

**Task:** I owned the infra workflow identity.

**Action:** I said no to the static key. I showed `id-token: write` and `role-to-assume` on `shopsphere-gha-terraform`. I offered to add the GitHub Environment approval the same afternoon. I did not store a key "just for the demo."

**Result:** The workflow stayed OIDC. No key to rotate. The ticket closed with the role ARN in `docs/day-29-aws-delivery.md`.

</details>
