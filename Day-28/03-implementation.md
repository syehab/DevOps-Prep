# Day 28 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 28 teaches AWS networking as a path, not as a list of product names. A VPC holds the address space. Subnets sit in Availability Zones. A route table answers where the packet goes. A Security Group answers whether the packet is allowed. An Internet Gateway makes a subnet public. A NAT Gateway lets a private subnet start outbound internet traffic. A VPC endpoint lets a private subnet reach an AWS service without the internet.

This lab is a design on paper. You plan VPC `10.50.0.0/16` across two Availability Zones. You draw public, private-app, and private-db subnets, then you write the IGW, NAT, routes, and Security Groups. Docker networks are an optional local stand-in. Do not create AWS resources. NAT Gateways, load balancers, and Elastic IPs bill even when the application is idle.

---

## Goal

Design one VPC `10.50.0.0/16` with six subnets across two Availability Zones: public, private-app, and private-db in AZ-a, and the same three roles in AZ-b. Write the route tables for IGW and NAT. Write Security Group flows for Internet → ALB 443, ALB → App 8080, and App → RDS 5432. Draw the packet path in markdown.

Then break the design on purpose. Remove NAT from the private-app subnet and add no VPC endpoint. Explain why that subnet cannot reach the internet or public AWS APIs. Restore the path on paper with a NAT Gateway for general egress, or with a gateway endpoint if the destination is S3.

If `docker` works on this machine, create local networks as a stand-in for public versus private-with-no-egress. Ping from a container on the internal network so you can see the missing path. If Docker is missing, the markdown design is the lab.

Time box: 45 to 75 minutes. Cost stays at ₹0. Stop when the notes file holds the CIDR plan, the diagram, the routes, the Security Groups, the break, and the restore. If you used Docker, remove the containers and networks before you stop.

---

## What you need

You need a shell and a text editor. You do not need AWS, Azure, Terraform, or a paid account. Do not run `aws ec2 create-vpc` or any other create command against a cloud account. This lab must not spend money.

Docker is optional. Check it first:

```bash
docker version
```

If that command fails, skip every Docker step. Write `docker missing — markdown design is the lab` in your notes. Do not invent a substitute tool. Do not open the AWS console to “make it real.”

If Docker is present, use only these real commands and flags:

- `docker network create` to make a user-defined network
- `docker network create --internal` to make a network with no external access
- `docker run --network` to attach a container to that network
- `docker exec` plus `ping` to test reachability
- `docker network connect` to add a second network, which is the local analog of adding a NAT path
- `docker rm` and `docker network rm` to clean up

Create the lab under `/tmp`, not under this course clone. Keep a notes file named `day-28-vpc-lab.md` in that temp directory. Record the CIDR plan, the diagram, the routes, the Security Groups, the break, and whether Docker ran.

---

## Steps

1. Create a throwaway directory and enter it. Use a unique folder name so you do not collide with another lab. Confirm the path is under `/tmp`.

```bash
LAB_DIR="/tmp/day-28-vpc-lab-$$"
mkdir -p "$LAB_DIR"
cd "$LAB_DIR"
pwd
```

2. Start the notes file. The markdown design is the required lab. Docker comes later only if `docker version` works.

```bash
cat > day-28-vpc-lab.md << 'EOF'
# Day 28 VPC lab notes

## CIDR plan

VPC:
AZ-a public:
AZ-a private-app:
AZ-a private-db:
AZ-b public:
AZ-b private-app:
AZ-b private-db:

## Diagram

## Routes

Public:
Private-app:
Private-db:

## Security Groups

Internet → ALB 443:
ALB → App 8080:
App → RDS 5432:
Internet → RDS 5432:

## Break

## Restore

## Docker

EOF
```

3. Write the address plan into the notes. Use this layout. Do not overlap the six `/24` ranges. Leave the rest of `10.50.0.0/16` free for later subnets such as VPC endpoints or Transit Gateway attachments.

```text
VPC              10.50.0.0/16

AZ-a public      10.50.1.0/24
AZ-a private-app 10.50.11.0/24
AZ-a private-db  10.50.21.0/24

AZ-b public      10.50.2.0/24
AZ-b private-app 10.50.12.0/24
AZ-b private-db  10.50.22.0/24
```

The `/16` is the whole private network. Each `/24` is one subnet inside it. A subnet lives in one Availability Zone, so you copy the three roles into AZ-b. Write that these ranges do not overlap on-premises, VPN, Direct Connect, or other VPCs. Overlap makes later connectivity fail.

4. Draw the VPC in the notes. Copy this markdown diagram, then keep it as the picture you explain on a call.

```text
                         Internet
                            |
                           IGW
                            |
          +-----------------+-----------------+
          |         VPC 10.50.0.0/16          |
          |                                   |
          |  AZ-a             AZ-b            |
          |  10.50.1.0/24     10.50.2.0/24    |  public (ALB, NAT)
          |        |                 |        |
          |       NAT               NAT       |
          |        |                 |        |
          |  10.50.11.0/24    10.50.12.0/24   |  private-app
          |        |                 |        |
          |  10.50.21.0/24    10.50.22.0/24   |  private-db
          +-----------------------------------+
```

Write where each decision sits. DNS answers the name. The route table answers where the packet goes. The Security Group answers whether the packet is allowed. The database port must be listening. These are separate checks.

5. Write the route tables. Public subnets send `0.0.0.0/0` to the Internet Gateway. Private-app subnets send `0.0.0.0/0` to a NAT Gateway that sits in the public subnet of the same AZ. Private-db subnets keep the local VPC route only. Do not give the database a default route to IGW or NAT unless you have a specific reason.

```text
Public:
  10.50.0.0/16 → local
  0.0.0.0/0    → Internet Gateway

Private-app:
  10.50.0.0/16 → local
  0.0.0.0/0    → NAT Gateway

Private-db:
  10.50.0.0/16 → local
```

Write one sentence: a subnet is public because of its route and addressing, not because of its name. Write a second sentence: the NAT Gateway needs the public subnet and an Elastic IP, because NAT itself must reach the Internet Gateway.

6. Write the Security Group flows. Prefer a Security Group as the source, not the whole VPC CIDR.

```text
Internet → ALB SG : TCP 443 allow
ALB SG   → App SG : TCP 8080 allow
App SG   → DB SG  : TCP 5432 allow
Internet → DB SG  : no inbound rule (denied)
```

Write that RDS stays in private-db with no public IP. Users enter through the ALB in the public subnet. The app never needs a public IP when NAT or a VPC endpoint covers outbound needs.

7. Write the intended inbound and outbound paths.

```text
Inbound:  User → DNS → ALB (public) → App (private-app) → RDS (private-db)
Outbound: App → private-app route → NAT → IGW → internet
S3:       App → S3 gateway endpoint (no NAT) when you add that endpoint
```

8. Check Docker. If the command fails, write `docker missing — markdown design is the lab` and go to Verify. Do not run the container steps.

```bash
docker version
```

9. If Docker is present, create two networks. `day28-public` is a normal user-defined network. It can reach the host’s external path, so it stands in for a public subnet with IGW or for a private subnet that has NAT. `day28-private-no-egress` uses `--internal`. Docker blocks external access on that network. That stands in for a private subnet with no NAT and no VPC endpoint.

```bash
docker network create day28-public
docker network create --internal day28-private-no-egress
docker network ls
```

10. Run one Alpine container on the internal network. `sleep 3600` keeps it running so you can exec into it. If the Alpine pull fails, use BusyBox the same way.

```bash
docker run -d --name day28-app --network day28-private-no-egress alpine sleep 3600
```

11. Ping an internet address from the container. Copy the result into your notes. The ping should fail, because the internal network has no path out. This is the local analog of a private subnet with no NAT Gateway and no VPC endpoint.

```bash
docker exec day28-app ping -c 3 1.1.1.1
```

12. Restore a path. Connect the same container to `day28-public`. Ping again. The ping should succeed if this machine can reach the internet. Write that you did not open a Security Group. You added a network path, which is the analog of adding NAT (or an endpoint for AWS services).

```bash
docker network connect day28-public day28-app
docker exec day28-app ping -c 3 1.1.1.1
```

---

## Verify

Read the notes as if you are on a call. You should name the `/16`, the six `/24` subnets, the IGW route, the NAT route, and the three Security Group allow rules.

Check these points:

- The notes show VPC `10.50.0.0/16` with public `10.50.1.0/24` and `10.50.2.0/24`, private-app `10.50.11.0/24` and `10.50.12.0/24`, and private-db `10.50.21.0/24` and `10.50.22.0/24`.
- The diagram shows IGW, NAT in public subnets, app in private-app, and RDS in private-db across two AZs.
- Public `0.0.0.0/0` points at IGW. Private-app `0.0.0.0/0` points at NAT. Private-db has no internet default route.
- ALB allows 443 from the internet. App allows 8080 from the ALB Security Group. RDS allows 5432 from the App Security Group only.
- The break section says a private subnet with no NAT and no VPC endpoint cannot reach the internet, because no route target exists for `0.0.0.0/0` or for the AWS prefix list.
- If Docker was missing, the notes say so, and you did not run container commands.
- If Docker ran, ping failed on `--internal` and succeeded after `docker network connect day28-public`.

If a required Docker command is missing, write that in the notes and keep the paper plan. Do not invent flags. Do not create an AWS VPC to finish the lab.

---

## Break and fix

Break the paper design first. This is the required failure.

Erase the private-app default route to NAT. Do not add a VPC endpoint. The app still has a local route to `10.50.0.0/16`, so it can reach RDS on 5432 if the Security Groups allow it. The app cannot reach `https://api.example.com`. It cannot reach public S3. Package updates that need the internet also fail. Write that sentence in the notes. The missing piece is the next hop, not the Security Group.

Restore on paper. Pick one path and write it:

- General internet: put NAT in the public subnet, then set private-app `0.0.0.0/0` to that NAT Gateway.
- S3 only: add an S3 gateway endpoint and a prefix-list route. S3 then stays on the AWS network. Other internet hosts still need NAT.

Do not give the app a public IP to “make it work.” Do not attach the private-app route table to the Internet Gateway. That would make the subnet public.

If Docker ran, you already broke the path in step 11. The fix in step 12 is `docker network connect`, not a new Security Group rule. Say that out loud: routing and network membership are not the same as a Security Group allow.

---

## Clean up

If you did not run Docker, leave the notes if you want them, then delete the temp directory.

```bash
cd /tmp
rm -rf "$LAB_DIR"
```

If you ran Docker, remove the container first, then remove both networks. Use `docker rm -f` so a running container does not block the delete.

```bash
docker rm -f day28-app
docker network rm day28-public day28-private-no-egress
```

Confirm the names are gone. Then delete the temp directory.

```bash
cd /tmp
rm -rf "$LAB_DIR"
```

If you want to keep the notes, copy `day-28-vpc-lab.md` out before `rm -rf`. You created no AWS resources, so there is no VPC, NAT Gateway, load balancer, or Elastic IP to delete. That is the point of this lab.

---

## Interview story

I design an AWS network from the CIDR down, not from product names. For `10.50.0.0/16` I place public, private-app, and private-db subnets in two Availability Zones so one AZ failure does not take the platform. Public subnets route `0.0.0.0/0` to an Internet Gateway. Private-app subnets route `0.0.0.0/0` to a NAT Gateway in the public subnet. The database subnet has no internet route. Users hit an ALB on 443. The ALB Security Group is the only source into the app on 8080. The app Security Group is the only source into RDS on 5432. If I forget NAT and I add no VPC endpoint, the private subnet cannot reach the internet, because no route target exists. I restore NAT for general egress, or an S3 gateway endpoint when the destination is S3. I do not put a public IP on the app to hide a routing mistake. On a laptop I can show the same missing path with `docker network create --internal`.
