# Day 13 — Questions and answers

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Then answer each item below before you open the Answer block. After that, do the lab in [03-implementation.md](03-implementation.md).

Write your own answer first. Open the Answer block only after you try. Keep the original numbering.

---

## 1. What belongs in the Spring Boot image, and what belongs at runtime

**Practice**

Take a Spring Boot application and list what it needs:

```text
Application
Java Runtime
Libraries
Configuration
Certificates / OS capabilities
Network access
Database access
```

Decide which items belong inside the image and which should be supplied at runtime.

<details>
<summary>Answer</summary>

Put the application, Java runtime, and required libraries in the image. Those pieces must stay the same from Dev through Production. Keep OS capabilities that the process always needs in the image as well.

Supply configuration, certificates that change by environment, network access, and database access at runtime. A database URL and secrets are not image contents. The image is the consistent execution unit. Runtime values make that unit fit each environment.

</details>

---

## 2. Compare the process view with `docker run`, `inspect`, `top`, and `exec`

**Practice**

Run:

```bash
docker run -d --name web nginx
docker inspect web
docker top web
```

Then compare the process view inside the container with the host's process view.

Try:

```bash
docker exec web ps
```

Notice that the container sees a different process environment even though the process is ultimately running on the host kernel.

<details>
<summary>Answer</summary>

Run `docker run -d --name web nginx`. Then run `docker inspect web` and `docker top web`. Inspect shows namespaces, mounts, and network settings. `docker top` shows the process on the host.

Run `docker exec web ps`. Inside the container the PID view is different. The process still runs on the host kernel. Namespaces change what the process can see. Treat the container as an isolated process, not as a guest VM.

</details>

---

## 3. Inspect the `nginx` image with `pull`, `image ls`, `inspect`, and `history`

**Practice**

```bash
docker pull nginx
docker image ls
docker image inspect nginx
docker history nginx
```

Look at the image size, layers, default command, and exposed ports.

<details>
<summary>Answer</summary>

Run `docker pull nginx`, then `docker image ls`. Note the size. Run `docker image inspect nginx` and read the default command and exposed ports. Run `docker history nginx` to see layers.

The image is a read-only template. Layers stack from a base toward the application. A container adds a writable layer on top. Do not treat edits inside a running container as a permanent application change.

</details>

---

## 4. Read client, Engine, storage, and runtime from `docker version` and `docker info`

**Practice**

```bash
docker version
docker info
```

Identify the client, Engine/server, storage, runtime, and other information reported by Docker.

<details>
<summary>Answer</summary>

Run `docker version`. You should see a client and a server. Run `docker info`. Find storage, runtime, and Engine details.

The `docker` CLI is the interface. Docker Engine manages images, containers, networks, and volumes. Lower down you will often see containerd and an OCI runtime such as `runc`. Distinguish the developer tool from the runtime that starts the process.

</details>

---

## 5. Follow a container with `ps`, `inspect`, `logs`, `stop`, and `ps -a`

**Practice**

```bash
docker ps
docker inspect web
docker logs web
docker stop web
docker ps -a
```

<details>
<summary>Answer</summary>

After `docker run -d --name web -p 8080:80 nginx`, run `docker ps`. The container should be up while nginx runs. Run `docker inspect web` for configuration and network. Run `docker logs web` for process output.

Run `docker stop web`, then `docker ps -a`. The container exists but is stopped, because the main process is no longer running. `docker run` pulled or reused the image, created the container, configured it, and started PID 1.

</details>

---

## 6. Build a single-stage image and a multi-stage image, then compare

**Practice**

Build both versions and compare them:

```bash
docker build -t myapp:single-1.0.0 -f Dockerfile.single .
docker build -t myapp:multi-1.0.0 -f Dockerfile.multi .
docker image ls
```

Then inspect their layers:

```bash
docker history myapp:single-1.0.0
docker history myapp:multi-1.0.0
```

<details>
<summary>Answer</summary>

Build both:

```bash
docker build -t myapp:single-1.0.0 -f Dockerfile.single .
docker build -t myapp:multi-1.0.0 -f Dockerfile.multi .
docker image ls
docker history myapp:single-1.0.0
docker history myapp:multi-1.0.0
```

The single-stage image keeps Maven, the JDK, and source weight. The multi-stage image copies only the JAR into a JRE stage with `COPY --from=build`. The production image should not contain Maven, because Maven is not needed to run the application.

</details>

---

## 7. Self-test — Why Maven must not sit in the production image

Ask yourself:

> If Maven is not needed to run the application, why should Maven be inside the production image?

<details>
<summary>Answer</summary>

Maven compiles and packages the application. The running process needs a JRE and the JAR. Extra build tools increase image size, scan time, and attack surface.

A multi-stage build keeps Maven in the build stage. The runtime stage receives only `app.jar`. Build dependencies belong in the build stage, not in the production image.

</details>

---

## 8. Observe Docker layer cache by building twice

**Practice**

Build twice:

```bash
docker build -t myapp:cache-test .
docker build -t myapp:cache-test .
```

Look for cached steps in the second build. Then modify `pom.xml` and build again. Observe which layers are rebuilt.

<details>
<summary>Answer</summary>

Run `docker build -t myapp:cache-test .` twice. The second build should reuse unchanged layers. Copy `pom.xml` first, download dependencies, then copy source. A source-only change can reuse the dependency layer.

Change `pom.xml` and build again. That dependency layer must rebuild. Cache follows instruction order and inputs. Put rarely changing files earlier in the Dockerfile.

</details>

---

## 9. Add `.dockerignore` and rebuild

**Practice**

Create the file and rebuild:

```bash
docker build -t myapp:1.0.0 .
```

<details>
<summary>Answer</summary>

Create `.dockerignore` with `.git`, IDE files, `target`, `*.log`, and `.env`. Then run `docker build -t myapp:1.0.0 .`. Docker sends only the remaining build context.

A local `.env` file can hold a password or API key. If it enters the context, `COPY` can bake it into a layer. Use `.dockerignore` and keep secrets out of the image.

</details>

---

## 10. Self-test — Could a local `.env` contain a password?

Then ask:

> Could a developer's local `.env` file contain a password or API key?

This is one reason to use `.dockerignore` and proper secret management together.

<details>
<summary>Answer</summary>

Yes. Developers often put database passwords and API keys in `.env`. If that file is in the build context, the image build can copy it.

Exclude `.env` in `.dockerignore`. Do not `COPY .env` into the image. Supply secrets at runtime through a secret manager, not through image layers.

</details>

---

## 11. Restart keeps identity; remove and recreate makes a new instance

**Practice**

```bash
docker inspect web
docker restart web
docker inspect web
```

Then remove and recreate it:

```bash
docker rm -f web

docker run -d \
  --name web \
  --network appnet \
  nginx
```

Inspect its network information again. The important lesson is:

> Applications should depend on stable names/endpoints, not container instances.

<details>
<summary>Answer</summary>

Run `docker inspect web`, then `docker restart web`, then `docker inspect web` again. Restart keeps the same container and writable layer.

Then run `docker rm -f web` and `docker run -d --name web --network appnet nginx`. Inspect again. The IP can change. Applications must use stable names, not container IPs.

</details>

---

## 12. Keep data after container removal with `docker volume create`

**Practice:**

Create a volume:

```bash
docker volume create appdata
```

Run a container using it:

```bash
docker run -it \
  --name writer \
  -v appdata:/data \
  alpine sh
```

Inside:

```bash
echo "persistent data" > /data/message.txt
exit
```

Remove the container:

```bash
docker rm writer
```

Create another container using the same volume:

```bash
docker run --rm \
  -v appdata:/data \
  alpine cat /data/message.txt
```

The container disappeared, but the data remained because the volume was separate from the container.

<details>
<summary>Answer</summary>

Run `docker volume create appdata`. Start a container with `-v appdata:/data` and write `/data/message.txt`. Remove the container. Start another container with the same volume and read the file.

The container is gone. The data remains because the volume has a separate lifecycle. Put lasting filesystem data on a volume, not in the writable layer.

</details>

---

## 13. Compare `/tmp` on the writable layer with `/data` on a volume

**Practice**

Run:

```bash
docker run -it --name c1 -v appdata:/data alpine sh
```

Create both:

```bash
echo "temporary" > /tmp/temp.txt
echo "persistent" > /data/persistent.txt
```

Remove the container and create another container from the same image with the same volume. Compare `/tmp` with `/data`.

<details>
<summary>Answer</summary>

Run `docker run -it --name c1 -v appdata:/data alpine sh`. Write `temporary` to `/tmp/temp.txt` and `persistent` to `/data/persistent.txt`. Remove the container. Start another with the same image and volume.

`/tmp/temp.txt` is gone, because it lived in the writable layer. `/data/persistent.txt` remains on the volume. Use volumes for data that must survive replacement.

</details>

---

## 14. What `docker inspect` shows when the main process exits

**Practice**

```bash
docker run --name test alpine sh -c "exit 1"
docker ps -a
```

Inspect the result:

```bash
docker inspect test
```

Look for the exit code and reason about what caused the process to terminate.

<details>
<summary>Answer</summary>

Run `docker run --name test alpine sh -c "exit 1"`, then `docker ps -a`. The container is stopped, not running. Run `docker inspect test` and read the exit code.

The container lifecycle follows PID 1. When that process exits, the container stops. A restart can bring a new process. It does not by itself fix the cause of `exit 1`.

</details>

---

## 15. Review a Spring Boot image for production readiness

**Practice**

Review your Spring Boot image:

```text
Startup command
Base image
Image size
Non-root execution
Configuration
Secrets
Logging
Health
Resource usage
Version
Vulnerability scanning
```

<details>
<summary>Answer</summary>

Check the startup command, base image, size, non-root `USER`, configuration, secrets, logs, health, resource usage, version tag, and vulnerability scan. Use a maintained JRE image and a known version such as `myapp:1.0.0`.

Do not bake secrets into the image. Keep runtime configuration outside the image. Production readiness is more than the Dockerfile. Networking, identity, and recovery still matter.

</details>

---

## 16. Trace an image from developer to production through a registry

**Practice**

Conceptually trace:

```text
Developer
   ↓
Git
   ↓
CI Build
   ↓
Docker Image
   ↓
Registry
   ↓
Production Platform
```

<details>
<summary>Answer</summary>

The developer commits to Git. CI builds and tests, then produces a Docker image. The pipeline pushes that image to a registry such as Azure Container Registry or Amazon ECR.

The production platform pulls the same image. The registry is part of the supply chain. Control who can push, who can pull, and how you scan and retain images.

</details>

---

## 17. Tag versus digest with `docker image ls` and `docker image inspect`

**Practice**

```bash
docker image ls
docker image inspect myapp:1.0.0
```

Understand the difference:

```text
Tag
myapp:1.0.0
        ↓
Human-readable reference

Digest
sha256:...
        ↓
Exact image content
```

<details>
<summary>Answer</summary>

Run `docker image ls` and `docker image inspect myapp:1.0.0`. A tag such as `myapp:1.0.0` is a human-readable pointer. A digest such as `sha256:...` identifies exact image content.

`latest` can move to different content. Production should identify the exact image and promote that image. Do not rebuild a new image just to enter Production.

</details>

---

## 18. Choose container or VM isolation for four workloads

**Practice**

Consider:

```text
Spring Boot API
Legacy application requiring a custom OS
Kubernetes worker
Application requiring a different OS kernel
```

For each, explain what isolation and operating-system requirements matter.

<details>
<summary>Answer</summary>

A Spring Boot API fits a container: one process, shared kernel, fast start. A legacy application that needs a custom OS fits a VM with its own guest kernel. A Kubernetes worker is a machine, often a VM, that then runs containers.

An application that needs a different OS kernel needs a VM, because containers share the host kernel. VMs separate operating systems. Containers isolate processes more lightly.

</details>

---

## 19. Find the container runtime in `docker info`

**Practice**

```bash
docker info
```

Identify the runtime information available in your Docker environment and understand the rough relationship:

```text
Docker CLI
    ↓
Docker Engine
    ↓
containerd
    ↓
OCI runtime such as runc
    ↓
Linux kernel
```

<details>
<summary>Answer</summary>

Run `docker info` and read the runtime section. The usual chain is Docker CLI → Docker Engine → containerd → an OCI runtime such as `runc` → Linux kernel.

Kubernetes does not need Docker Engine itself to run application containers. It talks to a compatible runtime. Docker is the developer workflow. The runtime starts the process.

</details>

---

## 20. Self-test — Diagnose a broken application-to-database container path

Use the working application/database setup and introduce one failure at a time.

Break the hostname:

```bash
-e DB_HOST=mysql-wrong
```

Break the port:

```bash
-e DB_PORT=3307
```

Put the application on a different network:

```bash
docker network create isolated
docker run -d \
  --name app \
  --network isolated \
  myapp:1.0.0
```

Then ask:

```text
Can the application resolve the database name?
Are both containers on the same network?
Is the database listening?
Is the port correct?
Are credentials correct?
```

The objective is to diagnose the failure from evidence rather than simply restarting containers.

<details>
<summary>Answer</summary>

Break one thing at a time. A wrong `DB_HOST` fails DNS. A wrong `DB_PORT` fails the TCP port. A different Docker network means the application cannot resolve or reach `mysql`.

Ask, in order: can it resolve the name, are both containers on `appnet`, is MySQL listening, is the port `3306`, and are credentials correct. Diagnose from evidence. Do not only restart containers.

</details>

---

## Part 10 — Integrated Practice

Take a simple Spring Boot application and move through the complete container lifecycle.

---

## 21. Integrated Practice — Container lifecycle from source to `docker run`

Start with source code and build the JAR:

```bash
mvn clean package
```

Create a multi-stage Dockerfile, build the image, and run it:

```bash
docker build -t myapp:1.0.0 .
docker run -d --name myapp -p 8080:8080 myapp:1.0.0
```

<details>
<summary>Answer</summary>

Build the JAR with `mvn clean package`. Write a multi-stage Dockerfile that copies only the JAR into a JRE image. Run `docker build -t myapp:1.0.0 .`. Then run `docker run -d --name myapp -p 8080:8080 myapp:1.0.0`.

Inspect with `docker ps`, `docker logs myapp`, `docker inspect myapp`, and `docker top myapp`. The Git source became a JAR, then an image, then a Java process. `-p 8080:8080` publishes the host port. `EXPOSE` only documents it.

</details>

---

## 22. Integrated Practice — Failure checklist for the running app

Inspect the running workload:

```bash
docker ps
docker logs myapp
docker inspect myapp
docker top myapp
```

Then create a user-defined network and connect an application and database using stable names. Deliberately introduce failures such as a wrong database hostname, wrong port, missing environment variable, or stopped process.

For every failure, ask:

```text
Is the image correct?
Is the process running?
Can the application resolve the endpoint?
Can it reach the network?
Is the port correct?
Is configuration correct?
Is the external dependency healthy?
```

<details>
<summary>Answer</summary>

Create a user-defined network and attach app and database so the app uses the name `mysql`, not a container IP. Then break hostname, port, environment, or the main process.

Ask whether the image is correct and whether the process is running. Then ask whether it can resolve and reach the endpoint, and whether the port, configuration, and dependency are healthy. Walk DNS → network → port → service → authentication.

</details>

---

## 23. Integrated Practice — CI/CD flow that promotes one image

Finally, design the CI/CD flow:

```text
Git Commit
    ↓
Build & Unit Test
    ↓
Multi-stage Docker Build
    ↓
Image Security Scan
    ↓
Push to Registry
    ↓
Deploy Dev
    ↓
Deploy UAT
    ↓
Approval
    ↓
Deploy Prod
    ↓
Observe
    ↓
Rollback / Fix Forward
```

<details>
<summary>Answer</summary>

Git commit leads to build and unit test, then a multi-stage `docker build`, then an image scan, then a push to the registry. Deploy that same image to Dev, then UAT, then Production after approval.

Observe after deploy. Roll back or fix forward from evidence. Do not rebuild for Production. Runtime configuration and secrets change by environment. The image stays `myapp:1.0.0` or its digest.

</details>

---

## 24. Integrated Practice — Explain Git commit to a production container

The objective is to reach the point where you can explain:

> What exactly happens between my Git commit and my Spring Boot application running as a container in production?

<details>
<summary>Answer</summary>

Say the commit is built and tested. Then `docker build` creates one image. Scan that image and push it to the registry. The platform runs that same image. Configuration and secrets arrive at runtime. Logs and health tell you whether the Java process is good.

The image packages the application and runtime dependencies. The registry distributes it. The container runtime starts the isolated process. Production platforms add scheduling, identity, storage, and recovery around that process.

</details>

---

**5-Minute Interview Recall**

Before moving on, answer these without looking at the notes:

---

## 25. Interview Recall — What problem do containers solve?

1. What problem do containers solve?

<details>
<summary>Answer</summary>

Applications need a runtime, libraries, and a predictable environment. Different servers can provide different Java versions and fail in different ways.

A container packages the application with the runtime it needs. Dev, CI, UAT, and Production then run the same unit. Containers do not by themselves make an application secure.

</details>

---

## 26. Interview Recall — What is a container?

2. What is a container?

<details>
<summary>Answer</summary>

A container is an isolated process on a host operating system. It has its own view of processes, network, and files. It normally shares the host kernel.

Treat it as a replaceable execution unit, not as a permanent server. It is not a lightweight VM.

</details>

---

## 27. Interview Recall — What are namespaces and cgroups?

3. What are namespaces and cgroups?

<details>
<summary>Answer</summary>

Namespaces control what the process can see, such as PIDs, network, and mounts. Cgroups control how much CPU and memory it can use.

The runtime assembles those pieces with filesystem layers and networking. Isolation and resource control are different jobs.

</details>

---

## 28. Interview Recall — What is a container image?

4. What is a container image?

<details>
<summary>Answer</summary>

An image is a packaged, read-only template for containers. It holds a filesystem, application files, runtime dependencies, and metadata such as the default command.

Images are layers. A container adds a writable layer on top.

</details>

---

## 29. Interview Recall — What happens when you run `docker run`?

5. What happens when you run `docker run`?

<details>
<summary>Answer</summary>

Docker checks for the image and pulls it if needed. It creates the container, configures filesystem and network, then starts the main process.

The container stays up while that process runs. When the process exits, the container normally stops.

</details>

---

## 30. Interview Recall — Image versus container

6. What is the difference between an image and a container?

<details>
<summary>Answer</summary>

An image is the template. A container is one instance created from that image. One image can start many containers.

Build the image once, store it in a registry, and run that same image in Dev, UAT, and Production.

</details>

---

## 31. Interview Recall — What is a Dockerfile?

7. What is a Dockerfile?

<details>
<summary>Answer</summary>

A Dockerfile is the recipe that turns source and dependencies into an image. Instructions such as `FROM`, `COPY`, `RUN`, and `ENTRYPOINT` define layers and startup.

It is the definition of the runtime environment, not only a list of commands.

</details>

---

## 32. Interview Recall — `CMD` versus `ENTRYPOINT`

8. What is the difference between `CMD` and `ENTRYPOINT`?

<details>
<summary>Answer</summary>

`ENTRYPOINT` sets the primary executable. `CMD` sets default arguments, or a default command when no entrypoint exists.

You can override `CMD` at `docker run`. Keep the application executable fixed. Allow selected arguments to change.

</details>

---

## 33. Interview Recall — Why images should be small

9. Why should images be small?

<details>
<summary>Answer</summary>

Smaller images build, transfer, scan, and start faster. They contain fewer packages to patch and fewer tools in the attack surface.

The main win is leaving build tools out of the runtime image, not deleting files by hand from a huge image.

</details>

---

## 34. Interview Recall — What a multi-stage build is, and why it helps

10. What is a multi-stage build and why is it useful?

<details>
<summary>Answer</summary>

A multi-stage Dockerfile uses more than one `FROM`. The build stage holds Maven and the JDK. The runtime stage holds a JRE and the JAR.

`COPY --from=build` moves only the artifact. The production image does not inherit the build environment.

</details>

---

## 35. Interview Recall — How Docker image caching works

11. How does Docker image caching work?

<details>
<summary>Answer</summary>

Docker reuses a layer when the instruction and its inputs have not changed. Order in the Dockerfile therefore matters.

Copy `pom.xml` and download dependencies before you copy source. A source change can then reuse the dependency layer.

</details>

---

## 36. Interview Recall — Why we use `.dockerignore`

12. Why do we use `.dockerignore`?

<details>
<summary>Answer</summary>

`.dockerignore` keeps files out of the build context. That speeds the build and reduces accidental copies.

Exclude `.git`, `target`, logs, and `.env`. A secret in context can become an image layer.

</details>

---

## 37. Interview Recall — How container networking works

13. How does container networking work?

<details>
<summary>Answer</summary>

Docker attaches containers to a virtual network and gives them addresses. On a user-defined bridge, containers can reach each other by name.

Prefer a user-defined network such as `appnet` over the default network for application stacks.

</details>

---

## 38. Interview Recall — What `-p 8080:80` does

14. What does `-p 8080:80` actually do?

<details>
<summary>Answer</summary>

`-p 8080:80` publishes a host port. Traffic to the host on port 8080 forwards to port 80 in the container.

Confirm with `docker port` and `curl http://localhost:8080`. Publishing is a host mapping, not only a container listen socket.

</details>

---

## 39. Interview Recall — Does `EXPOSE` publish a port?

15. Does `EXPOSE` publish a port?

<details>
<summary>Answer</summary>

No. `EXPOSE` documents the port the application listens on. It does not create a host mapping.

You still need `-p` to reach the container from `localhost` on the host.

</details>

---

## 40. Interview Recall — Why use a service name instead of a container IP

16. Why should an application use a service name rather than a container IP?

<details>
<summary>Answer</summary>

Container IPs change when you remove and recreate a container. A name such as `mysql` stays stable on a user-defined network.

Pass `DB_HOST=mysql` as configuration. Do not hard-code `172.x.x.x`.

</details>

---

## 41. Interview Recall — Why the container filesystem is ephemeral

17. Why is the container filesystem ephemeral?

<details>
<summary>Answer</summary>

The writable layer belongs to that container instance. Remove the container and those writes disappear.

Replace containers instead of editing them. Put business data outside the writable layer.

</details>

---

## 42. Interview Recall — When to use a Docker volume

18. When would you use a Docker volume?

<details>
<summary>Answer</summary>

Use a volume when the workload truly needs filesystem data that must survive container removal. Local MySQL data is a common lab example.

In cloud production, prefer a managed database or object storage for business data. A volume is not automatic for every application.

</details>

---

## 43. Interview Recall — How should secrets be supplied?

19. How should secrets be supplied?

<details>
<summary>Answer</summary>

Do not put passwords in the Dockerfile or copy `.env` into the image. Do not commit secrets to Git.

For a lab, environment variables can hold non-secret config. Production should use a secret manager such as Azure Key Vault or AWS Secrets Manager.

</details>

---

## 44. Interview Recall — What happens when the main process exits?

20. What happens when the main process exits?

<details>
<summary>Answer</summary>

The container normally stops, because its lifecycle follows PID 1. `docker ps -a` shows the stopped container. `docker inspect` shows the exit code.

An orchestrator can start a replacement. Restarting does not by itself fix the underlying defect.

</details>

---

## 45. Interview Recall — What makes a container production-ready?

21. What makes a container production-ready?

<details>
<summary>Answer</summary>

Use a predictable startup command, a small trusted base image, a known version, non-root execution, runtime configuration, proper secrets, logs, health, and a scan.

Set CPU and memory limits where the platform supports them. Production readiness also includes networking, identity, and recovery.

</details>

---

## 46. Interview Recall — Why we need a container registry

22. Why do we need a container registry?

<details>
<summary>Answer</summary>

A registry stores and distributes images so CI/CD and production can pull them. Azure Container Registry and Amazon ECR are examples.

Authentication, scanning, retention, and immutability then become supply-chain concerns.

</details>

---

## 47. Interview Recall — Why build once and promote the same image

23. Why build an image once and promote the same image?

<details>
<summary>Answer</summary>

One image from one Git commit gives a traceable path through Dev, UAT, and Production. Environment values change. The application bits do not.

Rebuilding for Production creates a different artifact and breaks that trace.

</details>

---

## 48. Interview Recall — Tag versus digest

24. What is the difference between a tag and a digest?

<details>
<summary>Answer</summary>

A tag is a mutable human-readable name. A digest is content-addressed and identifies exact bytes.

Production should know the exact image content that is running, not only a moving tag such as `latest`.

</details>

---

## 49. Interview Recall — What is a container runtime?

25. What is a container runtime?

<details>
<summary>Answer</summary>

The runtime does the lower-level work of creating and running containers. Docker sits above it. containerd and `runc` are common pieces.

Kubernetes talks to a compatible runtime. It does not need Docker Engine to run application containers.

</details>

---

## 50. Interview Recall — How a container differs from a VM

26. How is a container different from a VM?

<details>
<summary>Answer</summary>

A VM has a guest OS and its own kernel on a hypervisor. A container shares the host kernel and isolates a process with namespaces and cgroups.

VMs separate operating systems more strongly. Containers start faster and are lighter. Choose from workload needs.

</details>

---

## 51. Interview Recall — What changes from laptop Docker to production

27. What changes when a container moves from Docker on a laptop to production?

<details>
<summary>Answer</summary>

On a laptop, Docker provides runtime, network, storage, and lifecycle. In production, a cloud platform or Kubernetes spreads those jobs.

The platform schedules, networks, injects identity and secrets, restarts, scales, and collects logs. The container remains the execution unit.

</details>

---

## 52. Interview Recall — Why we need Kubernetes if containers already exist

28. Why do we need Kubernetes if containers already exist?

<details>
<summary>Answer</summary>

Containers package and isolate a process. They do not schedule hundreds of containers across machines, keep desired replica counts, or roll out versions.

Kubernetes sits above the runtime. It schedules, discovers services, heals, scales, and updates containerized workloads across a cluster.

</details>
