# Day 15 — Questions and answers

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Then answer each item below before you open the Answer block. After that, do the lab in [03-implementation.md](03-implementation.md).

Write your own answer first. Open the Answer block only after you try. Keep the original numbering.

---

## 1. Internal and external request paths

**Practice:** Using the Day 14 application, write down the exact path for an internal request:

```text
Pod A → ?
```

Then write the path for an external user:

```text
Browser → ?
```

For each step, identify whether the object is providing **DNS, stable addressing, routing, traffic filtering, or application processing**.

<details>
<summary>Answer</summary>

Write the internal path as Pod A → Kubernetes DNS → Service ClusterIP → Endpoints → Pod IP → container port → application. DNS gives the Service name. The Service gives a stable address. Endpoints hold current Pod IPs. The CNI routes the packet. The application processes the request.

Write the external path as Browser → public DNS → public IP / load balancer → Ingress → Service → Endpoints → Pod → application. Public DNS and the load balancer sit outside the cluster. Ingress and the Service still belong to Kubernetes. Start at the client and walk each arrow. Do not jump to the Pod first.

</details>

---

## 2. Which object creates Pods, which selects them, and where backend IPs appear

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

<details>
<summary>Answer</summary>

Deploy the Day 14 application. Run `kubectl get pods --show-labels`, `kubectl get svc myapp`, `kubectl describe svc myapp`, `kubectl get endpoints myapp -o wide`, and `kubectl get endpointslices`. The Deployment creates the Pods. The Service selector matches Pod labels such as `app=myapp`.

The actual backend Pod IPs appear in Endpoints and EndpointSlices, not on the Service ClusterIP itself. If Endpoints are empty, the selector does not match labels. The Service object can still look healthy.

</details>

---

## 3. Resolve the Service name, then fetch it, then compare short and FQDN

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

<details>
<summary>Answer</summary>

Start a debug Pod with `kubectl run net-debug --rm -it --image=busybox:1.36 -- sh`. Run `nslookup myapp`. Then run `wget -qO- http://myapp`. `nslookup` tests DNS. `wget` tests whether HTTP actually reaches the Service.

Find the ClusterIP with `kubectl get svc myapp`. Then resolve `myapp.default.svc.cluster.local` (use the real namespace). The short name and the FQDN point to the same ClusterIP. The short name works in the same namespace. The FQDN is unambiguous across namespaces.

</details>

---

## 4. Break the Service selector, then recover

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

<details>
<summary>Answer</summary>

Change the Service selector to `app: wrong-label`. Run `kubectl get endpoints myapp`. Endpoints become empty because no Pod matches. The Deployment and Pods still run. Clients cannot reach the application through the Service.

Restore `app: myapp`. Endpoints fill with Pod IPs again. A broken selector means **Service has no endpoints**. That is a discovery problem, not an application crash.

</details>

---

## 5. Break `targetPort`, then recover

**Practice — Break and Recover:**

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

<details>
<summary>Answer</summary>

Set `targetPort: 9090` while the application listens on `8080`. Run `kubectl get endpoints myapp`. Endpoints still exist because the selector still matches. Requests through the Service fail because traffic hits the wrong Pod port.

Restore `targetPort: 8080`. Prove recovery with `wget -qO- http://myapp` from a debug Pod. This is **Service has endpoints but requests fail**. That signature differs from an empty Endpoints list.

</details>

---

## 6. Break the readiness probe, then recover

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

<details>
<summary>Answer</summary>

Change the readiness path from `/actuator/health/readiness` to a path that does not exist. Run `kubectl get pods`, `kubectl get endpoints myapp`, and `kubectl describe pod <pod-name>`. The Pod stays `Running` because the process did not exit. Kubernetes marks it NotReady and removes it from usable Service backends.

Restore the correct probe. Confirm the Pod is Ready and that Endpoints list it again. Readiness controls traffic eligibility. It does not restart the container. That is why `Running` is not the same as receiving Service traffic.

</details>

---

## 7. NetworkPolicy lab: source, destination, port, and allow or deny

**Practice:** If your cluster supports NetworkPolicy, create two Pods with different labels and test connectivity before and after applying a policy. Your goal is to answer:

```text
Who is the source?
Who is the destination?
Which port is being used?
Which policy applies?
Why is the connection allowed or denied?
```

<details>
<summary>Answer</summary>

Create two Pods with different labels, such as `app=frontend` and `app=backend`. Test connectivity before any policy. Then apply a policy that selects `app=backend` and allows TCP `8080` only from `app=frontend`.

Answer the five questions every time. Source is the frontend Pod. Destination is the backend Pod. Port is `8080`. The policy that selects the destination applies. The connection is allowed from frontend and denied from other labels. Confirm the CNI enforces NetworkPolicy, or the object has no effect.

</details>

---

## 8. Change ClusterIP to LoadBalancer and name the extra infrastructure

**Practice:** Take the Day 14 application and mentally change the Service from `ClusterIP` to `LoadBalancer`. Before deploying anything, explain what additional infrastructure you expect to appear and which part of the request path is still handled by Kubernetes.

<details>
<summary>Answer</summary>

A `LoadBalancer` Service asks the cloud platform to create an external load balancer and a public IP or hostname. Kubernetes still owns the Service, Endpoints, Pods, and application processing. The cloud owns the load balancer, its listeners, and often the public DNS record.

Do not deploy yet. Expect a new cloud load-balancer object and an external address on `kubectl get svc myapp`. Internal Pod-to-Service traffic does not need that load balancer. Only internet clients do.

</details>

---

## 9. Full troubleshooting drill

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

<details>
<summary>Answer</summary>

Start from a working application. Change one layer at a time. Record the five fields for every failure: what changed, what to expect, which command proves it, which layer broke, and how you recovered.

1. Break the Service selector. Expect empty Endpoints. Prove with `kubectl get endpoints myapp`. Layer is Service discovery. Restore the selector.
2. Break `targetPort`. Expect Endpoints present and HTTP fail. Prove with `wget -qO- http://myapp` versus `wget -qO- http://<POD-IP>:8080`. Layer is Service port mapping. Restore `targetPort`.
3. Break the readiness probe. Expect `Running` and NotReady. Prove with `kubectl get pods` and `kubectl get endpoints myapp`. Layer is readiness. Restore the probe.
4. Test the Pod IP directly, then Service DNS. Direct success with Service failure isolates DNS or Service routing. Add a NetworkPolicy if the CNI supports it, then delete it with `kubectl delete networkpolicy backend-policy --ignore-not-found`. Prove recovery with the same `wget` tests.

</details>

---

## 10. Who controls each arrow: Kubernetes, cloud, application, or more than one

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

<details>
<summary>Answer</summary>

Internet → Cloud Load Balancer is cloud DNS, routing, and the load balancer. Cloud Load Balancer → Ingress is cloud plus the Ingress Controller. Ingress → Kubernetes Service is Kubernetes HTTP routing. Service → Spring Boot Pods is Kubernetes discovery, Endpoints, and CNI routing.

Pods → Private Database is more than one layer. Kubernetes handles Pod networking and NetworkPolicy. The cloud handles VNet or VPC routes, NSGs or Security Groups, and private endpoints. The application handles the database client, credentials, and queries. Investigate both Kubernetes and the cloud network when this hop fails.

</details>

---

## 11. Recall — Why use a Service instead of a Pod IP?

Without looking at the notes, explain these in your own words:

1. Why should an application normally use a Service instead of a Pod IP?

<details>
<summary>Answer</summary>

A Pod IP is temporary. A replacement Pod can receive a different address. A Service keeps a stable DNS name and ClusterIP while Kubernetes updates Endpoints.

Applications must not store `10.x.x.x` as a peer address. Pods change. Services stay the stable communication abstraction.

</details>

---

## 12. Recall — Labels, selectors, and endpoints

Without looking at the notes, explain these in your own words:

2. What is the relationship between labels, selectors and endpoints?

<details>
<summary>Answer</summary>

The Deployment puts labels on Pods, such as `app=myapp`. The Service selector matches those labels. Endpoints and EndpointSlices then hold the matching Pod IPs and ports.

If any link breaks, the application can deploy and still be unreachable. Empty Endpoints usually mean the selector and labels do not match.

</details>

---

## 13. Recall — Pod IP versus Service ClusterIP

Without looking at the notes, explain these in your own words:

3. What is the difference between a Pod IP and a Service ClusterIP?

<details>
<summary>Answer</summary>

A Pod IP identifies one workload instance. It changes when Kubernetes replaces the Pod. A Service ClusterIP is a stable virtual destination for the Service.

Clients should use the ClusterIP or the Service DNS name. Use a Pod IP only as a troubleshooting bypass.

</details>

---

## 14. Recall — `port` versus `targetPort`

Without looking at the notes, explain these in your own words:

4. What is the difference between `port` and `targetPort`?

<details>
<summary>Answer</summary>

`port` is the port the Service exposes to clients. `targetPort` is the destination port on the selected Pod. Example: Service `:80` forwards to Pod `:8080`.

`containerPort` documents the container port. It does not make the process listen. The application must actually listen on `targetPort`.

</details>

---

## 15. Recall — Service exists but has no endpoints

Without looking at the notes, explain these in your own words:

5. A Service exists but has no endpoints. What would you investigate?

<details>
<summary>Answer</summary>

Inspect the Service selector and Pod labels with `kubectl describe svc myapp` and `kubectl get pods --show-labels`. Check that matching Pods are Ready.

Do not start at the cloud load balancer. The Service currently has no backends. External routing cannot fix empty Endpoints.

</details>

---

## 16. Recall — DNS works, HTTP fails

Without looking at the notes, explain these in your own words:

6. DNS resolves successfully but the HTTP request fails. What would you investigate next?

<details>
<summary>Answer</summary>

Name resolution only proved that DNS returned an address. Next inspect the Service, Endpoints, Pod readiness, and `targetPort`. Run `kubectl get svc myapp`, `kubectl get endpoints myapp -o wide`, and `kubectl get pods -o wide`.

Then test HTTP to the ClusterIP and to a Pod IP. Move down the path. Do not keep repeating `nslookup`.

</details>

---

## 17. Recall — Pod is `Running` but receives no Service traffic

Without looking at the notes, explain these in your own words:

7. Why can a Pod be `Running` but not receive Service traffic?

<details>
<summary>Answer</summary>

The process can run while readiness fails. Kubernetes then keeps the Pod out of ready Endpoints. Check `kubectl get pods`, `kubectl describe pod <pod-name>`, and `kubectl get endpoints`.

Other causes include a selector mismatch, NetworkPolicy, or a wrong listen port. `Running` is not traffic eligibility.

</details>

---

## 18. Recall — Readiness, liveness, and startup probes

Without looking at the notes, explain these in your own words:

8. What is the difference between readiness, liveness and startup probes?

<details>
<summary>Answer</summary>

Readiness answers whether the Pod should receive traffic. Liveness answers whether Kubernetes should restart the container. Startup gives a slow application time to initialize before liveness starts.

Mix them and you can restart a healthy but slow process. A liveness probe that depends on a database can worsen an outage.

</details>

---

## 19. Recall — What NetworkPolicy solves

Without looking at the notes, explain these in your own words:

9. What problem does NetworkPolicy solve?

<details>
<summary>Answer</summary>

NetworkPolicy restricts which Pods and namespaces may talk, on which ports. A cluster with many applications should not mean every workload can reach every other workload.

Select the destination Pods, name the allowed sources, and name the port. Enforcement depends on the CNI. Declaring the object does not guarantee enforcement.

</details>

---

## 20. Recall — ClusterIP, NodePort, and LoadBalancer

Without looking at the notes, explain these in your own words:

10. What is the difference between ClusterIP, NodePort and LoadBalancer?

<details>
<summary>Answer</summary>

`ClusterIP` is the normal internal Service type. `NodePort` exposes the Service on a port on each node. `LoadBalancer` asks the cloud to provide an external load balancer.

These types control how traffic enters the Service. They do not change how Pods talk to each other inside the cluster.

</details>

---

## 21. Recall — Ingress resource versus Ingress Controller

Without looking at the notes, explain these in your own words:

11. What does an Ingress resource do, and what does an Ingress Controller do?

<details>
<summary>Answer</summary>

The Ingress resource describes desired HTTP routing, such as host and path to a Service. The Ingress Controller processes that traffic.

An Ingress object in the cluster does not mean HTTP is being handled. You still need a running controller and correct rules.

</details>

---

## 22. Recall — Users cannot reach the application from the Internet

Without looking at the notes, explain these in your own words:

12. How would you troubleshoot an application that users cannot reach from the Internet?

<details>
<summary>Answer</summary>

Walk DNS → public IP / load balancer → listener → Ingress Controller → Ingress rules → Service → Endpoints → Pod readiness → Pod port → application. Prove each hop before you change the next.

This is the Day 12 cloud path extended into Kubernetes. Do not start inside the Pod if users never reach the cluster.

</details>

---

## 23. Recall — Pod IP works, Service does not

Without looking at the notes, explain these in your own words:

13. If the Pod IP works but the Service does not, what layers have you already eliminated?

<details>
<summary>Answer</summary>

You already eliminated the application listen port, the Pod network path, and basic Pod health. Remaining layers are DNS, Service selection, Endpoints, kube-proxy or CNI Service routing, and NetworkPolicy on the Service path.

Bypass layers on purpose. Direct Pod success plus Service failure is a Service-path problem.

</details>

---

## 24. Recall — Empty Endpoints and the cloud load balancer

Without looking at the notes, explain these in your own words:

14. If the Service has no endpoints, would you start debugging the cloud load balancer? Why or why not?

<details>
<summary>Answer</summary>

Do not start at the cloud load balancer. Empty Endpoints mean the Service has no backends. The load balancer can be perfect and still have nowhere to send traffic.

Fix selector, labels, and readiness first. Investigate the cloud load balancer only after Kubernetes has ready backends.

</details>

---

## 25. Recall — Why both Kubernetes and VNet or VPC can be involved

Without looking at the notes, explain these in your own words:

15. Why can Kubernetes networking problems require investigation of both the Kubernetes network and the underlying Azure VNet/AWS VPC?

<details>
<summary>Answer</summary>

Kubernetes networking sits on top of cloud networking. Pods, Services, and NetworkPolicy do not replace VNets, VPCs, routes, NSGs, or Security Groups.

If an AKS or EKS application cannot reach a database, check Service and Pod networking and the underlying cloud route and security. Investigate only one side and you miss the failing layer.

</details>
