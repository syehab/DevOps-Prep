# Day 5 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 5 teaches that a branch is a moving pointer, a commit is an exact version, and an environment is where that version runs. This lab makes those three ideas visible with real Git commands. You do not use Azure, AWS, or a pipeline product.

Work only in a temporary directory that you create for this lab. Do not run `git init`, `git reset`, or `rm -rf` inside the DevOps-Prep course repository.

---

## Goal

Create a tiny local Git repository. Merge a feature branch into `main` with a merge commit. Tag that merge as artifact id `app-1.0.0`. Then commit again on `main` and prove that the tag still points at the old commit while `main` has moved.

That is the same idea as Dev versus Production. Both can come from `main`. Production can keep a tagged artifact while Dev already runs a later commit. After that, commit on the wrong branch on purpose and move the commit with real Git commands.

When you finish, you can show a branch pointer, a commit SHA, and a tag that does not move. You can also recover a commit that landed on `main` by mistake.

---

## What you need

You need Git. This lab uses Git 2.28 or later so that `git init -b main` works. Check the version first:

```bash
git --version
```

You do not need a remote, a GitHub account, Azure DevOps, or cloud resources. Keep the cost at zero.

Create the lab repository under `/tmp`, not under this course clone. The course repository is a real Git repo. Commands such as `git reset --keep` and `rm -rf` in the wrong directory can damage it.

Time box: 45 to 75 minutes. Stop when the tag is stable, the wrong-branch fix is done, and the temp directory is gone.

---

## Steps

1. Create a throwaway directory and initialize a new repository on `main`. Use a unique folder name so you do not collide with another lab.

```bash
LAB_DIR="/tmp/day-05-git-lab-$$"
mkdir -p "$LAB_DIR"
cd "$LAB_DIR"
git init -b main
```

Confirm you are not in the course repository:

```bash
pwd
git rev-parse --show-toplevel
```

The top-level path must be `$LAB_DIR`. If it is the DevOps-Prep clone, stop. `cd` into `/tmp` and start again.

2. Add a tiny application file and make the first commit on `main`. This commit is the baseline, like an empty main line before a feature.

```bash
echo "app version 0.9" > app.txt
git add app.txt
git commit -m "Add app baseline"
git log --oneline --decorate
```

`main` now points at this commit. A branch is only a name that points at a commit. The commit is the exact version.

3. Create a feature branch and change the application on that branch. Do not change `main` yet.

```bash
git checkout -b feature/payment-api
echo "app version 1.0-payment" > app.txt
git add app.txt
git commit -m "Add payment API on feature branch"
git log --oneline --decorate --graph --all
```

`feature/payment-api` is ahead of `main`. That is a line of development. It is not an environment. Nothing is "running in Dev" yet. You only have source history.

4. Merge the feature into `main` with a merge commit. `--no-ff` keeps the feature history visible. A fast-forward merge would just move `main` and hide the branch join.

```bash
git checkout main
git merge --no-ff feature/payment-api -m "Merge branch 'feature/payment-api'"
git log --oneline --decorate --graph --all
```

`main` now contains the payment change. In a real team this merge would follow a Pull Request. The next step stands in for "build once and give the artifact an id."

5. Tag the current `main` commit as artifact id `app-1.0.0`. Treat this tag as the immutable artifact you would promote to UAT and Production.

```bash
git tag app-1.0.0
git show --oneline --no-patch app-1.0.0
git rev-parse main
git rev-parse app-1.0.0
```

Right now `main` and `app-1.0.0` are the same commit. Write that SHA down. That SHA is the exact version. The tag name is the artifact id.

Map this to environments on paper, not as extra Git branches:

```text
app-1.0.0  →  what Production would run
main HEAD  →  what Dev would run after the next commit
```

One branch (`main`) can feed both. The tag names the version that Production keeps.

6. Commit again on `main`. This is a later change that Dev can receive before Production is approved.

```bash
echo "app version 1.1-dev" > app.txt
git add app.txt
git commit -m "Start 1.1 work on main"
```

7. Prove the tag did not move. `main` is a moving pointer. The tag is not.

```bash
git log --oneline --decorate --graph --all
echo "main:    $(git rev-parse --short main)"
echo "tag:     $(git rev-parse --short app-1.0.0)"
git show --oneline --no-patch main
git show --oneline --no-patch app-1.0.0
```

`main` and `app-1.0.0` must now be different SHAs. If someone says "Production is on `main`, so it has the latest code," the tag shows why that is false. Production would still run `app-1.0.0`. Dev would run the later `main` commit.

---

## Verify

Stay in `$LAB_DIR`. Run the graph once more:

```bash
git log --oneline --decorate --graph --all
git status
```

Check these points:

- The repository top-level is still the temp directory, not the course clone.
- `feature/payment-api` exists. `main` contains the merge commit from `--no-ff`.
- Tag `app-1.0.0` exists. `git rev-parse app-1.0.0` equals the merge commit, not the later 1.1 commit.
- `git rev-parse main` is a different SHA from `git rev-parse app-1.0.0`.
- `app.txt` on `main` contains `1.1-dev`. `git show app-1.0.0:app.txt` still contains `1.0-payment`.

If the tag SHA equals `main`, you tagged after the 1.1 commit. Delete only that tag in this temp repo with `git tag -d app-1.0.0`, reset your place with the graph, and tag the merge commit by SHA. Do not run tag deletion in the course repository.

---

## Break and fix

Commit on the wrong branch on purpose. You are on `main`. You mean to put a docs change on `feature/docs`, but you commit on `main` first.

```bash
git checkout main
echo "How to run the app" > README.txt
git add README.txt
git commit -m "Add usage notes"
```

`main` now has a commit that should not be there. Production-style `main` should not collect random work. Find the commit, keep it on a feature branch, then move `main` back.

```bash
git log --oneline --decorate -5
WRONG=$(git rev-parse HEAD)
echo "$WRONG"
```

Create the feature branch at the mistaken commit so the work is not lost. Then check `main` out again and move `main` back one commit. `--keep` moves `HEAD` and keeps the files that already match the target tree. It refuses the reset if that would throw away uncommitted work.

```bash
git checkout -b feature/docs
git checkout main
git reset --keep HEAD~1
git log --oneline --decorate --graph --all
```

`feature/docs` must still show `Add usage notes`. `main` must be back at the 1.1 commit. `app-1.0.0` must still be the merge commit. The tag does not change, because you did not move it.

If `feature/docs` already existed at an older commit, you would check that branch out and use `git cherry-pick "$WRONG"`, then reset `main` with `--keep`. Here the new branch started at the wrong commit, so `checkout -b` plus `reset --keep` is enough. Use only these Git commands. Do not delete `.git` to "fix" history.

Confirm the files:

```bash
git checkout feature/docs
cat README.txt
git checkout main
test ! -f README.txt && echo "README is not on main"
echo "main:    $(git rev-parse --short main)"
echo "docs:    $(git rev-parse --short feature/docs)"
echo "tag:     $(git rev-parse --short app-1.0.0)"
```

---

## Clean up

Leave the temp repository, then delete only that directory. Expand `$LAB_DIR` and read it before you delete.

```bash
cd /tmp
echo "About to remove: $LAB_DIR"
pwd
rm -rf "$LAB_DIR"
```

`$LAB_DIR` must start with `/tmp/day-05-git-lab-`. If it does not, do not run `rm -rf`. Never run this cleanup against the course clone, `Day-05/`, or any path that contains the DevOps-Prep `.git` directory.

You created no cloud resources. There is no pipeline, registry, or environment to delete. If you opened a remote Git host out of habit, create nothing there.

---

## Interview story

I do not treat `main` as Production. A branch is a moving pointer. A commit SHA is the exact source version. A tag such as `app-1.0.0` is a stable artifact id, and it does not move when I commit again on `main`. Dev can run the later commit while Production still runs the tagged artifact from the same branch. If I commit on the wrong branch, I find the SHA with `git log`, keep the work on the right branch, and move the wrong branch back with `git reset --keep` or `git cherry-pick`.
