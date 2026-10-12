# Day 14 — Kubernetes Mental Model

**Goal:** Build the one mental model behind all of Kubernetes — you declare the state you want, and Kubernetes continuously works to make reality match it — and see how Pods, Deployments, and Services each serve that model.

> **JD note:** Nearly every Senior and Lead DevOps JD expects production Kubernetes, and this model is the base for all of it. See the [Kubernetes in production pattern card](jd-insights/patterns/kubernetes-production.md).

## What you will learn

Docker taught us how to package and run a container. Kubernetes becomes important when we need to run many containers reliably across multiple machines. The goal today is not to memorize YAML; it is to build the mental model that makes Kubernetes YAML understandable. By the end you should be able to explain:

- what Kubernetes is actually managing
- why Pods exist
- how Deployments maintain desired state
- how Services provide stable networking
- how configuration and secrets reach workloads
- what happens when a Pod fails

---

## Part 1 — Why Kubernetes Exists

1. What problem does Kubernetes solve?

Running one container with Docker is simple. Running hundreds of containers across many servers introduces a new set of problems:

- deciding where each container should run
- replacing containers that fail
- scaling applications up and down
- giving workloads stable network endpoints
- rolling out new versions safely
- keeping the running system aligned with the intended configuration

Kubernetes answers all of these with one control system. Instead of manually telling individual servers what to do, you describe the state you want, and Kubernetes continuously works toward maintaining that state.

**Example**

Without Kubernetes:

```text
Server 1 → run container
Server 2 → run container
Server 3 → run container

Container fails
      ↓
Engineer notices
      ↓
Engineer restarts it
```

With Kubernetes:

```text
Desired State
     ↓
Kubernetes Control Plane
     ↓
Schedule / Monitor / Replace
     ↓
Running Workloads
```

2. What does "desired state" mean?

Kubernetes works primarily by comparing the state you declare with the state that actually exists. If you declare that three replicas of an application should be running but only two are healthy, Kubernetes attempts to create another Pod. If someone manually deletes one of the Pods, Kubernetes sees that the actual state no longer matches the desired state and replaces it. This reconciliation loop is one of the most important ideas in Kubernetes.

**Example**

You declare:

```yaml
spec:
  replicas: 3
```

Kubernetes continuously tries to maintain:

```text
Desired:
3 Pods

Actual:
2 Pods

Kubernetes:
Create another Pod
```

**Remember:** Kubernetes is a reconciliation system, not simply a command executor.

3. What is a Kubernetes cluster?

A Kubernetes cluster is a group of machines and control-plane components working together to run containerized workloads. The **control plane** makes decisions about the cluster, while **worker nodes** provide the compute capacity where application Pods run. Managed services such as AKS and EKS operate much of the control plane for you, but the underlying architecture is still important for troubleshooting and interviews.

```text
Kubernetes Cluster
│
├── Control Plane
│   ├── API Server
│   ├── Scheduler
│   ├── Controller Manager
│   └── etcd
│
└── Worker Nodes
    ├── kubelet
    ├── container runtime
    └── Pods
```

---

## Part 2 — Kubernetes Architecture

4. What is the Kubernetes API Server?

The API Server is the main entry point into Kubernetes. `kubectl`, CI/CD systems, controllers, operators, and other Kubernetes components communicate with the cluster through the API. It authenticates and authorizes requests, validates Kubernetes objects, and provides access to the cluster's desired state. A useful mental model is that the API Server is the front door of the Kubernetes control plane.

**Practice**

```bash
kubectl cluster-info
kubectl get nodes
kubectl get pods -A
```

Every one of these commands ultimately interacts with the Kubernetes API.

5. What is etcd?

`etcd` is the distributed key-value store used by Kubernetes to persist important cluster state. Kubernetes stores information about objects such as Deployments, Services, ConfigMaps, Secrets, and other resources through the API/control-plane architecture. etcd provides durable storage for that state. If you use a managed Kubernetes service, the cloud provider generally operates etcd for you. As a Senior/Lead engineer you should still understand that loss or corruption of control-plane state is a serious cluster-level concern.

```text
kubectl
   ↓
API Server
   ↓
etcd
   ↓
Cluster State
```

6. What does the Scheduler do?

The Scheduler decides which worker node should run a newly created Pod. It considers factors such as available resources, node constraints, affinity/anti-affinity, taints and tolerations, and other scheduling requirements. The Scheduler does not actually run the container; it makes the placement decision and the kubelet on the selected node handles execution.

**Example**

```text
New Pod
  ↓
Scheduler
  ↓
Node 1 has insufficient memory
Node 2 has enough memory
Node 3 does not satisfy constraint
  ↓
Pod assigned to Node 2
```

7. What does the Controller Manager do?

Kubernetes controllers continuously observe the cluster and attempt to make actual state match desired state. A Deployment controller, for example, notices that a Deployment requires three replicas and works with ReplicaSets to maintain that number. This controller-based architecture is why Kubernetes can automatically replace failed or deleted workloads.

**Example**

```text
Desired: 3 Pods
Actual:  2 Pods

Controller detects difference
        ↓
Creates replacement
        ↓
Actual: 3 Pods
```

8. What does the kubelet do?

The kubelet is the main Kubernetes agent running on each worker node. It receives Pod specifications assigned to that node and works with the container runtime to create and manage the containers. It also reports information about the node and workloads back to the control plane. The kubelet does not make cluster-wide scheduling decisions; that is the Scheduler's job.

```text
Control Plane
     ↓
Pod assigned to Node 2
     ↓
kubelet on Node 2
     ↓
container runtime
     ↓
Container
```

9. Where does the container runtime fit?

Kubernetes does not itself execute container processes. The kubelet communicates with a compatible container runtime, commonly containerd, through the Kubernetes container runtime interface. The runtime handles the lower-level work required to create and run the container.

```text
Kubernetes
    ↓
kubelet
    ↓
container runtime
    ↓
Linux
    ↓
Container process
```

This connects directly with Day 13: Docker is a higher-level developer platform, while the runtime is responsible for running containers.

---

## Part 3 — Pods

10. What is a Pod?

A Pod is the smallest deployable unit in Kubernetes. It represents one or more containers that Kubernetes schedules together onto the same node. Those containers share certain resources, including a network namespace and optionally storage volumes. In the common case, a Pod contains one main application container, but sidecar patterns can place tightly coupled helper containers in the same Pod.

**Example**

```text
Pod
│
├── Spring Boot container
│
└── optional sidecar
```

The important distinction is:

```text
Docker:
Container is a primary unit

Kubernetes:
Pod is the primary scheduling/deployment unit
Pod contains container(s)
```

11. Why doesn't Kubernetes deploy containers directly?

Kubernetes needs a unit that can represent more than just a single container process. A Pod provides shared networking, storage, lifecycle, and scheduling context for tightly coupled containers. It also gives Kubernetes a stable abstraction for scheduling workloads without exposing the implementation details of the underlying container runtime.

12. Why can a Pod contain multiple containers?

Multiple containers belong in one Pod when they need to be tightly coupled and share the same lifecycle, network namespace, or volumes. A common example is a sidecar that performs a supporting function for the main application. However, putting unrelated applications into one Pod makes scaling and failure handling harder.

**Example**

```text
Pod
├── Application
└── Log/Proxy sidecar
```

Both containers share the Pod's network namespace, so they can communicate through `localhost`.

**Remember:** Multiple containers in one Pod share the Pod's network namespace.

13. What is the Pod IP?

A Pod receives an IP address from the Kubernetes cluster network. Containers inside the same Pod share that network namespace and therefore share the Pod's IP. Pod IPs are generally temporary because Pods are replaceable; a replacement Pod can receive a different IP. Applications should therefore use Services rather than store Pod IPs as permanent endpoints.

**Example**

```text
Pod A → 10.244.1.10
Pod fails
     ↓
Replacement Pod
     ↓
10.244.2.15
```

The application should not depend on `10.244.1.10` remaining unchanged.

14. How do you create a Pod?

You can create a Pod directly with YAML, although in production you usually manage Pods indirectly through higher-level resources such as Deployments.

**Example:**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  containers:
    - name: nginx
      image: nginx:1.27
      ports:
        - containerPort: 80
```

Apply it:

```bash
kubectl apply -f pod.yaml
```

Inspect it:

```bash
kubectl get pod nginx
kubectl describe pod nginx
kubectl logs nginx
```

Delete it:

```bash
kubectl delete pod nginx
```

Now notice what happens: because this Pod was created directly, Kubernetes does not have a Deployment controller responsible for recreating it.

---

## Part 4 — Deployments and ReplicaSets

15. Why don't we normally create individual Pods?

A manually created Pod is not enough for production because it does not provide the higher-level management features normally required for application workloads. If the Pod dies or is deleted, nothing automatically maintains the desired replica count. A Deployment provides a declarative way to manage a replicated application and gives Kubernetes the controller behavior needed for replacement and rolling updates.

16. What is a Deployment?

A Deployment describes the desired state of a stateless application workload. It normally specifies the container image, number of replicas, Pod template, labels, and update strategy. Kubernetes creates and manages ReplicaSets behind the Deployment, and those ReplicaSets maintain the requested number of Pods.

```text
Deployment
    ↓
ReplicaSet
    ↓
Pods
    ↓
Containers
```

17. What is a ReplicaSet?

A ReplicaSet keeps a specified number of matching Pods. If the desired count is three and one Pod disappears, the ReplicaSet creates another Pod. In normal application deployments, you usually manage the Deployment rather than directly managing the ReplicaSet.

**Example**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
        - name: myapp
          image: myapp:1.0.0
          ports:
            - containerPort: 8080
```

Apply:

```bash
kubectl apply -f deployment.yaml
```

Verify:

```bash
kubectl get deployment
kubectl get replicasets
kubectl get pods -l app=myapp
```

18. What happens if a Pod fails?

Kubernetes continuously observes workload state. If a Pod managed by a Deployment disappears, the controller creates a replacement to restore the desired replica count. This is one of the major differences between running containers manually and running them under an orchestrator.

**Practice**

Start with:

```bash
kubectl get pods -l app=myapp
```

Delete one:

```bash
kubectl delete pod <pod-name>
```

Then immediately watch:

```bash
kubectl get pods -l app=myapp -w
```

You should see Kubernetes create a replacement.

**Remember:** You normally replace Pods rather than repair them manually.

---

## Part 5 — Services and Kubernetes Networking

19. Why do we need a Service?

Pods are replaceable and their IP addresses can change, so clients need a stable endpoint. A Kubernetes Service provides a stable virtual IP and DNS name and selects the appropriate Pods using labels. This separates the identity of the application from the identity of individual Pod instances.

```text
Client
  ↓
Service: myapp
  ↓
Pod 1
Pod 2
Pod 3
```

If Pod 2 is replaced, the Service can continue directing traffic to the available matching Pods.

20. How does a Service find Pods?

A Service uses a selector to identify the Pods that should receive traffic. The labels on the Pods must match the selector configured on the Service.

**Example Pod labels:**

```yaml
labels:
  app: myapp
```

**Service selector:**

```yaml
selector:
  app: myapp
```

The relationship is:

```text
Service
selector: app=myapp
        ↓
Pod 1: app=myapp
Pod 2: app=myapp
Pod 3: app=myapp
```

A common production troubleshooting problem is a selector mismatch: the Pods may be healthy, but the Service selects zero endpoints.

21. How do you create a Service?

**Example:**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp
spec:
  selector:
    app: myapp
  ports:
    - port: 80
      targetPort: 8080
```

Here:

```text
Service port     = 80
Container target = 8080
```

Apply:

```bash
kubectl apply -f service.yaml
```

Inspect:

```bash
kubectl get service myapp
kubectl describe service myapp
```

Check endpoints:

```bash
kubectl get endpoints myapp
```

If the Service has no endpoints, investigate the selector and Pod labels.

22. What is the difference between `port` and `targetPort`?

`port` is the port exposed by the Service, while `targetPort` is the port on the selected Pod that receives the traffic. They do not have to be the same.

**Example:**

```yaml
ports:
  - port: 80
    targetPort: 8080
```

The flow is:

```text
Client
   ↓
Service:80
   ↓
Pod:8080
```

This allows the Service to provide a consistent application-facing port even when the application listens on a different container port.

23. What are common Service types?

`ClusterIP` provides internal cluster connectivity and is the normal default. `NodePort` exposes a service through a port on each node and is useful to understand Kubernetes networking. Production cloud architectures often use a LoadBalancer or Ingress instead. `LoadBalancer` integrates with a cloud provider to provision external load-balancing infrastructure.

**Mental model:**

```text
ClusterIP
Internal only

NodePort
Node IP + port

LoadBalancer
Cloud load balancer + Service
```

24. How does DNS work inside Kubernetes?

Kubernetes provides internal DNS so applications can normally reach Services by name instead of using IP addresses. Workloads in the appropriate namespace can resolve a Service such as `myapp`, and you can use fully qualified service names when needed. This is the Kubernetes continuation of the Docker networking principle learned on Day 13: use stable names instead of ephemeral container or Pod IPs.

**Example:**

```text
Spring Boot Pod
      ↓
http://myapp
      ↓
Kubernetes DNS
      ↓
Service
      ↓
Application Pods
```

---

## Part 6 — Configuration, Secrets and Health

25. How should application configuration be supplied?

Keep configuration that differs between environments outside the container image. Kubernetes provides ConfigMaps for non-sensitive configuration and Secrets for sensitive values. You can then deploy the same image to Dev, UAT, and Production while each environment supplies different runtime configuration.

**Example ConfigMap:**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: myapp-config
data:
  APP_ENV: "dev"
  LOG_LEVEL: "INFO"
```

A Deployment can consume these values as environment variables.

26. What is a Kubernetes Secret?

A Secret is a Kubernetes object intended for sensitive configuration such as passwords, tokens, and certificates. The word "Secret" does not automatically mean the data meets every required production protection standard. Access control, encryption at rest, RBAC, secret rotation, and integration with external secret managers still matter.

**Example:**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
type: Opaque
stringData:
  DB_USERNAME: appuser
  DB_PASSWORD: example
```

A Pod can consume these values at runtime rather than embedding them in the image.

27. What is a readiness probe?

A readiness probe answers:

> "Should this Pod receive application traffic?"

A container can be running while the application is still starting or unable to serve requests. If the readiness probe fails, Kubernetes can keep the Pod out of Service traffic while leaving the container running.

**Example:**

```yaml
readinessProbe:
  httpGet:
    path: /actuator/health/readiness
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 5
```

For a Spring Boot application, this can connect Kubernetes traffic management with Spring Boot Actuator health endpoints.

28. What is a liveness probe?

A liveness probe answers:

> "Is this container still functioning well enough to remain running?"

If a liveness probe repeatedly fails, Kubernetes may restart the container. Liveness should not simply duplicate readiness, because an application can be temporarily unable to receive traffic and still not need a restart.

**Example:**

```yaml
livenessProbe:
  httpGet:
    path: /actuator/health/liveness
    port: 8080
  periodSeconds: 10
```

**Remember:**

```text
Readiness → Should traffic reach me?
Liveness  → Should I be restarted?
```

29. What is a startup probe?

A startup probe is useful for applications that take a long time to initialize. It gives the application time to start before liveness checks become active. This prevents Kubernetes from repeatedly restarting a slow-starting application simply because it has not yet become responsive.

```yaml
startupProbe:
  httpGet:
    path: /actuator/health
    port: 8080
  failureThreshold: 30
  periodSeconds: 10
```

For slow Java applications, startup probes can be especially useful when initialization involves large caches, migrations, or dependency loading.

---

## Part 7 — Scaling and Resource Management

30. How does Kubernetes scale an application?

A Deployment can increase or decrease its replica count. For example:

```bash
kubectl scale deployment myapp --replicas=5
```

Kubernetes then attempts to maintain five Pods.

```text
Before:
Deployment
   ↓
Pod Pod Pod

After:
Deployment
   ↓
Pod Pod Pod Pod Pod
```

31. What are CPU and memory requests?

A resource request tells Kubernetes how much CPU or memory a container needs for scheduling purposes. The Scheduler uses requests when deciding whether a Pod can fit on a node. Requests therefore influence placement, capacity planning, and cluster utilization.

**Example:**

```yaml
resources:
  requests:
    cpu: "250m"
    memory: "512Mi"
```

This does not mean the container is permanently consuming exactly that amount; it establishes its requested scheduling resources.

32. What are CPU and memory limits?

Limits place an upper boundary on how much of a resource a container can consume, subject to Kubernetes and runtime behavior. Memory limits are particularly important because uncontrolled memory growth can affect other workloads on the node. Poorly chosen limits can also cause problems. Examples: container OOM (out-of-memory) kills, where Kubernetes stops a container that uses more memory than its limit allows, and CPU throttling. Base resource values on observed application behavior, not on arbitrary numbers.

**Example:**

```yaml
resources:
  requests:
    cpu: "250m"
    memory: "512Mi"
  limits:
    cpu: "1"
    memory: "1Gi"
```

33. What happens when a node does not have enough resources?

If the cluster does not have enough allocatable resources to satisfy a new Pod's requests, the Scheduler may leave the Pod in a `Pending` state. This is different from an application crash: the container may never have started because the cluster could not place it.

**Practice**

```bash
kubectl get pods
kubectl describe pod <pending-pod>
```

Look for scheduling events explaining why placement failed.

This is an important troubleshooting distinction:

```text
Pending
   ↓
Scheduling / capacity problem

CrashLoopBackOff
   ↓
Container repeatedly starts and fails

Running but not Ready
   ↓
Application readiness problem
```

---

## Part 8 — Updates, Rollouts and Self-Healing

34. How does a Deployment perform a rolling update?

When the image version changes, the Deployment creates a new ReplicaSet. It then gradually replaces Pods from the old ReplicaSet with Pods from the new one, according to its rollout strategy. This lets you update an application without taking all replicas offline at once.

**Example:**

```bash
kubectl set image deployment/myapp \
  myapp=myapp:1.1.0
```

Watch:

```bash
kubectl rollout status deployment/myapp
```

Inspect:

```bash
kubectl rollout history deployment/myapp
```

35. How do you roll back a Deployment?

If a new version causes problems, Kubernetes can roll back to a previous Deployment revision.

```bash
kubectl rollout undo deployment/myapp
```

Then:

```bash
kubectl rollout status deployment/myapp
```

The important operational point: base rollback on evidence from application health, metrics, logs, and deployment behavior. Do not assume every failed deployment requires rollback.

36. What does self-healing mean?

Self-healing means Kubernetes continuously attempts to restore the declared state when managed workloads fail or disappear. If a Pod crashes and the controller determines that another replica is required, it creates a replacement. Self-healing does not mean Kubernetes can repair application bugs; it can replace failed infrastructure/workload instances, but the underlying application failure may continue.

**Example:**

```text
Application bug
      ↓
Pod starts
      ↓
Application crashes
      ↓
Kubernetes restarts/replaces it
      ↓
New Pod
      ↓
Application crashes again
```

The platform is healthy enough to restart the workload, but the application defect still needs investigation.

---

## Part 9 — Integrated Practice

Deploy a small Spring Boot application to Kubernetes.

Start with the image you built on Day 13:

```text
Spring Boot
    ↓
Dockerfile
    ↓
Container Image
    ↓
Registry
```

Create a Deployment with three replicas:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
        - name: myapp
          image: myapp:1.0.0
          ports:
            - containerPort: 8080
          resources:
            requests:
              cpu: "250m"
              memory: "512Mi"
            limits:
              cpu: "1"
              memory: "1Gi"
          readinessProbe:
            httpGet:
              path: /actuator/health/readiness
              port: 8080
```

Create a Service:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp
spec:
  selector:
    app: myapp
  ports:
    - port: 80
      targetPort: 8080
```

Apply:

```bash
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
```

Inspect:

```bash
kubectl get deployments
kubectl get replicasets
kubectl get pods -o wide
kubectl get services
```

Then deliberately break the system.

Delete a Pod:

```bash
kubectl delete pod <pod-name>
```

Observe Kubernetes replace it.

Break the Service selector:

```yaml
selector:
  app: wrong-name
```

Apply the change and inspect:

```bash
kubectl get endpoints myapp
```

You should find that the Service has no matching endpoints.

Break the application image:

```yaml
image: myapp:does-not-exist
```

Then inspect:

```bash
kubectl get pods
kubectl describe pod <pod-name>
```

Look for image-pull errors.

Finally, deploy a new version:

```bash
kubectl set image deployment/myapp \
  myapp=myapp:1.1.0

kubectl rollout status deployment/myapp
```

Your final mental flow should be:

```text
Git Commit
    ↓
Build
    ↓
Container Image
    ↓
Registry
    ↓
Kubernetes Deployment
    ↓
ReplicaSet
    ↓
Pods
    ↓
Container Runtime
    ↓
Application

Traffic:
Client
   ↓
Service
   ↓
Ready Pods

Configuration:
ConfigMap / Secret
   ↓
Pod

Health:
Readiness / Liveness / Startup
   ↓
Traffic + Restart decisions
```

---

**5-Minute Interview Recall**

1. What problem does Kubernetes solve?
2. What is desired state?
3. What is a Kubernetes cluster?
4. What does the API Server do?
5. What is etcd?
6. What does the Scheduler do?
7. What does the Controller Manager do?
8. What does the kubelet do?
9. Where does the container runtime fit?
10. What is a Pod?
11. Why does Kubernetes use Pods instead of directly managing containers?
12. Can a Pod contain multiple containers?
13. Why are Pod IPs not normally used as permanent endpoints?
14. What is a Deployment?
15. What is a ReplicaSet?
16. What happens when a Pod managed by a Deployment is deleted?
17. Why do we need a Service?
18. How does a Service find Pods?
19. What is the difference between `port` and `targetPort`?
20. What is ClusterIP?
21. How does Kubernetes DNS help applications?
22. What is a ConfigMap?
23. What is a Secret?
24. What is the difference between readiness and liveness?
25. Why is a startup probe useful?
26. What are resource requests?
27. What are resource limits?
28. Why might a Pod remain Pending?
29. What happens during a rolling update?
30. How does rollback work?
31. What does self-healing actually mean?
32. What is the difference between a container failure and an application failure?

**Core Mental Model**

```text
                  Kubernetes API
                       ↓
              Desired State
                       ↓
        ┌──────────────┴──────────────┐
        ↓                             ↓
   Controllers                    Scheduler
        ↓                             ↓
 Deployment                    Select Node
        ↓                             ↓
 ReplicaSet                    kubelet
        ↓                             ↓
      Pods                 Container Runtime
        ↓                             ↓
    Containers  ←─────────────────────┘
        ↓
   Application

Traffic:
Client → Service → Ready Pods

Configuration:
ConfigMap / Secret → Pod

Health:
Probes → Traffic / Restart Decisions
```

The most important Kubernetes idea is:

> You declare what you want, and Kubernetes continuously works to make the actual system match that desired state.

**Cleanup**

If you used a dedicated lab namespace:

```bash
kubectl delete namespace docker-lab
```

If you deployed into the default namespace, remove the resources individually:

```bash
kubectl delete deployment myapp
kubectl delete service myapp
```

Verify:

```bash
kubectl get deployments
kubectl get pods
kubectl get services
```

Do not delete shared cluster resources that belong to other workloads.

## Answers to practice

### 1. Talk to the API with `kubectl cluster-info`, `get nodes`, and `get pods`

<details>
<summary>Answer</summary>

Run `kubectl cluster-info`. Then run `kubectl get nodes`. Then run `kubectl get pods -A`. Each command goes to the Kubernetes API Server.

`cluster-info` shows control-plane endpoints. `get nodes` lists worker capacity. `get pods -A` lists workloads in all namespaces. You are not talking to a node by hand. You are asking the API for cluster state.

</details>

### 2. Create a Pod, then `describe` it, then delete it

<details>
<summary>Answer</summary>

Apply a Pod manifest with `kubectl apply -f pod.yaml`. Inspect with `kubectl get pod nginx`, `kubectl describe pod nginx`, and `kubectl logs nginx`. `describe` shows events, IP, and container status.

Delete with `kubectl delete pod nginx`. This Pod has no Deployment. Kubernetes does not recreate it. That is why production rarely creates standalone Pods.

</details>

### 3. Apply a Deployment and list ReplicaSets and Pods

<details>
<summary>Answer</summary>

Apply with `kubectl apply -f deployment.yaml`. Then run `kubectl get deployment`, `kubectl get replicasets`, and `kubectl get pods -l app=myapp`. You should see three Pods when `replicas: 3`.

The Deployment owns a ReplicaSet. The ReplicaSet owns the Pods. Manage the Deployment. Do not manage ReplicaSets by hand in normal operations.

</details>

### 4. Delete a Pod from a Deployment and watch the replacement

<details>
<summary>Answer</summary>

Run `kubectl get pods -l app=myapp`. Delete one with `kubectl delete pod <pod-name>`. Immediately run `kubectl get pods -l app=myapp -w`.

Kubernetes sees fewer than three healthy Pods. The ReplicaSet creates a replacement. You replace Pods. You do not repair that instance by hand.

</details>

### 5. Create a Service and confirm endpoints

<details>
<summary>Answer</summary>

Apply the Service with `kubectl apply -f service.yaml`. Run `kubectl get service myapp` and `kubectl describe service myapp`. Then run `kubectl get endpoints myapp`.

The Service selects Pods with `app: myapp`. Port `80` forwards to `targetPort` `8080`. If endpoints are empty, the selector does not match Pod labels. Healthy Pods then still receive no Service traffic.

</details>

### 6. Use `kubectl describe` on a Pending Pod

<details>
<summary>Answer</summary>

Run `kubectl get pods`. If a Pod stays `Pending`, run `kubectl describe pod <pending-pod>`. Read the scheduling events.

Pending usually means the Scheduler could not place the Pod. Requests may not fit node capacity, or a constraint may block the node. That is not a crash. The container may never have started.

</details>

### 7. Roll out a new image and read rollout status

<details>
<summary>Answer</summary>

Run `kubectl set image deployment/myapp myapp=myapp:1.1.0`. Then run `kubectl rollout status deployment/myapp` and `kubectl rollout history deployment/myapp`.

The Deployment creates a new ReplicaSet and replaces Pods gradually. Old replicas leave as new ones become ready. You update without taking every replica offline at once.

</details>

### 8. Roll back a Deployment after a bad version

<details>
<summary>Answer</summary>

Run `kubectl rollout undo deployment/myapp`. Then run `kubectl rollout status deployment/myapp`. Kubernetes returns to a previous revision.

Base the decision on health, metrics, logs, and rollout behavior. Do not assume every failed deploy needs undo. Fix forward when that is safer.

</details>

### 9. Integrated Practice — Deploy three replicas and a Service

<details>
<summary>Answer</summary>

Start from the Day 13 image `myapp:1.0.0` in a registry. Apply the Deployment with three replicas, resource requests and limits, and a readiness probe on `/actuator/health/readiness`. Apply the Service that selects `app: myapp` and maps port `80` to `8080`.

Run `kubectl apply -f deployment.yaml` and `kubectl apply -f service.yaml`. Then run `kubectl get deployments`, `kubectl get replicasets`, `kubectl get pods -o wide`, and `kubectl get services`. Confirm three Pods and a ClusterIP Service.

</details>

### 10. Integrated Practice — Delete a Pod and break the Service selector

<details>
<summary>Answer</summary>

Delete one Pod with `kubectl delete pod <pod-name>`. Watch Kubernetes create a replacement. Desired replica count is still three.

Change the Service selector to `app: wrong-name` and apply it. Run `kubectl get endpoints myapp`. Endpoints should be empty. The Pods can be healthy and still receive no traffic, because labels no longer match.

</details>

### 11. Integrated Practice — Bad image, then a rolling update

<details>
<summary>Answer</summary>

Set `image: myapp:does-not-exist`. Run `kubectl get pods` and `kubectl describe pod <pod-name>`. You should see image-pull errors. The control plane cannot run a container it cannot pull.

Then deploy a real new version with `kubectl set image deployment/myapp myapp=myapp:1.1.0` and `kubectl rollout status deployment/myapp`. Follow Git → image → registry → Deployment → ReplicaSet → Pods → runtime → application. Clients reach Ready Pods through the Service.

</details>

### 12. Integrated Practice — Configuration, health, and traffic path

<details>
<summary>Answer</summary>

Inject non-secret settings from a ConfigMap and sensitive values from a Secret. Readiness decides whether the Service may send traffic. Liveness decides whether Kubernetes should restart the container. A startup probe protects slow Java startup.

The traffic path is Client → Service → Ready Pods. Self-healing replaces missing Pods. It does not fix an application bug that crashes every new Pod.

</details>

### 13. Interview Recall — What problem does Kubernetes solve?

<details>
<summary>Answer</summary>

One container on Docker is simple. Many containers across servers need placement, restarts, scaling, stable endpoints, and safe rollouts.

You declare the state you want. Kubernetes continuously works to keep reality matching that state.

</details>

### 14. Interview Recall — What is desired state?

<details>
<summary>Answer</summary>

Desired state is what you declare, such as `replicas: 3`. Kubernetes compares that with actual running Pods.

If actual is two, it creates another Pod. Kubernetes is a reconciliation system, not only a command executor.

</details>

### 15. Interview Recall — What is a Kubernetes cluster?

<details>
<summary>Answer</summary>

A cluster is machines plus control-plane components that run containerized workloads. The control plane decides. Worker nodes run Pods.

The control plane includes the API Server, Scheduler, Controller Manager, and etcd. Each worker runs kubelet, a container runtime, and Pods.

</details>

### 16. Interview Recall — What does the API Server do?

<details>
<summary>Answer</summary>

The API Server is the front door of the control plane. `kubectl`, CI/CD, and controllers all talk to it.

It authenticates, authorizes, validates objects, and exposes cluster state. `kubectl cluster-info` and `kubectl get` use this API.

</details>

### 17. Interview Recall — What is etcd?

<details>
<summary>Answer</summary>

etcd is the distributed key-value store for cluster state. Kubernetes persists objects such as Deployments, Services, ConfigMaps, and Secrets through the control plane into that store.

On AKS or EKS the provider operates etcd. Loss of control-plane state is still a cluster-level incident.

</details>

### 18. Interview Recall — What does the Scheduler do?

<details>
<summary>Answer</summary>

The Scheduler chooses which worker node should run a new Pod. It checks resources, constraints, affinity, and taints.

It does not start the container. The kubelet on the chosen node does that.

</details>

### 19. Interview Recall — What does the Controller Manager do?

<details>
<summary>Answer</summary>

Controllers watch the cluster and drive actual state toward desired state. A Deployment controller keeps the replica count through ReplicaSets.

That loop is why Kubernetes can replace a deleted or failed Pod.

</details>

### 20. Interview Recall — What does the kubelet do?

<details>
<summary>Answer</summary>

The kubelet is the node agent. It receives the Pod spec for that node and works with the container runtime to run containers.

It reports node and workload status to the control plane. It does not make cluster-wide scheduling decisions.

</details>

### 21. Interview Recall — Where does the container runtime fit?

<details>
<summary>Answer</summary>

Kubernetes does not execute the process itself. kubelet talks to a compatible runtime, commonly containerd, through the runtime interface.

The chain is Kubernetes → kubelet → container runtime → Linux → container process. This continues the Day 13 runtime model.

</details>

### 22. Interview Recall — What is a Pod?

<details>
<summary>Answer</summary>

A Pod is the smallest deployable unit in Kubernetes. It holds one or more containers scheduled together on one node.

Those containers share a network namespace and can share volumes. Docker uses a container as the unit. Kubernetes schedules Pods.

</details>

### 23. Interview Recall — Why Pods instead of managing containers directly?

<details>
<summary>Answer</summary>

A Pod gives shared networking, storage, lifecycle, and scheduling for tightly coupled containers. Kubernetes then has one abstraction to place.

The runtime details stay behind that unit. You schedule a Pod, not a raw container process.

</details>

### 24. Interview Recall — Can a Pod contain multiple containers?

<details>
<summary>Answer</summary>

Yes, when those containers must share lifecycle, network, or volumes. A sidecar next to the main application is the usual case.

They share the Pod IP and can use `localhost`. Do not put unrelated applications in one Pod. Scaling and failure handling then become harder.

</details>

### 25. Interview Recall — Why Pod IPs are not permanent endpoints

<details>
<summary>Answer</summary>

A Pod IP comes from the cluster network and dies with the Pod. A replacement Pod often gets a new IP.

Use a Service name, not a stored Pod IP. Clients must survive replacement.

</details>

### 26. Interview Recall — What is a Deployment?

<details>
<summary>Answer</summary>

A Deployment declares the desired state of a stateless application. It sets image, replica count, Pod template, labels, and update strategy.

Kubernetes creates ReplicaSets from it. Those ReplicaSets keep the Pods.

</details>

### 27. Interview Recall — What is a ReplicaSet?

<details>
<summary>Answer</summary>

A ReplicaSet keeps a stated number of matching Pods. If one Pod disappears, it creates another.

You normally manage the Deployment. You do not edit ReplicaSets directly for ordinary application deploys.

</details>

### 28. Interview Recall — What happens when you delete a Pod from a Deployment?

<details>
<summary>Answer</summary>

The controller sees actual replicas below desired count. It creates a new Pod. `kubectl get pods -l app=myapp -w` shows the replacement.

That is the difference from a standalone Pod, which stays gone after `kubectl delete pod`.

</details>

### 29. Interview Recall — Why we need a Service

<details>
<summary>Answer</summary>

Pods are replaceable and their IPs change. A Service gives a stable virtual IP and DNS name.

It selects Pods by labels. Clients target `myapp`, not a single Pod instance.

</details>

### 30. Interview Recall — How a Service finds Pods

<details>
<summary>Answer</summary>

The Service selector must match Pod labels. `selector: app: myapp` matches Pods labeled `app: myapp`.

If labels do not match, endpoints stay empty. The Pods can be Running and still receive no traffic.

</details>

### 31. Interview Recall — `port` versus `targetPort`

<details>
<summary>Answer</summary>

`port` is the port on the Service. `targetPort` is the port on the Pod that receives traffic. They do not have to match.

A client can call Service port `80` while the container listens on `8080`.

</details>

### 32. Interview Recall — What is ClusterIP?

<details>
<summary>Answer</summary>

ClusterIP is the default Service type. It provides an internal virtual IP inside the cluster.

It is not for direct internet clients. NodePort and LoadBalancer expose different external paths.

</details>

### 33. Interview Recall — How Kubernetes DNS helps applications

<details>
<summary>Answer</summary>

Cluster DNS lets workloads use Service names such as `myapp` instead of Pod IPs. Fully qualified names work across namespaces when needed.

This continues the Docker lesson: use stable names, not ephemeral addresses.

</details>

### 34. Interview Recall — What is a ConfigMap?

<details>
<summary>Answer</summary>

A ConfigMap holds non-sensitive configuration, such as `APP_ENV` or log level. A Deployment can inject those values as environment variables.

Keep environment differences out of the image. Deploy the same image to Dev, UAT, and Production.

</details>

### 35. Interview Recall — What is a Secret?

<details>
<summary>Answer</summary>

A Secret holds sensitive values such as passwords, tokens, and certificates. The Pod consumes them at runtime instead of baking them into the image.

The object name does not finish the security job. You still need RBAC, encryption at rest, rotation, and often an external secret manager.

</details>

### 36. Interview Recall — Readiness versus liveness

<details>
<summary>Answer</summary>

Readiness asks whether the Pod should receive traffic. A failed readiness probe keeps the Pod out of the Service while the container may still run.

Liveness asks whether the container should be restarted. Do not copy readiness into liveness. A temporary unready app does not always need a restart.

</details>

### 37. Interview Recall — Why a startup probe is useful

<details>
<summary>Answer</summary>

A startup probe gives a slow application time to initialize before liveness starts. Java applications that load caches or run migrations often need this.

Without it, Kubernetes can restart a healthy but slow-starting container.

</details>

### 38. Interview Recall — What are resource requests?

<details>
<summary>Answer</summary>

Requests tell the Scheduler how much CPU and memory the container needs for placement. Example: `cpu: "250m"` and `memory: "512Mi"`.

They affect capacity planning. They are not a promise that the process always uses exactly that amount.

</details>

### 39. Interview Recall — What are resource limits?

<details>
<summary>Answer</summary>

Limits cap how much CPU or memory a container may use. Memory over the limit can cause an OOM kill. CPU over the limit can throttle.

Set values from observed behavior. Bad limits cause new failures.

</details>

### 40. Interview Recall — Why a Pod might remain Pending

<details>
<summary>Answer</summary>

The Scheduler cannot place it, usually because requests do not fit remaining node capacity or a constraint excludes nodes.

Run `kubectl describe pod` and read scheduling events. Pending is not CrashLoopBackOff. The container may never have started.

</details>

### 41. Interview Recall — What happens during a rolling update?

<details>
<summary>Answer</summary>

The Deployment creates a new ReplicaSet for the new image. It adds new Pods and removes old Pods according to the rollout strategy.

Some replicas stay up while others update. That avoids taking the whole application offline at once.

</details>

### 42. Interview Recall — How rollback works

<details>
<summary>Answer</summary>

`kubectl rollout undo deployment/myapp` returns the Deployment to a previous revision. Then watch `kubectl rollout status deployment/myapp`.

Use evidence from health, metrics, and logs. Rollback is one response, not the only response.

</details>

### 43. Interview Recall — What self-healing actually means

<details>
<summary>Answer</summary>

Self-healing means Kubernetes restores declared replica count when a managed Pod fails or disappears. It creates a replacement.

It does not repair application bugs. A crashing app will crash in the new Pod too until you fix the code or configuration.

</details>

### 44. Interview Recall — Container failure versus application failure

<details>
<summary>Answer</summary>

A container or Pod failure is an instance problem: the process exited, the node failed, or the Pod was deleted. Kubernetes can replace that instance.

An application failure is a defect in code or config. Replacements keep failing. Platform health is not the same as application health.

</details>
