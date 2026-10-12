# Day 13 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 13 teaches a container as an isolated process started from a layered image. This lab builds a small HTTP image from `python:3.12-slim`. You run the container, read `docker ps`, `docker logs`, and `docker inspect`, then you stop and remove it. You also break the listen port on purpose, watch `curl` fail, and fix `CMD`.

Work only in a temporary directory. Do not build inside this course repository. `python:3.12-slim` and `nginx:alpine` are real images. This lab uses `python:3.12-slim` so you can set the listen port in `CMD`.

---

## Goal

Create one image and one container. Prove that the process inside the container serves HTTP on port `8080`. Then change `CMD` so the process listens on `9090` while you still publish host port `8080` to container port `8080`. `curl` should fail. `docker logs` and `docker inspect` should show the mismatch. Restore `CMD`, rebuild, and confirm `curl` works.

When you finish, you can explain image versus container, `EXPOSE` versus `-p`, and why `CMD` must match the port you publish. You also remove every container and image this lab created.

Time box: 45 to 75 minutes. Cost stays at ₹0. Stop when the working `curl` succeeds, the broken `curl` is in your notes, and cleanup has removed the lab container and the lab image.

---

## What you need

You need a shell, `curl`, and Docker Engine. Check them first:

```bash
command -v curl
command -v docker
docker version
```

If `docker` is missing, still create the Dockerfile and `index.html` below. Write the same commands into your notes. Run them when Docker is on your `PATH`. Do not invent flags. Do not skip the files.

You do not need Azure, AWS, Kubernetes, Maven, or a Spring Boot project. `python -m http.server` is part of the Python image. The image name `python:3.12-slim` is real. `nginx:alpine` is also real and listens on port `80`. Do not switch images in the middle of this lab.

Create the lab under `/tmp`, not under this course clone. Docker writes image layers on the host. You must be able to delete the directory and the lab image when you clean up.

Keep a notes file named `day-13-docker-lab.md` in the same temp directory. Record command output, the failed `curl`, and the `CMD` you saw in `docker inspect`. Do not paste secrets. This lab should not create any.

---

## Steps

1. Create a throwaway directory and enter it. Use a unique folder name so you do not collide with another lab. Confirm the path is under `/tmp`.

```bash
LAB_DIR="/tmp/day-13-docker-lab-$$"
mkdir -p "$LAB_DIR"
cd "$LAB_DIR"
pwd
```

2. Write `index.html`. This is the file the HTTP server will return. The body must be easy to recognize in `curl`.

```bash
printf 'day-13-lab\n' > index.html
cat index.html
```

3. Write `Dockerfile`. `FROM` starts from `python:3.12-slim`. `WORKDIR` sets `/app`. `COPY` adds `index.html`. `EXPOSE 8080` documents the listen port. It does not publish a host port. `CMD` starts the process that actually listens.

```dockerfile
FROM python:3.12-slim

WORKDIR /app

COPY index.html .

EXPOSE 8080

CMD ["python", "-m", "http.server", "8080"]
```

Save that file as `Dockerfile` in `$LAB_DIR`. Confirm the four files you care about exist:

```bash
ls
cat Dockerfile
```

You should see `Dockerfile` and `index.html`.

4. Build the image. The tag `day13-lab:1.0.0` is a human-readable name. Docker may pull `python:3.12-slim` on the first build. Wait for the build to finish.

```bash
docker build -t day13-lab:1.0.0 .
```

If `docker` is missing, copy this command into the notes and continue writing files. Do not replace it with a made-up tool.

5. Confirm the image exists on this machine.

```bash
docker image ls
```

You should see `day13-lab` with tag `1.0.0`. Record the image ID in the notes.

6. Run a container from that image. `-d` runs it in the background. `--name day13-lab` sets a stable name. `-p 8080:8080` publishes host port `8080` to container port `8080`. `EXPOSE` does not do that job.

```bash
docker run -d --name day13-lab -p 8080:8080 day13-lab:1.0.0
```

If host port `8080` is already in use, stop. Choose `18080` instead and use `-p 18080:8080` in every later `docker run` and `curl`. Write the host port you used.

7. List running containers. The container named `day13-lab` should be up while the Python process runs.

```bash
docker ps
```

8. Read the process output. You should see that `http.server` is serving on port `8080`.

```bash
docker logs day13-lab
```

9. Inspect the container. Find the command, the image, and the port mapping. `CMD` should show `python -m http.server 8080`. The published port should map host `8080` to container `8080`.

```bash
docker inspect day13-lab
```

Copy those fields into the notes. Do not paste unrelated host configuration.

10. Request the page from the host. You should see `day-13-lab`.

```bash
curl -sS http://127.0.0.1:8080/
```

If you published `18080`, curl `http://127.0.0.1:18080/` instead. Paste the body into the notes. This is the working baseline.

---

## Verify

Read the notes as if you are on a call. You should name the image, the container, the published port, and the process command.

Check these points:

- `docker image ls` shows `day13-lab:1.0.0`.
- `docker ps` shows `day13-lab` while the server runs.
- `docker logs day13-lab` shows the HTTP server on port `8080`.
- `docker inspect day13-lab` shows `CMD` listening on `8080` and a host mapping to container port `8080`.
- `curl` returned `day-13-lab`.
- You did not treat `EXPOSE 8080` as a host publish. `-p` created the mapping.

If `curl` fails before the break step, read `docker ps` and `docker logs` again. Confirm the container is running and that you curled the host port you published.

---

## Break and fix

The working container still holds port `8080`. Stop it and remove it before you run a broken one with the same name.

```bash
docker stop day13-lab
docker rm day13-lab
docker ps -a
```

`docker ps -a` should no longer list `day13-lab`. The image `day13-lab:1.0.0` should still exist.

Now break `CMD`. Keep `EXPOSE 8080`. Change only the listen port in `CMD` to `9090`. The process will listen on `9090`. You will still publish `8080:8080`.

```dockerfile
FROM python:3.12-slim

WORKDIR /app

COPY index.html .

EXPOSE 8080

CMD ["python", "-m", "http.server", "9090"]
```

Rebuild the same tag, then run it the same way as before:

```bash
docker build -t day13-lab:1.0.0 .
docker run -d --name day13-lab -p 8080:8080 day13-lab:1.0.0
docker ps
docker logs day13-lab
docker inspect day13-lab
curl -sS http://127.0.0.1:8080/
```

`curl` should fail. Nothing listens on container port `8080`. `docker logs` should show the server on port `9090`. `docker inspect` should show `CMD` with `9090`. `EXPOSE 8080` did not move the process onto `8080`. `-p 8080:8080` only maps the host port to container port `8080`.

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
docker stop day13-lab
docker rm day13-lab
docker build -t day13-lab:1.0.0 .
docker run -d --name day13-lab -p 8080:8080 day13-lab:1.0.0
docker logs day13-lab
curl -sS http://127.0.0.1:8080/
```

`curl` should print `day-13-lab` again. Write one sentence in the notes: `CMD` sets the listen port, `EXPOSE` documents it, and `-p` publishes it.

Do not skip the investigation. Look at logs and inspect before you change the file. Restarting the broken container will not fix a wrong `CMD`.

---

## Clean up

Stop and remove the lab container. Then remove the lab image. Run these commands from any directory. They use the container name and image tag from this lab.

```bash
docker stop day13-lab
docker rm day13-lab
docker ps -a
docker image rm day13-lab:1.0.0
docker image ls
```

`docker ps -a` must not show `day13-lab`. `docker image ls` must not show `day13-lab:1.0.0`. If this lab pulled `python:3.12-slim` and you do not need that base image, remove it too:

```bash
docker image rm python:3.12-slim
```

If Docker refuses because another image still uses that base, leave it. Do not run a broad prune. Remove only what this lab created.

Leave the lab directory and delete it:

```bash
cd /tmp
rm -rf "$LAB_DIR"
```

If you copied notes you want to keep, move `day-13-docker-lab.md` out before `rm -rf`. You created no Azure or AWS resources, so there is no resource group, cluster, or registry to delete.

---

## Interview story

I treat a container as an isolated process started from an image, not as a small virtual machine. I write a Dockerfile from `python:3.12-slim`, set `CMD` to `python -m http.server 8080`, and publish that port with `-p 8080:8080`. `EXPOSE` only documents the port. It does not open the host mapping. When `CMD` listens on `9090` and I still publish `8080:8080`, `curl` fails. `docker logs` and `docker inspect` show the mismatch. I fix `CMD`, rebuild, and run the same image tag again. Then I `docker stop`, `docker rm`, and `docker image rm` so the lab leaves no container or image behind.
