# Day 13 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 13 teaches a container as an isolated process started from a layered image. The old lab built a one-stage `python:3.12-slim` HTTP server in `/tmp`. This lab lands the **ShopSphere catalog image** in your product repo: a **multi-stage, non-root Dockerfile**, a size comparison against a fat base, and a **Trivy** scan. Day 23 is the harder sibling. It bakes a golden image or publishes the same digest to Azure Container Apps.

Work in **your ShopSphere repository**. Copy [../capstone/shopsphere-starter/](../capstone/shopsphere-starter/) first if that repo does not exist yet. The starter `app/Dockerfile` is a single-stage non-root file. You replace it today.

---

## Goal

Rewrite `app/Dockerfile` as a multi-stage image. The runtime stage runs as UID `10001`. The process listens on `0.0.0.0:8080`, not `127.0.0.1`. Build the image. Record its size. Build a fat `python:3.12` variant and record that size too. Scan the slim image with Trivy (or `trivy fs` if Docker is missing).

When you finish, you can explain image versus container, why `USER` matters, why `EXPOSE` is not `-p`, and why a listen address of `127.0.0.1` is a silent production failure inside a container.

Time box: 60 to 90 minutes.

---

## Capstone stage

| Path in ShopSphere | What it adds |
|:--|:--|
| `app/Dockerfile` | Multi-stage, non-root catalog image |
| `app/main.py` | `HOST = "0.0.0.0"` so the container is reachable |
| `docs/day-13-image.md` | Size table, Trivy summary, user ID |

Do not push to ACR today unless you will delete the repository the same session. Day 19 adds Cosign. Day 23 publishes the digest.

---

## What you need

You need a shell, Python 3.12, and a text editor.

```bash
python3 --version
command -v docker
docker version
command -v trivy
```

Docker Engine 27+ is the preferred path. Trivy 0.58.1 (or current 0.58+) scans the image. If Docker is missing, still write the Dockerfile and the `HOST` change. Run `python3 app/main.py` on the host. Run `trivy fs app` if Trivy is installed. Do not invent a container runtime.

You do not need Azure, AWS, Kubernetes, or a paid registry.

---

## Cost

| Path | Estimated USD | Why |
|:--|:--|:--|
| Local Docker build + Trivy + Python | **0.00** | Laptop CPU and a public base-image pull |
| Push to Azure Container Registry | **0.05–0.40** | Storage and operations. Delete the repo after the session. |

Do not write "cost stays at INR 0" if you pushed to ACR. A leftover registry is cheap. Say so in the notes if you keep it on purpose.

---

## Steps

1. Open ShopSphere. Confirm you are not inside DevOps-Prep.

```bash
pwd
git rev-parse --show-toplevel
ls app/Dockerfile app/main.py app/requirements.txt
mkdir -p docs
```

The starter Dockerfile already has `USER 10001`. It is still one stage. `app/main.py` binds `HOST = "127.0.0.1"`. That works on your laptop. It does **not** work when another container or the host curls a published port.

2. Fix the listen address. In `app/main.py`, change only the host constant.

```python
HOST = "0.0.0.0"
PORT = 8080
```

`0.0.0.0` means every interface inside the container. The process still serves `/health`, `/products`, and `/metrics`. Run the starter check on the host. `app/test_api.py` is a script, not a `unittest` module. It starts a short-lived server and curls `/health` and `/products`.

```bash
python3 app/test_api.py
```

Expected: `app/test_api.py: ok`. The script opens `http://HOST:PORT`. `HOST = "0.0.0.0"` still answers on this machine.

3. Prove the bind on the host. Start the API. In a second terminal, curl it.

```bash
python3 app/main.py
```

```bash
curl -sS http://127.0.0.1:8080/health
curl -sS http://127.0.0.1:8080/products
curl -sS http://127.0.0.1:8080/metrics
```

Expected: `{"status": "ok"}`, a product list, and `shopsphere_up 1`. Stop the process with Ctrl+C.

This Python path was executed on Python 3.12.3 in the authoring environment after the `HOST` change.

4. Replace `app/Dockerfile`. Multi-stage even when `requirements.txt` is empty. The builder is the install step. The runtime is the process you ship.

```dockerfile
# syntax=docker/dockerfile:1.7
FROM python:3.12-slim AS builder
WORKDIR /build
COPY requirements.txt .
RUN python -m pip install --upgrade pip \
 && python -m pip install --prefix=/install --no-cache-dir -r requirements.txt

FROM python:3.12-slim
RUN useradd --create-home --uid 10001 shopsphere
COPY --from=builder /install /usr/local
WORKDIR /app
COPY main.py test_api.py requirements.txt ./
USER 10001
EXPOSE 8080
CMD ["python", "main.py"]
```

`USER 10001` is the numeric UID. Kubernetes `runAsNonRoot` accepts it. `EXPOSE 8080` documents the port. It does not publish a host port. `-p` does that.

Write `app/.dockerignore` if it is missing:

```text
__pycache__/
*.pyc
.pytest_cache/
```

5. Build the slim image. Docker may pull `python:3.12-slim` on the first build.

```bash
docker build -t shopsphere-catalog:1.0.0 -f app/Dockerfile app
docker image ls shopsphere-catalog:1.0.0
docker image inspect shopsphere-catalog:1.0.0 --format '{{.Size}} {{.Config.User}}'
```

Expected `User`: `10001`. Record the size in bytes in `docs/day-13-image.md`.

6. Run the container. Publish host `8080` to container `8080`.

```bash
docker run -d --name shopsphere-catalog -p 8080:8080 shopsphere-catalog:1.0.0
docker ps
docker logs shopsphere-catalog
docker exec shopsphere-catalog id
curl -sS http://127.0.0.1:8080/health
```

Expected logs: `shopsphere listening on http://0.0.0.0:8080`. Expected `id`: `uid=10001(shopsphere)`. Expected curl: `{"status": "ok"}`.

If host port `8080` is in use, use `-p 18080:8080` and curl `18080`. Write the host port you used.

7. Build a fat image so the size comparison is real. Keep it as a local tag only.

```dockerfile
# app/Dockerfile.fat — teaching file, not the ship path
FROM python:3.12
WORKDIR /app
COPY main.py test_api.py requirements.txt ./
CMD ["python", "main.py"]
```

```bash
docker build -t shopsphere-catalog:fat -f app/Dockerfile.fat app
docker image ls shopsphere-catalog
```

Record both sizes. The fat `python:3.12` image is hundreds of megabytes larger. That is why the runtime stage uses `python:3.12-slim`. Commit `Dockerfile.fat` only if you want the teaching file. Prefer to delete it after the notes exist.

8. Scan. Trivy 0.58.1 (or current 0.58+) is the pin in [../capstone/VERSIONS.md](../capstone/VERSIONS.md).

```bash
trivy image --severity HIGH,CRITICAL --exit-code 0 shopsphere-catalog:1.0.0
```

`--exit-code 0` keeps the lab moving when the base image has known CVEs. Record the count. Do not "fix" a Debian CVE by switching to `latest`. Day 19 adds the pipeline gate.

If Docker is missing:

```bash
trivy fs --scanners vuln,secret,misconfig app
```

If Trivy is missing, write both commands in the notes and record `trivy not executed`. Do not invent flags.

9. Optional registry push. Budget first. Use a throwaway ACR only if you will delete it.

```bash
az acr create --resource-group rg-shopsphere-dev --name <uniqueacr> --sku Basic
az acr login --name <uniqueacr>
docker tag shopsphere-catalog:1.0.0 <uniqueacr>.azurecr.io/catalog:1.0.0
docker push <uniqueacr>.azurecr.io/catalog:1.0.0
```

Skip this if you have no Azure account. The local image is enough.

---

## Verify

Read the notes on a call. You should name the two stages, the UID, the listen address, and the size delta.

Check these points:

- `app/Dockerfile` has a `builder` stage and a runtime stage.
- Runtime uses `USER 10001` and `python:3.12-slim`.
- `app/main.py` sets `HOST = "0.0.0.0"`.
- `python3 app/test_api.py` printed `ok`, or you recorded why.
- You recorded slim versus fat sizes, or you recorded `docker missing`.
- Trivy ran against the image or the filesystem, or you recorded `trivy not executed`.
- You did not treat `EXPOSE` as a host publish.
- Files live in ShopSphere, not only under `/tmp`.

---

## Break and fix

Do both failures.

### Failure 1 — listen on localhost inside the container

Put `HOST = "127.0.0.1"` back. Rebuild and run the same `-p 8080:8080`.

```bash
docker stop shopsphere-catalog && docker rm shopsphere-catalog
docker build -t shopsphere-catalog:1.0.0 -f app/Dockerfile app
docker run -d --name shopsphere-catalog -p 8080:8080 shopsphere-catalog:1.0.0
curl -sS --max-time 3 http://127.0.0.1:8080/health || true
docker logs shopsphere-catalog
```

Expected: `curl` fails or times out. Logs still say the process is listening on `127.0.0.1`. The published port maps to the container namespace. Nothing in that namespace accepts connections from the bridge. Diagnose with logs, not with a new NSG.

Restore `HOST = "0.0.0.0"`. Rebuild. Curl again. Expected: `{"status": "ok"}`.

If Docker is missing, bind the host process to `127.0.0.1` and write the same diagnosis. The failure is the listen address, not Docker.

### Failure 2 — image runs as root

Remove `USER 10001` from the runtime stage. Rebuild and run.

```bash
docker exec shopsphere-catalog id
```

Expected: `uid=0(root)`. That is the break. A CVSS in the app now has the container's root. Restore `USER 10001`. Rebuild. `id` must show `10001`.

If Docker is missing, write the `id` you would expect for each file. Keep `USER 10001` in Git.

---

## Stretch

- Add `HEALTHCHECK --interval=10s CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/health')"` so Docker restarts a dead process. Inside the container, `127.0.0.1` is correct for a self-check.
- Pin `python:3.12-slim` by digest. Record the digest in the notes.
- Compare `docker history shopsphere-catalog:1.0.0` to the fat image. Name the layer that disappeared.

---

## Clean up

```bash
docker stop shopsphere-catalog
docker rm shopsphere-catalog
docker image rm shopsphere-catalog:1.0.0 shopsphere-catalog:fat || true
docker image ls
```

`docker ps -a` must not show `shopsphere-catalog`. Keep `python:3.12-slim` if later Days will rebuild. Remove `Dockerfile.fat` if you do not want it in Git.

If you created ACR:

```bash
az acr delete --name <uniqueacr> --yes
```

Confirm the registry is gone. Do not leave a Basic SKU running unused.

Commit `app/Dockerfile`, the `HOST` change, and the notes. Do not commit image tarballs.

---

## Interview story

**Situation:** ShopSphere shipped a single-stage image that still bound HTTP to `127.0.0.1`, so a published port looked healthy in `docker ps` and failed on `curl`. **Task:** Make the catalog image multi-stage, non-root, and reachable, and prove size plus scan before Day 23 publishes it. **Action:** I rewrote `app/Dockerfile` with a builder stage and `python:3.12-slim` runtime, set `USER 10001`, and changed `HOST` to `0.0.0.0`. I compared the slim image to `python:3.12` and scanned with Trivy 0.58. I reproduced the localhost bind and the root user, then restored both. **Result:** I can explain image versus container, why `EXPOSE` is not `-p`, and why Day 23 must bake or promote this digest instead of rebuilding it by hand.

---

## Self-score checklist

- [ ] Dockerfile has two stages and `USER 10001`.
- [ ] `HOST` is `0.0.0.0` and `/health` works.
- [ ] I recorded slim versus fat size, or I recorded `docker missing`.
- [ ] Trivy ran, or I recorded `trivy not executed`.
- [ ] I broke the localhost bind and I used logs to diagnose it.
- [ ] I broke root and I restored `USER 10001`.
- [ ] I removed the lab container and the fat tag.
- [ ] Files live in ShopSphere, not only under `/tmp`.

Count the boxes. 7 or 8 is done.

**Executed:** Python 3.12.3 `python3 app/test_api.py` (`ok`) and `curl /health` plus `/metrics` on the host after `HOST = "0.0.0.0"`. **Not executed:** `docker build`, `docker run`, `trivy image`, ACR push.
