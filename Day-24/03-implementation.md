# Day 24 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 24 teaches Azure traffic as a path, not as a list of product names. A VNet holds the address space. Subnets place the web, app, and database tiers. An NSG answers whether a flow is allowed. A route table answers where the packet goes. This lab makes you design that path on paper first.

Azure CLI is optional. Use `az network` only if `az account show` succeeds on this machine. Use only flags that appear in this Day’s lesson. Delete every lab resource before you stop. If Azure CLI is missing or not logged in, the markdown design and the NSG diagram are the lab.

---

## Goal

Design one VNet `10.20.0.0/16` with three `/24` subnets: Web `10.20.1.0/24`, App `10.20.2.0/24`, and DB `10.20.3.0/24`. Write NSG rules for inbound TCP 443 to web, TCP 8080 from web to app, and TCP 5432 from app to db. Deny internet sources to the database port. Draw the packet path from a browser to PostgreSQL.

Then break the design on purpose. Add an NSG deny for TCP 5432 so the app cannot reach the database. Restore allow from the app subnet only. Do not open the database to the internet to “make it work.”

If `az` is logged in, create the VNet, subnets, and NSG rules in a throwaway resource group, list the rules, add the deny, remove the deny, and delete the group. If `az` is not logged in, stay on the markdown design. Do not invent a portal walkthrough.

Time box: 45 to 75 minutes. Paper-only cost stays at ₹0. Stop when the notes file holds the CIDR plan, the four NSG rules, the break, the restore, and, if you used Azure, the resource group is gone.

---

## What you need

You need a shell and a text editor. You do not need Kubernetes, Terraform, or a paid Azure lab to finish. The address plan and the NSG diagram are enough when Azure CLI is unavailable.

Azure CLI is optional. Check it, then check login. Skip every `az network` step if either command fails.

```bash
command -v az
az account show
```

If `command -v az` prints nothing, write `az missing — markdown and diagram are the lab` in your notes. If `az account show` fails, write `az not logged in — markdown and diagram are the lab`. Do not create resources in the Azure portal as a substitute. Do not invent flags.

If login succeeds, use only these lesson commands and flags:

- `az group create --name --location`
- `az network vnet create --resource-group --name --address-prefix --subnet-name --subnet-prefix`
- `az network vnet subnet create --resource-group --vnet-name --name --address-prefix`
- `az network nsg create --resource-group --name`
- `az network nsg rule create --resource-group --nsg-name --name --priority --source-address-prefixes --destination-port-ranges --protocol --access --direction`
- `az network vnet subnet update --resource-group --vnet-name --name --network-security-group`
- `az network nsg rule list --resource-group --nsg-name --output table`
- `az network nsg rule delete --resource-group --nsg-name --name`
- `az group delete --name --yes --no-wait`
- `az group show --name`

Create the lab under `/tmp`, not under this course clone. Keep a notes file named `day-24-nsg-lab.md` in that temp directory. Record the CIDR plan, the NSG table, the break, and the restore. Do not paste subscription IDs or secrets.

---

## Steps

1. Create a throwaway directory and enter it. Use a unique folder name so you do not collide with another lab. Confirm the path is under `/tmp`.

```bash
LAB_DIR="/tmp/day-24-nsg-lab-$$"
mkdir -p "$LAB_DIR"
cd "$LAB_DIR"
pwd
```

2. Start the notes file. The design is the required lab. Azure create steps come later only if login works.

```bash
cat > day-24-nsg-lab.md << 'EOF'
# Day 24 NSG lab notes

## CIDR plan

VNet:
Web:
App:
DB:

## NSG rules

Internet → Web 443:
Web → App 8080:
App → DB 5432:
Internet → DB 5432:

## Path

Client → DNS → Web → App → DB

## Break

## Restore

## Azure CLI

EOF
```

3. Write the address plan into the notes. Use this layout. Do not overlap the three `/24` ranges. Leave the rest of `10.20.0.0/16` free for later subnets such as private endpoints.

```text
VNet  10.20.0.0/16
│
├── snet-web  10.20.1.0/24
│
├── snet-app  10.20.2.0/24
│
└── snet-data 10.20.3.0/24
```

4. Write the NSG table. Routing and NSGs are different controls. The table answers “is this traffic allowed?” It does not choose the next hop.

```text
Priority  Name                 Direction  Source           Dest port  Access
100       Allow-Internet-443   Inbound    0.0.0.0/0        443        Allow   (nsg-web)
100       Allow-Web-8080       Inbound    10.20.1.0/24     8080       Allow   (nsg-app)
100       Allow-App-Postgres   Inbound    10.20.2.0/24     5432       Allow   (nsg-data)
200       Deny-Internet-5432   Inbound    0.0.0.0/0        5432       Deny    (nsg-data)
```

The allow from `10.20.2.0/24` to 5432 has a lower priority number than the deny from `0.0.0.0/0`. The first matching rule wins. App traffic matches the allow. Internet traffic does not match that source, so it hits the deny. Do not use `*` as the source on the database allow.

5. Draw the inbound path in the notes. Keep the database off the public internet.

```text
Client
  → DNS
  → public IP / Application Gateway
  → snet-web :443
  → snet-app :8080
  → snet-data :5432
```

Write one sentence: the database has no public listener. Web may not open 5432. App is the only intended source for PostgreSQL.

6. On paper, break TCP 5432. Add a deny from the app subnet with priority 90, which is lower than the allow at 100. The first match is now deny. Write what the app sees: `nc -vz <db-ip> 5432` times out or is refused. This is an NSG problem, not a missing route. The route to `10.20.3.0/24` still exists.

```text
Priority 90  Deny-App-Postgres  Inbound  10.20.2.0/24  5432  Deny
```

7. Restore allow from the app subnet only. Remove the priority-90 deny. Keep `Allow-App-Postgres` at 100 with source `10.20.2.0/24`. Keep `Deny-Internet-5432` at 200. Do not “fix” the outage by allowing `0.0.0.0/0` to 5432. Write the restored table in the notes.

8. Check Azure CLI login. If either command fails, write that in the Azure CLI section of the notes and go to Verify. Do not run the create steps.

```bash
command -v az
az account show
```

9. If login succeeded, create a throwaway resource group. Use `centralindia` as this Day’s lesson does. Replace the suffix with your own unique value if `$$` is awkward in your shell.

```bash
az group create \
  --name rg-day24-nsg-lab \
  --location centralindia
```

10. Create the VNet and the web subnet first. Then add the app and data subnets. These flags match the VNet examples in the lesson.

```bash
az network vnet create \
  --resource-group rg-day24-nsg-lab \
  --name vnet-day24 \
  --address-prefix 10.20.0.0/16 \
  --subnet-name snet-web \
  --subnet-prefix 10.20.1.0/24

az network vnet subnet create \
  --resource-group rg-day24-nsg-lab \
  --vnet-name vnet-day24 \
  --name snet-app \
  --address-prefix 10.20.2.0/24

az network vnet subnet create \
  --resource-group rg-day24-nsg-lab \
  --vnet-name vnet-day24 \
  --name snet-data \
  --address-prefix 10.20.3.0/24
```

11. Create one NSG per subnet. Add the four intended rules. Associate each NSG with its subnet. List the data NSG and confirm Allow at 100 and Deny at 200.

```bash
az network nsg create --resource-group rg-day24-nsg-lab --name nsg-web
az network nsg create --resource-group rg-day24-nsg-lab --name nsg-app
az network nsg create --resource-group rg-day24-nsg-lab --name nsg-data

az network nsg rule create \
  --resource-group rg-day24-nsg-lab \
  --nsg-name nsg-web \
  --name Allow-Internet-443 \
  --priority 100 \
  --source-address-prefixes 0.0.0.0/0 \
  --destination-port-ranges 443 \
  --protocol Tcp \
  --access Allow \
  --direction Inbound

az network nsg rule create \
  --resource-group rg-day24-nsg-lab \
  --nsg-name nsg-app \
  --name Allow-Web-8080 \
  --priority 100 \
  --source-address-prefixes 10.20.1.0/24 \
  --destination-port-ranges 8080 \
  --protocol Tcp \
  --access Allow \
  --direction Inbound

az network nsg rule create \
  --resource-group rg-day24-nsg-lab \
  --nsg-name nsg-data \
  --name Allow-App-Postgres \
  --priority 100 \
  --source-address-prefixes 10.20.2.0/24 \
  --destination-port-ranges 5432 \
  --protocol Tcp \
  --access Allow \
  --direction Inbound

az network nsg rule create \
  --resource-group rg-day24-nsg-lab \
  --nsg-name nsg-data \
  --name Deny-Internet-5432 \
  --priority 200 \
  --source-address-prefixes 0.0.0.0/0 \
  --destination-port-ranges 5432 \
  --protocol Tcp \
  --access Deny \
  --direction Inbound

az network vnet subnet update \
  --resource-group rg-day24-nsg-lab \
  --vnet-name vnet-day24 \
  --name snet-web \
  --network-security-group nsg-web

az network vnet subnet update \
  --resource-group rg-day24-nsg-lab \
  --vnet-name vnet-day24 \
  --name snet-app \
  --network-security-group nsg-app

az network vnet subnet update \
  --resource-group rg-day24-nsg-lab \
  --vnet-name vnet-day24 \
  --name snet-data \
  --network-security-group nsg-data

az network nsg rule list \
  --resource-group rg-day24-nsg-lab \
  --nsg-name nsg-data \
  --output table
```

Copy the table into the notes. This lab does not create VMs, so you do not run `nc` against a live database. The rule list is the evidence.

12. If login succeeded, add the break rule, list again, then delete the break rule so the app-subnet allow is first again.

```bash
az network nsg rule create \
  --resource-group rg-day24-nsg-lab \
  --nsg-name nsg-data \
  --name Deny-App-Postgres \
  --priority 90 \
  --source-address-prefixes 10.20.2.0/24 \
  --destination-port-ranges 5432 \
  --protocol Tcp \
  --access Deny \
  --direction Inbound

az network nsg rule list \
  --resource-group rg-day24-nsg-lab \
  --nsg-name nsg-data \
  --output table

az network nsg rule delete \
  --resource-group rg-day24-nsg-lab \
  --nsg-name nsg-data \
  --name Deny-App-Postgres

az network nsg rule list \
  --resource-group rg-day24-nsg-lab \
  --nsg-name nsg-data \
  --output table
```

After the delete, priority 90 is gone. Priority 100 allow from `10.20.2.0/24` is the first match for app traffic. Priority 200 still denies internet to 5432. Write both tables in the notes.

---

## Verify

Read the notes as if you are on a call. You should name the `/16`, the three `/24` subnets, and the four NSG rules. You should say why a deny at priority 90 blocks the app even though an allow at 100 still exists.

Check these points:

- The notes show VNet `10.20.0.0/16`, Web `10.20.1.0/24`, App `10.20.2.0/24`, and DB `10.20.3.0/24`.
- Inbound 443 is allowed to web. 8080 is allowed from web to app. 5432 is allowed from the app subnet only.
- Internet to 5432 is deny. The database source is not `*`.
- The break is an NSG deny on 5432 from the app subnet at a lower priority number than the allow.
- The restore keeps allow from `10.20.2.0/24` and does not open 5432 to `0.0.0.0/0`.
- If `az` was missing or not logged in, the notes say so, and you did not run create commands.
- If `az` ran, both `az network nsg rule list` outputs are in the notes, and you deleted the resource group in Clean up.

If a required `az` flag is missing on your CLI version, write the error in the notes and keep the paper plan. Do not invent a replacement flag.

---

## Break and fix

You already added the deny in step 6, and in step 12 if Azure ran. That is the lab failure. The app cannot reach PostgreSQL because the first matching NSG rule is deny. The route is still correct. Do not start by changing a UDR.

Say that out loud: wrong path is routing; correct path but blocked is NSG. Restore by removing the deny, not by allowing the internet. Confirm the remaining allow names the app subnet as source.

If Azure CLI was missing, the paper break is enough. Do not create a real VNet in the portal to finish this step.

---

## Clean up

If you did not run `az`, leave the notes if you want them, then delete the temp directory.

```bash
cd /tmp
rm -rf "$LAB_DIR"
```

If you created Azure resources, delete the whole lab resource group. Do not delete shared hub, firewall, or DNS resources that you did not create in this lab. This lab used a dedicated group, so delete that group.

```bash
az group delete \
  --name rg-day24-nsg-lab \
  --yes \
  --no-wait

az group show \
  --name rg-day24-nsg-lab
```

`az group show` should fail after delete completes. Then remove the temp directory.

```bash
cd /tmp
rm -rf "$LAB_DIR"
```

If you want to keep the notes, copy `day-24-nsg-lab.md` out before `rm -rf`. Do not leave a billed VNet, NSG, or public IP behind.

---

## Interview story

I design Azure networks from the packet path, not from a service catalog. I put web, app, and database in separate subnets inside `10.20.0.0/16`. Users reach web on TCP 443. Web reaches app on 8080. App reaches PostgreSQL on 5432. The database has no internet allow. An NSG deny at a lower priority number than the allow is enough to take the app down even when the route still exists. I restore the allow from the app subnet only. I do not open 5432 to the world. If I use `az network`, I create the rules, list them, break 5432, restore, and delete the resource group.
