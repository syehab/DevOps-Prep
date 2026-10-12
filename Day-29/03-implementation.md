# Day 29 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 29 teaches AWS DevOps as a controlled path from a Git commit to a running workload. CodePipeline orchestrates stages. CodeBuild builds the image. ECR stores it. ECS runs it. This lab stays on your machine. You build one image, tag it without a second build, and write a GitHub Actions workflow whose stages map to CodePipeline Source, Build, and Deploy.

Work only in a temporary directory. Do not build inside this course repository. Do not create an AWS account, an ECR repository, or an ECS service. A local image and a YAML file are enough.

---

## Goal

Build one container image in a throwaway directory. Record its image ID. Tag the same image as `uat` and later as `prod` without running `docker build` again. Write a GitHub Actions workflow that checks out source, builds that image once, and promotes the same image ID. Write a short map from CodePipeline stages to GitHub Actions steps.

When you finish, you can explain why a Production rebuild is not a promotion. You can also name Source, Build, and Deploy in both CodePipeline and GitHub Actions.

Time box: 45 to 75 minutes. Cost stays at ₹0. Stop when the image IDs match across tags, the workflow file exists, the mapping is written, and the break-and-fix cycle has shown a rebuild versus a tag.

---

## What you need

You need a shell and Git. Check them first:

```bash
git --version
```

Check for Docker. The commands below print a version if Docker Engine is installed. If they fail, still write every file in this lab. Copy the Docker commands into your notes. Run them later when Docker is on your `PATH`. Do not invent a replacement tool.

```bash
command -v docker
docker version
```

You do not need AWS, CodePipeline, CodeBuild, ECR, or ECS. GitHub Actions reads `.github/workflows/` when a repository is connected. A file on disk is still valid YAML if GitHub never runs it. `python:3.12-slim` is a real image. This lab uses it so `CMD` is a known HTTP server.

Create the lab under `/tmp`, not under this course clone. Docker writes image layers on the host. You must be able to delete the directory and the lab image when you clean up.

Keep a notes file named `day-29-devops-lab.md` in the same temp directory. Record command output, image IDs, and the CodePipeline map. Do not paste secrets. This lab should not create any.

---

## Steps

1. Create a throwaway directory and enter it. Use a unique folder name so you do not collide with another lab. Confirm the path is under `/tmp`.

```bash
LAB_DIR="/tmp/day-29-aws-devops-lab-$$"
mkdir -p "$LAB_DIR"
cd "$LAB_DIR"
pwd
```

2. Write `index.html`. This is the file the HTTP server will return. The body must be easy to recognize later if a rebuild changes it.

```bash
printf 'day-29-build\n' > index.html
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

You should see `Dockerfile` and `index.html`.

4. If Docker is present, build the image once. Tag it `shopsphere-app:build`. Docker may pull `python:3.12-slim` on the first build. Wait for the build to finish.

```bash
docker build -t shopsphere-app:build .
```

If `docker` is missing, copy this command into the notes and continue writing files. Do not replace it with a made-up tool.

5. Record the image ID. This ID is the local content identity. A registry digest appears after a push to ECR. This lab never pushes, so the ID is the proof that two tags name the same bytes.

```bash
docker inspect --format='{{.Id}}' shopsphere-app:build
```

Paste the full `sha256:` value into `day-29-devops-lab.md`. Label it `BUILD_ID`.

6. Promote the image to UAT without a rebuild. `docker tag` creates a new name for the same image ID. It does not run `docker build`.

```bash
docker tag shopsphere-app:build shopsphere-app:uat
docker inspect --format='{{.Id}}' shopsphere-app:uat
```

The UAT ID must match `BUILD_ID`. If it does not, you built twice. Stop and tag the `build` image again.

7. Initialize a scratch Git repository in this temp directory. GitHub Actions and CodePipeline both start from a commit. Record the short SHA. That SHA is the source identity from the lesson.

```bash
git init
git add Dockerfile index.html
git commit -m "Add shopsphere-app image sources"
git rev-parse --short HEAD
```

Paste the short SHA into the notes next to `BUILD_ID`.

8. Write the CodePipeline map before you write YAML. Create `day-29-devops-lab.md` if it does not exist. Put this table in it. The table is the interview artifact.

```text
Stage   | CodePipeline                         | GitHub Actions
--------|--------------------------------------|-------------------------------
Source  | Source action (GitHub / CodeCommit)  | actions/checkout@v4
Build   | CodeBuild (docker build, tests)      | docker build in the Build step
Store   | ECR image digest                     | local image ID until you push
Deploy  | ECS / CodeDeploy using that digest   | docker tag of the same image
```

Write two more sentences under the table. CodePipeline passes artifacts from stage to stage. GitHub Actions jobs run on separate machines, so a Deploy job cannot see an image from a Build job unless you push that image to a registry. Keep Source, Build, and Deploy as steps in one job in this lab so the image stays on the same runner.

9. Create the workflow directory. GitHub Actions reads `.github/workflows/` on push.

```bash
mkdir -p .github/workflows
```

10. Write `.github/workflows/build-and-promote.yml`. The keys below are real: `on`, `push`, `jobs`, `runs-on`, `steps`, `uses: actions/checkout@v4`, and `run`. Source checks out the commit. Build runs `docker build` once. Deploy tags the same image as `prod`. Deploy does not run `docker build`.

```yaml
name: build-and-promote

on: push

jobs:
  pipeline:
    runs-on: ubuntu-latest
    steps:
      - name: Source
        uses: actions/checkout@v4

      - name: Build
        run: docker build -t shopsphere-app:build .

      - name: Deploy
        run: |
          docker tag shopsphere-app:build shopsphere-app:prod
          docker inspect --format='{{.Id}}' shopsphere-app:build
          docker inspect --format='{{.Id}}' shopsphere-app:prod
```

Write the file with that content:

```bash
cat > .github/workflows/build-and-promote.yml << 'EOF'
name: build-and-promote

on: push

jobs:
  pipeline:
    runs-on: ubuntu-latest
    steps:
      - name: Source
        uses: actions/checkout@v4

      - name: Build
        run: docker build -t shopsphere-app:build .

      - name: Deploy
        run: |
          docker tag shopsphere-app:build shopsphere-app:prod
          docker inspect --format='{{.Id}}' shopsphere-app:build
          docker inspect --format='{{.Id}}' shopsphere-app:prod
EOF
```

Read the file once. `Source` is the CodePipeline source action. `Build` is CodeBuild. `Deploy` is the promotion step that ECS would consume. There is no second `docker build` in Deploy.

11. If Docker is present, run the same Deploy promotion locally. Tag `prod` from `build`. Compare IDs.

```bash
docker tag shopsphere-app:build shopsphere-app:prod
docker inspect --format='{{.Id}}' shopsphere-app:build
docker inspect --format='{{.Id}}' shopsphere-app:prod
```

Both IDs must match `BUILD_ID`. Paste them into the notes. Label the pair `promoted`.

12. Commit the workflow and the notes. A local file is enough to finish the Day. Do not push this scratch repository to the course remote.

```bash
git add .github/workflows/build-and-promote.yml day-29-devops-lab.md
git commit -m "Add Source, Build, Deploy workflow that promotes the same image"
```

---

## Verify

Read `day-29-devops-lab.md` out loud as if you are on a call. Start at Source. Stop at Deploy. You should not need an AWS console.

Check these points:

- `Dockerfile` and `index.html` exist under `$LAB_DIR`.
- If Docker is present, `docker inspect --format='{{.Id}}'` matches for `shopsphere-app:build`, `shopsphere-app:uat`, and `shopsphere-app:prod`.
- `.github/workflows/build-and-promote.yml` has steps named Source, Build, and Deploy. Deploy uses `docker tag`. It does not use `docker build`.
- The notes table maps CodePipeline Source, Build, and Deploy to GitHub Actions.
- You recorded the Git short SHA next to `BUILD_ID`.

If Docker is missing, the files and the table still complete the lab. Write one line: Docker is absent, so the image IDs were not recorded. Do not skip the workflow.

If a YAML key appears that you cannot explain, remove it. A short workflow that you understand is better than a copied template.

---

## Break and fix

The broken Production path rebuilds the image instead of promoting the digest. Do this on purpose.

Change `index.html` so a rebuild cannot hide behind cache luck. Keep the `build` tag as the tested artifact.

```bash
printf 'day-29-prod-rebuild\n' > index.html
cat index.html
```

If Docker is present, run a Production rebuild. This is the wrong path from the lesson.

```bash
docker build -t shopsphere-app:prod .
docker inspect --format='{{.Id}}' shopsphere-app:build
docker inspect --format='{{.Id}}' shopsphere-app:prod
```

The Prod ID should differ from `BUILD_ID`. UAT still passed the old image. Production now has different bytes. That is the traceability break: the source tree moved, and Production did not receive the artifact that UAT tested.

Write those two IDs in the notes. Label them `broken rebuild`.

Restore `index.html` so the working tree matches the tested image:

```bash
printf 'day-29-build\n' > index.html
cat index.html
```

Rewrite Production to promote the digest. Tag `prod` from `build` again. Do not run `docker build` for Production.

```bash
docker tag shopsphere-app:build shopsphere-app:prod
docker inspect --format='{{.Id}}' shopsphere-app:build
docker inspect --format='{{.Id}}' shopsphere-app:prod
```

The IDs must match `BUILD_ID` again. That is the fix: promote the image that already passed Build. In AWS, the same rule is an ECR digest. CodePipeline Deploy consumes that digest. It does not ask CodeBuild to compile Production as a new image.

If Docker is missing, still write both command blocks into the notes. Label the first block broken. Label the second block fixed. The workflow file must keep `docker tag` in Deploy.

Do not “fix” the break by adding a second GitHub Actions job that runs `docker build -t shopsphere-app:prod .`. That job would rebuild on a fresh runner. The fix is promotion of the same ID, or a push of that digest to a registry that Deploy can pull.

---

## Clean up

You created no AWS resources. There is no ECR repository, ECS service, load balancer, NAT Gateway, or IAM role to delete.

If Docker is present, remove the lab tags. `docker rmi` removes a tag. The `python:3.12-slim` base image may remain on the host from the pull. You may leave that base image.

```bash
docker rmi shopsphere-app:prod shopsphere-app:uat shopsphere-app:build
```

Leave the lab directory and delete it, including `.git` and `.github`.

```bash
cd /tmp
rm -rf "$LAB_DIR"
```

If you copied notes you want to keep, move `day-29-devops-lab.md` out before `rm -rf`. Strip any pasted image IDs you do not want to keep. Do not copy the scratch Git repository into the course tree. This lab must not contain passwords, keys, or account IDs.

The cleanup list in [01-concepts.md](01-concepts.md) applies when you later run the AWS hands-on from [02-questions-and-answers.md](02-questions-and-answers.md). This local lab has none of those resources.

---

## Interview story

I treat AWS DevOps as a path, not as a list of product names. CodePipeline orchestrates Source, Build, and Deploy. CodeBuild builds the image once. ECR stores the digest. ECS runs that digest. I can show the same idea without AWS: I build `shopsphere-app:build`, I record the image ID, and I `docker tag` it to `uat` and `prod`. A Production `docker build` is a new artifact, even when the Git repo looks familiar. GitHub Actions maps cleanly when Source is `actions/checkout@v4`, Build is `docker build`, and Deploy promotes the same ID. I do not split Build and Deploy onto two runners unless a registry holds the digest between them.
