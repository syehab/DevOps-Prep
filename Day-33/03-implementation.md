# Day 33 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 33 teaches a delivery pipeline as a supply chain. One Git commit produces one artifact. Dev, UAT, and Production must run those same bytes. This lab builds that artifact once. You then promote it with a new name. You do not rebuild it for the next environment.

Work only in a temporary directory that you create for this lab. Do not build inside this course repository. Do not push to ECR. Do not create an AWS account. A local image ID, or a local tarball checksum, is enough to prove promotion.

---

## Goal

Build one artifact. Record its identity. Tag it as `app:dev`. Promote the same artifact to `app:uat` without a second build. Prove the two identities match. Then break the rule: build again for Production and show that the identity can differ. Fix the break by promoting the first identity to `app:prod`.

If Docker Engine is present, the artifact is a container image. You record `Id` with `docker inspect`. `RepoDigests` stays empty until a registry push, so local `Id` is the proof in this lab. If Docker is missing, the artifact is a tarball. You record its SHA-256 with `sha256sum`. Promotion is a copy of that same file, not a new archive.

When you finish, you can explain why a Production rebuild is not a promotion. You can also name the identity you would write on a release record.

Time box: 40 to 70 minutes. Cost stays at ₹0. Stop when Dev and UAT identities match, the rebuild differs, the fix matches the first identity, and the temp directory is deleted.

---

## What you need

You need a shell. Check it first:

```bash
pwd
```

Check for Docker. The commands below print a path and a version if Docker Engine is installed and the daemon answers.

```bash
command -v docker
docker version
```

If `docker` is missing, or the daemon does not answer, use the tarball path in every later step. Write `docker: skipped` in your notes. Do not invent a replacement container tool.

You also need GNU `sha256sum` and `tar` for the fallback, and as a second record even when Docker works:

```bash
command -v sha256sum
command -v tar
```

You do not need AWS, ECR, ECS, Maven, or GitHub Actions minutes. `python:3.12-slim` is a real image. This lab uses it so `CMD` is a known HTTP server. Do not switch base images in the middle of the lab.

Create the lab under `/tmp`, not under this course clone. Docker writes image layers on the host. You must be able to delete the directory and the lab tags when you clean up.

Keep a notes file named `day-33-promotion-lab.md` in the same temp directory. Record command output, image IDs or checksums, and the rebuild difference. Do not paste secrets. This lab should not create any.

---

## Steps

1. Create a throwaway directory and enter it. Use a unique folder name so you do not collide with another lab. Confirm the path is under `/tmp`.

```bash
LAB_DIR="/tmp/day-33-promotion-lab-$$"
mkdir -p "$LAB_DIR"
cd "$LAB_DIR"
pwd
```

2. Write `index.html`. This is the file the HTTP server will return. Keep the content exact so a later rebuild cannot hide behind the same bytes.

```bash
printf 'day-33-app-v1\n' > index.html
cat index.html
```

3. Write `Dockerfile`. `FROM` starts from `python:3.12-slim`. `WORKDIR` sets `/app`. `COPY` adds `index.html`. `EXPOSE 8080` documents the listen port. `CMD` starts the process.

```dockerfile
FROM python:3.12-slim

WORKDIR /app

COPY index.html .

EXPOSE 8080

CMD ["python", "-m", "http.server", "8080"]
```

Save that file as `Dockerfile` in `$LAB_DIR`. Confirm the files exist:

```bash
ls
cat Dockerfile
```

You should see `Dockerfile` and `index.html`. These files are the source of the artifact. The promotion rule starts after the first successful build.

4. Decide the path. If `docker version` succeeded, follow the Docker steps below. If it failed, skip to step 8 and use the tarball. Do not mix the two paths for the identity you record as `DEV_ID`.

5. Build the image once. Tag it `app:dev`. Docker may pull `python:3.12-slim` on the first build. Wait for the build to finish. Do not add a second `-t` yet.

```bash
docker build -t app:dev .
```

This is the only `docker build` that creates the artifact you will promote. Dev, UAT, and Production must point at this image.

6. Record the local image identity. `Id` names the image content on this machine. `RepoDigests` names the image after a registry push. This lab never pushes, so `RepoDigests` should be empty.

```bash
docker inspect --format='{{.Id}}' app:dev
docker inspect --format='{{json .RepoDigests}}' app:dev
```

Paste the full `sha256:` value from `Id` into `day-33-promotion-lab.md`. Label it `DEV_ID`. Paste the `RepoDigests` JSON next to it. An empty list `[]` is the expected local result. In production you would record the digest after the ECR push instead of this local `Id`.

7. Promote the same image to UAT without a rebuild. `docker tag` creates a new name for the same image ID. It does not run `docker build`.

```bash
docker tag app:dev app:uat
docker inspect --format='{{.Id}}' app:uat
docker inspect --format='{{json .RepoDigests}}' app:uat
```

The UAT `Id` must match `DEV_ID`. If it does not, you built twice. Stop and tag `app:dev` again. Write both IDs in the notes. Label the pair `promoted uat`. Skip step 8 if Docker succeeded.

8. Tarball fallback, only if Docker is missing. Pack the same source files once. That archive is the artifact. Hash it. Copy it to a UAT name. Do not run `tar` a second time to create UAT.

```bash
tar -cf app-dev.tar Dockerfile index.html
sha256sum app-dev.tar | tee app-dev.sha256
cp app-dev.tar app-uat.tar
sha256sum app-uat.tar | tee app-uat.sha256
```

The two checksums must match. Paste both lines into the notes. Label them `DEV_ID` and `promoted uat`. `cp` is the promotion. A second `tar -cf` would be a rebuild.

9. Write the release record. Create `day-33-promotion-lab.md` if it does not exist. Put this block in it. Fill the values you just recorded.

```text
Git SHA: local lab, no remote
Build: once
Artifact name: app:dev
Identity (Id or sha256sum):
UAT name: app:uat
UAT identity:
IDs match: yes/no
RepoDigests (Docker only):
```

This is the same kind of record the lesson asks for after a real release: commit, artifact, digest, environment result. A branch name such as `main` is not an identity.

---

## Verify

Read the notes as if you are on a call. Start at the first build. Stop at UAT. You should not need an AWS console.

Check these points:

- `Dockerfile` and `index.html` exist under `$LAB_DIR`.
- You ran `docker build` once for `app:dev`, or you ran `tar -cf app-dev.tar` once.
- `docker inspect --format='{{.Id}}'` matches for `app:dev` and `app:uat`, or `sha256sum` matches for `app-dev.tar` and `app-uat.tar`.
- `RepoDigests` is `[]` when you did not push. You still recorded `Id`.
- The notes file holds `DEV_ID` and the matching UAT identity.

If Docker is missing, the tarball pair still completes Verify. Write one line: Docker is absent, so image IDs were not recorded. Do not skip the checksum.

If the two identities differ before the break step, you rebuilt. Delete the extra tag or extra tarball. Promote from the first artifact again. Do not continue until they match.

---

## Break and fix

The broken Production path rebuilds the artifact instead of promoting the identity. Do this on purpose.

Change `index.html` so a rebuild cannot hide behind cache luck. Keep `app:dev` as the tested artifact.

```bash
printf 'day-33-app-prod-rebuild\n' > index.html
cat index.html
```

If Docker is present, run a Production rebuild. This is the wrong path from the lesson.

```bash
docker build -t app:prod .
docker inspect --format='{{.Id}}' app:dev
docker inspect --format='{{.Id}}' app:prod
```

The Prod `Id` should differ from `DEV_ID`. UAT still passed the old image. Production now has different bytes. That is the traceability break: the source tree moved, and Production did not receive the artifact that UAT tested.

Write those two IDs in the notes. Label them `broken rebuild`.

If Docker is missing, rebuild the tarball instead:

```bash
tar -cf app-prod.tar Dockerfile index.html
sha256sum app-dev.tar
sha256sum app-prod.tar
```

The Prod checksum should differ from `DEV_ID`. Label those two lines `broken rebuild`.

Restore `index.html` so the working tree matches the tested artifact:

```bash
printf 'day-33-app-v1\n' > index.html
cat index.html
```

Rewrite Production to promote the first identity. Do not run `docker build` for Production. Do not run `tar -cf` for Production.

```bash
docker tag app:dev app:prod
docker inspect --format='{{.Id}}' app:dev
docker inspect --format='{{.Id}}' app:prod
```

The IDs must match `DEV_ID` again. That is the fix: promote the image that already passed Dev and UAT. In AWS, the same rule is an ECR digest. The deploy stage consumes that digest. It does not ask the build stage to compile Production as a new image.

If Docker is missing, copy the first tarball:

```bash
cp app-dev.tar app-prod.tar
sha256sum app-dev.tar
sha256sum app-prod.tar
```

The checksums must match `DEV_ID`. Label the pair `fixed promotion`.

Write one sentence in the notes: Production now names the same artifact that Dev and UAT already used. A second build is not a promotion, even when the Git tree looks familiar.

---

## Clean up

You created no AWS resources. There is no ECR repository, ECS service, load balancer, or IAM role to delete.

If Docker is present, remove the lab tags. `docker rmi` removes a tag. The `python:3.12-slim` base image may remain on the host from the pull. You may leave that base image.

```bash
docker rmi app:prod app:uat app:dev
```

If a rebuild left an untagged image, `docker images` may still show `<none>`. Remove dangling lab images only if you created them here:

```bash
docker images
```

Leave the lab directory and delete it, including tarballs and checksum files.

```bash
cd /tmp
rm -rf "$LAB_DIR"
```

If you copied notes you want to keep, move `day-33-promotion-lab.md` out before `rm -rf`. Strip any pasted image IDs you do not want to keep. Do not copy the lab directory into the course tree. This lab must not contain passwords, keys, or account IDs.

The cleanup list in [01-concepts.md](01-concepts.md) applies when you later run ShopSphere in AWS. This local lab has none of those resources. Keep any real ShopSphere environment that Day 34 will reuse.

---

## Interview story

I treat a deployment pipeline as a supply chain, not as a list of shell commands. One Git commit produces one artifact. I build `app:dev` once, I record `docker inspect` `Id`, and I `docker tag` that same image as `app:uat`. The IDs match, so UAT did not get a new build. If I run `docker build` again for Production, the `Id` can differ, even from similar source. That rebuild is the bug. The fix is to promote the first `Id` to `app:prod`. When Docker is absent, `sha256sum` on a tarball is the same proof: copy the file, do not pack it again. In AWS I would record the ECR digest after the push and deploy that digest. I must prove Production runs the bytes that passed UAT.
