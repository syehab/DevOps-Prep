# Day 23 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 23 teaches Azure compute as a management-responsibility choice. A Spring Boot API can run on a VM, App Service, Container Apps, or AKS. The code can stay the same. What you operate changes. This lab records that choice in a decision table. Then you run the same tiny HTTP app two ways: as a local Python process, and as `docker run` if Docker exists. Those two runtimes stand in for “same workload, different compute abstraction.” You do not create Azure resources.

Work only in a temporary directory that you create for this lab. Do not run the app inside the DevOps-Prep course repository. Do not run `az vm create`, `az webapp up`, or `az aks create`.

---

## Goal

Fill one decision table for a standard Spring Boot REST API. Compare Azure VM, App Service, Container Apps, and AKS. Record what you manage, what Azure manages, how you scale, and how you roll back. Then serve the same `index.html` from `python3 -m http.server` on the host and, if Docker is present, from `docker run`.

After the working `curl` succeeds, break the container on purpose. Keep `EXPOSE 8080`. Change `CMD` so the process listens on `9090`. Publish host port `8080` to container port `8080`. `curl` should fail. `docker logs` should show the listen port. That mismatch is the break. Fix `CMD`, rebuild, and curl again. Stop the process and the container when you finish.

Time box: 45 to 75 minutes. Cost stays at ₹0. Stop when the table is complete, both runtimes have a successful `curl` (or Docker is recorded as missing), the broken `curl` is in your notes, and cleanup has stopped the process and removed the lab container.

---

## What you need

You need a shell, `curl`, and Python 3. Check them first:

```bash
command -v curl
command -v python3
python3 --version
```

Docker Engine is optional. Check it next:

```bash
command -v docker
docker version
```

If `docker` is missing, still write the Dockerfile below. Write the `docker` commands into your notes. Run the local Python process. Do not invent another container tool. Do not create an Azure App Service or AKS cluster to compensate.

You do not need Java, Maven, Spring Boot, or an Azure subscription. `python3 -m http.server` is the stand-in for the API process. The image name `python:3.12-slim` is real. Do not switch images in the middle of this lab.

Create the lab under `/tmp`, not under this course clone. Keep a notes file named `day-23-compute-lab.md` in that temp directory. Record the decision table, both `curl` bodies, the failed `curl`, and whether Docker ran. Do not paste secrets. This lab should not create any.

---

## Steps

1. Create a throwaway directory and enter it. Use a unique folder name so you do not collide with another lab. Confirm the path is under `/tmp`.

```bash
LAB_DIR="/tmp/day-23-compute-lab-$$"
mkdir -p "$LAB_DIR"
cd "$LAB_DIR"
pwd
```

2. Create the notes file. Put the date at the top. Write one short paragraph: you will choose compute for a Spring Boot API on paper. You will run a tiny HTTP app as a local process. You will run the same app with `docker run` only if Docker is already on this machine.

```bash
touch day-23-compute-lab.md
ls
```

3. Write the workload sentence before the table. The application is a standard Spring Boot REST API with conventional HTTP traffic. It talks to PostgreSQL. It does not need OS-level agents. It does not need custom Kubernetes controllers. Name that workload in the notes. Do not change it later to force AKS.

Write at least one short paragraph. Say that the JAR can stay the same across VM, App Service, Container Apps, and AKS. Say that operational responsibility is what changes. Say that you pick the simplest compute model that meets the requirements.

4. Add the decision table. Copy this block into the notes file. Fill every cell in your own words. Do not leave a cell as a product name only.

```markdown
| Question | Azure VM | App Service | Container Apps | AKS |
|:--|:--|:--|:--|:--|
| Who patches the OS? | | | | |
| Who runs the Java process? | | | | |
| How do you deploy a new version? | | | | |
| How do you roll back? | | | | |
| How does it scale? | | | | |
| What Azure manages | | | | |
| What your team still owns | | | | |
| When this fits a Spring Boot API | | | | |
```

Fill the VM column first. You install Java, run the JAR under `systemd`, patch the guest OS, and own disks and NSGs. Azure owns the host hardware. A restart is not high availability.

Fill App Service next. Azure patches the platform. You deploy a JAR or a container to a plan. Slots support a staging swap. You still own the app, identity, and settings. You do not SSH into a guest OS.

Fill Container Apps next. You push an image and run a revision. Azure hides nodes and the Kubernetes API. You own the image, ingress, scale rules, and identity.

Fill AKS last. Azure manages the control plane. You still own node pools, Deployments, Services, probes, and cluster networking. Write one requirement that would justify AKS over Container Apps for this API. If you cannot name one, do not pick AKS.

5. Write two sentences under the table. For this standard Spring Boot API, App Service or Container Apps usually fit. A VM is justified by OS-level need. AKS is justified by Kubernetes-native need. “Containers” is not that need. “More modern” is not a requirement.

6. Write `index.html`. This is the file the HTTP server will return. The body must be easy to recognize in `curl`.

```bash
printf 'day-23-lab\n' > index.html
cat index.html
```

7. Start the same app as a local Python process. Bind it to port `18080` on this machine. Run it in the background. Record the process ID.

```bash
python3 -m http.server 18080 --bind 127.0.0.1 > http-server.log 2>&1 &
echo $! > http-server.pid
cat http-server.pid
```

If port `18080` is already in use, stop. Choose `18082` instead and use that port in every later local `curl`. Write the port you used.

8. Request the page from the host. You should see `day-23-lab`. This is the process model: you started the runtime, you own the listen port, and you must stop the process later.

```bash
curl -sS http://127.0.0.1:18080/
```

Paste the body into the notes. Confirm the PID file still exists. Do not stop the process yet. The container run should use a different host port so both can answer at the same time.

9. Write `Dockerfile`. `FROM` starts from `python:3.12-slim`. `WORKDIR` sets `/app`. `COPY` adds `index.html`. `EXPOSE 8080` documents the listen port. It does not publish a host port. `CMD` starts the process that actually listens.

```dockerfile
FROM python:3.12-slim

WORKDIR /app

COPY index.html .

EXPOSE 8080

CMD ["python", "-m", "http.server", "8080"]
```

Save that file as `Dockerfile` in `$LAB_DIR`. Confirm the files you care about exist:

```bash
ls
cat Dockerfile
```

You should see `Dockerfile`, `index.html`, `day-23-compute-lab.md`, and the PID file.

10. Check Docker. If the command fails, write `docker missing — local process and decision table are the lab` in the notes. Skip every `docker` step through the break. Go to Verify. Do not invent a replacement.

```bash
command -v docker
docker version
```

11. If Docker is present, build the image. The tag `day23-lab:1.0.0` is a human-readable name. Docker may pull `python:3.12-slim` on the first build. Wait for the build to finish.

```bash
docker build -t day23-lab:1.0.0 .
```

12. Run a container from that image. `-d` runs it in the background. `--name day23-lab` sets a stable name. `-p 18081:8080` publishes host port `18081` to container port `8080`. That host port is not the local process port. `EXPOSE` does not create the mapping. `-p` does.

```bash
docker run -d --name day23-lab -p 18081:8080 day23-lab:1.0.0
```

If host port `18081` is already in use, stop. Choose `18083` instead and use `-p 18083:8080` in every later `docker run` and `curl`. Write the host port you used.

13. Prove the container path. List the container. Read the logs. Inspect the command and the port mapping. Then curl the published host port. You should see `day-23-lab` again. The body matches the local process. The execution model is different.

```bash
docker ps
docker logs day23-lab
docker inspect day23-lab
curl -sS http://127.0.0.1:18081/
```

Copy the `CMD`, the published port, and both `curl` bodies into the notes. Write one sentence: the local process is the VM-style runtime you operate; the container is the image you would hand to App Service, Container Apps, or AKS.

---

## Verify

Read `day-23-compute-lab.md` as if you are on a call. You should name a compute choice for the Spring Boot API and say why the simpler option was not enough, or why it was enough.

Check these points:

- The table has rows for patching, the Java process, deploy, rollback, scale, Azure’s job, your job, and fit for a Spring Boot API.
- The VM column says you patch the guest OS. The App Service column says Azure patches the platform.
- Container Apps hides the Kubernetes API. AKS still gives you node pools and Deployments.
- You picked App Service or Container Apps for this API unless you wrote a real OS or Kubernetes requirement.
- `curl` to the local process returned `day-23-lab`. `cat http-server.pid` still shows a PID.
- If Docker ran, `docker ps` shows `day23-lab`, `docker logs` shows the HTTP server on port `8080`, and `curl` to the published host port returned `day-23-lab`.
- You did not treat `EXPOSE 8080` as a host publish. `-p` created the mapping.
- You did not create Azure VMs, App Service plans, Container Apps, or AKS. Cost stays at ₹0.

If a table cell is only a heading, fill it before you stop. A comparison with empty cells is not a design. If the local `curl` fails, read `http-server.log` and confirm the PID is still running.

---

## Break and fix

If Docker is missing, do this break on paper. Keep `EXPOSE 8080` in the Dockerfile. Write that `CMD` will listen on `9090` while `-p 18081:8080` still maps host `18081` to container `8080`. Write that `curl` to `18081` would fail because nothing listens on container port `8080`. Then put `CMD` back to `8080` in the notes. Go to Clean up and stop the local process.

If Docker is present, the working container still holds port `18081`. Stop it and remove it before you run a broken one with the same name.

```bash
docker stop day23-lab
docker rm day23-lab
docker ps -a
```

`docker ps -a` should no longer list `day23-lab`. The image `day23-lab:1.0.0` should still exist. The local Python process should still be running on `18080`.

Now break `CMD`. Keep `EXPOSE 8080`. Change only the listen port in `CMD` to `9090`. The process will listen on `9090`. You will still publish `18081:8080`.

```dockerfile
FROM python:3.12-slim

WORKDIR /app

COPY index.html .

EXPOSE 8080

CMD ["python", "-m", "http.server", "9090"]
```

Rebuild the same tag, then run it the same way as before:

```bash
docker build -t day23-lab:1.0.0 .
docker run -d --name day23-lab -p 18081:8080 day23-lab:1.0.0
docker ps
docker logs day23-lab
docker inspect day23-lab
curl -sS http://127.0.0.1:18081/
```

`curl` should fail. Nothing listens on container port `8080`. `docker logs` should show the server on port `9090`. `docker inspect` should show `CMD` with `9090`. `EXPOSE 8080` did not move the process onto `8080`. `-p 18081:8080` only maps the host port to container port `8080`.

Record the failed `curl`, the log line, and the `CMD` in the notes. That is the evidence.

Fix the Dockerfile. Put `CMD` back to port `8080`. `EXPOSE` and `-p` must match the port the process listens on.

```dockerfile
FROM python:3.12-slim

WORKDIR /app

COPY index.html .

EXPOSE 8080

CMD ["python", "-m", "http.server", "8080"]
```

Replace the broken container, rebuild, and run again:

```bash
docker stop day23-lab
docker rm day23-lab
docker build -t day23-lab:1.0.0 .
docker run -d --name day23-lab -p 18081:8080 day23-lab:1.0.0
docker logs day23-lab
curl -sS http://127.0.0.1:18081/
```

`curl` should print `day-23-lab` again. Curl the local process too. It should still return `day-23-lab` on `18080`. Write one sentence in the notes: `CMD` sets the listen port, `EXPOSE` documents it, and `-p` publishes it. The local process has no `EXPOSE`. You chose the port when you started `python3`.

Do not skip the investigation. Look at logs and inspect before you change the file. Restarting the broken container will not fix a wrong `CMD`.

---

## Clean up

Stop the local Python process first. Use the PID you saved. Then confirm the port no longer answers.

```bash
kill "$(cat http-server.pid)"
sleep 1
curl -sS http://127.0.0.1:18080/ || true
```

The `curl` should fail. If the process is still running, check the PID and stop it again. Do not leave a Python HTTP server on this machine.

If Docker ran, stop and remove the lab container. Then remove the lab image.

```bash
docker stop day23-lab
docker rm day23-lab
docker ps -a
docker image rm day23-lab:1.0.0
docker image ls
```

`docker ps -a` must not show `day23-lab`. `docker image ls` must not show `day23-lab:1.0.0`. If this lab pulled `python:3.12-slim` and you do not need that base image, remove it too:

```bash
docker image rm python:3.12-slim
```

If Docker refuses because another image still uses that base, leave it. Do not run a broad prune. Remove only what this lab created.

Leave the lab directory and delete it:

```bash
cd /tmp
rm -rf "$LAB_DIR"
```

If you copied notes you want to keep, move `day-23-compute-lab.md` out before `rm -rf`. You created no Azure or AWS resources, so there is no resource group, App Service plan, Container Apps environment, or AKS cluster to delete. Do not run `az group delete` as cleanup. You never created that group.

---

## Interview story

I treat Azure compute as a choice about operational responsibility, not as a list of product names. For a standard Spring Boot API I fill a table across VM, App Service, Container Apps, and AKS. I ask who patches the OS, how I deploy, how I roll back, and what requirement removes the simpler option. I then run the same tiny HTTP app two ways. `python3 -m http.server` is the process I would operate on a VM. `docker run` is the image I would hand to App Service, Container Apps, or AKS. When `CMD` listens on `9090` and I still publish `8080`, `curl` fails. `EXPOSE` did not open that port. `docker logs` shows the mismatch. I fix `CMD`, rebuild, and stop both the process and the container so the lab leaves nothing running.
