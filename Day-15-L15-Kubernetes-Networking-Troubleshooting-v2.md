# Day 15 — Kubernetes Networking & Troubleshooting

**Goal:** Build a clear mental model of how Kubernetes networking works and learn to troubleshoot connectivity problems systematically, from DNS all the way to the application.

**Core idea:** Kubernetes networking is not one feature. It is several layers working together: Pod networking, Services, DNS, endpoint discovery, kube-proxy/CNI behavior, NetworkPolicy, and external load balancing or Ingress. A Senior/Lead DevOps engineer should be able to identify which layer is failing instead of treating every connectivity problem as a generic “Kubernetes network issue.”

## Part 1 — Kubernetes Networking Mental Model

1. Kubernetes networking starts with a simple expectation: every Pod gets an IP address, and Pods should be able to communicate with other Pods across the cluster. Unlike Docker's default bridge networking, Kubernetes is designed around a cluster-wide network model where a Pod can communicate with another Pod without manually publishing ports. The actual implementation is provided by the cluster's networking layer, commonly through a CNI plugin. This gives us the first mental model: **Pod IP = address of a workload instance, but not a stable application endpoint**.

2. A Pod IP is normally temporary because Pods are disposable. If a Deployment replaces a Pod, the replacement can receive a different IP address. Therefore, an application should not normally store `10.x.x.x` as the address of another Pod and assume it will remain valid. Kubernetes introduces the Service abstraction precisely because workloads change while applications still need a stable way to communicate. **Pods change; Services remain the stable communication abstraction.**

3. A useful request path to remember is:

```text
Client
   ↓
DNS name
   ↓
Service
   ↓
Service endpoints
   ↓
Pod IP
   ↓
Container port
   ↓
Application
```

For external traffic, additional layers appear:

```text
Internet
   ↓
DNS
   ↓
Public IP / Load Balancer
   ↓
Ingress
   ↓
Service
   ↓
Pod
   ↓
Application
```

The important point is that every arrow represents a possible failure boundary. If users cannot reach an application, do not jump directly to the Pod. Start at the point where the traffic originates and progressively eliminate each layer.

4. Kubernetes networking also has an important distinction between **routing** and **service discovery**. Routing answers “How does traffic reach this IP?” while service discovery answers “Which IP should I use for this application?” Kubernetes DNS and Services primarily solve the second problem, while the CNI, node networking, routes and underlying cloud network help solve the first. This distinction is useful because DNS can work perfectly while packets still fail to reach their destination.

5. There are several different IPs you will encounter:

```text
Pod IP
Service ClusterIP
Node IP
Load Balancer IP
```

A Pod IP identifies a particular Pod instance. A Service ClusterIP provides a stable virtual destination for a Service. A Node IP identifies a Kubernetes node, and a Load Balancer IP provides an externally reachable entry point when the environment provisions one. Confusing these addresses is a common source of troubleshooting mistakes.

6. Kubernetes networking is implemented through several components rather than one “Kubernetes network service.” The CNI is responsible for providing Pod networking, while components or mechanisms such as kube-proxy, eBPF-based networking, or the particular CNI implementation can provide Service traffic handling. The exact implementation differs between clusters, but the logical model remains the same. **As a DevOps engineer, understand the behavior first and then learn how your specific CNI implements it.**

**Practice:** Using the Day 14 application, write down the exact path for an internal request:

```text
Pod A → ?
```

Then write the path for an external user:

```text
Browser → ?
```

For each step, identify whether the object is providing **DNS, stable addressing, routing, traffic filtering, or application processing**.

---

## Part 2 — Services: Stable Access to Dynamic Pods

1. A Kubernetes Service exists because Pod IPs are not reliable application addresses. A Service provides a stable virtual IP and a DNS name while Kubernetes continuously maintains the set of Pods that should receive traffic. The Service discovers those Pods using labels and selectors. This means the Service does not care which particular Pod instance is running; it cares which Pods currently match its selection criteria.

2. Consider this Deployment:

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
```

The important part is:

```text
Pod labels:
app=myapp
```

Now the Service can select those Pods:

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

The Service effectively says: **“Find Pods labelled `app=myapp` and send Service traffic to them.”**

3. The relationship between the objects is therefore:

```text
Deployment
    ↓
creates Pods
    ↓
Pods receive labels
    ↓
Service selector matches labels
    ↓
Endpoints / EndpointSlices contain matching Pod addresses
    ↓
Service sends traffic to those Pods
```

This is an extremely important chain to understand. If any link is broken, the application can be deployed successfully but still be unreachable.

4. `port` and `targetPort` are frequently confused. `port` is the port exposed by the Service, while `targetPort` is the destination port on the selected Pod. For example:

```yaml
ports:
  - port: 80
    targetPort: 8080
```

means:

```text
Client
  ↓
Service :80
  ↓
Pod :8080
```

The application inside the container must actually be listening on `8080`. The `containerPort` field in a Pod specification is useful documentation and metadata, but it does not itself make an application listen on that port.

5. Services have different exposure types for different traffic requirements. `ClusterIP` is the normal internal Service type. `NodePort` exposes a Service through a port on each node and is useful in certain scenarios, although managed cloud environments commonly use higher-level load-balancing integrations. `LoadBalancer` asks the surrounding infrastructure, typically the cloud platform, to provide an externally reachable load balancer. These types are about how traffic enters the Service, not about how Pods communicate internally.

6. A Service can therefore be completely healthy as a Kubernetes object while still having no usable backend. The first thing to inspect is:

```bash
kubectl get svc myapp
kubectl get endpoints myapp
kubectl get endpointslices
```

If the Service has no endpoints, investigate the selector and Pod labels. If endpoints exist, investigate whether the destination Pods are Ready and whether the target port is correct.

**Practice:** Deploy the Day 14 application and inspect the complete relationship:

```bash
kubectl get pods --show-labels
kubectl get svc myapp
kubectl describe svc myapp
kubectl get endpoints myapp -o wide
kubectl get endpointslices
```

Then answer:

**Which object creates the Pods? Which object selects them? Where can you see the actual backend Pod IPs?**

---

## Part 3 — Kubernetes DNS and Service Discovery

1. Kubernetes DNS allows applications to find Services using names rather than hard-coded IP addresses. A Service such as `myapp` can normally be resolved by another Pod in the same namespace using the name `myapp`. Kubernetes DNS creates records for Services and allows applications to use these stable names even though the underlying Pods may change repeatedly. This is one of the reasons Kubernetes applications can be dynamically scaled and rescheduled without changing application configuration.

2. A Service name can be represented using a fully qualified DNS name such as:

```text
myapp.production.svc.cluster.local
```

The general structure is:

```text
<service>.<namespace>.svc.cluster.local
```

Within the same namespace, the shorter form is usually enough:

```text
http://myapp
```

Across namespaces, you can use:

```text
http://myapp.production
```

or the fully qualified form when appropriate.

3. DNS troubleshooting should be separated from connectivity troubleshooting. First ask:

```text
Can the name resolve?
```

Then:

```text
Does the resolved destination accept connections?
```

A successful DNS lookup only proves that name resolution produced an address. It does not prove that the application is healthy or that network traffic can reach the destination.

4. Run a temporary debugging Pod:

```bash
kubectl run net-debug \
  --rm -it \
  --image=busybox:1.36 \
  -- sh
```

Inside it:

```bash
nslookup myapp
```

Then:

```bash
wget -qO- http://myapp
```

These tests answer different questions. `nslookup` tests name resolution, while `wget` tests whether an HTTP request can actually reach the Service and receive a response.

5. If the DNS name resolves but the request fails, move to the next layer rather than repeatedly testing DNS. Inspect the Service, endpoints, Pod readiness and target port:

```bash
kubectl get svc myapp
kubectl get endpoints myapp -o wide
kubectl get pods -o wide
kubectl describe pod <pod-name>
```

This creates a disciplined troubleshooting sequence instead of guesswork.

6. DNS failures can have several causes, including incorrect Service names, incorrect namespaces, problems with the cluster DNS service, or problems reaching the DNS service from the Pod. On a real cluster, you should also inspect the CoreDNS workload and logs when the evidence points toward DNS itself:

```bash
kubectl get pods -n kube-system
kubectl logs -n kube-system -l k8s-app=kube-dns
```

The exact labels can vary depending on the Kubernetes distribution, so first inspect what exists in your cluster rather than assuming a particular label.

**Practice:** From the debug Pod, perform:

```bash
nslookup myapp
wget -qO- http://myapp
```

Then find the Service ClusterIP:

```bash
kubectl get svc myapp
```

Try resolving the Service using its fully qualified name and explain what changed between the short and full names.

---

## Part 4 — Endpoints, Pod IPs and the Traffic Path

1. Endpoint information is where Kubernetes translates the logical idea of “Pods selected by this Service” into actual backend addresses. If the Service selector matches three Pods, the corresponding endpoint information should contain the addresses and relevant ports of those Pods. Modern Kubernetes uses EndpointSlices to represent this information efficiently, especially for large Services. For troubleshooting, the key question is still simple: **Does this Service currently know where its traffic should go?**

2. Suppose you have:

```text
Service: myapp
Selector: app=myapp

Pods:
myapp-1 → 10.0.1.10
myapp-2 → 10.0.1.11
myapp-3 → 10.0.2.15
```

The Service provides a stable destination, while the endpoint information represents the current backend Pods. If `myapp-2` is deleted and replaced, its address may change, but the Service remains the same. Kubernetes updates the backend membership accordingly.

3. A very useful troubleshooting pattern is to bypass layers one at a time. First test the Service name:

```bash
wget -qO- http://myapp
```

Then test the Service ClusterIP:

```bash
wget -qO- http://<CLUSTER-IP>
```

Then, when appropriate, test a Pod IP directly:

```bash
wget -qO- http://<POD-IP>:8080
```

If the Pod IP works but the Service does not, the application itself may be healthy while the Service path has a problem. If the Pod IP also fails, investigate the Pod, application, port or network policy.

4. This approach is powerful because each test removes a layer of abstraction. A request through the Service depends on DNS, Service discovery and Service routing. A direct Pod IP request removes DNS and Service selection from the equation. You are not simply “trying different commands”; you are designing experiments that eliminate possible causes.

5. You should also inspect the Pod's actual listening sockets when possible. For a Linux-based image that contains suitable tools:

```bash
kubectl exec -it <pod-name> -- sh
```

Then, depending on the image:

```bash
ss -lnt
```

or:

```bash
netstat -lnt
```

A common failure is assuming that the application listens on `8080` because the Deployment says `containerPort: 8080`, while the application is actually configured to listen on another port.

**Practice — Break and Recover:**

First break the Service selector:

```yaml
selector:
  app: wrong-label
```

Observe:

```bash
kubectl get endpoints myapp
```

Then restore it.

Next change:

```yaml
targetPort: 9090
```

when the application listens on `8080`.

Observe the difference between:

```text
Service has no endpoints
```

and:

```text
Service has endpoints but requests fail
```

This distinction is exactly what you should be able to explain in an interview.

---

## Part 5 — Readiness, Liveness and Startup Probes

1. A Kubernetes container being `Running` does not necessarily mean that the application is ready to receive production traffic. The process may still be starting, the application may have failed to connect to its database, or it may have loaded configuration incorrectly. Readiness probes give Kubernetes a signal for whether the application should currently receive traffic. When readiness fails, the Pod can remain running while being removed from the Service's ready backend set.

2. Liveness answers a different question: **“Is this application still alive enough that Kubernetes should keep this container?”** If a liveness probe repeatedly fails, Kubernetes can restart the container. This means readiness is primarily about **traffic eligibility**, while liveness is primarily about **container recovery**. Mixing these two concepts can cause serious production problems, especially if an application takes a long time to start.

3. Startup probes help with slow-starting applications. Without an appropriate startup strategy, a liveness probe might begin checking too early and repeatedly restart an application that simply needs more time to initialize. For a Spring Boot application, this can matter when startup includes migrations, dependency initialization, large caches or other expensive initialization work.

4. Consider three Pods behind a Service:

```text
Pod A   Running + Ready
Pod B   Running + Ready
Pod C   Running + NotReady
```

The Service should normally direct traffic to A and B rather than treating C as a ready backend. Therefore, if you see a running Pod that appears to receive no traffic, check its readiness state and endpoint membership before assuming that networking is broken.

5. Useful commands are:

```bash
kubectl get pods
kubectl describe pod <pod-name>
kubectl get endpoints <service-name>
kubectl logs <pod-name>
```

Look at the Events section in `describe`, probe failures, restart counts and whether the Pod is represented as a ready endpoint. These pieces of evidence together tell you whether the problem is traffic routing or application readiness.

6. A poorly designed probe can also create an outage. A liveness probe that depends on a database might restart every application instance whenever the database has a temporary problem, potentially making the outage worse. In many architectures, readiness may legitimately depend on critical dependencies, while liveness should focus on whether the application process itself is functioning. The exact design depends on the application's failure model.

**Practice:** Change the readiness path from:

```text
/actuator/health/readiness
```

to a path that does not exist.

Then observe:

```bash
kubectl get pods
kubectl get endpoints myapp
kubectl describe pod <pod-name>
```

Explain why the Pod can remain `Running` while disappearing from usable Service backends.

Restore the correct probe and verify recovery.

---

## Part 6 — NetworkPolicy and Pod-to-Pod Security

1. Kubernetes networking is not only about making traffic work; it is also about controlling which workloads are allowed to communicate. NetworkPolicy provides a mechanism for restricting traffic based on Pod and namespace identity, ports and other selectors. This is important because a cluster containing many applications should not automatically mean that every workload can communicate with every other workload. A production design should consider which communication paths are actually required.

2. Imagine this application:

```text
Internet
   ↓
frontend
   ↓
backend
   ↓
database
```

The intended communication might be:

```text
frontend → backend :8080
backend  → database :5432
```

while unrelated workloads should not be able to access the database. NetworkPolicy can help express these intended relationships.

3. A conceptual ingress policy could look like:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-policy
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: frontend
      ports:
        - protocol: TCP
          port: 8080
```

The important part is not memorizing this YAML. Understand the logic: **select the destination Pods, identify the allowed source Pods, and specify the destination port.**

4. NetworkPolicy troubleshooting requires knowing the behavior of the cluster's network implementation. Kubernetes defines the NetworkPolicy API, but enforcement depends on the networking implementation supporting it. Therefore, when a policy appears to have no effect, verify that the CNI supports and enforces NetworkPolicy. This is another Senior-level principle: **never assume that declaring a configuration object guarantees that an underlying component implements it.**

5. When a policy blocks traffic, identify both sides of the connection:

```text
Source Pod
   ↓
Destination Pod
   ↓
Destination port
```

Then determine which policies select the destination and what those policies allow. Test from the actual source workload whenever possible. A test from a different Pod may produce a completely different result because NetworkPolicy decisions can depend on Pod labels and namespace.

6. NetworkPolicy is therefore similar to a firewall conceptually, but it is not simply an Azure NSG or AWS Security Group copied into Kubernetes. Cloud firewalls operate at different networking boundaries, while NetworkPolicy operates around Pod traffic according to Kubernetes networking semantics. In a production architecture, you may need both cloud-level network controls and Kubernetes-level workload controls.

**Practice:** If your cluster supports NetworkPolicy, create two Pods with different labels and test connectivity before and after applying a policy. Your goal is to answer:

```text
Who is the source?
Who is the destination?
Which port is being used?
Which policy applies?
Why is the connection allowed or denied?
```

---

## Part 7 — External Traffic: NodePort, LoadBalancer and Ingress

1. So far, most traffic has been internal to the cluster. External users introduce additional layers because the Internet cannot normally connect directly to a ClusterIP or Pod IP. A common managed-Kubernetes path looks like:

```text
User
 ↓
Public DNS
 ↓
Public Load Balancer
 ↓
Ingress Controller / Service
 ↓
Kubernetes Service
 ↓
Pod
 ↓
Application
```

Each layer has a different responsibility, so troubleshooting must follow the complete path.

2. `NodePort` exposes a Service through a port on Kubernetes nodes. Conceptually:

```text
Client
   ↓
Node IP :NodePort
   ↓
Service
   ↓
Pod
```

It is useful for understanding how external exposure can work, but production managed-Kubernetes architectures often use cloud load balancers or ingress controllers instead of exposing applications directly through arbitrary node ports.

3. A `LoadBalancer` Service asks the surrounding infrastructure to provide an external load-balancing entry point:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp
spec:
  type: LoadBalancer
  selector:
    app: myapp
  ports:
    - port: 80
      targetPort: 8080
```

The cloud provider may provision a load balancer and assign an external IP or hostname. The exact implementation depends on the Kubernetes/cloud integration.

4. Ingress provides HTTP/HTTPS-aware routing rules. For example:

```text
api.example.com/users
        ↓
users-service

api.example.com/orders
        ↓
orders-service
```

The Ingress resource describes the desired routing, but an Ingress Controller is responsible for actually processing that traffic. Therefore, an Ingress object existing in the cluster does not by itself mean that HTTP traffic is being handled.

5. When an external application is unavailable, use a longer troubleshooting chain:

```text
1. DNS
   ↓
2. Public IP / Load Balancer
   ↓
3. Listener / Load Balancer configuration
   ↓
4. Ingress Controller
   ↓
5. Ingress rules
   ↓
6. Service
   ↓
7. Endpoints
   ↓
8. Pod readiness
   ↓
9. Pod port
   ↓
10. Application
```

This is essentially the Day 12 cloud-networking troubleshooting model extended into Kubernetes.

6. Azure and AWS provide different implementations around Kubernetes, but the underlying concepts map well. In AKS, you may encounter Azure Load Balancer, Application Gateway and Azure networking constructs. In EKS, you may encounter AWS Load Balancers, VPC networking and AWS-specific controllers. Do not memorize the cloud product names first; understand the traffic path first and then learn how each cloud implements that path.

**Practice:** Take the Day 14 application and mentally change the Service from `ClusterIP` to `LoadBalancer`. Before deploying anything, explain what additional infrastructure you expect to appear and which part of the request path is still handled by Kubernetes.

---

## Part 8 — The Kubernetes Troubleshooting Workflow

1. Senior-level troubleshooting is about reducing the search space. If a user says “the application is down,” that statement is too broad to act on directly. Convert it into a precise question: **Can the name resolve? Can I reach the Service? Does the Service have endpoints? Are those endpoints Ready? Can I reach the Pod port? Is traffic blocked? Is the application responding?** Each answer narrows the problem.

2. For an internal Service, use this sequence:

```text
DNS
 ↓
Service
 ↓
Endpoints / EndpointSlices
 ↓
Pod readiness
 ↓
Pod IP
 ↓
Port
 ↓
NetworkPolicy
 ↓
Application
```

For an external application:

```text
DNS
 ↓
Public IP / Load Balancer
 ↓
Ingress Controller
 ↓
Ingress
 ↓
Service
 ↓
Endpoints
 ↓
Pod
 ↓
Application
```

3. Useful commands should be used as evidence-gathering tools:

```bash
kubectl get pods -o wide
kubectl get svc
kubectl get endpoints
kubectl get endpointslices

kubectl describe svc <service>
kubectl describe pod <pod>

kubectl logs <pod>
kubectl exec -it <pod> -- sh
```

For connectivity testing:

```bash
kubectl run net-debug \
  --rm -it \
  --image=busybox:1.36 \
  -- sh
```

Then:

```bash
nslookup <service>
wget -qO- http://<service>
wget -qO- http://<pod-ip>:<port>
```

4. Consider this incident:

```text
Users report:
"API is unavailable."

You discover:
Deployment exists
Pods are Running
Service exists
```

That is not enough evidence to declare the application healthy. Continue:

```text
DNS resolves?
        ↓
Service has endpoints?
        ↓
Endpoints are Ready?
        ↓
Pod accepts connections?
        ↓
Correct port?
        ↓
NetworkPolicy allows traffic?
        ↓
Application returns a valid response?
```

This is the troubleshooting mindset you should carry into production.

5. The most common Kubernetes networking mistakes are surprisingly basic: incorrect Service selectors, incorrect `targetPort`, wrong namespace, Pods not Ready, applications listening on the wrong interface or port, DNS problems, NetworkPolicy restrictions, and incorrect external routing. Senior engineers still encounter these issues; the difference is that they diagnose them systematically and avoid changing unrelated components.

6. **Break → Observe → Explain → Recover** is more valuable than simply deploying a working YAML file. During this lab, deliberately break one layer at a time and predict what evidence should change. For example, a broken selector should affect endpoint membership, while a broken readiness probe should affect readiness and usable backend membership. A wrong application port should behave differently from a missing endpoint. Your goal is to recognize these signatures quickly.

**Practice — Full Troubleshooting Drill:**

Start with a working application.

Then perform these failures one at a time:

```text
1. Break Service selector
2. Restore selector
3. Break targetPort
4. Restore targetPort
5. Break readiness probe
6. Restore readiness probe
7. Test Pod IP directly
8. Test Service DNS
9. Add NetworkPolicy if supported
10. Remove the policy and verify recovery
```

For every failure, record:

```text
What did I change?
What should I expect?
What command proves it?
What layer is broken?
How did I recover?
```

This turns Kubernetes troubleshooting into a repeatable engineering process rather than memorized commands.

---

## Part 9 — Azure ↔ AWS ↔ Kubernetes Mapping

1. The networking concepts you have learned across the course should now start connecting together. Azure has VNets, subnets, NSGs, private endpoints and load balancers; AWS has VPCs, subnets, security groups, private endpoints and load balancers; Kubernetes adds Pods, Services, NetworkPolicies and ingress mechanisms on top of the underlying cloud network. These are not interchangeable objects, but they solve related problems at different layers. A Senior engineer needs to understand where each control lives.

2. Think about the layers like this:

```text
Cloud network
   ↓
VNet / VPC
   ↓
Subnet
   ↓
Node network
   ↓
Kubernetes CNI
   ↓
Pod network
   ↓
Service
   ↓
Ingress / Load Balancer
   ↓
Application
```

The cloud network does not disappear when Kubernetes is introduced. Kubernetes workloads still ultimately depend on infrastructure networking, identity, DNS, load balancing and security controls provided by the surrounding platform.

3. A useful mapping is:

| Concept | Azure | AWS | Kubernetes |
|---|---|---|---|
| Private network | VNet | VPC | Cluster/Pod networking |
| Subnetwork | Subnet | Subnet | Pod/node network segments |
| Network firewall rule | NSG | Security Group | NetworkPolicy |
| Load balancing | Azure Load Balancer | ELB family | Service / cloud integration |
| HTTP routing | Application Gateway | ALB | Ingress |
| Workload instance | VM / container | EC2 / container | Pod |
| Stable workload access | Private IP / LB / DNS | Private IP / LB / DNS | Service |
| Service discovery | Private DNS | Route 53 / Cloud Map patterns | Kubernetes DNS |

The mapping is conceptual rather than one-to-one. For example, a Kubernetes Service is not simply the Kubernetes version of an Azure Load Balancer or AWS load balancer.

4. The most important connection to remember is that Kubernetes networking adds an application/workload layer on top of cloud networking. If an AKS or EKS application cannot connect to a database, you may need to investigate both sides: Kubernetes Service/Pod networking and the underlying Azure VNet or AWS VPC routing/security. Troubleshooting stops being effective when engineers investigate only Kubernetes or only the cloud network.

**Practice:** Draw the architecture for:

```text
Internet
   ↓
Cloud Load Balancer
   ↓
Ingress
   ↓
Kubernetes Service
   ↓
Spring Boot Pods
   ↓
Private Database
```

For every arrow, identify whether the traffic is controlled by Kubernetes, the cloud platform, the application, or more than one layer.

---

## Part 10 — 5-Minute Recall

Without looking at the notes, explain these in your own words:

1. Why should an application normally use a Service instead of a Pod IP?

2. What is the relationship between labels, selectors and endpoints?

3. What is the difference between a Pod IP and a Service ClusterIP?

4. What is the difference between `port` and `targetPort`?

5. A Service exists but has no endpoints. What would you investigate?

6. DNS resolves successfully but the HTTP request fails. What would you investigate next?

7. Why can a Pod be `Running` but not receive Service traffic?

8. What is the difference between readiness, liveness and startup probes?

9. What problem does NetworkPolicy solve?

10. What is the difference between ClusterIP, NodePort and LoadBalancer?

11. What does an Ingress resource do, and what does an Ingress Controller do?

12. How would you troubleshoot an application that users cannot reach from the Internet?

13. If the Pod IP works but the Service does not, what layers have you already eliminated?

14. If the Service has no endpoints, would you start debugging the cloud load balancer? Why or why not?

15. Why can Kubernetes networking problems require investigation of both the Kubernetes network and the underlying Azure VNet/AWS VPC?

**Core mental model:**

> **Pods provide temporary workload addresses. Services provide stable application access. DNS provides discoverability. Endpoints connect Services to current Pods. NetworkPolicy controls allowed traffic. Ingress/Load Balancers provide external access.**

**Core troubleshooting model:**

> **DNS → Service → Endpoints → Readiness → Pod IP → Port → NetworkPolicy → Application**

For external traffic:

> **DNS → Load Balancer → Ingress → Service → Endpoints → Pod → Application**

---

## Part 11 — Cleanup

Delete the resources created for the lab:

```bash
kubectl delete deployment myapp --ignore-not-found
kubectl delete service myapp --ignore-not-found
kubectl delete pod net-debug --ignore-not-found
```

If you created a NetworkPolicy:

```bash
kubectl delete networkpolicy backend-policy --ignore-not-found
```

Verify:

```bash
kubectl get all
kubectl get networkpolicy
```

If you created the lab inside a dedicated namespace, delete the namespace only after confirming that it contains no resources you want to keep:

```bash
kubectl delete namespace k8s-networking-lab
```

The operational habit remains:

**Create → Use → Break → Diagnose → Recover → Destroy → Verify**

**Next: Day 16 — Helm + GitOps Mental Model**
