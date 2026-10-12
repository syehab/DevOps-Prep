# Day 14 — Questions and answers

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Then answer each item below before you open the Answer block. After that, do the lab in [03-implementation.md](03-implementation.md).

Write your own answer first. Open the Answer block only after you try. Keep the original numbering.

---

## 1. Talk to the API with `kubectl cluster-info`, `get nodes`, and `get pods`

**Practice**

```bash
kubectl cluster-info
kubectl get nodes
kubectl get pods -A
```

Every one of these commands ultimately interacts with the Kubernetes API.

<details>
<summary>Answer</summary>

Run `kubectl cluster-info`. Then run `kubectl get nodes`. Then run `kubectl get pods -A`. Each command goes to the Kubernetes API Server.

`cluster-info` shows control-plane endpoints. `get nodes` lists worker capacity. `get pods -A` lists workloads in all namespaces. You are not talking to a node by hand. You are asking the API for cluster state.

</details>

---

## 2. Create a Pod, then `describe` it, then delete it

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

<details>
<summary>Answer</summary>

Apply a Pod manifest with `kubectl apply -f pod.yaml`. Inspect with `kubectl get pod nginx`, `kubectl describe pod nginx`, and `kubectl logs nginx`. `describe` shows events, IP, and container status.

Delete with `kubectl delete pod nginx`. This Pod has no Deployment. Kubernetes does not recreate it. That is why production rarely creates standalone Pods.

</details>

---

## 3. Apply a Deployment and list ReplicaSets and Pods

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

<details>
<summary>Answer</summary>

Apply with `kubectl apply -f deployment.yaml`. Then run `kubectl get deployment`, `kubectl get replicasets`, and `kubectl get pods -l app=myapp`. You should see three Pods when `replicas: 3`.

The Deployment owns a ReplicaSet. The ReplicaSet owns the Pods. Manage the Deployment. Do not manage ReplicaSets by hand in normal operations.

</details>

---

## 4. Delete a Pod from a Deployment and watch the replacement

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

<details>
<summary>Answer</summary>

Run `kubectl get pods -l app=myapp`. Delete one with `kubectl delete pod <pod-name>`. Immediately run `kubectl get pods -l app=myapp -w`.

Kubernetes sees fewer than three healthy Pods. The ReplicaSet creates a replacement. You replace Pods. You do not repair that instance by hand.

</details>

---

## 5. Create a Service and confirm endpoints

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

<details>
<summary>Answer</summary>

Apply the Service with `kubectl apply -f service.yaml`. Run `kubectl get service myapp` and `kubectl describe service myapp`. Then run `kubectl get endpoints myapp`.

The Service selects Pods with `app: myapp`. Port `80` forwards to `targetPort` `8080`. If endpoints are empty, the selector does not match Pod labels. Healthy Pods then still receive no Service traffic.

</details>

---

## 6. Use `kubectl describe` on a Pending Pod

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

<details>
<summary>Answer</summary>

Run `kubectl get pods`. If a Pod stays `Pending`, run `kubectl describe pod <pending-pod>`. Read the scheduling events.

Pending usually means the Scheduler could not place the Pod. Requests may not fit node capacity, or a constraint may block the node. That is not a crash. The container may never have started.

</details>

---

## 7. Roll out a new image and read rollout status

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

<details>
<summary>Answer</summary>

Run `kubectl set image deployment/myapp myapp=myapp:1.1.0`. Then run `kubectl rollout status deployment/myapp` and `kubectl rollout history deployment/myapp`.

The Deployment creates a new ReplicaSet and replaces Pods gradually. Old replicas leave as new ones become ready. You update without taking every replica offline at once.

</details>

---

## 8. Roll back a Deployment after a bad version

If a new version causes problems, Kubernetes can roll back to a previous Deployment revision.

```bash
kubectl rollout undo deployment/myapp
```

Then:

```bash
kubectl rollout status deployment/myapp
```

The important operational point: base rollback on evidence from application health, metrics, logs, and deployment behavior. Do not assume every failed deployment requires rollback.

<details>
<summary>Answer</summary>

Run `kubectl rollout undo deployment/myapp`. Then run `kubectl rollout status deployment/myapp`. Kubernetes returns to a previous revision.

Base the decision on health, metrics, logs, and rollout behavior. Do not assume every failed deploy needs undo. Fix forward when that is safer.

</details>

---

## 9. Integrated Practice — Deploy three replicas and a Service

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

<details>
<summary>Answer</summary>

Start from the Day 13 image `myapp:1.0.0` in a registry. Apply the Deployment with three replicas, resource requests and limits, and a readiness probe on `/actuator/health/readiness`. Apply the Service that selects `app: myapp` and maps port `80` to `8080`.

Run `kubectl apply -f deployment.yaml` and `kubectl apply -f service.yaml`. Then run `kubectl get deployments`, `kubectl get replicasets`, `kubectl get pods -o wide`, and `kubectl get services`. Confirm three Pods and a ClusterIP Service.

</details>

---

## 10. Integrated Practice — Delete a Pod and break the Service selector

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

<details>
<summary>Answer</summary>

Delete one Pod with `kubectl delete pod <pod-name>`. Watch Kubernetes create a replacement. Desired replica count is still three.

Change the Service selector to `app: wrong-name` and apply it. Run `kubectl get endpoints myapp`. Endpoints should be empty. The Pods can be healthy and still receive no traffic, because labels no longer match.

</details>

---

## 11. Integrated Practice — Bad image, then a rolling update

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

<details>
<summary>Answer</summary>

Set `image: myapp:does-not-exist`. Run `kubectl get pods` and `kubectl describe pod <pod-name>`. You should see image-pull errors. The control plane cannot run a container it cannot pull.

Then deploy a real new version with `kubectl set image deployment/myapp myapp=myapp:1.1.0` and `kubectl rollout status deployment/myapp`. Follow Git → image → registry → Deployment → ReplicaSet → Pods → runtime → application. Clients reach Ready Pods through the Service.

</details>

---

## 12. Integrated Practice — Configuration, health, and traffic path

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

<details>
<summary>Answer</summary>

Inject non-secret settings from a ConfigMap and sensitive values from a Secret. Readiness decides whether the Service may send traffic. Liveness decides whether Kubernetes should restart the container. A startup probe protects slow Java startup.

The traffic path is Client → Service → Ready Pods. Self-healing replaces missing Pods. It does not fix an application bug that crashes every new Pod.

</details>

---

## 13. Interview Recall — What problem does Kubernetes solve?

1. What problem does Kubernetes solve?

<details>
<summary>Answer</summary>

One container on Docker is simple. Many containers across servers need placement, restarts, scaling, stable endpoints, and safe rollouts.

You declare the state you want. Kubernetes continuously works to keep reality matching that state.

</details>

---

## 14. Interview Recall — What is desired state?

2. What is desired state?

<details>
<summary>Answer</summary>

Desired state is what you declare, such as `replicas: 3`. Kubernetes compares that with actual running Pods.

If actual is two, it creates another Pod. Kubernetes is a reconciliation system, not only a command executor.

</details>

---

## 15. Interview Recall — What is a Kubernetes cluster?

3. What is a Kubernetes cluster?

<details>
<summary>Answer</summary>

A cluster is machines plus control-plane components that run containerized workloads. The control plane decides. Worker nodes run Pods.

The control plane includes the API Server, Scheduler, Controller Manager, and etcd. Each worker runs kubelet, a container runtime, and Pods.

</details>

---

## 16. Interview Recall — What does the API Server do?

4. What does the API Server do?

<details>
<summary>Answer</summary>

The API Server is the front door of the control plane. `kubectl`, CI/CD, and controllers all talk to it.

It authenticates, authorizes, validates objects, and exposes cluster state. `kubectl cluster-info` and `kubectl get` use this API.

</details>

---

## 17. Interview Recall — What is etcd?

5. What is etcd?

<details>
<summary>Answer</summary>

etcd is the distributed key-value store for cluster state. Kubernetes persists objects such as Deployments, Services, ConfigMaps, and Secrets through the control plane into that store.

On AKS or EKS the provider operates etcd. Loss of control-plane state is still a cluster-level incident.

</details>

---

## 18. Interview Recall — What does the Scheduler do?

6. What does the Scheduler do?

<details>
<summary>Answer</summary>

The Scheduler chooses which worker node should run a new Pod. It checks resources, constraints, affinity, and taints.

It does not start the container. The kubelet on the chosen node does that.

</details>

---

## 19. Interview Recall — What does the Controller Manager do?

7. What does the Controller Manager do?

<details>
<summary>Answer</summary>

Controllers watch the cluster and drive actual state toward desired state. A Deployment controller keeps the replica count through ReplicaSets.

That loop is why Kubernetes can replace a deleted or failed Pod.

</details>

---

## 20. Interview Recall — What does the kubelet do?

8. What does the kubelet do?

<details>
<summary>Answer</summary>

The kubelet is the node agent. It receives the Pod spec for that node and works with the container runtime to run containers.

It reports node and workload status to the control plane. It does not make cluster-wide scheduling decisions.

</details>

---

## 21. Interview Recall — Where does the container runtime fit?

9. Where does the container runtime fit?

<details>
<summary>Answer</summary>

Kubernetes does not execute the process itself. kubelet talks to a compatible runtime, commonly containerd, through the runtime interface.

The chain is Kubernetes → kubelet → container runtime → Linux → container process. This continues the Day 13 runtime model.

</details>

---

## 22. Interview Recall — What is a Pod?

10. What is a Pod?

<details>
<summary>Answer</summary>

A Pod is the smallest deployable unit in Kubernetes. It holds one or more containers scheduled together on one node.

Those containers share a network namespace and can share volumes. Docker uses a container as the unit. Kubernetes schedules Pods.

</details>

---

## 23. Interview Recall — Why Pods instead of managing containers directly?

11. Why does Kubernetes use Pods instead of directly managing containers?

<details>
<summary>Answer</summary>

A Pod gives shared networking, storage, lifecycle, and scheduling for tightly coupled containers. Kubernetes then has one abstraction to place.

The runtime details stay behind that unit. You schedule a Pod, not a raw container process.

</details>

---

## 24. Interview Recall — Can a Pod contain multiple containers?

12. Can a Pod contain multiple containers?

<details>
<summary>Answer</summary>

Yes, when those containers must share lifecycle, network, or volumes. A sidecar next to the main application is the usual case.

They share the Pod IP and can use `localhost`. Do not put unrelated applications in one Pod. Scaling and failure handling then become harder.

</details>

---

## 25. Interview Recall — Why Pod IPs are not permanent endpoints

13. Why are Pod IPs not normally used as permanent endpoints?

<details>
<summary>Answer</summary>

A Pod IP comes from the cluster network and dies with the Pod. A replacement Pod often gets a new IP.

Use a Service name, not a stored Pod IP. Clients must survive replacement.

</details>

---

## 26. Interview Recall — What is a Deployment?

14. What is a Deployment?

<details>
<summary>Answer</summary>

A Deployment declares the desired state of a stateless application. It sets image, replica count, Pod template, labels, and update strategy.

Kubernetes creates ReplicaSets from it. Those ReplicaSets keep the Pods.

</details>

---

## 27. Interview Recall — What is a ReplicaSet?

15. What is a ReplicaSet?

<details>
<summary>Answer</summary>

A ReplicaSet keeps a stated number of matching Pods. If one Pod disappears, it creates another.

You normally manage the Deployment. You do not edit ReplicaSets directly for ordinary application deploys.

</details>

---

## 28. Interview Recall — What happens when you delete a Pod from a Deployment?

16. What happens when a Pod managed by a Deployment is deleted?

<details>
<summary>Answer</summary>

The controller sees actual replicas below desired count. It creates a new Pod. `kubectl get pods -l app=myapp -w` shows the replacement.

That is the difference from a standalone Pod, which stays gone after `kubectl delete pod`.

</details>

---

## 29. Interview Recall — Why we need a Service

17. Why do we need a Service?

<details>
<summary>Answer</summary>

Pods are replaceable and their IPs change. A Service gives a stable virtual IP and DNS name.

It selects Pods by labels. Clients target `myapp`, not a single Pod instance.

</details>

---

## 30. Interview Recall — How a Service finds Pods

18. How does a Service find Pods?

<details>
<summary>Answer</summary>

The Service selector must match Pod labels. `selector: app: myapp` matches Pods labeled `app: myapp`.

If labels do not match, endpoints stay empty. The Pods can be Running and still receive no traffic.

</details>

---

## 31. Interview Recall — `port` versus `targetPort`

19. What is the difference between `port` and `targetPort`?

<details>
<summary>Answer</summary>

`port` is the port on the Service. `targetPort` is the port on the Pod that receives traffic. They do not have to match.

A client can call Service port `80` while the container listens on `8080`.

</details>

---

## 32. Interview Recall — What is ClusterIP?

20. What is ClusterIP?

<details>
<summary>Answer</summary>

ClusterIP is the default Service type. It provides an internal virtual IP inside the cluster.

It is not for direct internet clients. NodePort and LoadBalancer expose different external paths.

</details>

---

## 33. Interview Recall — How Kubernetes DNS helps applications

21. How does Kubernetes DNS help applications?

<details>
<summary>Answer</summary>

Cluster DNS lets workloads use Service names such as `myapp` instead of Pod IPs. Fully qualified names work across namespaces when needed.

This continues the Docker lesson: use stable names, not ephemeral addresses.

</details>

---

## 34. Interview Recall — What is a ConfigMap?

22. What is a ConfigMap?

<details>
<summary>Answer</summary>

A ConfigMap holds non-sensitive configuration, such as `APP_ENV` or log level. A Deployment can inject those values as environment variables.

Keep environment differences out of the image. Deploy the same image to Dev, UAT, and Production.

</details>

---

## 35. Interview Recall — What is a Secret?

23. What is a Secret?

<details>
<summary>Answer</summary>

A Secret holds sensitive values such as passwords, tokens, and certificates. The Pod consumes them at runtime instead of baking them into the image.

The object name does not finish the security job. You still need RBAC, encryption at rest, rotation, and often an external secret manager.

</details>

---

## 36. Interview Recall — Readiness versus liveness

24. What is the difference between readiness and liveness?

<details>
<summary>Answer</summary>

Readiness asks whether the Pod should receive traffic. A failed readiness probe keeps the Pod out of the Service while the container may still run.

Liveness asks whether the container should be restarted. Do not copy readiness into liveness. A temporary unready app does not always need a restart.

</details>

---

## 37. Interview Recall — Why a startup probe is useful

25. Why is a startup probe useful?

<details>
<summary>Answer</summary>

A startup probe gives a slow application time to initialize before liveness starts. Java applications that load caches or run migrations often need this.

Without it, Kubernetes can restart a healthy but slow-starting container.

</details>

---

## 38. Interview Recall — What are resource requests?

26. What are resource requests?

<details>
<summary>Answer</summary>

Requests tell the Scheduler how much CPU and memory the container needs for placement. Example: `cpu: "250m"` and `memory: "512Mi"`.

They affect capacity planning. They are not a promise that the process always uses exactly that amount.

</details>

---

## 39. Interview Recall — What are resource limits?

27. What are resource limits?

<details>
<summary>Answer</summary>

Limits cap how much CPU or memory a container may use. Memory over the limit can cause an OOM kill. CPU over the limit can throttle.

Set values from observed behavior. Bad limits cause new failures.

</details>

---

## 40. Interview Recall — Why a Pod might remain Pending

28. Why might a Pod remain Pending?

<details>
<summary>Answer</summary>

The Scheduler cannot place it, usually because requests do not fit remaining node capacity or a constraint excludes nodes.

Run `kubectl describe pod` and read scheduling events. Pending is not CrashLoopBackOff. The container may never have started.

</details>

---

## 41. Interview Recall — What happens during a rolling update?

29. What happens during a rolling update?

<details>
<summary>Answer</summary>

The Deployment creates a new ReplicaSet for the new image. It adds new Pods and removes old Pods according to the rollout strategy.

Some replicas stay up while others update. That avoids taking the whole application offline at once.

</details>

---

## 42. Interview Recall — How rollback works

30. How does rollback work?

<details>
<summary>Answer</summary>

`kubectl rollout undo deployment/myapp` returns the Deployment to a previous revision. Then watch `kubectl rollout status deployment/myapp`.

Use evidence from health, metrics, and logs. Rollback is one response, not the only response.

</details>

---

## 43. Interview Recall — What self-healing actually means

31. What does self-healing actually mean?

<details>
<summary>Answer</summary>

Self-healing means Kubernetes restores declared replica count when a managed Pod fails or disappears. It creates a replacement.

It does not repair application bugs. A crashing app will crash in the new Pod too until you fix the code or configuration.

</details>

---

## 44. Interview Recall — Container failure versus application failure

32. What is the difference between a container failure and an application failure?

<details>
<summary>Answer</summary>

A container or Pod failure is an instance problem: the process exited, the node failed, or the Pod was deleted. Kubernetes can replace that instance.

An application failure is a defect in code or config. Replacements keep failing. Platform health is not the same as application health.

</details>
