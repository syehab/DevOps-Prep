# 06 — You made the next person faster

**Timer:** 8 minutes write, 3 minutes speak.

## Prompt

"How do you enable the people around you?" (Lead flavor: "How do you raise the team?")

## Constraints

- The artifact must exist: module, drill, runbook, CODEOWNERS, or a test.
- "I am happy to help" is a fail.
- Name who used it and what they stopped asking you.

## Hints

1. Pick one artifact from this repo: a Day lab, a drill pack, a `terraform test`.
2. Say the before: they pinged you for the command.
3. Say the after: they run `run-all.sh` or `terraform test`.

## Solution

<details>
<summary>Open after the timer or after you tried the hints.</summary>

**Situation:** New engineers asked how to prove a Pod restart without a cluster.

**Task:** I owned the scripting pack path for interviews.

**Action:** I wrote `drills/scripting/04-k8s-restarts/` with a `pods.json` fixture and `find_restarts.py`. I added it to `run-all.sh`. I pointed the next person at the fixture, not at my laptop kubeconfig.

**Result:** They finish the drill in 15 minutes with no AWS or Azure. I stop pasting `kubectl` JSON into chat.

</details>
