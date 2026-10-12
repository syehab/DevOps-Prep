# Day 19 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 19 teaches the software supply chain as the trusted path from source to production. This lab proves two controls from that path: artifact integrity and pinned pipeline actions. You create a tiny artifact file, hash it with `sha256sum`, and record the digest. You then write a GitHub Actions workflow that uses `actions/checkout@v4`, not `@main`. You do not need a scanner, a registry account, or a paid GitHub org. Checksum plus pin is enough.

Work only in a temporary directory that you create for this lab. Do not write the artifact or the workflow inside this course repository. Do not push the lab to GitHub unless you already have a throwaway repo you own. Local files and local checksum verification are the required path.

---

## Goal

Create `artifact.txt`. Hash it with `sha256sum`. Save the digest in `artifact.sha256`. Confirm `sha256sum -c` reports OK. Write `.github/workflows/record-digest.yml` so the checkout step uses `actions/checkout@v4`. Then change `artifact.txt` on purpose, watch the checksum fail, restore the original bytes, and watch the checksum pass again.

If Docker is installed, pull a small public image and inspect `RepoDigests`. That optional step shows how a registry digest identifies image content the same way `sha256sum` identifies a file. Skip Docker if the binary is missing. Do not invent scanner flags.

Time box: 40 to 70 minutes. Cost stays at ₹0. Stop when the restored checksum is OK, the workflow pins `@v4`, and the temp directory is deleted.

---

## What you need

You need a shell and GNU `sha256sum`. Check them first:

```bash
command -v sha256sum
sha256sum --version
```

You do not need Azure, AWS, Maven, Kubernetes, Trivy, or a GitHub Actions minute. This lab never calls a vulnerability scanner. If you add a scan step, you are outside the lab.

Docker is optional. Check it, then decide:

```bash
command -v docker
```

If `docker` is missing, write `docker: skipped` in your notes and continue. If it exists, you may run the optional inspect step later. Do not treat a missing daemon as a failed lab.

Create the lab under `/tmp`, not under this course clone. You must be able to delete that directory when you clean up.

Keep a notes file named `day-19-supply-chain-lab.md` in the same temp directory. Record the digest, the failed checksum, the restored checksum, and the checkout pin. Do not paste secrets. This lab should not create any.

---

## Steps

1. Create a throwaway directory and enter it. Use a unique folder name so you do not collide with another lab. Confirm the path is under `/tmp`.

```bash
LAB_DIR="/tmp/day-19-supply-chain-lab-$$"
mkdir -p "$LAB_DIR"
cd "$LAB_DIR"
pwd
```

2. Create the artifact. This file stands in for a build output: a JAR, a tarball, or an image layer. Keep the content exact so the later restore matches.

```bash
printf 'day-19-artifact-v1\n' > artifact.txt
cat artifact.txt
```

3. Hash the file and save the digest. `sha256sum` prints the digest and the filename. `tee` writes that line to `artifact.sha256` and shows it on the terminal. Copy the digest into `day-19-supply-chain-lab.md`.

```bash
sha256sum artifact.txt | tee artifact.sha256
cat artifact.sha256
```

The first field is the SHA-256 digest. The second field is the file name. That pair is the integrity record. Production release notes should hold the same kind of record for a real artifact.

4. Verify the record against the file. `sha256sum -c` rereads `artifact.txt`, hashes it again, and compares the result with `artifact.sha256`. You should see `artifact.txt: OK`.

```bash
sha256sum -c artifact.sha256
```

If the check fails now, you typed the wrong content or you edited the file after hashing. Recreate `artifact.txt` with the `printf` from step 2, then hash again.

5. Create the workflow directory. GitHub Actions loads YAML from `.github/workflows/`. The lab writes that path locally so you can inspect the pin. You do not have to push it.

```bash
mkdir -p .github/workflows
```

6. Write `.github/workflows/record-digest.yml`. The checkout action is pinned to `@v4`. Do not use `@main`. `@main` moves when the action repository moves. `@v4` is a published version tag. Copy this file exactly.

```yaml
name: record-artifact-digest

on:
  push:
  pull_request:

jobs:
  checksum:
    runs-on: ubuntu-latest
    steps:
      - name: Check out source
        uses: actions/checkout@v4
      - name: Record SHA-256 of the artifact
        run: sha256sum artifact.txt
```

7. Prove the pin. Search the workflow for `actions/checkout`. You should see `@v4` and you should not see `@main`.

```bash
grep -n 'actions/checkout' .github/workflows/record-digest.yml
grep -n 'checkout@main' .github/workflows/record-digest.yml || echo 'checkout@main is absent'
```

Write one sentence in the notes: the pipeline checks out source with `actions/checkout@v4`, not `@main`. A mutable action tag is a supply-chain risk in the same way a mutable image tag is.

8. Optional Docker inspect, only if `command -v docker` succeeded and the daemon responds. Pull a small public image, then print `RepoDigests`. `RepoDigests` is the registry content digest after pull. A tag such as `alpine` can move. The digest names the exact image content.

```bash
docker pull alpine:3.20
docker image inspect alpine:3.20 --format '{{json .RepoDigests}}'
```

Copy the `RepoDigests` JSON into the notes. If pull or inspect fails, write `docker inspect: skipped` and continue. Do not add Trivy, Grype, or `docker sbom` flags. Checksum plus pin is the required proof.

9. Start the notes file if you have not already. Record the file digest, the workflow pin, and the optional image digest. Keep the notes in the lab directory.

```bash
{
  echo '# Day 19 supply-chain lab'
  echo
  echo 'Artifact digest:'
  cat artifact.sha256
  echo
  echo 'Checkout pin:'
  grep -n 'actions/checkout' .github/workflows/record-digest.yml
} > day-19-supply-chain-lab.md
cat day-19-supply-chain-lab.md
```

---

## Verify

Read the notes as if you are on a call. You should name the artifact digest, say that `sha256sum -c` reported OK, and say that checkout is pinned to `@v4`.

Check these points:

- `artifact.txt` contains `day-19-artifact-v1`.
- `artifact.sha256` holds one line: digest, space, `artifact.txt`.
- `sha256sum -c artifact.sha256` prints `artifact.txt: OK`.
- `.github/workflows/record-digest.yml` contains `uses: actions/checkout@v4`.
- That workflow does not contain `actions/checkout@main`.
- If Docker ran, the notes contain a `RepoDigests` value or an explicit skip.

If `sha256sum -c` already fails, stop. Restore the file from step 2 before you go to Break and fix. The break step only has meaning when the baseline check is green.

---

## Break and fix

Change the artifact without updating `artifact.sha256`. This is the supply-chain break: the bytes no longer match the recorded digest. Do not edit `artifact.sha256` yet.

```bash
printf 'day-19-artifact-tampered\n' > artifact.txt
cat artifact.txt
sha256sum artifact.txt
sha256sum -c artifact.sha256
```

The new `sha256sum artifact.txt` digest must differ from the line in `artifact.sha256`. `sha256sum -c` must fail. Copy the failed output into the notes. That failure is the control working. A tag or a file name stayed the same. The content did not.

Restore the original bytes. Do not change `artifact.sha256`. The recorded digest is the source of truth for this lab.

```bash
printf 'day-19-artifact-v1\n' > artifact.txt
sha256sum -c artifact.sha256
```

The check must print `artifact.txt: OK` again. Write one sentence in the notes: a changed artifact fails the checksum; restoring the original bytes makes the recorded digest match.

Optional extra check on the workflow pin, if you still have time. Copy the workflow to a broken file that uses `@main`, then confirm your real workflow still uses `@v4`.

```bash
sed 's/actions\/checkout@v4/actions\/checkout@main/' .github/workflows/record-digest.yml > /tmp/day-19-bad-workflow.yml
grep -n 'actions/checkout' /tmp/day-19-bad-workflow.yml .github/workflows/record-digest.yml
rm -f /tmp/day-19-bad-workflow.yml
```

Do not leave `checkout@main` in `.github/workflows/record-digest.yml`. The broken copy is only a contrast. The lab workflow stays on `@v4`.

---

## Clean up

Leave the lab directory and delete it. That removes the artifact, the digest file, the workflow, and the notes unless you copied the notes out first.

```bash
cd /tmp
rm -rf "$LAB_DIR"
```

If you pulled `alpine:3.20` and you do not need that image, remove it. Do not run a broad prune.

```bash
docker image rm alpine:3.20
```

If Docker is missing, skip that command. You created no Azure or AWS resources, so there is no registry, cluster, or resource group to delete. Do not delete shared or production images.

---

## Interview story

I treat a release artifact as untrusted until I can name its digest. I write a small file, run `sha256sum`, and store that line. When the file changes, `sha256sum -c` fails. When I restore the original bytes, the check passes. That is the same idea as pinning a container to `myapp@sha256:<digest>` instead of a moving tag. I also pin GitHub Actions checkout to `actions/checkout@v4` and I refuse `@main`, because the pipeline is part of the supply chain. If Docker is present I inspect `RepoDigests` after pull. I do not add a scanner I cannot operate. Checksum plus pin is enough to explain integrity in an interview.
