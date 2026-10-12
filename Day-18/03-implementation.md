# Day 18 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 18 teaches identity, secrets, and blast radius. A secret that lands in Git stays in history even after you delete the file. This lab keeps that lesson local. You generate a real secret with `openssl`, store it in a file, and prove Git ignores it. You never push. You never use the course repository.

Work only in a temporary Git repository under `/tmp`. Do not run `git add` inside this DevOps-Prep clone. Do not create Azure Key Vault, AWS Secrets Manager, or a paid cluster. Optional Kubernetes steps run only if `kind` and `kubectl` already work on this machine.

---

## Goal

Create a throwaway Git repository. Generate a 16-byte secret with `openssl rand -hex 16` and write it to a file. Add that file to `.gitignore`. Show that `git check-ignore` reports the file and that `git status` does not list it.

Then break the lab on purpose. Stage the secret with `git add`. Remove it from the index with `git rm --cached` before any commit of the secret and before any push. Put the path in `.gitignore` again. Confirm Git no longer tracks it.

Optional: if `kind` is present and `kubectl` can reach a cluster, create a Kubernetes Secret from the same file with `kubectl create secret generic`. Do not commit that Secret YAML. Do not paste the secret into notes, tickets, or chat.

Time box: 40 to 70 minutes. Cost stays at ₹0. Stop when `git status` is clean of secret files, `git check-ignore` names the secret file, you have not run `git push`, and cleanup has deleted the temp repository.

---

## What you need

You need a shell, Git, and OpenSSL. Check them first:

```bash
command -v git
command -v openssl
git version
openssl version
```

`openssl rand -hex 16` writes 16 random bytes as hex. That is a real secret for this lab. Treat it like a password. Do not reuse it anywhere else. Do not print it into a shared document.

You do not need Azure, AWS, AKS, or EKS. Kubernetes is optional. Check whether `kind` and `kubectl` exist. Skip the optional Secret step if either command is missing or if `kubectl cluster-info` fails.

```bash
command -v kind
command -v kubectl
kubectl version --client
```

Create the lab under `/tmp`, not under this course clone. The course `.gitignore` must not be the file you edit. The lab repository must be a new `git init` directory. You must be able to delete that directory when you clean up.

Keep a notes file named `day-18-secrets-lab.md` in the same temp directory. Record command output, not the secret value. Write `ignored` or `staged` as the result. If you paste `openssl` output into the notes, you have already leaked the lab secret.

---

## Steps

1. Create a throwaway directory and enter it. Use a unique folder name so you do not collide with another lab. Confirm the path is under `/tmp` and is not inside the DevOps-Prep clone.

```bash
LAB_DIR="/tmp/day-18-secrets-lab-$$"
mkdir -p "$LAB_DIR"
cd "$LAB_DIR"
pwd
```

Write the date and the path at the top of `day-18-secrets-lab.md`. Write one sentence: this repository is disposable, and you will not run `git push`.

2. Initialize a new Git repository here. This is the only Git repository you touch in this lab. Check `git rev-parse --show-toplevel` so you can see the root. It must equal `$LAB_DIR`.

```bash
git init
git rev-parse --show-toplevel
```

If the toplevel is the course clone, stop. You are in the wrong directory. Go back to step 1.

3. Create a README so the repository has a file you are allowed to commit. You will commit this file. You will not commit the secret.

```bash
printf 'day-18 secrets hygiene lab\n' > README.md
git add README.md
git status
```

`git status` should list `README.md` as staged. There is no secret file yet.

4. Generate the secret and write it to a file named `app.secret`. Use `openssl rand -hex 16`. Do not type a made-up password. Redirect the output so the value lives in the file, not in your notes.

```bash
openssl rand -hex 16 > app.secret
ls -l app.secret
wc -c app.secret
```

The file should exist and should not be empty. Do not run `cat app.secret` in a recorded terminal if you will share that recording. For your own screen, you may confirm the file has one hex line. Do not copy that line anywhere else.

5. Ignore the secret before you stage anything else. Create `.gitignore` with the file name. Then prove Git agrees.

```bash
printf 'app.secret\n' > .gitignore
git check-ignore -v app.secret
git status
```

`git check-ignore -v app.secret` should print a line that names `.gitignore` and `app.secret`. `git status` should show `.gitignore` as untracked or staged later. It must not list `app.secret`. If `app.secret` appears under untracked files, the ignore rule did not match. Fix `.gitignore` before you continue.

6. Stage and commit only the files that are allowed. That is `README.md` and `.gitignore`. Do not run `git add app.secret`. Do not run `git add .` until you have confirmed `git check-ignore` still reports `app.secret`.

```bash
git add README.md .gitignore
git status
git commit -m "Add lab readme and ignore app.secret"
git status
```

After the commit, `git status` should be clean. `git ls-files` should list `README.md` and `.gitignore` only. `app.secret` must not appear in `git ls-files`.

```bash
git ls-files
git check-ignore -v app.secret
```

7. Optional Kubernetes Secret, only if `kind` exists and `kubectl cluster-info` works. If either check fails, write `skipped kubectl: no cluster` in your notes and go to Verify. Do not create a cluster for this optional step.

```bash
command -v kind
kubectl cluster-info
```

If those commands succeed, create a generic Secret from the file. Use a unique name so you do not overwrite another Secret. Then show that Kubernetes stores it as a Secret object. Do not print the decoded value.

```bash
kubectl create secret generic day18-lab-db \
  --from-file=password=app.secret
kubectl get secret day18-lab-db
kubectl describe secret day18-lab-db
```

`kubectl describe` should hide the password data. That matches the lesson: a Kubernetes Secret is a cluster object, not a Git file. Do not run `kubectl get secret day18-lab-db -o yaml` into your notes. Encoding is not encryption. Anyone who can `get` the Secret can decode it.

Write `created k8s secret: yes` or `created k8s secret: no` in `day-18-secrets-lab.md`.

---

## Verify

Read the notes as if you are on a call. You should name the temp repository, say that `openssl rand -hex 16` created `app.secret`, and say that Git ignores that file.

Check these points:

- `pwd` and `git rev-parse --show-toplevel` are under `/tmp`, not inside the course clone.
- `git check-ignore -v app.secret` prints a matching ignore rule.
- `git status` does not list `app.secret`.
- `git ls-files` does not list `app.secret`.
- You committed `.gitignore` and `README.md` only.
- You did not run `git push`.
- You did not paste the secret value into `day-18-secrets-lab.md`.

If `git status` still shows `app.secret`, the file is not ignored. Check the spelling in `.gitignore`. The ignore path is relative to the repository root. Run `git check-ignore -v app.secret` again until it prints the rule.

---

## Break and fix

The failure this Day trains is an accidental `git add` of a secret. You will stage a secret on purpose, then remove it from the index before any commit of that file and before any push.

1. Copy the ignored secret to a new file that is not yet ignored. This is the accident. Do not add a remote. Do not push.

```bash
cp app.secret leaked.secret
git add leaked.secret
git status
```

`git status` should show `leaked.secret` as staged for commit. That is the break. The file is in the index. It is not in `.gitignore` yet. Stop here. Do not run `git commit`. Do not run `git push`. A staged secret is already a leak if you commit it.

2. Remove the file from the index and keep it on disk. `git rm --cached` unstages the path. It does not delete `leaked.secret` in the working tree.

```bash
git rm --cached leaked.secret
git status
```

`leaked.secret` should now appear as untracked, not as a staged new file. The secret still exists on disk. Git is no longer about to commit it.

3. Ignore the leaked name, then prove Git ignores it. Append the path to `.gitignore`. Stage `.gitignore` only.

```bash
printf 'leaked.secret\n' >> .gitignore
git check-ignore -v leaked.secret
git add .gitignore
git status
git commit -m "Ignore leaked.secret after unstaging"
git ls-files
```

`git check-ignore -v leaked.secret` should print the new rule. `git status` must not list `leaked.secret`. `git ls-files` must not list `leaked.secret` or `app.secret`. The latest commit should change only `.gitignore`.

4. Confirm there is no remote and that you never pushed. This lab has no origin. If a remote exists, you used the wrong repository. Stop and go back to step 1 of Steps.

```bash
git remote -v
git log --oneline
```

`git remote -v` should print nothing. The log should show the README commit and the ignore commit. It should not show a commit whose diff adds `app.secret` or `leaked.secret`.

If you already committed the secret in this temp repository, do not push. Delete the entire `$LAB_DIR` in Clean up and start again. History in a temp repo is disposable. History in a shared repo is not. That is why this lab never uses the course clone.

---

## Clean up

If you created the optional Kubernetes Secret, delete it. Skip this command when you wrote `created k8s secret: no`.

```bash
kubectl delete secret day18-lab-db --ignore-not-found
```

Leave the lab directory and delete it. This removes `app.secret`, `leaked.secret`, `.git`, and the notes unless you copied the notes out first.

```bash
cd /tmp
rm -rf "$LAB_DIR"
```

If you want to keep notes, copy `day-18-secrets-lab.md` to a safe local folder before `rm -rf`. Redact any hex value if you captured one. Do not copy `app.secret` or `leaked.secret` into the course repository.

You created no Azure or AWS resources, so there is no Key Vault, Secrets Manager, or resource group to delete. You did not run `git push`, so there is no remote history to rewrite.

---

## Interview story

I treat a secret as a lifecycle problem, not as a file I hope nobody opens. I generate a value with `openssl rand -hex 16` and I keep it out of Git with `.gitignore`. I prove that with `git check-ignore` and with `git status` that does not list the file. If I accidentally run `git add` on a secret, I stop. I run `git rm --cached`, I add the path to `.gitignore`, and I do that before any commit of the secret and before any push. I do this drill in a throwaway repository so the course history never holds a credential. Kubernetes can consume the same file as a Secret object. Git is still not the secret store.
