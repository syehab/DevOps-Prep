# Day 4 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 4 teaches the CI mental model. The old lab wrote a trivial workflow in a notes folder. This lab writes **ShopSphere app CI**: a real test file and `.github/workflows/ci.yml` that runs it. Day 6 adds build and digest. Day 25 is the infra pipeline. Do not merge those jobs into this file.

Work in **your ShopSphere repository**.

---

## Goal

1. Add `app/test_health.py` that checks the catalog health JSON shape.
2. Run `python3 -m unittest` locally until it passes.
3. Write `.github/workflows/ci.yml` that checks out the repo and runs the same command.
4. Draw Developer → Git → CI → artifact in `docs/ci-flow.md`.

Time box: 45 to 75 minutes. Cost is **USD 0.00** locally. GitHub-hosted minutes are free until the account cap.

---

## Capstone stage

| Path | Adds |
|:--|:--|
| `app/test_health.py` | Unittest |
| `.github/workflows/ci.yml` | Lint/test job |
| `docs/ci-flow.md` | Delivery boxes |

---

## What you need

```bash
git --version
python3 --version
```

You do not need Azure DevOps or a cloud account.

---

## Cost

| Path | Estimated USD |
|:--|:--|
| Local unittest | **0.00** |
| GitHub-hosted `ubuntu-latest` | **0.00** until the minute cap |

---

## Steps

1. Open ShopSphere.

```bash
mkdir -p app .github/workflows docs
```

2. Write `app/test_health.py`.

```python
import json
import unittest


def health_body() -> dict:
    return {"status": "ok"}


class HealthTest(unittest.TestCase):
    def test_status_ok(self) -> None:
        body = health_body()
        self.assertEqual(body["status"], "ok")
        self.assertEqual(json.dumps(body, separators=(",", ":")), '{"status":"ok"}')


if __name__ == "__main__":
    unittest.main()
```

```bash
python3 -m unittest app.test_health
```

Expected: `OK`. Executed on Python 3.12. If you already have `app/main.py` from the capstone, import `/health` from that module instead of the stub.

3. Write `.github/workflows/ci.yml`.

```yaml
name: ci
on:
  push:
  pull_request:
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
      - run: python3 -m unittest app.test_health
```

4. Write `docs/ci-flow.md`:

```text
Developer → Git pull request → CI (this workflow) → reviewed merge → artifact (Day 6)
```

CI runs tests. It does not apply Terraform. It does not deploy Production.

---

## Verify

- `python3 -m unittest app.test_health` prints `OK`.
- The workflow has `on`, `jobs`, `runs-on`, `steps`.
- Notes say CI ≠ apply.

---

## Break and fix

### Failure 1 — fail the test

Change only `health_body` to return `{"status": "ready"}`. Leave the assert on `"ok"`. Unittest exits non-zero. Restore `ok`. CI must not be green on a bad health contract. Do not replace every `"ok"` in the file — that keeps the test green.

### Failure 2 — apply in the same job

Add `terraform apply` to `ci.yml`. Delete it. Day 25 is the infra pipeline. A test job that applies Prod is the identity incident.

---

## Stretch

- Add `ruff check app` if you already use ruff.
- Push the workflow and open the Actions tab.

---

## Clean up

Keep the files. You created no cloud resources.

---

## Interview story

**Situation:** A Lead asked what CI does on this repo. **Task:** Show a workflow that fails closed. **Action:** I wrote `app/test_health.py`, ran `python3 -m unittest` to `OK`, and committed `.github/workflows/ci.yml` that runs the same command on `ubuntu-latest`. I refused to put `terraform apply` in that job. **Result:** I can point at `on`, `jobs`, and `steps`, and I can say Day 6 builds the digest while Day 25 plans infrastructure.

---

## Self-score checklist

- [ ] Unittest passes locally.
- [ ] `ci.yml` exists and only tests.
- [ ] I failed the test on purpose and restored it.

**Executed:** `python3 -m unittest` on the health stub (run in the lab). **Not executed:** GitHub-hosted run, ruff, Azure DevOps.
