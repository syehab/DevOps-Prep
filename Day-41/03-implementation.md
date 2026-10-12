# Day 41 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 41 is a production simulation. A pipeline can report SUCCESS while checkout returns 5xx. This lab starts on paper. You write an incident timeline in markdown. You detect the symptom, you do not roll back immediately, you collect evidence, and then you decide rollback versus fix-forward. After the tabletop, you may run the same evidence-then-undo sequence on a local `kind` cluster with a bad image. `kubectl rollout undo` restores that image. It does not reverse a database migration.

Work in a temporary directory. Do not write incident notes inside the DevOps-Prep course repository. Prefer `kind` if you run the optional cluster steps. If `kind` is missing, finish the tabletop and the paper break. Then install `kind` from [kind.sigs.k8s.io](https://kind.sigs.k8s.io) if you want the cluster path. Do not invent other cluster tools or flags.

---

## Goal

Write `INC-001-ShopSphere-Production-Deployment.md`. Record start time, service, environment, versions, error rate, and the failing business function. Build a factual timeline from deploy start through mitigation. Measure blast radius. Collect evidence from workload, Service, endpoints, logs, and the database dependency. Decide rollback versus fix-forward only after that evidence exists.

If you have Docker, `kind` or `minikube`, and `kubectl`, apply a known-good `shopsphere-api` Deployment, ship a tag that does not exist, and collect the same class of evidence before you undo. Then break the recovery on paper: roll back a schema-incompatible release and show why undo is unsafe. Rewrite the change as expand-and-contract.

Time box: 45 to 75 minutes. Cost stays at ₹0. Stop when the incident file has a timeline, an evidence list, and a rollback-versus-fix-forward decision, the paper expand-and-contract note exists, and any cluster you created for this lab is deleted.

---

## What you need

You need a text editor and a shell. The tabletop is required. The cluster path is optional. You do not need Azure, AWS, EKS, or a paid registry.

If you run the optional cluster steps, you need Docker, `kind` or `minikube`, and `kubectl`. `kind` runs Kubernetes nodes as Docker containers. `kubectl` talks to the API Server. Check what is already on your `PATH`:

```bash
command -v docker
command -v kind
command -v minikube
command -v kubectl
docker version
kubectl version --client
```

If `kind` is missing, install it from [kind.sigs.k8s.io](https://kind.sigs.k8s.io) only if you want the optional path. Follow that site. Come back and run the same commands in this file. `minikube` is an alternative local cluster. Prefer `kind` for this lab. Do not mix both tools against the same kubeconfig context unless you already know which context is active. Do not use a production cluster. Do not create AKS, EKS, or cloud load balancers.

Create a throwaway directory under `/tmp`. Keep notes in `INC-001-ShopSphere-Production-Deployment.md` in that directory. Record times, evidence, and the recovery decision. Do not paste kubeconfig secrets, tokens, or registry passwords into a shared place.

The optional cluster uses the public `nginx:1.27` image as a stand-in for ShopSphere API. That image is not the ShopSphere application. It is local capacity you can roll and undo. Delete the Deployment and any `kind` cluster you created when you finish.

---

## Steps

1. Create a lab directory and enter it. Confirm the path is under `/tmp`. Stay in this directory for every file you write.

```bash
LAB_DIR="/tmp/day-41-incident-lab-$$"
mkdir -p "$LAB_DIR"
cd "$LAB_DIR"
pwd
```

2. Create the incident file. You will fill it as you work. Confirm the file exists before you write the timeline.

```bash
touch INC-001-ShopSphere-Production-Deployment.md
ls
```

3. Detect. Copy this opening into the incident file. Do not add a rollback command yet. Detection is a record of symptom, time, and impact. It is not a change to Production.

```markdown
# INC-001 ShopSphere Production Deployment

## Detection

- Incident start: 10:15
- Affected service: shopsphere-api
- Affected environment: Production
- Deployment version: v1.9
- Previous version: v1.8
- Current error rate: HTTP 5xx increasing
- Affected business function: checkout / POST /api/orders
- Customer impact: some customers cannot place orders
- Pipeline status: Production deployment SUCCESS
- Pod status at detection: Running
```

Write one short paragraph under that list. Pipeline SUCCESS means the deploy mechanism finished. Running Pods mean the process was scheduled. Neither fact proves that checkout works. You have a symptom. You do not yet have a cause.

4. Do not roll back immediately. Add this decision block before any recovery command.

```markdown
## Hold on rollback

I will not run kubectl rollout undo yet.

I do not yet know whether v1.9 caused the 5xx.
I do not yet know whether the database schema still fits v1.8.
I do not yet know the blast radius.
```

A rollback without evidence can hide the cause. It can also break a schema that already moved. Containment comes after the timeline and the blast radius, not before them.

5. Collect evidence. Build the timeline first. A temporal relationship is evidence. It is not yet proof of causation. Paste this into the incident file and keep the times factual.

```markdown
## Timeline

- 10:00 Production deployment begins
- 10:05 Deployment completes (SUCCESS)
- 10:08 5xx begins increasing
- 10:10 Checkout failures reported
- 10:15 Incident declared
- 10:20 Investigation indicates failures began after v1.9
- 10:28 Order endpoint identified as affected path
- 10:32 Database compatibility issue suspected
```

Leave later recovery times blank until you decide. Do not write “the database definitely caused everything” until the causal chain is proven.

6. Measure blast radius. Record which paths still work. The lesson example is products 200 and orders 500. Copy this table and fill the result column.

```markdown
## Blast radius

| Check | Result |
|:--|:--|
| GET /api/products | 200 |
| GET /api/products/{id} | 200 |
| POST /api/orders | 500 |
| All AZs | unknown until checked |
| New Pods only | unknown until checked |
| Authenticated users only | unknown until checked |
```

Write two sentences under the table. The entire application may not be broken. The failure may sit on the order path. Narrow failure means contain the order path. Do not restart the whole cluster.

7. Record the evidence you would collect on the live cluster. Use the same commands the lesson uses. If you are not running `kind` yet, still type them into the incident file as the evidence plan. You are collecting evidence. You are not changing Production.

```bash
kubectl get deployment shopsphere-api
kubectl get pods -o wide
kubectl get rs
kubectl get events --sort-by=.lastTimestamp
kubectl get svc shopsphere-api
kubectl describe svc shopsphere-api
kubectl get endpoints shopsphere-api
kubectl rollout history deployment/shopsphere-api
kubectl rollout status deployment/shopsphere-api
```

Then inspect one Pod. Replace `<pod-name>` with a real name only when the cluster exists.

```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

Add this evidence list to the incident file:

```markdown
## Evidence plan

- Deployment desired / available / ready replicas
- Pod Running vs Ready vs restart count vs age
- ReplicaSets and recent events
- Service selector vs endpoints
- Application logs for SQL error, timeout, or missing column
- Database: availability, connections, schema, recent migration
```

Compare Running Pods, Ready Pods, and Service endpoints. A Running Pod that is not Ready should not be in the ready endpoints. Deployment success is not business health.

8. Form the hypothesis from the lesson. v1.9 expects `orders.customer_reference`. Production does not have that column. Order requests return SQL errors as HTTP 500. Readiness only checked process startup, so the rollout looked healthy. Write that chain in the incident file as a hypothesis, not as a proven finding.

9. Decide rollback versus fix-forward. Ask the questions from the lesson, then write the answer in the incident file.

```markdown
## Decision

Can v1.8 run on the current schema?
Is the failure isolated to POST /api/orders?
Can a tested fix reach Production faster than rollback?
What is the fastest safe recovery?

Decision: rollback application to v1.8.
Reason: the Production database was not migrated. v1.8 still fits the current schema.
Not chosen: fix-forward, because a schema add in the incident window is a larger change.
Not chosen: terraform apply, scale, or security-group edits. Those are unrelated.
```

If the schema still fits v1.8, rollback is the smallest safe action that restores checkout. If the database already changed incompatibly, rollback may be unsafe. You will prove that second case in Break and fix. Do not skip this decision and jump to `kubectl rollout undo`.

10. Optional cluster path. Skip to Verify if you have no Docker or no cluster tool. The tabletop already satisfies the required lab. If you continue, list clusters and the current context.

```bash
kind get clusters
kubectl config current-context
```

Create a cluster only when you need one:

```bash
kind create cluster --name day41
```

If you use `minikube` instead, start it only when you have no cluster:

```bash
minikube start
```

Wait until the command exits. Then confirm the API answers:

```bash
kubectl cluster-info
kubectl get nodes
kubectl get pods -A
```

Write `CREATED_KIND=yes` in the incident file if you ran `kind create cluster --name day41`. Write `CREATED_MINIKUBE=yes` if you ran `minikube start` for this lab. Write `CREATED_KIND=no` and `CREATED_MINIKUBE=no` if you reused an existing cluster. Cleanup uses those notes.

11. Write `deployment.yaml`. This file is a local stand-in named `shopsphere-api`. Two replicas. Container name `api`. Known-good image `nginx:1.27`. That image stands in for v1.8. The Service selects the same label so you can compare Ready Pods with endpoints. You do not create Pods by hand.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shopsphere-api
spec:
  replicas: 2
  selector:
    matchLabels:
      app: shopsphere-api
  template:
    metadata:
      labels:
        app: shopsphere-api
    spec:
      containers:
        - name: api
          image: nginx:1.27
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: shopsphere-api
spec:
  selector:
    app: shopsphere-api
  ports:
    - port: 80
      targetPort: 80
```

Apply it and wait until both replicas are Ready.

```bash
kubectl apply -f deployment.yaml
kubectl rollout status deployment/shopsphere-api
kubectl get deployment shopsphere-api
kubectl get pods -l app=shopsphere-api -o wide
kubectl get svc shopsphere-api
kubectl describe svc shopsphere-api
kubectl get endpoints shopsphere-api
kubectl rollout history deployment/shopsphere-api
```

Record the revision number. The first successful apply is usually revision `1`. `rollout status` means this rolling update reached the declared replica count. It does not mean checkout works in Production.

12. Detect a bad release without rolling back. Change the container named `api` to a tag that does not exist. That tag stands in for v1.9. `kubectl set image` still updates desired state. Kubernetes then cannot pull the image.

```bash
kubectl set image deployment/shopsphere-api api=nginx:not-a-real-tag-day41
```

Do not run `kubectl rollout undo` yet. Collect evidence first.

```bash
kubectl rollout status deployment/shopsphere-api --timeout=60s
kubectl get deployment shopsphere-api
kubectl get pods -l app=shopsphere-api -o wide
kubectl get rs
kubectl get events --sort-by=.lastTimestamp
kubectl rollout history deployment/shopsphere-api
```

`--timeout` is a real flag on `kubectl rollout status`. Status should fail or time out. Events often show `ImagePullBackOff` or `ErrImagePull`. Describe a stuck Pod and copy the image name into the incident file.

```bash
kubectl get pods -l app=shopsphere-api
kubectl describe pod <stuck-pod-name>
kubectl logs <stuck-pod-name>
```

Replace `<stuck-pod-name>` with a real name from `kubectl get pods`. Logs may be empty if the image never started. That is still evidence. Record: desired replicas, Ready replicas, the bad image, and that you have not undone yet.

13. Decide on the cluster. This failure is a bad image. There is no database. The previous revision still fits. Rollback is safe. Fix-forward would mean shipping a real tag. Undo is the smallest safe recovery here.

```bash
kubectl rollout undo deployment/shopsphere-api
kubectl rollout status deployment/shopsphere-api
kubectl get pods -l app=shopsphere-api -o wide
kubectl rollout history deployment/shopsphere-api
```

`--to-revision` is a real flag if history shows that undo did not land on the known-good image. Use the revision number from history, not a guessed number.

```bash
kubectl rollout history deployment/shopsphere-api
kubectl rollout undo deployment/shopsphere-api --to-revision=1
kubectl rollout status deployment/shopsphere-api
```

Do not declare recovery only because Pods become `Running`. Recovery in this stand-in is `2/2` Ready on `nginx:1.27`. In the tabletop, recovery is a successful checkout. Add the missing times to the timeline: rollback initiated, error rate decreasing, checkout verified, incident mitigated.

---

## Verify

Read `INC-001-ShopSphere-Production-Deployment.md` as if you are on an incident call. You should name the symptom, the hold on rollback, the timeline, the blast radius, the evidence, and the decision without opening the lesson.

Check these points:

- Detection names Production, `shopsphere-api`, v1.9, v1.8, and checkout as the failing function.
- The file states that you will not roll back until evidence exists.
- The timeline includes deploy start, SUCCESS, 5xx, customer report, and incident declared.
- Blast radius shows products succeeding and orders failing.
- The decision says why rollback is safe in the tabletop (schema still fits v1.8) and what you refused to change during the incident.
- If you ran the cluster path, `kubectl get deployment shopsphere-api` shows `2/2` after undo, and the incident file records evidence collected before undo.

If a section is only a heading, fill it before you stop. An incident report with empty headings is not a report. If you have no cluster, stop after the markdown exists. Create the cluster later and continue from apply. Do not invent fake `kubectl` output.

---

## Break and fix

The cluster undo recovered a bad image. A schema-incompatible release is a different failure. `kubectl rollout undo` moves the Deployment back to the previous ReplicaSet. It does not reverse a database migration. Rollback of the application and rollback of the database are different problems. Prove that on paper. Do not run a dangerous Production migration.

1. Copy the incident file so the good tabletop stays intact.

```bash
cp INC-001-ShopSphere-Production-Deployment.md INC-001-schema-incompatible.md
```

2. Open `INC-001-schema-incompatible.md`. Change the hypothesis. v1.9 already applied this Production migration:

```text
ALTER TABLE orders DROP COLUMN customer_code;
ALTER TABLE orders ADD COLUMN customer_reference TEXT NOT NULL;
```

v1.8 reads and writes `orders.customer_code`. v1.9 reads and writes `orders.customer_reference`. Both versions cannot run against this schema. Write a section titled `Why rollback is unsafe` and answer these questions in prose, not as a checklist:

- What happens to `POST /api/orders` if you run `kubectl rollout undo` and v1.8 starts against the new schema?
- Does undo restore the dropped column `customer_code`?
- Do Running Pods on v1.8 prove checkout works?
- Would adding API replicas help, or would they open more failing queries?

Write the outcome. Undo returns v1.8. The column v1.8 needs is gone. Order SQL fails again. Customers still cannot place orders. You destroyed a useful timeline and you did not restore the business function. That is why you collect schema compatibility evidence before you undo.

3. Rewrite the change as expand-and-contract in the same file. Keep both versions viable. Do not drop the old column in the same release that adds the new one.

```text
Expand:
1. Add orders.customer_reference as nullable. Do not drop customer_code.
2. Deploy a dual-write version. Write both columns. Read customer_code.
3. Backfill customer_reference from customer_code.
4. Verify both v1.8 and the dual-write version can create an order.

Contract:
5. Deploy a version that reads customer_reference and still writes both columns.
6. Confirm checkout on that version.
7. Stop writing customer_code.
8. Drop customer_code only after no running version reads it.
```

Write two sentences under that list. Expand-and-contract keeps rollback possible at each step. A single incompatible migration makes `kubectl rollout undo` unsafe even when the Deployment undo succeeds.

4. Return to `INC-001-ShopSphere-Production-Deployment.md`. Confirm it still records the compatible-schema rollback decision from the tabletop. The incompatible case lives in `INC-001-schema-incompatible.md`. Do not overwrite the good decision with the unsafe one.

---

## Clean up

If you did not create a cluster, you have markdown only. There is no cloud resource to destroy.

If you applied `deployment.yaml`, delete that object. This lab used the default namespace.

```bash
kubectl delete -f deployment.yaml
```

Confirm it is gone:

```bash
kubectl get deployment shopsphere-api
kubectl get pods -l app=shopsphere-api
```

Those gets should report that the resources were not found, or they should show no `shopsphere-api` Pods. Do not delete shared cluster resources that belong to other workloads.

If your notes say `CREATED_KIND=yes`, delete the cluster you created. This removes the `kind` nodes for `day41`.

```bash
kind delete cluster --name day41
```

If your notes say `CREATED_MINIKUBE=yes`, stop and delete that profile only when you created it for this lab:

```bash
minikube delete
```

If your notes say `CREATED_KIND=no` and `CREATED_MINIKUBE=no`, do not delete the cluster. You reused a cluster that you did not create for this lab.

Leave the lab directory and remove it:

```bash
cd /tmp
rm -rf "$LAB_DIR"
```

If you want to keep notes, copy `INC-001-ShopSphere-Production-Deployment.md` and `INC-001-schema-incompatible.md` out before `rm -rf`. You created no Azure or AWS resources, so there is no resource group or VPC to delete. Do not copy the files into the course repository unless you are submitting homework through a path your instructor named.

---

## Interview story

I treat a green pipeline as a deploy-mechanism result, not as checkout health. When Production 5xx rises after v1.9, I record impact, build a timeline, and measure blast radius before I touch traffic. I compare Running Pods, Ready Pods, and Service endpoints, then I read logs on the failing order path. I ask whether v1.8 can still run on the current schema before I run `kubectl rollout undo`. If the schema still fits, rollback is the smallest safe recovery. If the migration already dropped the old column, undo puts v1.8 on an incompatible database and checkout stays broken. I recover that class of change with expand-and-contract, not with an immediate undo. On a local cluster I still collect evidence on a bad image before undo, then I confirm `2/2` Ready. Recovery is the business function working again, not the rollback command exiting.
