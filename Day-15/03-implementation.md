# Day 15 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 15 teaches Kubernetes networking as layers, not as one feature. This lab deploys an nginx Deployment and a ClusterIP Service. You inspect Endpoints, break the Service selector, watch Endpoints go empty, and restore the selector. You do not create Azure or AWS resources.

---

## Goal

Create a local cluster with kind or minikube, or use a cluster you already have. Deploy nginx as `myapp`. Confirm the Service has Endpoints. Change the Service selector to `app: wrong-label`, prove that Endpoints are empty, then restore `app: myapp`. Optionally set `targetPort` to `9090` so you can see the other failure: Endpoints exist, but requests fail.

When you finish, you can explain the difference between **Service has no endpoints** and **Service has endpoints but requests fail**. That is the interview signature this Day trains.

Time box: 45 to 75 minutes. Cost stays at ₹0. Stop when Endpoints are restored, the notes file is complete, and you have deleted the lab resources. If this lab created the cluster, delete the cluster too.

---

## What you need

You need `kubectl` and a local Kubernetes cluster. Prefer kind. Use minikube if kind is missing. Docker must be running if you use kind. You do not need AKS, EKS, or a cloud load balancer.

Check the tools first:

```bash
command -v kubectl
command -v docker
command -v kind
command -v minikube
kubectl version --client
```

`kind` and `minikube` are alternatives. You need one of them, or an existing local cluster that `kubectl cluster-info` can reach. Do not use a production cluster. Do not invent extra flags.

Work under `/tmp`, not inside this course repository. Kubernetes objects live in the cluster, but the YAML files belong in a throwaway directory.

Create a notes file named `day-15-net-lab.md` in that temp directory. Record command output and whether this lab created the cluster. Do not put kubeconfig secrets, tokens, or cloud account IDs in the file.

This lab uses `nginx:1.27` from Day 14 and `busybox:1.36` from this Day. nginx listens on port `80`. The lesson examples that use `targetPort: 8080` describe a Spring Boot app. For nginx, the working `targetPort` is `80`.

---

## Steps

1. Create a throwaway directory and enter it. Confirm the path is under `/tmp`.

```bash
LAB_DIR="/tmp/day-15-net-lab-$$"
mkdir -p "$LAB_DIR"
cd "$LAB_DIR"
pwd
```

Write the date and the path at the top of `day-15-net-lab.md`. Write one sentence: you will break Service discovery, not the nginx process.

2. Confirm `kubectl` can talk to a cluster. If this command prints cluster details, skip step 3 and write `created cluster: no` in the notes.

```bash
kubectl cluster-info
```

3. If step 2 failed, create a local cluster. Prefer kind. Record `created cluster: yes` and the tool you used.

```bash
kind create cluster --name day-15-net
```

If `kind` is missing, start minikube instead:

```bash
minikube start
```

Then confirm the cluster again:

```bash
kubectl cluster-info
```

4. Create the lab namespace from the lesson cleanup section. Later commands use `-n k8s-networking-lab` so you do not touch other workloads.

```bash
kubectl create namespace k8s-networking-lab
```

5. Write `deployment.yaml`. This Deployment creates nginx Pods labelled `app: myapp`. Those labels are what the Service will select.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 2
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - containerPort: 80
```

6. Write `service.yaml`. `port` is `80` because clients call `http://myapp`. `targetPort` is `80` because nginx listens on `80`.

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
      targetPort: 80
```

7. Apply both files. The Deployment creates the Pods. The Service selects them.

```bash
kubectl apply -n k8s-networking-lab -f deployment.yaml
kubectl apply -n k8s-networking-lab -f service.yaml
```

8. Wait until both Pods are Ready. Re-run this command until `READY` shows `1/1` for each Pod. The first pull of `nginx:1.27` can take a few minutes.

```bash
kubectl get pods -n k8s-networking-lab -o wide
```

9. Inspect the relationship the lesson uses. Copy the output into the notes. The Deployment creates the Pods. The Service selector matches `app=myapp`. Endpoints hold the backend Pod IPs.

```bash
kubectl get pods -n k8s-networking-lab --show-labels
kubectl get svc myapp -n k8s-networking-lab
kubectl describe svc myapp -n k8s-networking-lab
kubectl get endpoints myapp -n k8s-networking-lab -o wide
kubectl get endpointslices -n k8s-networking-lab
```

You should see two Pod IPs on the `myapp` Endpoints object. If Endpoints are already empty, stop. Check that the Pod labels and the Service selector both say `app=myapp`.

10. Break the Service selector. Write `service-wrong-selector.yaml` with `app: wrong-label`, then apply it. Do not change the Deployment.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp
spec:
  selector:
    app: wrong-label
  ports:
    - port: 80
      targetPort: 80
```

```bash
kubectl apply -n k8s-networking-lab -f service-wrong-selector.yaml
```

11. Observe empty Endpoints. This is the discovery failure from the lesson.

```bash
kubectl get endpoints myapp -n k8s-networking-lab
kubectl get pods -n k8s-networking-lab --show-labels
```

Endpoints should have no Pod IPs. The Pods should still be Running and Ready. Write in the notes: **Service has no endpoints**. The nginx process did not crash. The selector no longer matches the labels.

12. Restore the selector. Re-apply the original Service. Endpoints should fill with Pod IPs again.

```bash
kubectl apply -n k8s-networking-lab -f service.yaml
kubectl get endpoints myapp -n k8s-networking-lab -o wide
```

13. Optional, if you still have time: break `targetPort`. Write `service-wrong-port.yaml` with `targetPort: 9090` while nginx still listens on `80`. Apply it.

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
      targetPort: 9090
```

```bash
kubectl apply -n k8s-networking-lab -f service-wrong-port.yaml
kubectl get endpoints myapp -n k8s-networking-lab -o wide
```

Endpoints should still list the Pod IPs, because the selector still matches. That is the second signature: **Service has endpoints but requests fail**. Restore `targetPort: 80` before you continue.

```bash
kubectl apply -n k8s-networking-lab -f service.yaml
kubectl get endpoints myapp -n k8s-networking-lab -o wide
```

14. Prove the Service path from a debug Pod. Use the exact `kubectl run` from the lesson. Add `-n k8s-networking-lab` so the Pod lands in the same namespace as `myapp`.

```bash
kubectl run net-debug \
  --rm -it \
  --image=busybox:1.36 \
  -n k8s-networking-lab \
  -- sh
```

Inside the debug Pod, run these lesson commands:

```bash
nslookup myapp
wget -qO- http://myapp
```

`nslookup` tests DNS. `wget` tests whether HTTP reaches nginx through the Service. You should see nginx HTML. Then exit the shell. `--rm` deletes `net-debug` when you exit.

If you want the fully qualified name from the lesson, resolve `myapp.k8s-networking-lab.svc.cluster.local` as well. The short name and the FQDN should point at the same ClusterIP.

---

## Verify

Read the notes as if you are on a call. You should name the layer that failed when the selector was wrong.

Check these points:

- `kubectl get pods -n k8s-networking-lab --show-labels` showed `app=myapp`.
- After the first apply, `kubectl get endpoints myapp -n k8s-networking-lab` listed Pod IPs.
- After `app: wrong-label`, Endpoints were empty and the Pods were still Running.
- After you re-applied `service.yaml`, Endpoints listed Pod IPs again.
- If you did the optional `targetPort: 9090` change, Endpoints stayed populated. That is not the same failure as an empty Endpoints list.
- `nslookup myapp` and `wget -qO- http://myapp` from `net-debug` succeeded after restore.

If Endpoints are still empty after restore, run `kubectl describe svc myapp -n k8s-networking-lab` and compare the selector with `kubectl get pods -n k8s-networking-lab --show-labels`. The selector and the labels must match.

---

## Break and fix

You already broke the selector in step 10. That is the main failure this Day trains.

If you skipped the optional `targetPort` change, do it now. Apply `service-wrong-port.yaml`. Confirm Endpoints still exist. Start `net-debug` again and run `wget -qO- http://myapp`. The request should fail because traffic hits port `9090` on a process that listens on `80`. Then restore `service.yaml` and prove `wget -qO- http://myapp` again.

Do not delete Pods to "fix" a selector mismatch. Restore the selector. The Pods were never the broken layer.

---

## Clean up

Delete the lab resources with the lesson commands. Add `-n k8s-networking-lab` because that is the namespace you created.

```bash
kubectl delete deployment myapp --ignore-not-found -n k8s-networking-lab
kubectl delete service myapp --ignore-not-found -n k8s-networking-lab
kubectl delete pod net-debug --ignore-not-found -n k8s-networking-lab
```

Then delete the namespace only after you confirm it holds no resources you want to keep:

```bash
kubectl get all -n k8s-networking-lab
kubectl delete namespace k8s-networking-lab
```

Leave the lab directory and delete it:

```bash
cd /tmp
rm -rf "$LAB_DIR"
```

If you copied notes you want to keep, move `day-15-net-lab.md` out before `rm -rf`.

If this lab created a kind cluster named `day-15-net`, delete that cluster:

```bash
kind delete cluster --name day-15-net
```

If this lab started minikube and you do not need that cluster for another Day, delete it:

```bash
minikube delete
```

If you used a cluster that already existed, do not delete it. You created no Azure or AWS resources, so there is no resource group, VPC, or load balancer to remove.

---

## Interview story

I treat Kubernetes networking as a path, not as one feature. I deploy a Service in front of nginx and prove Endpoints with `kubectl get endpoints`. When the selector does not match Pod labels, Endpoints go empty even though the Pods stay Running. That is a discovery problem. I restore the selector and Endpoints fill again. A wrong `targetPort` is a different signature: Endpoints still exist, but the Service sends traffic to a port the process does not listen on. I do not start at a cloud load balancer while Kubernetes has no backends.
