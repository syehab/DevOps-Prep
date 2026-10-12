# Day 27 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 27 teaches AWS compute as a management-responsibility choice. A Spring Boot API can run on EC2, ECS on Fargate, EKS, or Lambda. The JAR or image can stay the same. What you operate changes. This lab records that choice in a decision table. Then you run one tiny HTTP app. If Docker is present, you use `docker run`. If Docker is missing, you use `python3 -m http.server`. Those runtimes stand in for “same workload, different compute abstraction.” You do not create AWS resources.

Work only in a temporary directory that you create for this lab. Do not run the app inside the DevOps-Prep course repository. Do not run `aws ec2 run-instances`, `aws ecs create-service`, `eksctl`, or `aws lambda create-function`.

---

## Goal

Fill one decision table for a standard Spring Boot REST API. Compare EC2, ECS on Fargate, EKS, and Lambda. Record what you manage, what AWS manages, how you scale, and how you roll back. Then serve the same `index.html` with `docker run` if Docker exists. If Docker is missing, serve it with `python3 -m http.server`.

After the working `curl` succeeds, break the design on paper. Keep four healthy API replicas in the notes. Scale them to twelve while the database connection limit stays at 100. Document the next bottleneck. Write what you would inspect and what you would stop doing. Do not create an RDS instance to prove it.

Time box: 45 to 75 minutes. Cost stays at ₹0. Stop when the table is complete, one runtime has a successful `curl`, the paper bottleneck note is filled, and cleanup has stopped the process or removed the lab container.

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

If `docker` is missing, still write the Dockerfile below. Write the `docker` commands into your notes. Run the local Python process. Do not invent another container tool. Do not create an EC2 instance, an ECS cluster, an EKS cluster, or a Lambda function to compensate.

You do not need Java, Maven, Spring Boot, or an AWS account. `python3 -m http.server` is the stand-in for the API process. The image name `python:3.12-slim` is real. Do not switch images in the middle of this lab.

Create the lab under `/tmp`, not under this course clone. Keep a notes file named `day-27-compute-lab.md` in that temp directory. Record the decision table, the successful `curl` body, whether Docker ran, and the paper bottleneck. Do not paste secrets. This lab should not create any.

---

## Steps

1. Create a throwaway directory and enter it. Use a unique folder name so you do not collide with another lab. Confirm the path is under `/tmp`.

```bash
LAB_DIR="/tmp/day-27-compute-lab-$$"
mkdir -p "$LAB_DIR"
cd "$LAB_DIR"
pwd
```

2. Create the notes file. Put the date at the top. Write one short paragraph: you will choose compute for a Spring Boot API on paper. You will run a tiny HTTP app with `docker run` if Docker is already on this machine. If Docker is missing, you will run the same file with `python3 -m http.server`. You will not launch EC2.

```bash
touch day-27-compute-lab.md
ls
```

3. Write the workload sentence before the table. The application is a standard Spring Boot REST API with conventional HTTP traffic. It talks to PostgreSQL on RDS. It does not need OS-level agents. It does not need custom Kubernetes controllers. It is not a short S3-triggered function. Name that workload in the notes. Do not change it later to force EKS or Lambda.

Write at least one short paragraph. Say that the JAR or image can stay the same across EC2, ECS on Fargate, and EKS. Say that operational responsibility is what changes. Say that Lambda is a different execution model, not a drop-in host for a long-lived Spring Boot process. Say that you pick the simplest compute model that meets the requirements.

4. Add the decision table. Copy this block into the notes file. Fill every cell in your own words. Do not leave a cell as a product name only.

```markdown
| Question | EC2 | ECS on Fargate | EKS | Lambda |
|:--|:--|:--|:--|:--|
| Who patches the OS? | | | | |
| Who runs the Java process? | | | | |
| How do you deploy a new version? | | | | |
| How do you roll back? | | | | |
| How does it scale? | | | | |
| What AWS manages | | | | |
| What your team still owns | | | | |
| When this fits a Spring Boot API | | | | |
```

Fill the EC2 column first. You bake an AMI or install Java, run the JAR under `systemd`, patch the guest OS, and own Security Groups and the Auto Scaling Group. AWS owns the hypervisor. One instance restart is not high availability.

Fill ECS on Fargate next. You push an image to ECR. You write a Task Definition and an ECS Service. AWS runs the servers. You still own VPC, subnets, Security Groups, IAM roles, logs, secrets, and scale. You do not patch an EC2 node fleet.

Fill EKS next. AWS manages the Kubernetes control plane. You still own node groups or Fargate, Deployments, Services, probes, IAM, and VPC networking. Write one requirement that would justify EKS over ECS for this API. If you cannot name one, do not pick EKS.

Fill Lambda last. Lambda fits short event-driven work. A continuously available Spring Boot API does not fit that model. Write that you would keep this API on ECS or a similar always-on platform. Do not force the API onto Lambda to complete the table.

5. Write two sentences under the table. For this standard Spring Boot API, ECS on Fargate usually fits. EC2 is justified by OS-level need. EKS is justified by Kubernetes-native need. Lambda is justified by short event execution. “Containers” is not a reason to choose EKS. “More modern” is not a requirement.

6. Write `index.html`. This is the file the HTTP server will return. The body must be easy to recognize in `curl`.

```bash
printf 'day-27-lab\n' > index.html
cat index.html
```

7. Write `Dockerfile`. `FROM` starts from `python:3.12-slim`. `WORKDIR` sets `/app`. `COPY` adds `index.html`. `EXPOSE 8080` documents the listen port. It does not publish a host port. `CMD` starts the process that actually listens.

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

You should see `Dockerfile`, `index.html`, and `day-27-compute-lab.md`.

8. Check Docker. If the command fails, write `docker missing — python http.server is the lab` in the notes. Skip every `docker` step. Go to step 12. Do not invent a replacement. Do not create EC2 because Docker is missing.

```bash
command -v docker
docker version
```

9. If Docker is present, build the image. The tag `day27-lab:1.0.0` is a human-readable name. Docker may pull `python:3.12-slim` on the first build. Wait for the build to finish.

```bash
docker build -t day27-lab:1.0.0 .
```

10. If Docker is present, run a container from that image. `-d` runs it in the background. `--name day27-lab` sets a stable name. `-p 18081:8080` publishes host port `18081` to container port `8080`. `EXPOSE` does not create the mapping. `-p` does. This container stands in for the image you would hand to ECS on Fargate or EKS.

```bash
docker run -d --name day27-lab -p 18081:8080 day27-lab:1.0.0
```

If host port `18081` is already in use, stop. Choose `18083` instead and use `-p 18083:8080` in every later `docker run` and `curl`. Write the host port you used.

11. If Docker is present, prove the container path. List the container. Read the logs. Inspect the command and the port mapping. Then curl the published host port. You should see `day-27-lab`. Copy the `CMD`, the published port, and the `curl` body into the notes. Write one sentence: this image is what ECS or EKS would schedule; you still own the Task Definition or Deployment, the IAM role, and the health check.

```bash
docker ps
docker logs day27-lab
docker inspect day27-lab
curl -sS http://127.0.0.1:18081/
```

Skip step 12 if Docker ran and `curl` returned `day-27-lab`. Go to Verify.

12. If Docker is missing, start the same app as a local Python process. Bind it to port `18080` on this machine. Run it in the background. Record the process ID. This process stands in for the runtime you would operate on EC2. You start it. You own the listen port. You must stop it later.

```bash
python3 -m http.server 18080 --bind 127.0.0.1 > http-server.log 2>&1 &
echo $! > http-server.pid
cat http-server.pid
curl -sS http://127.0.0.1:18080/
```

If port `18080` is already in use, stop. Choose `18082` instead and use that port in `http.server` and in `curl`. Write the port you used. Paste the `curl` body into the notes. Confirm the PID file still exists.

---

## Verify

Read `day-27-compute-lab.md` as if you are on a call. You should name a compute choice for the Spring Boot API and say why the simpler option was not enough, or why it was enough.

Check these points:

- The table has rows for patching, the Java process, deploy, rollback, scale, AWS’s job, your job, and fit for a Spring Boot API.
- The EC2 column says you patch the guest OS. The Fargate column says AWS runs the servers.
- EKS still gives you Kubernetes objects and much of the data plane. Lambda is marked a poor fit for a long-lived Spring Boot process.
- You picked ECS on Fargate for this API unless you wrote a real OS or Kubernetes requirement.
- If Docker ran, `docker ps` shows `day27-lab`, `docker logs` shows the HTTP server on port `8080`, and `curl` to the published host port returned `day-27-lab`.
- If Docker was missing, `curl` to the local process returned `day-27-lab` and `cat http-server.pid` still shows a PID.
- You did not treat `EXPOSE 8080` as a host publish. `-p` created the mapping when Docker ran.
- You did not create EC2 instances, ECS services, EKS clusters, or Lambda functions. Cost stays at ₹0.

If a table cell is only a heading, fill it before you stop. A comparison with empty cells is not a design. If `curl` fails, read `docker logs` or `http-server.log` and confirm the process or container is still running.

---

## Break and fix

Do this break on paper. Keep the running container or Python process as it is. Do not scale a real ECS Service. Do not change RDS. The Day 27 failure drill is that extra API replicas can saturate the database.

Copy this starting state into the notes:

```text
Workload: Spring Boot API → RDS PostgreSQL
API replicas: 4
Pool size per replica: 10
Open database connections: 40
RDS max_connections: 100
API CPU: 25%
Database CPU: 55%
Request latency: rising
```

Now scale the app. Write that desired count moves from 4 to 12 because latency rose. Keep pool size at 10. Keep `max_connections` at 100. Compute the new connection demand: `12 × 10 = 120`. That number is above 100. Write the next bottleneck in one sentence: database connections saturate before API CPU does.

Draw the chain in the notes:

```text
Client
 ↓
API replicas 4 → 12
 ↓
Connection pool 40 → 120
 ↓
RDS max_connections = 100
 ↓
Database saturates
 ↓
Latency worse
```

List at least five places you would inspect before you add more replicas: API CPU, API memory, the connection pool, database CPU, database connections, database I/O, and a downstream API. Write which signal you would trust here. Database connections and database latency are the evidence. API CPU at 25% is not a scale-out signal.

Write the fix on paper. Cap desired count so `replicas × pool size` stays under `max_connections`. Lower the pool, add RDS Proxy, add a cache, or raise database capacity after you measure. Do not keep adding API tasks. That move increases pressure on the dependency.

If Docker ran, leave `day27-lab` running while you write this. If Python ran, leave the PID running. The process or container is not the break. The paper scale-out is the break. The notes are the fix.

Do not skip the investigation. The lesson rule is scale the bottleneck, not the symptom. A healthy compute platform does not prove a healthy application path.

---

## Clean up

If Docker ran, stop and remove the lab container. Then remove the lab image.

```bash
docker stop day27-lab
docker rm day27-lab
docker ps -a
docker image rm day27-lab:1.0.0
docker image ls
```

`docker ps -a` must not show `day27-lab`. `docker image ls` must not show `day27-lab:1.0.0`. If this lab pulled `python:3.12-slim` and you do not need that base image, remove it too:

```bash
docker image rm python:3.12-slim
```

If Docker refuses because another image still uses that base, leave it. Do not run a broad prune. Remove only what this lab created.

If Python ran, stop the local process. Use the PID you saved. Then confirm the port no longer answers.

```bash
kill "$(cat http-server.pid)"
sleep 1
curl -sS http://127.0.0.1:18080/ || true
```

The `curl` should fail. If the process is still running, check the PID and stop it again. Do not leave a Python HTTP server on this machine.

Leave the lab directory and delete it:

```bash
cd /tmp
rm -rf "$LAB_DIR"
```

If you copied notes you want to keep, move `day-27-compute-lab.md` out before `rm -rf`. You created no AWS resources, so there is no instance, cluster, NAT Gateway, or load balancer to delete. Do not run `aws ec2 terminate-instances` as cleanup. You never created that instance. Part 28 in [01-concepts.md](01-concepts.md) remains the cleanup pattern for a real AWS lab. This local lab has nothing in the account.

---

## Interview story

I treat AWS compute as a choice about operational responsibility, not as a list of product names. For a standard Spring Boot API I fill a table across EC2, ECS on Fargate, EKS, and Lambda. I ask who patches the OS, how I deploy, how I roll back, and what requirement removes the simpler option. ECS on Fargate fits this API unless I need OS control or Kubernetes APIs. Lambda is the wrong execution model for a long-lived process. I then run the same tiny HTTP app. `docker run` is the image I would hand to Fargate or EKS. If Docker is missing, `python3 -m http.server` is the process I would operate on EC2. When I scale API replicas from 4 to 12 on paper while the database allows 100 connections, the next bottleneck is the database, not the API CPU. I cap replica count, inspect pools and RDS, and I do not add more tasks until evidence says the API is the constraint.
