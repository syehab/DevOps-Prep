# Day 14 — Kubernetes Mental Model

## What you will learn

Docker taught us how to package and run a container. Kubernetes becomes important when we need to run many containers reliably across multiple machines. A Senior/Lead DevOps engineer should understand what Kubernetes is actually managing, why Pods exist, how Deployments maintain desired state, how Services provide stable networking, how configuration and secrets reach workloads, and what happens when a Pod fails. The goal today is not to memorize YAML; it is to build the mental model that makes Kubernetes YAML understandable.

---

## Part 1 — Why Kubernetes Exists

1. What problem does Kubernetes solve?

Running one container with Docker is simple. Running hundreds of containers across many servers introduces problems such as deciding where containers should run, replacing failed containers, scaling applications, exposing them through stable network endpoints, performing rolling deployments, and keeping the actual system aligned with the desired configuration. Kubernetes provides a control system that continuously manages these concerns. Instead of manually telling individual servers what to do, you describe the state you want and Kubernetes works toward maintaining that state.

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

`etcd` is the distributed key-value store used by Kubernetes to persist important cluster state. Kubernetes stores information about objects such as Deployments, Services, ConfigMaps, Secrets, and other resources through the API/control-plane architecture, with etcd providing durable storage for that state. If you are using a managed Kubernetes service, the cloud provider generally operates etcd for you, but as a Senior/Lead engineer you should understand that loss or corruption of control-plane state is a serious cluster-level concern.

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

A Pod is the smallest deployable unit in Kubernetes. It represents one or more containers that are scheduled together onto the same node and share certain resources, including a network namespace and optionally storage volumes. In the common case, a Pod contains one main application container, but sidecar patterns can place tightly coupled helper containers in the same Pod.

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

A Pod receives an IP address from the Kubernetes cluster network. Containers inside the same Pod share that network namespace and therefore share the Pod's IP. Pod IPs are generally temporary because Pods are replaceable; a replacement Pod can receive a different IP. Applications should therefore normally use Services rather than storing Pod IPs as permanent endpoints.

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

A ReplicaSet maintains a specified number of matching Pods. If the desired count is three and one Pod disappears, the ReplicaSet causes another Pod to be created. In normal application deployments, you usually manage the Deployment rather than directly managing the ReplicaSet.

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

Kubernetes continuously observes workload state. If a Pod managed by a Deployment disappears, the controller creates a replacement so that the desired replica count is restored. This is one of the major differences between running containers manually and running them under an orchestrator.

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

`ClusterIP` provides internal cluster connectivity and is the normal default. `NodePort` exposes a service through a port on each node and is useful for understanding Kubernetes networking, although production cloud architectures often use a LoadBalancer or Ingress instead. `LoadBalancer` integrates with a cloud provider to provision external load-balancing infrastructure.

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

Kubernetes provides internal DNS so applications can normally reach Services by name instead of using IP addresses. A Service such as `myapp` can be resolved by workloads in the appropriate namespace, and fully qualified service names can be used when needed. This is the Kubernetes continuation of the Docker networking principle learned on Day 13: use stable names instead of ephemeral container or Pod IPs.

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

Configuration that differs between environments should normally be kept outside the container image. Kubernetes provides ConfigMaps for non-sensitive configuration and Secrets for sensitive values. This allows the same image to be deployed to Dev, UAT, and Production while receiving different runtime configuration.

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

A Secret is a Kubernetes object intended for sensitive configuration such as passwords, tokens, and certificates. It is important to understand that the word "Secret" does not automatically mean the data is protected to every required production standard; access control, encryption at rest, RBAC, secret rotation, and integration with external secret managers still matter.

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

If a liveness probe repeatedly fails, Kubernetes may restart the container. Liveness should not simply duplicate readiness because an application can be temporarily unable to receive traffic without needing to be restarted.

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

Limits place an upper boundary on how much of a resource a container can consume, subject to Kubernetes and runtime behavior. Memory limits are particularly important because uncontrolled memory growth can affect other workloads on the node. Poorly chosen limits can also cause problems, such as container OOM kills or CPU throttling, so resource values should be based on observed application behavior rather than arbitrary numbers.

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

When the image version changes, the Deployment creates a new ReplicaSet and gradually replaces Pods from the old ReplicaSet with Pods from the new one according to its rollout strategy. This allows an application to be updated without necessarily taking all replicas offline at once.

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

The important operational point is that rollback should be based on evidence from application health, metrics, logs, and deployment behavior rather than simply assuming every failed deployment requires rollback.

36. What does self-healing mean?

Self-healing means Kubernetes continuously attempts to restore the declared state when managed workloads fail or disappear. If a Pod crashes and the controller determines that another replica is required, a replacement is created. Self-healing does not mean Kubernetes can repair application bugs; it can replace failed infrastructure/workload instances, but the underlying application failure may continue.

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

