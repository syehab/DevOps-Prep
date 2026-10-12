# Day 12 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 12 teaches one cloud networking model: name, IP, route, security, then destination. This lab makes you write that model on paper for `10.20.0.0/16`. You plan three `/24` subnets for web, app, and database. You also draw the request path and the NSG or Security Group flows.

If Docker is present, you then prove the same idea on a local user-defined network. You create one Docker network, run two containers, and ping across it. You then disconnect one container so the path breaks. If Docker is missing, the address plan and the path diagram are the lab. Say that in your notes and stop after Verify. Do not create Azure or AWS resources.

---

## Goal

Write a CIDR plan for `10.20.0.0/16` with Web `10.20.1.0/24`, App `10.20.2.0/24`, and DB `10.20.3.0/24`. Record which subnet may talk to which other subnet. Draw the user request path through DNS, a public load balancer, private web, private app, and private database.

If `docker` works on this machine, create a local Docker network and run two Alpine or BusyBox containers on it. Ping from one container to the other. Disconnect one container from the network so ping fails. Reconnect it so ping works again. When you finish, you can explain address planning, routing versus security, and why a missing path stops traffic, without a cloud bill.

Time box: 45 to 75 minutes. Cost stays at ₹0. Stop when the notes file is complete and, if you used Docker, the containers and network are gone.

---

## What you need

You need a shell and a text editor. You do not need Azure, AWS, Terraform, or a paid account. Cost stays at ₹0.

Docker is optional. Check it first:

```bash
docker version
```

If that command fails, skip every Docker step. The address plan and the path diagram are then the full lab. Write `docker missing` in your notes. Do not invent a substitute tool.

If Docker is present, use only these real commands and flags:

- `docker network create` to make a user-defined network
- `docker run --network` to attach a container to that network
- `docker exec` plus `ping` to test reachability by container name
- `docker network disconnect` to break the path
- `docker network connect` to restore the path
- `docker rm` and `docker network rm` to clean up

Create the lab under `/tmp`, not under this course clone. Keep a notes file named `day-12-network-lab.md` in that temp directory. Record the address plan, the path, the allow rules, and whether Docker ran.

---

## Steps

1. Create a throwaway directory and enter it. Use a unique folder name so you do not collide with another lab. Confirm the path is under `/tmp`.

```bash
LAB_DIR="/tmp/day-12-network-lab-$$"
mkdir -p "$LAB_DIR"
cd "$LAB_DIR"
pwd
```

2. Create `day-12-network-lab.md`. Put the date at the top. Write one sentence: you will plan `10.20.0.0/16` for web, app, and database, then prove a local network path only if Docker is present.

3. Write the address plan into the notes file. Copy this block, then fill the usable-host note in your own words.

```text
VNet/VPC: 10.20.0.0/16
Web:      10.20.1.0/24
App:      10.20.2.0/24
DB:       10.20.3.0/24
```

The `/16` is the whole private network. Each `/24` is one subnet inside it. Cloud platforms reserve some addresses in each subnet, so usable host counts sit below 256. Write that these ranges do not overlap. Overlapping CIDR blocks make peering and hybrid links hard later.

4. Write the allowed flows. Web may receive traffic from a public load balancer. Web may reach App on the application port. App may reach DB on TCP `5432`. Web must not talk to DB. DB must not start connections to Web. This is segmentation, not a full mesh.

5. Draw the request path in the notes file:

```text
User → DNS → Public Load Balancer → Web 10.20.1.0/24 → App 10.20.2.0/24 → DB 10.20.3.0/24
```

Write where each decision sits. DNS answers the name. The route table answers where the packet goes. The NSG or Security Group answers whether the packet is allowed. The database port must be listening. These are separate checks.

6. Write the intended database security rule:

```text
Source: Application subnet 10.20.2.0/24
Destination: Database 10.20.3.0/24
Port: 5432
Protocol: TCP
Action: Allow
```

Write one sentence: an internet-wide source is wrong for a private database. Routing and this allow rule are not the same control.

7. Check Docker. If the command fails, write `docker missing — address plan and path diagram are the lab` and go to Verify. Do not run the container steps.

```bash
docker version
```

8. If Docker is present, create one user-defined network. Docker embeds DNS on this network, so container names resolve. That is the local analog of private name resolution on a shared network.

```bash
docker network create day12-lab
```

9. Run two containers on that network. Use Alpine. If the Alpine pull fails, use BusyBox the same way. `sleep 3600` keeps each container running so you can exec into it.

```bash
docker run -d --name day12-web --network day12-lab alpine sleep 3600
docker run -d --name day12-app --network day12-lab alpine sleep 3600
```

10. Ping from web to app by name. Copy the result into your notes. A reply means both containers share a network path and name resolution worked.

```bash
docker exec day12-web ping -c 3 day12-app
```

11. Break the path. Disconnect the app container from the network. Ping again. The ping should fail because the route to that name is gone. Copy the failure into your notes. This is the local analog of a missing route, not a cloud NSG change.

```bash
docker network disconnect day12-lab day12-app
docker exec day12-web ping -c 3 day12-app
```

12. Restore the path. Connect the app container again. Ping once more. The ping should succeed. Write that you fixed the path by restoring membership on the network, not by opening a firewall.

```bash
docker network connect day12-lab day12-app
docker exec day12-web ping -c 3 day12-app
```

---

## Verify

Read the notes as if you are on a call. You should name the `/16`, the three `/24` subnets, the allowed flows, and the user request path.

Check these points:

- The notes show `10.20.0.0/16` with Web `10.20.1.0/24`, App `10.20.2.0/24`, and DB `10.20.3.0/24`.
- The notes say Web may reach App, App may reach DB on `5432`, and Web must not reach DB.
- The path includes DNS, a public load balancer, and private web, app, and database.
- The database rule uses the application subnet as source, not the internet.
- If Docker was missing, the notes say so, and you did not run container commands.
- If Docker ran, ping succeeded, failed after `docker network disconnect`, and succeeded again after `docker network connect`.

If a required Docker command is missing, write that in the notes and keep the paper plan. Do not invent flags.

---

## Break and fix

If Docker ran, you already broke the path in step 11. That is the lab failure. The fix is `docker network connect`, not a new security rule. Say that out loud: routing and network membership are not the same as an NSG or Security Group allow.

If Docker is missing, break the design on paper. Remove the App-to-DB route, or change the database source to the internet. Write what fails for a Spring Boot application that needs TCP `5432`. Then restore the original rule. The paper break is enough when Docker is not present.

Do not start a real Azure VNet or AWS VPC to complete this break. This lab stays local.

---

## Clean up

If you did not run Docker, leave the notes if you want them, then delete the temp directory.

```bash
cd /tmp
rm -rf "$LAB_DIR"
```

If you ran Docker, remove the containers first, then remove the network. Use `docker rm -f` so a running container does not block the delete. Then `docker network rm`.

```bash
docker rm -f day12-web day12-app
docker network rm day12-lab
```

Confirm both names are gone. Then delete the temp directory.

```bash
cd /tmp
rm -rf "$LAB_DIR"
```

If you want to keep the notes, copy `day-12-network-lab.md` out before `rm -rf`. You created no Azure or AWS resources, so there is no VNet, VPC, NAT Gateway, or public IP to delete.

---

## Interview story

I plan cloud networks from the CIDR down, not from product names. For `10.20.0.0/16` I cut Web, App, and Database into `/24` subnets so each tier has its own routing and security. A user HTTPS request hits DNS, then a public load balancer, then private web and app. The database has no public IP. App reaches it on TCP `5432` only. Routing answers where the packet goes. An NSG or Security Group answers whether it is allowed. On a laptop I prove the path idea with `docker network create` and two containers. Ping works until I disconnect one container. I restore the path with `docker network connect`. Azure VNet and AWS VPC are two names for that same model.
