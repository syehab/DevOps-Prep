# Day 17 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 17 teaches AKS and EKS as managed Kubernetes plus cloud integrations. The cloud provider manages the control plane. Your team still owns compute, networking, identity, and workloads. This lab produces a markdown comparison of AKS and EKS. You fill control plane, node identity versus Workload Identity and IRSA, networking, and add-ons. You do not create an AKS or EKS cluster. Those services cost money.

If `kind` is present, you may start a local cluster as a stand-in. `kind` is not AKS. It is not EKS. It only lets you see a control plane and worker capacity on your machine. If `kind` is missing, the comparison table and the identity note are the lab.

---

## Goal

Write one comparison document that maps AKS to EKS for four platform jobs: control plane, node identity and workload identity, networking, and add-ons. Record who owns each job. Then write a broken identity: the cluster identity is admin on the whole Azure subscription or AWS account. Shrink that identity to the cluster and to one application secret.

If Docker and `kind` work on this machine, create a disposable local cluster named `day17`. List nodes. Apply one nginx Deployment so you can see that you still own the workload. Delete that cluster if this lab created it. Do not run `az aks create`. Do not run `eksctl` or `aws eks create-cluster`.

Time box: 45 to 75 minutes. Cost stays at ₹0. Stop when the comparison table is complete, the identity blast-radius note is written, and any `kind` cluster this lab created is gone.

---

## What you need

You need a text editor and a shell. You do not need an Azure subscription or an AWS account. Do not create AKS or EKS. The required deliverable is markdown.

`kind` is optional. Check the tools first:

```bash
command -v docker
command -v kind
command -v kubectl
```

If `kind` or Docker is missing, skip every `kind` and `kubectl` step. Write `kind missing — comparison table and identity note are the lab` in your notes. Do not invent another cluster tool. Do not open a cloud console to compensate.

If `kind` is present, you also need `kubectl` and a running Docker engine. Check versions:

```bash
docker version
kind version
kubectl version --client
```

Create the lab under `/tmp`, not under this course clone. Keep notes in `day-17-aks-eks-lab.md` in that temp directory. Record the table, the identity shrink, and whether this lab created a `kind` cluster. Do not paste kubeconfig, tokens, or cloud account IDs.

---

## Steps

1. Create a throwaway directory and enter it. Use a unique folder name so you do not collide with another lab. Confirm the path is under `/tmp`.

```bash
LAB_DIR="/tmp/day-17-aks-eks-lab-$$"
mkdir -p "$LAB_DIR"
cd "$LAB_DIR"
pwd
```

2. Create the notes file. Put the date at the top. Write one short paragraph: you will compare AKS and EKS on paper. You will not create those clusters. You will use `kind` only if it is already on this machine, and only as a local stand-in.

```bash
touch day-17-aks-eks-lab.md
ls
```

3. Write the ownership sentence before the table. Use the lesson model. Azure or AWS manages the Kubernetes control plane. Your team still owns node pools or managed node groups, workloads, networking design, identity bindings, and operations. Never write that the provider manages Kubernetes as if everything is managed.

Write at least one short paragraph. Name AKS and EKS. Say that Kubernetes objects stay the same. Say that identity, network, registry, load balancing, and monitoring integrations change.

4. Add the AKS versus EKS comparison table. Copy this block into the notes file. Fill every cell in your own words. Do not leave a cell as a product name only. Write what the layer does, then the Azure name, then the AWS name.

```markdown
| Layer | What it does | AKS / Azure | EKS / AWS | Who owns it |
|:--|:--|:--|:--|:--|
| Control plane | API server, scheduler, controllers, cluster state | | | |
| Node identity | Nodes call cloud APIs (pull images, attach disks, join the VPC/VNet) | | | |
| Workload identity | A Pod calls cloud APIs without a static access key | Workload Identity | IRSA / EKS Pod Identity | |
| Networking | Nodes and Pods sit on a cloud network with routes and security rules | VNet, subnets, NSGs, CNI | VPC, subnets, security groups, CNI | |
| Add-ons | Monitoring, DNS inside the cluster, cloud load-balancer integration | | | |
```

Fill control plane first. Azure manages the AKS control plane. AWS manages the EKS control plane. You do not run etcd. You still reach the Kubernetes API.

Fill node identity next. On AKS, nodes use a managed identity to talk to Azure. On EKS, nodes use an IAM instance role. That identity is for the node, not for the application.

Fill workload identity. Azure Workload Identity maps a ServiceAccount to a Microsoft Entra ID identity. IRSA lets a ServiceAccount assume an IAM role through an OIDC trust. EKS Pod Identity attaches an IAM role without you wiring the OIDC provider by hand. No access keys live in the Pod.

Fill networking. AKS sits on a VNet. EKS sits on a VPC. Kubernetes does not remove routes, NSGs, or security groups. A missing cloud route still looks like the application is down.

Fill add-ons. Map Azure Monitor to CloudWatch. Map ACR to ECR only as the image source the cluster pulls. Map Azure Load Balancer or Application Gateway to the ELB family. Say the map is conceptual. Behavior is not identical.

5. Write two sentences under the table. AKS and EKS are both managed Kubernetes. They are not the same service. Workload Identity is not IRSA. A VNet is not a VPC. You learn the concept once, then you map the cloud implementation.

6. Draw the local stand-in versus managed ownership. Copy this block, then add one sentence: `kind` shows Kubernetes. It does not show Azure or AWS integrations.

```text
kind (this lab, optional)
 └── You operate the local control plane and the worker node (Docker)

AKS / EKS (not created in this lab)
 ├── Cloud provider: managed control plane
 └── You: node pools / node groups, workloads, VNet/VPC, identity, add-ons
```

7. Check `kind`. If the command fails, write `kind missing` and go to Verify. Do not run the cluster steps.

```bash
command -v kind
command -v kubectl
docker version
```

8. If `kind` is present, decide whether you need a new cluster. List clusters. If `kubectl get nodes` already works on a disposable local cluster, you may reuse it. Record the context. Do not use a production cluster. Do not use AKS or EKS.

```bash
kind get clusters
kubectl config current-context
```

Create a cluster only when you need one:

```bash
kind create cluster --name day17
```

Wait until the command exits. Then confirm the API answers:

```bash
kubectl cluster-info
kubectl get nodes
kubectl get pods -A
```

`cluster-info` shows control-plane endpoints. `get nodes` lists worker capacity. `get pods -A` lists system Pods. On `kind`, the control-plane node is a Docker container on your machine. On AKS or EKS you would not operate that node. Write `CREATED_KIND=yes` in your notes if you ran `kind create cluster --name day17`. Write `CREATED_KIND=no` if you reused a cluster, or if you skipped `kind`.

9. If you have a local cluster, apply one nginx Deployment. This is the workload you still own after the control plane is someone else's problem. The image is `nginx:1.27` from Day 14.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - containerPort: 80
```

Save that YAML as `deployment.yaml`. Apply it and list Pods:

```bash
kubectl apply -f deployment.yaml
kubectl get deployment nginx
kubectl get pods -l app=nginx
```

Record the node name from `kubectl get pods -l app=nginx -o wide`. The Pod runs on worker capacity. That is the compute layer you still size on AKS node pools or EKS node groups. `kind` does not give you Workload Identity, IRSA, a VNet, or a VPC. Write that limit in the notes.

---

## Verify

Read `day-17-aks-eks-lab.md` as if you are on a call. You should name what the provider manages and what stays yours, without opening the lesson.

Check these points:

- The table has rows for control plane, node identity, workload identity, networking, and add-ons.
- Workload identity names Azure Workload Identity and IRSA or EKS Pod Identity. The notes say no access keys live in the Pod.
- Networking names VNet and VPC. The notes say Kubernetes does not remove cloud routes or security rules.
- Add-ons map monitoring and load-balancer integration. The notes say the map is conceptual, not identical.
- The ownership paragraph says the provider manages the control plane and you still own workloads.
- If `kind` ran, `kubectl get nodes` returned at least one Ready node, and `kubectl get deployment nginx` shows the Deployment.
- You did not create AKS or EKS. Cost stays at ₹0.

If a table cell is only a heading, fill it before you stop. A comparison with empty cells is not a design.

---

## Break and fix

The lesson asks you to keep least privilege at the cloud layer and at the Kubernetes layer. Break that on paper. Do not assign a real Owner role. Do not attach `AdministratorAccess`. Document the mistake, then shrink it.

Copy the notes so you can compare the two designs:

```bash
cp day-17-aks-eks-lab.md day-17-aks-eks-lab-broken.md
```

Open `day-17-aks-eks-lab-broken.md`. Add a section titled `Over-privileged cluster identity`. Write that the AKS cluster identity is Owner on the whole Azure subscription. Write that the EKS node role or cluster role is `AdministratorAccess` on the whole AWS account. Keep the tidy table above it. A tidy table does not shrink blast radius.

Write a short `Blast radius` paragraph in that broken file. Answer these questions in prose:

- What can a stolen kubelet identity or a escaped Pod do if the cluster identity already administers the subscription or account?
- Can that identity create or delete other teams' resource groups, VPCs, or Key Vaults and secrets?
- What happens to billing and quotas when one cluster can create resources anywhere in the account?
- Does Kubernetes RBAC inside one namespace stop a cloud-admin identity from calling ARM or AWS APIs?

Kubernetes RBAC does not limit Azure RBAC or IAM. A cluster-admin on the Kubernetes API is already too broad. A cluster identity with Owner or `AdministratorAccess` on the whole subscription or account is worse. The blast radius is the entire billing boundary, not one namespace.

Then fix `day-17-aks-eks-lab.md`. Add a section titled `Least-privilege cluster identity`. Shrink the Azure side: the cluster or kubelet identity may manage the node resource group and the AKS resource. It does not get Owner on the subscription. The application uses Workload Identity with permission to read one Key Vault secret, not every vault.

Shrink the AWS side the same way. The node IAM role may pull from ECR, describe instances, and talk to the VPC CNI. It does not get `AdministratorAccess`. The application uses IRSA or EKS Pod Identity with permission to read one secret or one S3 prefix. The CI/CD role that deploys YAML is a third identity. It is not the runtime role.

Do not leave the broken design as the main document. Keep `day-17-aks-eks-lab-broken.md` as the evidence of the mistake.

---

## Clean up

If you applied nginx, delete that Deployment:

```bash
kubectl delete -f deployment.yaml
kubectl get deployment nginx
```

The get should report that the Deployment was not found. Do not delete shared cluster resources that belong to other workloads.

If your notes say `CREATED_KIND=yes`, delete the cluster you created:

```bash
kind delete cluster --name day17
```

If your notes say `CREATED_KIND=no`, do not run `kind delete cluster`. You reused a cluster, or you never created one.

This lab created no AKS or EKS cluster. There is no resource group, VPC, or node pool to delete in Azure or AWS. Do not run `az group delete` or `aws eks delete-cluster` as cleanup. You never created those resources.

Leave the lab directory and remove it. Copy `day-17-aks-eks-lab.md` out first if you want to keep the notes.

```bash
cd /tmp
rm -rf "$LAB_DIR"
```

Do not copy kubeconfig or the broken identity file into the course repository.

---

## Interview story

I treat AKS and EKS as managed Kubernetes plus cloud integrations, not as two different Kubernetes products. Azure or AWS runs the control plane. I still own node pools or node groups, the VNet or VPC, add-ons, and the workloads. Workload Identity on Azure, and IRSA or EKS Pod Identity on AWS, map a ServiceAccount to a cloud role so the Pod never stores an access key. I prove the Kubernetes loop on `kind` when I need a local stand-in. I do not create AKS or EKS for that proof. I then write the failure mode: a cluster identity with Owner or `AdministratorAccess` on the whole subscription or account can reach every other team's resources. I shrink that identity to the cluster resource group or node role, and I give the application one secret. Kubernetes RBAC does not replace that cloud boundary.
