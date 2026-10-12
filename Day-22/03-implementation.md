# Day 22 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 22 teaches Azure as a stack of boundaries: Entra tenant, management groups, subscriptions, resource groups, then resources. This lab makes you draw that stack for ShopSphere. You write management groups, three subscriptions, resource groups, one VNet, and one Key Vault on paper. You do not need a billable VM, VNet, or vault in Azure.

Azure CLI is optional. If `az account show` proves you are logged in, create one empty lab resource group and then delete that same group. If Azure CLI is missing or not logged in, keep the work in markdown. Do not invent extra `az` flags. Do not create a VM, VNet, or Key Vault in the cloud.

---

## Goal

Write one Azure platform sketch for ShopSphere. The sketch must name the Entra tenant, the management-group tree, three subscriptions, resource groups for one workload, one VNet, and one Key Vault. Say who owns each layer. Say what a delete at each layer would destroy.

Then break the sketch on purpose. Put Key Vault in the same resource group as a disposable lab VM. Write why that shared group is a lifecycle clash. Split them so the vault outlives the VM. If Azure CLI is logged in, prove control-plane create and delete on one lab resource group only.

Time box: 45 to 75 minutes. Cost stays at ₹0 unless you create the optional lab resource group, and even then you delete it in the same session. Stop when the sketch is complete, the break-and-fix note explains the clash, and any lab resource group is gone.

---

## What you need

You need a text editor and a shell. You do not need Terraform, Bicep, a VM, or a paid Azure service. The required deliverable is a markdown sketch.

Azure CLI is optional. Check it first with the same command the lesson uses:

```bash
az account show
```

If that command prints a subscription and a tenant, you may run the optional `az group create` and `az group delete` steps. If the command fails, write `az not logged in` in your notes and skip every Azure CLI step. Do not guess flags. Do not open the portal to create extra resources.

Create the lab under `/tmp`, not under this course clone. Keep a notes file named `day-22-platform-lab.md`. Record the hierarchy, the resource-group split, and whether Azure CLI ran. Do not paste secrets, subscription IDs you must not share, or access tokens.

Use only these Azure CLI commands, and only if `az account show` succeeded. Every flag below already appears in this Day:

```bash
az account show
az group create \
  --name rg-day22-platform-lab \
  --location centralindia
az group show \
  --name rg-day22-platform-lab
az group list --output table
az resource list \
  --resource-group rg-day22-platform-lab \
  --output table
az group delete \
  --name rg-day22-platform-lab \
  --yes \
  --no-wait
az group exists \
  --name rg-day22-platform-lab
```

Do not add tags, VMs, VNets, or Key Vault with CLI in this lab. The sketch holds those objects. The optional CLI path creates and deletes one empty resource group.

---

## Steps

1. Create a throwaway directory and enter it. Use a unique folder name so you do not collide with another lab. Confirm the path is under `/tmp`.

```bash
LAB_DIR="/tmp/day-22-platform-lab-$$"
mkdir -p "$LAB_DIR"
cd "$LAB_DIR"
pwd
```

2. Create `day-22-platform-lab.md`. Put the date at the top. Write one short paragraph: ShopSphere is one company with one Entra tenant. The tenant holds users, groups, applications, and service principals. Subscriptions under that tenant hold resources. A tenant is not a subscription.

3. Draw the management-group tree. Start at the root. Add Platform, Production, and NonProduction. Write that management groups govern subscriptions. They do not hold VMs or Key Vault. Assign Policy and RBAC at these groups so child subscriptions inherit the rules.

Copy this block into the notes, then add one sentence in your own words that says why you did not make one management group per team:

```text
Root
 ├── Platform
 ├── Production
 └── NonProduction
```

4. Place three subscriptions. Put a Dev subscription and a UAT subscription under NonProduction. Put a Production subscription under Production. If you also want a network or shared-services subscription, keep it as a note under Platform. Do not replace the required three. The three required subscriptions are the isolation units for this lab: Dev, UAT, and Production.

Write why Production is separate. A bad Dev deploy must not share Production RBAC, quota, or billing. One subscription per environment is a design choice. Name the choice. Do not treat it as a law.

5. Place resource groups, a VNet, and Key Vault for ShopSphere Production. Use names a stranger can read:

```text
sub-shopsphere-prod
  ├── rg-shopsphere-prod-api
  │     └── vnet-shopsphere-prod
  └── rg-shopsphere-prod-data
        └── kv-shopsphere-prod
```

Write a short paragraph under that tree. The VNet is the network boundary for the workload. Key Vault holds secrets. Both are Azure resources. They sit inside resource groups. They do not sit in the management group. The resource group is a lifecycle and ownership boundary. It is not a subnet, a region, or an availability zone.

6. Repeat a thinner Dev and UAT sketch so the three subscriptions stay visible. You may reuse the same resource-group pattern with `dev` and `uat` in the names. Keep Production stronger: tighter RBAC, Deny-style region Policy, and no standing human Contributor.

7. Write ownership next to each layer. Entra holds identity. Platform owns Policy at the management group. The network team owns the hub story even if this sketch only shows one VNet. The ShopSphere team owns the API resource group. Security cares about Key Vault. Cost uses tags such as `Environment`, `Application`, and `Owner`. You do not need to apply tags in Azure for this lab.

8. Optional Azure CLI path. Run this step only if step `az account show` already succeeded. Create one empty lab resource group in `centralindia`. Then show it and list it. Confirm it is empty with `az resource list`.

```bash
az group create \
  --name rg-day22-platform-lab \
  --location centralindia

az group show \
  --name rg-day22-platform-lab

az group list --output table

az resource list \
  --resource-group rg-day22-platform-lab \
  --output table
```

Write the group name and location into your notes. Do not create other resources in this group. This is control-plane practice only. If `az account show` failed, skip this step and stay on the markdown sketch.

---

## Verify

Read the notes as if you are on a call. You should name the tenant, the three subscriptions, and where Key Vault lives without opening the lesson.

Check these points:

- The sketch shows Root → Platform, Production, NonProduction.
- Dev, UAT, and Production are three subscriptions, not three resource groups inside one subscription.
- Production has a VNet and a Key Vault. Each has a resource group.
- The notes say a management group does not contain application resources.
- The notes say deleting a resource group can delete the resources inside it.
- If Azure CLI ran, `az group show` named `rg-day22-platform-lab`, and `az resource list` showed no extra resources in that group.
- If Azure CLI did not run, the notes say `az not logged in` and the sketch is still complete.

If a heading has no paragraph under it, fill it before you stop. An empty tree is not a platform design.

---

## Break and fix

Copy the finished sketch so you can keep the good design. Do not overwrite it until you have written the lifecycle note.

```bash
cp day-22-platform-lab.md day-22-platform-lab-broken.md
```

Open `day-22-platform-lab-broken.md`. Put a disposable lab VM and Key Vault in the same resource group:

```text
rg-shopsphere-prod-lab
  ├── vm-shopsphere-jump
  └── kv-shopsphere-prod
```

Write a section titled `Lifecycle clash`. Answer these questions in prose, not as a checklist.

A lab VM is short-lived. You create it, use it, and delete it. Key Vault holds secrets that the application still needs after the jump box is gone. Resource-group delete is not selective. If you delete `rg-shopsphere-prod-lab` to remove the VM, Azure can delete Key Vault as well. The secrets go with the vault. That is the clash: two resources that should not share a lifecycle now share a delete boundary.

RBAC follows the same mistake. Contributor on that group can change the VM and the vault. A person who only needed a jump box now sits on the secret store. Blast radius grew because the group mixed a disposable compute object with a durable secret object.

Then fix the main file `day-22-platform-lab.md`. Split the group. Put the disposable VM in `rg-shopsphere-prod-lab`. Put Key Vault in `rg-shopsphere-prod-data`. Keep the VNet in `rg-shopsphere-prod-api` or in a network group if you already drew one. Write one paragraph that says deleting the lab group now removes the VM only. The vault survives. That is the resource-group lesson from this Day.

Do not leave the mixed group as the main design. Keep `day-22-platform-lab-broken.md` as evidence of the mistake.

---

## Clean up

If you skipped Azure CLI, this lab created markdown only. There is no cloud resource to destroy.

If you created `rg-day22-platform-lab`, delete that group and no other group. Confirm it is the lab group before you delete. Do not delete `rg-azure-architecture-lab` unless you created that name yourself in another exercise and you know it holds only lab resources.

```bash
az group delete \
  --name rg-day22-platform-lab \
  --yes \
  --no-wait

az group exists \
  --name rg-day22-platform-lab
```

`az group exists` may still print `true` for a short time because `--no-wait` returns before the delete finishes. Run it again until it prints `false`. Then list resources so you did not leave an object in another group:

```bash
az resource list --output table
```

Do not delete shared, production, or centrally managed resources.

If you want to keep the sketch, copy `day-22-platform-lab.md` out of the temp directory first. Then leave the lab directory and delete it.

```bash
cd /tmp
rm -rf "$LAB_DIR"
```

Do not copy the files into the course repository unless you are submitting homework through a path your instructor named.

---

## Interview story

I design Azure from the tenant down, not from a service catalog. ShopSphere has one Entra tenant, management groups for Platform, Production, and NonProduction, and three subscriptions for Dev, UAT, and Production. Resource groups hold resources that share a lifecycle. A VNet and Key Vault are resources inside those groups. They are not children of the management group. I then put Key Vault in the same resource group as a disposable VM. Deleting that group to remove the VM would also delete the vault, so secrets would vanish with a jump box. I split them. The lab VM can die. The vault stays. If Azure CLI was logged in, I created one empty lab resource group and deleted that same group. I did not leave billable resources running.
