# 01 — Production outage

**Timer:** 8 minutes write, 3 minutes speak.

## Prompt

"Tell me about a production outage you handled. What did you do first?"

Write `docs/behavioral/01-incident.md` with the STAR card from [../STAR.md](../STAR.md).

## Constraints

- First action is evidence (`get`, `describe`, logs, a dashboard), not a restart.
- Name the blast radius (one Pod, one node, one region, all tenants).
- If you have no work outage, use a `drills/kubernetes-broken-cluster/` run and say so.

## Hints

1. Start with the user symptom, not the tool.
2. Say what you did **not** do (delete the namespace, scale to 50).
3. Close with the Git change that prevents the class of bug.

## Solution

<details>
<summary>Open after the timer or after you tried the hints.</summary>

**Situation:** ShopSphere catalog on `kind` (lab) returned 503. Grafana showed a 14.4× burn on a 5-minute window. One replica was `CrashLoopBackOff`.

**Task:** I owned the restore and the follow-up change. I did not own blame.

**Action:** I ran `kubectl get pods -n shopsphere` and `describe`. Last State exit 1. Logs `--previous` showed a bad command. I did not restart the node. I patched the Deployment command, waited for `1/1 Ready`, and watched the burn return to 0. I added the same probe and command to Git.

**Result:** Error rate back under the SLO in 12 minutes. The fix is in `k8s/base/`. The next person can apply the broken-cluster drill and hit the same path.

</details>
