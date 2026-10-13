# Day 6 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 6 is the application pipeline: test, build, push by **digest**. The old lab wrote Azure Pipelines YAML and a unittest in a notes folder. This lab writes both YAML dialects in **ShopSphere**, runs the test, and proves a digest. Docker is optional. `sha256sum` is the required path when Docker is missing.

Day 4 already added CI test. This Day adds the artifact. Day 25 is infra. Day 33 promotes the same digest across envs.

---

## Goal

1. Keep or add `app/test_health.py` from Day 4. Run it.
2. Write a build that produces `dist/catalog.txt` and record `sha256sum`.
3. Tag the same bytes as `uat` without changing the digest.
4. Write `.github/workflows/app.yml` and `azure-pipelines.yml` with Build, Test, Publish.

Time box: 45 to 75 minutes.

---

## Capstone stage

| Path | Adds |
|:--|:--|
| `app/test_health.py` | Test (reuse Day 4) |
| `dist/` note in docs | Artifact + digest |
| `.github/workflows/app.yml` | Test + digest |
| `azure-pipelines.yml` | Same stages for the lesson names |
| `docs/day-06-pipeline.md` | Digest lines |

---

## What you need

```bash
python3 --version
sha256sum --version | head -1
command -v docker || true
```

---

## Cost

| Path | Estimated USD |
|:--|:--|
| Local test + sha256 | **0.00** |
| `docker build` if you use it | **0.00** (local) |
| GitHub minutes | **0.00** until the cap |

Do not push to ACR/ECR in this lab.

---

## Steps

1. Open ShopSphere.

```bash
mkdir -p app dist docs .github/workflows
```

2. Test (Day 4 file, or the stub in [Day-04/03-implementation.md](../Day-04/03-implementation.md)).

```bash
python3 -m unittest app.test_health
```

3. Build the artifact. This stands in for `docker build` when Docker is missing.

```bash
printf 'catalog v1\n' > dist/catalog.txt
sha256sum dist/catalog.txt | tee docs/day-06-pipeline.md
```

Copy the digest. Call it `D1`.

4. Promote without rebuild.

```bash
cp dist/catalog.txt dist/catalog-uat.txt
sha256sum dist/catalog-uat.txt
```

Expected: same digest as `D1`. That is promotion. A second `printf 'catalog v2\n'` is a **new** artifact. Executed on this host: same bytes → `a81ae3bbd4c84dc1d801c45a6dfdaa29ace947c515a0d42bfa70127dc124169d`; `v2` changed the digest.

5. Optional Docker path (skip if `docker` is missing):

```bash
# docker build -t shopsphere/catalog:dev .
# docker inspect --format='{{.Id}}' shopsphere/catalog:dev
# docker tag shopsphere/catalog:dev shopsphere/catalog:uat
```

Tag does not rebuild. `docker build` again might.

6. `.github/workflows/app.yml`:

```yaml
name: app
on:
  push:
    paths: ["app/**", "dist/**", ".github/workflows/app.yml"]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
      - run: python3 -m unittest app.test_health
      - run: |
          mkdir -p dist
          printf 'catalog v1\n' > dist/catalog.txt
          sha256sum dist/catalog.txt
```

7. `azure-pipelines.yml` with stages named Build, Test, Publish (lesson names). `script` steps run the same commands. You do not need an Azure DevOps org.

---

## Verify

- Unittest passes.
- Copy + `sha256sum` matches. A content change does not.
- App workflow has no `terraform apply`.

---

## Break and fix

### Failure 1 — rebuild for UAT

Run `printf 'catalog v1\n'` twice in a row and compare. Same digest. Then change a byte. Digest changes. Write: a Prod rebuild is not a promotion.

### Failure 2 — publish `latest` only

Add `tag: latest` as the only promotion key in the notes. Replace it with the sha256. `latest` moves.

---

## Stretch

- `docker build` and compare `Id` after `docker tag`.
- Day 33: two Argo apps, same digest.

---

## Clean up

Keep workflows and docs. You may delete `dist/*.txt` if you do not want artifacts in Git.

---

## Interview story

**Situation:** A pipeline rebuilt the image in every environment. **Task:** Show one artifact, two names. **Action:** I hashed `dist/catalog.txt`, copied it to `catalog-uat.txt`, and got the same sha256. I changed one byte and the digest moved. I wrote GitHub Actions and Azure Pipelines stages that test then publish that digest, not `latest`. **Result:** I can say CodePipeline Build vs GitHub Actions, and I can refuse a Prod rebuild.

---

## Self-score checklist

- [ ] Test passes.
- [ ] Same bytes, same digest.
- [ ] Workflows do not apply Terraform.

**Executed:** `sha256sum` same-bytes / different-bytes. **Not executed:** `docker build`, ACR, ECR, hosted Actions.
