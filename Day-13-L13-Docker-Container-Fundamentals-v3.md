# Day 13 — Docker & Container Fundamentals

## What you will learn

Containers are one of the most common ways applications are packaged and delivered in modern DevOps environments. A Senior/Lead DevOps engineer should understand not only Docker commands, but what is happening underneath them: how Linux isolates a process, how an image is built from layers, how networking and storage work, how a container starts and stops, and how the same image moves through CI/CD into production. The goal is to understand the runtime model well enough that Kubernetes, ECS, Azure Container Apps, container registries, and container security become natural extensions of the same mental model.

---

## Part 1 — Why Containers Exist

1. What problem do containers solve?

An application depends on more than its source code. A Spring Boot application needs a Java runtime, libraries, operating-system capabilities, configuration, certificates, and a predictable environment. If developers, CI agents, UAT servers, and production servers provide slightly different environments, the application can behave differently in each place. Containers package the application together with the runtime dependencies it needs, giving Dev, CI, UAT, and Production a much more consistent execution unit. Containers do not magically make an application reliable or secure, but they solve a major packaging and environment-consistency problem.

**Example:** Without containers, one server might have Java 17 while another has Java 21. With a container, the image can explicitly contain the Java runtime expected by the application.

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

2. What is a Container?

A container is an isolated process running on a host operating system. It has its own view of processes, networking, filesystems, users, and other resources, but normally shares the host's kernel. This is why a container is lighter than a virtual machine: it does not normally need a complete guest operating-system kernel. The important operational idea is that the container should be treated as a replaceable execution unit rather than as a permanent server.

**Remember:** A container is an isolated process, not a lightweight VM.

3. What is actually behind a Container?

Containers are built using operating-system isolation and resource-control mechanisms. On Linux, two of the most important mechanisms are **namespaces** and **cgroups**. Namespaces isolate what a process can see: for example, a container can have its own PID view, network interfaces, mount points, hostname, and user namespace. Cgroups control and account for resources such as CPU and memory, which prevents one workload from consuming an uncontrolled amount of the host's resources. The container runtime combines these mechanisms with filesystem layers, capabilities, security controls, and networking to create the container environment.

A useful mental model is:

```text
Namespaces → What can the process see?
Cgroups    → How much can the process use?
Runtime    → How are these pieces assembled into a container?
```

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

**Remember:** Namespaces provide isolation; cgroups provide resource control.

4. What is a Container Image?

A container image is a packaged, read-only template from which containers are created. It contains a filesystem, application files, runtime dependencies, and metadata such as the default command. Images are built in layers, so common layers can be reused between images and versions. When a container starts, the runtime adds a writable layer on top of the image layers; this is one reason changes made directly inside a container should not be treated as a permanent way of managing an application.

**Example:**

```text
Base OS/runtime layer
        ↓
Java runtime layer
        ↓
Application dependencies
        ↓
Spring Boot JAR
        ↓
Container writable layer
```

**Practice**

```bash
docker pull nginx
docker image ls
docker image inspect nginx
docker history nginx
```

Look at the image size, layers, default command, and exposed ports.

---

## Part 2 — How Docker Works

5. What is Docker?

Docker is a platform and toolset for building, distributing, and running containers. The `docker` CLI is the interface you normally use, while the Docker Engine manages images, containers, networks, volumes, and the container runtime underneath. Modern Docker installations also use components such as containerd and an OCI runtime such as `runc`, so it is useful to distinguish Docker's developer experience from the lower-level runtime responsible for actually starting containers.

**Practice**

```bash
docker version
docker info
```

Identify the client, Engine/server, storage, runtime, and other information reported by Docker.

6. What happens when you run `docker run`?

`docker run` combines several operations into one command. Docker first checks whether the image exists locally and pulls it from a registry if necessary. It then creates a container filesystem and configures networking, environment variables, mounts, resource settings, and other options before asking the runtime to start the container's main process. The container normally remains running while that main process is running; when that process exits, the container normally stops.

For example:

```bash
docker run -d --name web -p 8080:80 nginx
```

Conceptually:

```text
Image available?
      ↓
Create container
      ↓
Configure filesystem/network
      ↓
Start main process
      ↓
nginx running
```

**Practice**

```bash
docker ps
docker inspect web
docker logs web
docker stop web
docker ps -a
```

7. What is the difference between an Image and a Container?

An image is the packaged template; a container is an instance created from that image. One image can create many containers, each with its own runtime state and configuration. This distinction is fundamental to CI/CD because you normally want to build a known image once, store it in a registry, and deploy that same image to multiple environments rather than rebuilding it separately for Dev, UAT, and Production.

**Example:**

```bash
docker run -d --name web1 nginx
docker run -d --name web2 nginx
```

Both containers can come from the same image while having different names, IP addresses, environment variables, and runtime state.

---

## Part 3 — Building Images

8. What is a Dockerfile?

A Dockerfile is the recipe used to turn application source code and dependencies into a container image. Each instruction describes part of the final filesystem or runtime configuration, and Docker can cache the resulting layers so that unchanged work does not have to be repeated. For a Spring Boot application, the Dockerfile might define a Java runtime, copy the application JAR, set `/app` as the working directory, document port `8080`, and define Java as the process that starts when the container runs. A good Dockerfile is therefore not just a list of commands; it is a definition of the application's runtime environment.

**Example — simple Spring Boot Dockerfile:**

```dockerfile
FROM eclipse-temurin:21-jre

WORKDIR /app

COPY target/myapp.jar app.jar

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]
```

Build it:

```bash
mvn clean package
docker build -t myapp:1.0.0 .
```

Run it:

```bash
docker run -d \
  --name myapp \
  -p 8080:8080 \
  myapp:1.0.0
```

Verify:

```bash
docker ps
docker logs myapp
curl http://localhost:8080
```

The flow is:

```text
Spring Boot source
       ↓
Maven build
       ↓
target/myapp.jar
       ↓
docker build
       ↓
myapp:1.0.0
       ↓
docker run
       ↓
Java process
```

9. What do the common Dockerfile instructions actually do?

The most important instructions are `FROM`, `WORKDIR`, `COPY`, `RUN`, `ENV`, `EXPOSE`, `USER`, `CMD`, and `ENTRYPOINT`. `FROM` chooses the starting image, `WORKDIR` establishes the directory used by later commands, `COPY` adds files from the build context, and `RUN` executes commands while the image is being built. `ENV` provides image-level environment defaults, `EXPOSE` documents the port the application listens on, `USER` selects the runtime user, and `CMD`/`ENTRYPOINT` define startup behavior. Understanding these instructions lets you read an unfamiliar Dockerfile and immediately understand what gets installed, what gets copied, and what process eventually runs.

**Example:**

```dockerfile
FROM eclipse-temurin:21-jre
WORKDIR /app
COPY target/myapp.jar app.jar
USER 10001
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```

Notice that there is no `RUN apt install ...` here. The runtime image is intentionally kept focused on what the application needs.

10. What is the difference between build-time and runtime?

Some work must happen while the image is being built, while other values should only be supplied when the container starts. Compiling source code, installing build dependencies, and creating the JAR are build-time activities. Database URLs, environment names, feature flags, credentials, and other environment-specific values are runtime concerns. Mixing these two concerns makes images less reusable and can accidentally put secrets or environment-specific configuration into the image.

**Example:**

```text
Build time
──────────
Source code
Maven
JDK
Dependencies
Unit tests
        ↓
   Container Image


Runtime
───────
DATABASE_URL
API_URL
APP_ENV
Secrets
        ↓
Running Container
```

A single `myapp:1.0.0` image can therefore run in Dev, UAT, and Production while receiving different runtime configuration.

11. What is the difference between `CMD` and `ENTRYPOINT`?

`ENTRYPOINT` defines the primary executable that the container is intended to run, while `CMD` provides default arguments or, when no entrypoint is defined, a default command. This distinction is useful when you want the application executable to remain fixed while allowing selected arguments to change.

**Example:**

```dockerfile
ENTRYPOINT ["java", "-jar", "app.jar"]
CMD ["--server.port=8080"]
```

The default startup becomes:

```text
java -jar app.jar --server.port=8080
```

You can experiment with another argument:

```bash
docker run --rm myapp:1.0.0 --server.port=9090
```

The important interview point is not memorizing syntax. It is understanding that `ENTRYPOINT` establishes the main executable while `CMD` provides defaults that can be overridden.

12. Why should Docker images be small?

A smaller image generally builds, transfers, scans, and starts faster. It also contains fewer packages that need patching and fewer tools that could become part of a security attack surface. The biggest improvement often comes from separating build dependencies from runtime dependencies rather than trying to manually remove every file from one large image.

**Example:**

A development/build environment may contain:

```text
JDK
Maven
Git
Source code
Test tools
Compilers
Debugging tools
```

A runtime image may need only:

```text
JRE
Application JAR
Required certificates
Runtime configuration
```

Check image size:

```bash
docker image ls
docker history myapp:1.0.0
```

13. What is a Multi-Stage Build?

A multi-stage build uses multiple `FROM` statements so that the build environment and runtime environment can be kept separate. The first stage can contain Maven, the JDK, source code, and build dependencies; the second stage can contain only the JRE and the compiled application. Docker copies the required artifact from the build stage into the runtime stage, so the final image does not inherit the entire build environment.

**Example — Spring Boot multi-stage build:**

```dockerfile
# -------------------------
# Stage 1: Build
# -------------------------
FROM maven:3.9-eclipse-temurin-21 AS build

WORKDIR /build

COPY pom.xml .
COPY src ./src

RUN mvn clean package -DskipTests


# -------------------------
# Stage 2: Runtime
# -------------------------
FROM eclipse-temurin:21-jre

WORKDIR /app

COPY --from=build /build/target/myapp.jar app.jar

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]
```

Build it:

```bash
docker build -t myapp:multi-1.0.0 .
```

Run it:

```bash
docker run -d \
  --name myapp \
  -p 8080:8080 \
  myapp:multi-1.0.0
```

The important instruction is:

```dockerfile
COPY --from=build /build/target/myapp.jar app.jar
```

Only the final JAR is copied into the runtime stage.

Compare the mental models:

```text
Single-stage

Maven + JDK + Source + Dependencies + JAR
                    ↓
              Final Image


Multi-stage

Maven + JDK + Source
          ↓
        JAR
          ↓
      JRE + JAR
          ↓
      Final Image
```

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

Ask yourself:

> If Maven is not needed to run the application, why should Maven be inside the production image?

**Remember:** Build dependencies normally belong in the build stage, not the production runtime image.

14. How does Docker image caching work?

Docker can reuse previously built layers when the instruction and its relevant inputs have not changed. This means Dockerfile ordering can have a major effect on build performance. A common Java pattern is to copy `pom.xml` first, download dependencies, and only then copy source code. If application source changes but dependencies do not, Docker can reuse the dependency layer.

**Example:**

```dockerfile
FROM maven:3.9-eclipse-temurin-21 AS build

WORKDIR /build

COPY pom.xml .
RUN mvn dependency:go-offline

COPY src ./src
RUN mvn clean package -DskipTests
```

If you change only:

```text
src/main/java/...
```

Docker may reuse the dependency layer.

If you change:

```text
pom.xml
```

the dependency layer normally has to be rebuilt.

**Practice**

Build twice:

```bash
docker build -t myapp:cache-test .
docker build -t myapp:cache-test .
```

Look for cached steps in the second build. Then modify `pom.xml` and build again. Observe which layers are rebuilt.

15. What is the Docker build context?

When you run:

```bash
docker build .
```

the `.` is the build context. Docker receives the files from that directory that are not excluded by `.dockerignore`, and Dockerfile instructions such as `COPY` can use those files. A large build context can make builds slower and can accidentally expose files to the build process. This is why a clean project directory and a good `.dockerignore` are important.

**Example project:**

```text
myapp/
├── Dockerfile
├── .dockerignore
├── pom.xml
├── src/
├── target/
├── .git/
└── README.md
```

You normally do not need `.git` or `target` in the build context for a multi-stage build.

16. What is `.dockerignore`?

`.dockerignore` prevents unnecessary files from being sent as part of the Docker build context. It is useful for excluding `.git`, IDE files, local build output, logs, test reports, and local environment files. This improves build performance and reduces the chance of accidentally copying files that should not be part of the image.

**Example:**

```text
.git
.idea
.vscode
target
*.log
.env
```

**Practice**

Create the file and rebuild:

```bash
docker build -t myapp:1.0.0 .
```

Then ask:

> Could a developer's local `.env` file contain a password or API key?

This is one reason `.dockerignore` and proper secret management should be used together.

---

## Part 4 — Container Networking

17. How does a container communicate over the network?

A container can communicate through a virtual network provided by Docker. Docker assigns network interfaces and addresses to containers and provides the connectivity required by the selected network type. For application stacks, a user-defined bridge network is usually more useful than relying on the default network because Docker provides name-based discovery between containers on that network.

**Example:**

```bash
docker network create appnet

docker run -d \
  --name web \
  --network appnet \
  nginx
```

Inspect the network:

```bash
docker network inspect appnet
```

You can see the containers attached to it and their network information.

18. How does container-to-container DNS work?

When containers are attached to the same user-defined Docker network, they can generally reach each other by container name. This is much safer operationally than hard-coding a container IP because container instances can be destroyed and recreated with different IP addresses.

**Example:**

Start a web container:

```bash
docker run -d \
  --name web \
  --network appnet \
  nginx
```

Start a temporary client:

```bash
docker run --rm -it \
  --network appnet \
  busybox sh
```

Inside the client:

```bash
ping web
```

You can also test HTTP:

```bash
wget -qO- http://web
```

The flow is:

```text
Client container
      ↓
DNS name: web
      ↓
Docker network
      ↓
web container
      ↓
Nginx:80
```

This same principle appears later in Kubernetes, where applications normally use Service DNS names instead of Pod IPs.

19. Why do we publish container ports?

A container can listen on a port without that port being directly exposed through the host. Port publishing creates a host-to-container mapping. For example, `-p 8080:80` means traffic arriving at the host on port 8080 is forwarded to port 80 of the container.

```bash
docker run -d \
  --name web-public \
  -p 8080:80 \
  nginx
```

Now:

```text
Browser
   ↓
localhost:8080
   ↓
Docker host
   ↓
Container:80
   ↓
Nginx
```

Verify the mapping:

```bash
docker port web-public
```

Then:

```bash
curl http://localhost:8080
```

**Important:** `EXPOSE 80` in a Dockerfile does not itself publish port 80. `-p` performs the host-to-container port mapping.

20. What is the difference between `EXPOSE` and `-p`?

`EXPOSE` is image metadata/documentation indicating that the application expects to listen on a particular port. It does not create a host port mapping by itself. `-p` explicitly publishes a port from the container through the host.

**Example:**

Dockerfile:

```dockerfile
EXPOSE 8080
```

Run:

```bash
docker run -d myapp:1.0.0
```

The application can listen on 8080 inside the container, but you have not necessarily made it reachable at `localhost:8080`.

Run instead:

```bash
docker run -d \
  -p 8080:8080 \
  myapp:1.0.0
```

Now the host's port 8080 maps to the container's port 8080.

21. How should an application communicate with a database container?

The application should normally use the database's service/container name rather than its changing IP address. Both containers should be attached to the same application network, and the database hostname should be supplied as configuration.

**Example:**

```bash
docker network create appnet
```

Start MySQL:

```bash
docker run -d \
  --name mysql \
  --network appnet \
  -e MYSQL_ROOT_PASSWORD=example \
  -e MYSQL_DATABASE=appdb \
  mysql:8
```

Start the application:

```bash
docker run -d \
  --name app \
  --network appnet \
  -e DB_HOST=mysql \
  -e DB_PORT=3306 \
  -e DB_NAME=appdb \
  myapp:1.0.0
```

The application connects to:

```text
mysql:3306
```

not:

```text
172.x.x.x:3306
```

because the container IP is an implementation detail that can change.

22. How should the database connection flow be understood?

When an application container connects to a database, do not jump directly to "the database is down" when the connection fails. Follow the network path step by step.

```text
Application
    ↓
Resolve DB hostname
    ↓
Reach Docker network
    ↓
Reach database IP
    ↓
Connect to TCP 3306
    ↓
MySQL accepts connection
    ↓
Authenticate
    ↓
Select database
```

Each stage can fail for a different reason.

**Example failures:**

```text
DB_HOST=mysql-wrong
        ↓
Name resolution failure


DB_HOST=mysql
DB_PORT=3307
        ↓
Port/connectivity failure


Correct network and port
Wrong password
        ↓
Authentication failure
```

This is the same troubleshooting mindset you learned in networking: **DNS → route/network → port → service → authentication**.

23. How can you deliberately break container networking?

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

24. What is the difference between internal and external container traffic?

Container-to-container traffic inside an application network is different from traffic coming from a browser or external service. Internal traffic can use Docker DNS and private network connectivity. External traffic normally enters through a published port, reverse proxy, load balancer, ingress controller, or cloud platform networking.

**Example:**

```text
Internet
   ↓
Load Balancer
   ↓
Application endpoint
   ↓
Container
   ↓
Internal Docker network
   ↓
Database
```

In Kubernetes, this becomes conceptually:

```text
Internet
   ↓
Ingress / Load Balancer
   ↓
Kubernetes Service
   ↓
Pod
   ↓
Database Service
```

The underlying networking idea remains the same even though the implementation changes.

25. What happens when a container is restarted or recreated?

A restart keeps the same container identity and writable layer, while removing and recreating a container creates a new instance. This distinction matters because a container's IP address and runtime state should not be treated as permanent. Production systems usually assume containers can be replaced at any time and therefore use stable service endpoints and externalized state.

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

---

## Part 5 — Container Storage and Configuration

26. Why is a container filesystem considered ephemeral?

The container has a writable filesystem layer on top of its image layers, but that writable layer belongs to that particular container instance. If the container is removed, those changes normally disappear. This design makes containers replaceable and supports immutable-style deployments: instead of modifying a running container, you create a new image and replace the old container. Important business data should therefore live outside the container's writable layer.

**Example:**

```bash
docker run -it --name test alpine sh
```

Inside:

```bash
echo "hello" > /tmp/message.txt
cat /tmp/message.txt
```

Exit:

```bash
exit
```

Remove the container:

```bash
docker rm test
```

Create another:

```bash
docker run --rm alpine cat /tmp/message.txt
```

The file is gone.

27. Why should application state usually live outside the container?

Containers are intentionally disposable. If a container crashes, is rescheduled, or is replaced during deployment, anything stored only inside its writable layer can disappear. A stateless Spring Boot API should therefore normally store user data in MySQL/PostgreSQL, files in object storage such as Azure Blob Storage or Amazon S3, and other persistent information in appropriate external services. This allows the application container to be replaced without losing business state.

**Example:**

Bad design:

```text
Spring Boot Container
 ├── Application
 └── User uploads
       ↓
   Container filesystem
```

Better design:

```text
Spring Boot Container
       ↓
Database ───────→ User records
       ↓
Object Storage → User files
```

28. What is a Docker Volume?

A Docker volume provides persistent storage outside the container's writable layer and can be mounted into a container. When the container is removed, the volume can remain. Volumes are useful when a workload genuinely needs persistent filesystem data, but they should not automatically be treated as the right storage solution for every application.

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

29. What is the difference between the container writable layer and a volume?

The writable layer belongs to the container instance and is therefore disposable when the container is removed. A volume has a separate lifecycle and can survive container replacement. This distinction is important when deciding whether data is temporary application state or persistent business data.

```text
Container

Image layers
     +
Writable layer
     ↓
Container removed
     ↓
Writable changes disappear


Volume

Container
   ↓
Mounted Volume
   ↓
Container removed
   ↓
Volume remains
```

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

30. When should you use a Docker volume versus external storage?

A volume is useful when the application genuinely requires filesystem persistence on the Docker host, such as some local development workloads or self-managed services. For cloud production systems, persistent business data is often better placed in managed databases, object storage, or cloud-managed storage because those services provide durability, backups, replication, and operational capabilities beyond a single Docker host. The correct choice depends on the workload and reliability requirements.

**Example:**

```text
Local development
Spring Boot + MySQL container
        ↓
Docker volume for MySQL data


Cloud production
Spring Boot container
        ↓
Azure Database for MySQL / Amazon RDS
```

The production container can then be replaced without affecting the database.

31. How should configuration be separated from the image?

The image should contain the application and its runtime dependencies, while environment-specific configuration should normally be injected when the container starts. This lets the same image run in different environments. For example, the Dev database endpoint and Production database endpoint should not require two different application images.

**Example:**

```bash
docker run -d \
  --name app \
  -e APP_ENV=dev \
  -e DB_HOST=mysql-dev \
  -e DB_PORT=3306 \
  myapp:1.0.0
```

Production might use:

```text
APP_ENV=prod
DB_HOST=prod-db.example.internal
DB_PORT=3306
```

The image remains:

```text
myapp:1.0.0
```

32. How should secrets be handled?

Secrets such as database passwords, API tokens, certificates, and private keys should not be baked into the image or committed to Git. Environment variables are useful for basic configuration and labs, but production environments should normally use dedicated secret-management mechanisms so that access can be controlled, audited, rotated, and separated from the application image.

**Bad:**

```dockerfile
ENV DB_PASSWORD=SuperSecret123
```

Anyone who obtains the image may be able to discover that value.

**Also bad:**

```dockerfile
COPY .env /app/.env
```

A secret has now become part of the image build process.

**Better concept:**

```text
Container
   ↓
Secret reference
   ↓
Secret Manager
   ↓
Password / Token
```

Examples in cloud environments include Azure Key Vault and AWS Secrets Manager.

33. How can you implement runtime configuration locally?

For a local lab, environment variables are simple and useful:

```bash
docker run -d \
  --name app \
  -e APP_ENV=dev \
  -e DB_HOST=mysql \
  -e DB_PORT=3306 \
  -e DB_NAME=appdb \
  myapp:1.0.0
```

You can also use an environment file for non-sensitive local configuration:

```text
APP_ENV=dev
DB_HOST=mysql
DB_PORT=3306
DB_NAME=appdb
```

Then:

```bash
docker run -d \
  --name app \
  --env-file app.env \
  myapp:1.0.0
```

For real secrets, avoid committing the file to Git. A local `.gitignore` can contain:

```text
.env
app.env
*.secret
```

34. What is a useful Docker Compose pattern for an application stack?

When an application needs multiple local containers, Docker Compose can describe the stack as one configuration. For example, a Spring Boot application can run alongside MySQL on the same logical network, with configuration passed into the application at runtime.

**Example `compose.yaml`:**

```yaml
services:

  mysql:
    image: mysql:8
    environment:
      MYSQL_ROOT_PASSWORD: example
      MYSQL_DATABASE: appdb
    volumes:
      - mysql-data:/var/lib/mysql

  app:
    build: .
    ports:
      - "8080:8080"
    environment:
      DB_HOST: mysql
      DB_PORT: 3306
      DB_NAME: appdb
    depends_on:
      - mysql

volumes:
  mysql-data:
```

Start:

```bash
docker compose up -d
```

Inspect:

```bash
docker compose ps
docker compose logs
```

Stop:

```bash
docker compose down
```

If you run:

```bash
docker compose down
```

the containers are removed, but named volumes are normally retained unless you explicitly remove them.

The architecture becomes:

```text
                Docker Compose
                     |
        +------------+------------+
        |                         |
   Spring Boot                 MySQL
   container                  container
        |                         |
        +------ app network ------+
                                  |
                            mysql-data volume
```

This is a very useful local bridge between individual Docker commands and the multi-container environments you will later see in Kubernetes.

## Part 6 — Container Lifecycle and Reliability

21. What happens when the main process exits?

The container's lifecycle is closely connected to its main process, usually PID 1 inside the container. If that process exits, the container normally stops. A production orchestrator can detect that state and start a replacement container according to the desired configuration. Restarting a failed container can restore service, but it does not necessarily fix the underlying problem.

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

22. Why should containers normally run one main application process?

A container is easiest to operate when its lifecycle maps clearly to one primary application process. This makes health checks, logs, scaling, restart behavior, and failure diagnosis easier to understand. It is technically possible to run multiple processes inside one container, but independently managed components are usually better represented as separate containers so the platform can scale and restart them independently.

**Example:**

Instead of:

```text
One container
 ├── Nginx
 ├── Spring Boot
 ├── Cron
 └── Monitoring agent
```

Prefer:

```text
Nginx container
      ↓
Spring Boot container

Cron workload → separately managed

Monitoring → platform/agent mechanism
```

23. What makes a container production-ready?

A production container should have a predictable startup command, minimal unnecessary software, runtime configuration, secure secret handling, useful logs, an appropriate health model, and a known image version. It should use a trusted and maintained base image, be scanned for vulnerabilities, run with only the permissions it needs, and have sensible CPU/memory limits where the platform supports them. Production readiness is broader than the Dockerfile: networking, observability, deployment strategy, storage, identity, and recovery all matter.

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

---

## Part 7 — Container Registry and CI/CD

24. Why do we need a Container Registry?

A container registry stores and distributes images so CI/CD systems and production platforms can retrieve them. Examples include Azure Container Registry and Amazon Elastic Container Registry. The registry becomes part of the software supply chain, so authentication, authorization, vulnerability scanning, retention, provenance, and image immutability become important operational and security concerns.

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

25. How should containers move through CI/CD?

A strong container pipeline builds the image once, tests it, scans it, pushes it to a trusted registry, and promotes that same image through Dev, UAT, and Production. Environment-specific configuration changes, but the application image should remain the same. This gives you traceability between a Git commit, the image that was built, the image that was deployed, and the behavior observed in production.

**Example:**

```text
Git Commit abc123
       ↓
Build & Test
       ↓
myapp:1.4.7
       ↓
Security Scan
       ↓
Container Registry
       ↓
Dev
       ↓
UAT
       ↓
Prod
```

The image should not be rebuilt just because it is being deployed to Production.

26. Why should images be tagged carefully?

A tag such as `latest` is a mutable pointer and can refer to different image contents over time. That makes it harder to know exactly what is running and can make rollback ambiguous. A version tag such as `1.4.7` is easier for humans to understand, while an image digest identifies the exact content-addressed image; in production, a strong deployment process should be able to identify the exact image content that is running.

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

**Remember:** Build once, identify the exact image, and promote that image.

---

## Part 8 — Containers vs Virtual Machines

27. How is a Container different from a Virtual Machine?

A virtual machine includes a complete guest operating system and its own kernel, running on a hypervisor. A container normally shares the host kernel and isolates the application process using operating-system mechanisms. VMs therefore provide stronger operating-system-level separation and can run different guest operating systems on the same physical host, while containers are generally lighter and faster to start. The choice depends on workload requirements rather than the idea that one technology universally replaces the other.

**Example:**

```text
Virtual Machine

Physical Host
   ↓
Hypervisor
   ↓
VM
 ├── Guest OS
 ├── Kernel
 └── Application


Container

Physical Host
   ↓
Host Kernel
   ↓
Container Runtime
   ↓
Container
 └── Application + dependencies
```

**Practice**

Consider:

```text
Spring Boot API
Legacy application requiring a custom OS
Kubernetes worker
Application requiring a different OS kernel
```

For each, explain what isolation and operating-system requirements matter.

28. What is the Container Runtime?

The container runtime is responsible for the lower-level work of creating and running containers. Docker provides a higher-level developer workflow, while modern container environments commonly use containerd and an OCI runtime such as `runc` underneath. This distinction matters when learning Kubernetes: Kubernetes does not require the Docker Engine itself to run application containers; it communicates with a compatible container runtime through its runtime interface.

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

---

## Part 9 — Containers in Cloud and Kubernetes

29. What changes when a container moves to the cloud?

On a laptop, Docker provides the host, container runtime, networking, storage, and basic lifecycle operations. In production, those responsibilities are usually distributed across a cloud container platform or orchestrator. The platform must decide where workloads run, how they receive traffic, how they obtain configuration and secrets, how they restart, how they scale, how identity works, and how logs and metrics are collected. This is why container knowledge is the foundation for services such as Azure Container Apps, Amazon ECS, AKS, and EKS.

**Example:**

```text
Local Docker

Docker
 ├── Runtime
 ├── Network
 ├── Storage
 └── Container


Production

Cloud Platform / Kubernetes
 ├── Scheduling
 ├── Networking
 ├── Identity
 ├── Secrets
 ├── Storage
 ├── Scaling
 ├── Health
 └── Observability
          ↓
      Container
```

30. Why do we need Kubernetes if containers already exist?

Containers solve packaging and process isolation, but they do not by themselves solve the problem of operating hundreds or thousands of containers across many machines. Kubernetes adds scheduling, service discovery, desired-state management, health checks, rolling deployments, scaling, and self-healing. It therefore sits above the container runtime and manages containerized workloads across a cluster.

**Example:**

Without orchestration:

```text
Server 1 → manually run container
Server 2 → manually run container
Server 3 → manually restart failed container
```

With Kubernetes:

```text
Desired State
     ↓
Kubernetes Control Plane
     ↓
Schedule / Monitor / Replace / Scale
     ↓
Containers across worker nodes
```

**Remember:** The container runtime runs containers; Kubernetes orchestrates containerized workloads.

---

## Part 10 — Integrated Practice

Take a simple Spring Boot application and move through the complete container lifecycle.

Start with source code and build the JAR:

```bash
mvn clean package
```

Create a multi-stage Dockerfile, build the image, and run it:

```bash
docker build -t myapp:1.0.0 .
docker run -d --name myapp -p 8080:8080 myapp:1.0.0
```

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

The objective is to reach the point where you can explain:

> What exactly happens between my Git commit and my Spring Boot application running as a container in production?

---

**5-Minute Interview Recall**

Before moving on, answer these without looking at the notes:

1. What problem do containers solve?
2. What is a container?
3. What are namespaces and cgroups?
4. What is a container image?
5. What happens when you run `docker run`?
6. What is the difference between an image and a container?
7. What is a Dockerfile?
8. What is the difference between `CMD` and `ENTRYPOINT`?
9. Why should images be small?
10. What is a multi-stage build and why is it useful?
11. How does Docker image caching work?
12. Why do we use `.dockerignore`?
13. How does container networking work?
14. What does `-p 8080:80` actually do?
15. Does `EXPOSE` publish a port?
16. Why should an application use a service name rather than a container IP?
17. Why is the container filesystem ephemeral?
18. When would you use a Docker volume?
19. How should secrets be supplied?
20. What happens when the main process exits?
21. What makes a container production-ready?
22. Why do we need a container registry?
23. Why build an image once and promote the same image?
24. What is the difference between a tag and a digest?
25. What is a container runtime?
26. How is a container different from a VM?
27. What changes when a container moves from Docker on a laptop to production?
28. Why do we need Kubernetes if containers already exist?

**Core Mental Model**

```text
Source Code
    ↓
Build & Test
    ↓
Container Image
    ↓
Registry
    ↓
Container Runtime
    ↓
Running Container
    ↓
Production Platform
    ↓
Networking + Identity + Secrets + Storage
    ↓
Scaling + Health + Observability
```

The image packages the application and its runtime dependencies. The registry distributes the image. The container runtime creates and runs the container. Production platforms add the operational capabilities needed to run many containers reliably.

**Cleanup**

Remove temporary lab containers and networks:

```bash
docker rm -f myapp web web1 web2 web-public mysql writer test 2>/dev/null || true
docker network rm appnet 2>/dev/null || true
docker volume rm appdata 2>/dev/null || true
```

Verify:

```bash
docker ps -a
docker network ls
docker volume ls
docker image ls
```
