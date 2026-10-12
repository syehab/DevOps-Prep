# Day 37 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 37 asks what operational responsibility ShopSphere gained by moving to Kubernetes. This lab makes that shift visible on a laptop. You run one tiny HTTP app as a local Python process, then as a Docker container, then as a Kubernetes Deployment and Service. The image stays the same. What changes is who restarts the process, how traffic finds it, and whether Kubernetes knows the process is ready.

Work in a temporary directory. Do not build or apply manifests inside the DevOps-Prep course repository. Prefer `kind` over `minikube`. If `kind` is missing, still write the Dockerfile and the YAML. Install `kind` from [kind.sigs.k8s.io](https://kind.sigs.k8s.io). Then run the same commands below. Do not invent other cluster tools or flags. Do not create AKS or EKS.

---

## Goal

Serve the same `app.py` three ways. First start it with `python3` on this machine and `curl` `/` and `/health`. Then build `day37-app:1` and run that image with `docker run` if Docker is present. Then load that same image into a local `kind` cluster and apply a Deployment plus a ClusterIP Service.

Leave the first Kubernetes apply without a readiness probe. Record that the Pod becomes Ready as soon as the container is running. Write what Kubernetes added: desired state, a Service, and (after the fix) a probe. Then add a simple HTTP readiness probe on `/health`. When you finish, you can explain the difference between a process you started yourself and a workload Kubernetes reconciles.

Time box: 45 to 75 minutes. Cost stays at ₹0. Stop when local `curl` worked, Docker `curl` worked or Docker is recorded as missing, the Deployment is Ready, the missing-probe risk is in your notes, the probe is applied, and cleanup has removed the lab objects. If this lab created the `kind` cluster, delete that cluster too.

---

## What you need

You need a shell, `curl`, and Python 3. Check them first:

```bash
command -v curl
command -v python3
python3 --version
curl --version
```

Docker Engine is the path into the same image you will run on Kubernetes. Check it next:

```bash
command -v docker
docker version
```

If `docker` is missing, still write `app.py` and the Dockerfile. Run the local Python process. Write the `docker` commands into your notes. Do not invent another container tool.

You also need `kind` and `kubectl` for the Kubernetes half. `kind` runs Kubernetes nodes as Docker containers. `kubectl` talks to the API Server. Check what is already on your `PATH`:

```bash
command -v kind
command -v minikube
command -v kubectl
kind version
kubectl version --client
```

If `kind` is missing, install it from [kind.sigs.k8s.io](https://kind.sigs.k8s.io). Follow that site. Come back and run the same commands in this file. `minikube` is an alternative local cluster. Prefer `kind` for this lab. Do not mix both tools against the same kubeconfig context unless you already know which context is active. Do not use a production cluster.

You do not need Java, Spring Boot, Helm, AKS, or EKS. `app.py` is the stand-in for the ShopSphere API. The image name `python:3.12-slim` is real. Do not switch base images in the middle of this lab.

Create the lab under `/tmp`, not under this course clone. Keep notes in `day-37-k8s-lab.md` in that directory. Record each `curl` body, whether Docker ran, whether this lab created the cluster, what Kubernetes added, and the readiness risk. Do not paste kubeconfig secrets, tokens, or registry passwords.

---

## Steps

1. Create a throwaway directory and enter it. Use a unique folder name so you do not collide with another lab. Confirm the path is under `/tmp`. Stay in this directory for every file you write.

```bash
LAB_DIR="/tmp/day-37-k8s-lab-$$"
mkdir -p "$LAB_DIR"
cd "$LAB_DIR"
pwd
```

Write the date and the path at the top of `day-37-k8s-lab.md`. Write one short paragraph: you will run one HTTP app as a process, as a container, and as a Kubernetes Deployment. You will then say what Kubernetes added that `python3` and `docker run` did not.

2. Write `app.py`. This process listens on `0.0.0.0` and port `8080` unless `PORT` is set. `GET /` and `GET /health` both return HTTP 200 and the body `day-37-app`. Other paths return 404. That `/health` path is the later readiness target. Do not add secrets or personal data.

```python
#!/usr/bin/env python3
import os
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

PORT = int(os.environ.get("PORT", "8080"))
BODY = b"day-37-app\n"


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        path = self.path.split("?", 1)[0]
        if path in ("/", "/health"):
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", str(len(BODY)))
            self.end_headers()
            self.wfile.write(BODY)
            return
        self.send_response(404)
        self.end_headers()

    def log_message(self, fmt, *args):
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))


if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", PORT), Handler)
    sys.stderr.write("listening on 0.0.0.0:%s\n" % PORT)
    server.serve_forever()
```

3. Start the same app as a local Python process. Bind host port `18080` so you do not collide with another lab. Run it in the background. Record the process ID.

```bash
PORT=18080 python3 app.py >/tmp/day37-python.log 2>&1 &
PY_PID=$!
echo "$PY_PID"
sleep 1
curl -sS -D - http://127.0.0.1:18080/
curl -sS -D - http://127.0.0.1:18080/health
```

Both responses should be HTTP 200 with body `day-37-app`. Copy the bodies into your notes. This is the managed-container analogue: you started the process, you own the port, and nothing restarts it if it dies.

Stop the process before you reuse the host port:

```bash
kill "$PY_PID"
wait "$PY_PID" || true
```

4. Write `Dockerfile`. `FROM` starts from `python:3.12-slim`. `WORKDIR` sets `/app`. `COPY` adds `app.py`. `EXPOSE 8080` documents the listen port. It does not publish a host port. `CMD` starts the same process you just ran.

```dockerfile
FROM python:3.12-slim

WORKDIR /app

COPY app.py .

EXPOSE 8080

CMD ["python3", "app.py"]
```

Confirm the files exist:

```bash
ls
cat Dockerfile
```

5. Build the image and run it with Docker if Docker is on your `PATH`. Tag it `day37-app:1`. Publish host port `18080` to container port `8080`. That is the same app, now isolated in a container.

```bash
docker build -t day37-app:1 .
docker run -d --name day37-app -p 18080:8080 day37-app:1
docker ps
curl -sS -D - http://127.0.0.1:18080/
curl -sS -D - http://127.0.0.1:18080/health
docker logs day37-app
```

Both curls should match the local Python run. Record that the image is `day37-app:1`. This is still a single container you started. Docker does not keep a replica count. Docker does not give the process a stable Service name inside a cluster.

Stop and remove that container so port `18080` is free. Keep the image. Kubernetes will use it next.

```bash
docker stop day37-app
docker rm day37-app
```

If `docker` is missing, write the build and run commands into your notes. Continue from the YAML. Do not skip writing the Dockerfile.

6. Decide whether you need a new cluster. List `kind` clusters if `kind` is installed. If you already have a disposable local cluster and `kubectl get nodes` works, you may use it. Record the context. If you have no cluster, create one named `day37`.

```bash
kind get clusters
kubectl config current-context
```

Create a cluster only when you need one:

```bash
kind create cluster --name day37
```

`kind create cluster --name day37` writes kubeconfig for that cluster. It does not deploy your app. Wait until the command exits. Then confirm the API answers:

```bash
kubectl cluster-info
kubectl get nodes
kubectl get pods -A
```

Write `CREATED_KIND=yes` in your notes if you ran `kind create cluster --name day37`. Write `CREATED_KIND=no` if you reused an existing cluster. Cleanup uses that note.

If you use `minikube` instead, start it only when you have no cluster:

```bash
minikube start
```

Write `CREATED_MINIKUBE=yes` only if you ran that start for this lab.

7. Load the same image into the cluster. `kind` nodes do not see host images until you load them. `--name day37` matches the cluster created above. If you reused a different `kind` cluster, pass that cluster name instead.

```bash
kind load docker-image day37-app:1 --name day37
```

If you use `minikube` instead of `kind`:

```bash
minikube image load day37-app:1
```

If you have no cluster yet, still write `deployment.yaml` and `service.yaml` below. Those commands do not change. Create the cluster when you can, then load the image and apply.

8. Write `deployment.yaml`. This Deployment declares two replicas of `day37-app:1`. The Pod template label is `app: day37-app`. The container listens on port `8080`. `imagePullPolicy: Never` tells Kubernetes not to pull from a registry. The image is already on the node from the load step. This first apply has no readiness probe. That omission is intentional.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: day37-app
  namespace: day37
spec:
  replicas: 2
  selector:
    matchLabels:
      app: day37-app
  template:
    metadata:
      labels:
        app: day37-app
    spec:
      containers:
        - name: app
          image: day37-app:1
          imagePullPolicy: Never
          ports:
            - containerPort: 8080
```

9. Write `service.yaml`. This Service is ClusterIP. ClusterIP is the default Service type and stays inside the cluster. The selector must match the Pod label `app: day37-app`. Port `8080` on the Service forwards to container port `8080`.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: day37-app
  namespace: day37
spec:
  type: ClusterIP
  selector:
    app: day37-app
  ports:
    - port: 8080
      targetPort: 8080
```

10. Create the namespace, then apply both objects. `kubectl apply` sends desired state to the API Server.

```bash
kubectl create namespace day37
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
```

11. Inspect the workload. You should see a Deployment, a ReplicaSet, two Pods, and a ClusterIP Service. Record the Pod names, whether each Pod is Ready, and whether endpoints list addresses.

```bash
kubectl -n day37 get deployment day37-app
kubectl -n day37 get replicasets
kubectl -n day37 get pods -l app=day37-app -o wide
kubectl -n day37 get service day37-app
kubectl -n day37 describe service day37-app
kubectl -n day37 get endpoints day37-app
```

The Pods should become Ready even though you did not set a probe. Kubernetes treats a running container as ready when no readiness probe exists. Copy that observation into your notes. That is the risk you will fix later.

12. Prove the same HTTP body through the Service. `kubectl port-forward` publishes Service port `8080` on `127.0.0.1:18080`. Run it in the background, curl, then stop the forward.

```bash
kubectl -n day37 port-forward svc/day37-app 18080:8080 >/tmp/day37-pf.log 2>&1 &
PF_PID=$!
sleep 2
curl -sS -D - http://127.0.0.1:18080/
curl -sS -D - http://127.0.0.1:18080/health
kill "$PF_PID"
wait "$PF_PID" || true
```

The body should still be `day-37-app`. This is the same image you built. Kubernetes did not change the application. It changed how the application is kept running and how traffic finds it.

13. Write a short paragraph in `day-37-k8s-lab.md` titled `What Kubernetes added`. Cover these three points in your own words. Desired state: the Deployment asks for two replicas, and a controller keeps that count. Service: clients use `day37-app` and the selector, not a Pod IP that can change. Probes: you have not added one yet, so Ready means the container process is running, not that `/health` passed. Compare that with `python3` and `docker run`, where you started one process and nothing reconciled it.

---

## Verify

Read the notes as if you are on a call. You should name the image tag, the replica count, and the three runtimes you used.

Check these points:

- Local `curl` to `http://127.0.0.1:18080/` returned `day-37-app`.
- `docker run` returned the same body, or you recorded that Docker was missing and you still wrote the Dockerfile.
- `kubectl -n day37 get deployment day37-app` shows `2/2` after apply.
- `kubectl -n day37 get endpoints day37-app` lists addresses while the selector matches.
- The first Deployment YAML has no `readinessProbe`. Your notes say Ready was true without that probe.
- The notes paragraph names desired state, Service, and probes.

If a Pod stays Pending, run `kubectl -n day37 describe pod <pending-pod>` and read scheduling events. Pending is not CrashLoopBackOff. If the events say the image was not found, run the `kind load docker-image` step again and confirm `imagePullPolicy` is `Never`. If you have no cluster, stop after the YAML exists and the commands are in your notes. Create the cluster, then continue from the load step. Do not invent a fake status output.

---

## Break and fix

The first apply omitted the readiness probe on purpose. That is the break. A running process is not necessarily ready to receive traffic. ShopSphere should not take requests until `/health` succeeds. Without a probe, Kubernetes adds the Pod to Service endpoints as soon as the container starts. A slow or broken process still receives traffic.

1. Record the risk in your notes before you change YAML. Write two sentences. Sentence one: Ready was true with no probe, so endpoints included the Pods because the container was running. Sentence two: during a real ShopSphere start, that would send users to a JVM that is still warming, or to a process that cannot answer `/actuator/health`.

2. Add a simple HTTP readiness probe to `deployment.yaml`. Keep the same image, labels, and replica count. Probe `GET /health` on port `8080`. `httpGet` is the probe type from the lesson. Do not add a liveness probe in this lab. Liveness restarts the container. Readiness only controls traffic.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: day37-app
  namespace: day37
spec:
  replicas: 2
  selector:
    matchLabels:
      app: day37-app
  template:
    metadata:
      labels:
        app: day37-app
    spec:
      containers:
        - name: app
          image: day37-app:1
          imagePullPolicy: Never
          ports:
            - containerPort: 8080
          readinessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 1
            periodSeconds: 5
```

3. Apply the fixed Deployment. Wait until both replicas are Ready. Confirm the probe appears in `describe` and that endpoints still list addresses.

```bash
kubectl apply -f deployment.yaml
kubectl -n day37 rollout status deployment/day37-app
kubectl -n day37 get pods -l app=day37-app
kubectl -n day37 describe pod -l app=day37-app
kubectl -n day37 get endpoints day37-app
```

`rollout status` should succeed. `describe` should show a readiness probe against `/health`. Endpoints should still have addresses because `/health` returns 200. Record that Ready now means the probe passed, not only that the process exists.

4. Optional extra check if you still have time. Change the probe path to `/missing` and apply. `/missing` returns 404, so Ready should become False and endpoints should empty while the Pods stay Running. Restore `/health` and apply again. Do not leave `/missing` applied.

```bash
kubectl -n day37 get pods -l app=day37-app
kubectl -n day37 get endpoints day37-app
```

That optional check is the Part 28 drill in miniature: process running, Ready false, Service has no backends. Restore `/health` before cleanup.

Do not skip the written risk. The lesson rule is that a running container is not the same as a ready application. The probe is how Kubernetes learns the difference.

---

## Clean up

Stop any leftover port-forward or Python process. Then delete the lab namespace. Deleting `day37` removes the Deployment, ReplicaSet, Pods, and Service in that namespace.

```bash
kill "$PF_PID" 2>/dev/null || true
kubectl delete namespace day37
```

Confirm they are gone:

```bash
kubectl get namespace day37
kubectl get deployment day37-app -n day37
```

Those gets should report that the namespace or resources were not found. Do not delete shared cluster resources that belong to other workloads.

If your notes say `CREATED_KIND=yes`, delete the cluster you created. This removes the `kind` nodes for `day37`.

```bash
kind delete cluster --name day37
```

If your notes say `CREATED_MINIKUBE=yes`, stop and delete that profile only when you created it for this lab:

```bash
minikube delete
```

If your notes say `CREATED_KIND=no` and `CREATED_MINIKUBE=no`, do not delete the cluster. You reused a cluster that you did not create for this lab.

Remove the lab image from Docker if you built it:

```bash
docker rmi day37-app:1
```

Leave the lab directory and remove it:

```bash
cd /tmp
rm -rf "$LAB_DIR"
```

If you want to keep notes, copy `day-37-k8s-lab.md` out before `rm -rf`. You created no Azure or AWS resources, so there is no AKS, EKS, or resource group to delete.

---

## Interview story

I treat a Kubernetes migration as a responsibility shift, not as a new image. I run the same tiny HTTP app with `python3`, then with `docker run`, then as a Deployment and Service on `kind`. The body does not change. Kubernetes adds desired replica count, a Service that selects Pods by label, and probes that decide who receives traffic. I ship the first Deployment without a readiness probe so Ready means only that the container started. That is unsafe for ShopSphere. I add `httpGet` on `/health` and then Ready means the application answered. EKS or AKS would still leave me owning that workload design.
