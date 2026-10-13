# 04 — Lead versus Senior

**Timer:** 10 minutes write (two STARs), 4 minutes speak (90 seconds each).

## Prompt

Same incident, two answers:

> Catalog 503 in Production. Burn-rate page. One replica is crash-looping. A second replica is fine.

Write **Senior** (you restore service). Write **Lead** (you change the system). Put both in `docs/behavioral/04-lead-vs-senior.md`.

## Constraints

- Senior: commands, evidence, time to green.
- Lead: who pages, who may apply, what Git gate you add, how you know it will not recur next quarter.
- Do not make the Lead answer a people-only story. Name the gate.

## Hints

1. Senior starts at `kubectl get` / Grafana.
2. Lead starts at "why did one replica ship a bad command" and "why did the page fire correctly."
3. Both answers keep the same facts. Only the altitude changes.

## Solution

<details>
<summary>Open after the timer or after you tried the hints.</summary>

**Senior.** Situation: 503, 14.4× burn, one `CrashLoopBackOff`. Task: restore `/catalog`. Action: get, describe, `--previous` logs, patch command, watch Ready, confirm burn. Result: 12 minutes to green. PR with the command fix.

**Lead.** Situation: same page. Task: stop this class of ship. Action: I asked why CI allowed a Deployment with `command: exit 1`. I added a Kyverno or conftest gate (or a unit test on the Helm template) so a non-zero exit command cannot merge. I kept the burn-rate page (it worked). I made the postmortem a Day 41 game-day card. I did not add a second pager on CPU. Result: the next bad command fails the pull request, not the SLO. The page still fires if a future bug escapes.

Score 5 only if both altitudes are present and the Lead names a **gate**, not a meeting.

</details>
