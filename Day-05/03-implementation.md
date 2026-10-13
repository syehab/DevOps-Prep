# Day 5 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 5 teaches that a branch is a moving pointer, a commit is an exact version, and an environment is where that version runs. The old lab used a throwaway repo only. This lab still uses a **nested demo repo** so you do not rewrite ShopSphere history. It then writes `docs/promotion.md` that maps `main` / tag / env values.

Work in **your ShopSphere repository**. Do not run `git reset` or `rm -rf .git` in ShopSphere or in this course clone.

---

## Goal

In `labs/day-05-git/`, merge a feature branch, tag `app-1.0.0`, commit again on `main`, and prove the tag stayed. Write `docs/promotion.md` plus `env/dev.yaml` and `env/prod.yaml` (Prod pins the tag; Dev follows `main`).

Time box: 45 to 75 minutes. Cost is **USD 0.00**.

---

## Capstone stage

| Path | Adds |
|:--|:--|
| `labs/day-05-git/` | Nested demo repo (you may gitignore `.git`) |
| `docs/promotion.md` | Branch vs tag vs environment |
| `env/dev.yaml` | Dev follows `main` |
| `env/prod.yaml` | Prod pins `app-1.0.0` |

---

## What you need

```bash
git --version
```

Git 2.28+ so `git init -b main` works.

---

## Cost

| Path | Estimated USD |
|:--|:--|
| Local Git | **0.00** |

---

## Steps

1. Open ShopSphere. Create the nested repo.

```bash
mkdir -p labs/day-05-git env docs
cd labs/day-05-git
git init -b main
git config user.email "you@example.com"
git config user.name "ShopSphere lab"
printf 'catalog v1\n' > app.txt
git add app.txt
git commit -m "catalog v1"
```

2. Feature branch, merge, tag.

```bash
git checkout -b feature/price
printf 'price\n' >> app.txt
git commit -am "add price"
git checkout main
git merge --no-ff feature/price -m "merge price"
git tag app-1.0.0
```

3. Move `main`. Prove the tag stays.

```bash
printf 'catalog v2\n' >> app.txt
git commit -am "catalog v2"
echo tag=$(git rev-parse app-1.0.0)
echo main=$(git rev-parse main)
```

Expected: the two SHAs differ. Executed on Git 2.x: tag stayed on v1 merge; `main` moved.

4. Write `env/dev.yaml` and `env/prod.yaml` in ShopSphere (not inside the nested repo).

```yaml
# env/dev.yaml
image: catalog
ref: main
```

```yaml
# env/prod.yaml
image: catalog
ref: app-1.0.0
```

5. Write `docs/promotion.md`. Say: Dev may run the tip of `main`. Prod runs the tagged artifact. A tag does not move when `main` does. Day 6 / 33 promote a **digest**, which is stronger than a moving tag if you retag. Prefer digest in Prod.

---

## Verify

- `git rev-parse app-1.0.0` ≠ `git rev-parse main`.
- `env/prod.yaml` pins the tag.
- You did not reset ShopSphere `main`.

---

## Break and fix

### Failure 1 — commit on `main` by mistake

```bash
git checkout main
printf 'oops\n' >> app.txt
git commit -am "oops"
```

Move the commit off `main` with `git reset --hard HEAD~1` **only inside `labs/day-05-git`**. Cherry-pick onto a feature branch if you still want the change.

### Failure 2 — move the tag

```bash
git tag -f app-1.0.0
```

That retags Prod. Restore the original SHA: `git tag -f app-1.0.0 <old-sha>`. Write: this is why Day 33 pins a digest.

---

## Stretch

- Add `labs/day-05-git/.git` to ShopSphere `.gitignore`.

---

## Clean up

Keep `docs/promotion.md` and the env files. You may delete `labs/day-05-git`.

---

## Interview story

**Situation:** A peer said Dev and Prod both track `main`. **Task:** Show a pointer that does not move. **Action:** I merged a feature, tagged `app-1.0.0`, committed again on `main`, and showed two SHAs. Prod yaml pins the tag. I forced the tag once to show the danger, then restored it. **Result:** I can say a branch moves, a commit does not, and a digest is safer than a retaggable tag.

---

## Self-score checklist

- [ ] Tag SHA ≠ `main` SHA.
- [ ] Prod yaml pins `app-1.0.0`.
- [ ] I reset only the nested repo.

**Executed:** nested `git init` + tag vs `main` (authoring VM). **Not executed:** GitHub Environments, Argo CD.
