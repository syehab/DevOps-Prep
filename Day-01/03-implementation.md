# Day 1 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 1 teaches a mental model, not a cloud product. This lab is a worked design exercise. You produce a map and a short failure note. You do not create cloud resources.

---

## Goal

Build one system map for a simple public web application. Place CI/CD, Terraform, networking, security, observability, reliability, and cost on that map. Then walk one failure along the same path, using evidence instead of a guess.

When you finish, you can point at each piece and say why it exists. You can also explain the first checks you would run if the application cannot reach its database.

---

## What you need

You need a markdown file, a whiteboard, or paper. You do not need Azure, AWS, Terraform, Docker, or a cluster. Keep the work local so the cost stays at zero.

Pick a small application that you already understand. A public blog with a database is enough. A Spring Boot API with MySQL is enough. Do not add extra services “to look senior.” The point is to place the pieces you already met in the lesson.

Time box: 45 to 60 minutes. Stop when the map and the failure note are complete. Do not start a cloud account in this lab.

---

## Steps

1. Create a file named `day-01-system-map.md` in a notes folder you control. Put the application name at the top. Write one sentence that says who the user is and what they do.

2. Draw the user path first. Start with User → Application → Database. Add the network pieces you think the user needs: DNS, load balancer, and the application. Keep this as a `text` diagram so you can edit it.

3. Add delivery next to the runtime, not on top of it. Place Developer → Git → CI/CD → Deploy → Application. Write one line under CI/CD that states its job: move reviewed code into the runtime as a versioned artifact.

4. Add infrastructure as the platform under the runtime. Place Terraform with three children: network, compute, and database. Write one line that says Terraform creates the platform; it does not run the Java process.

5. Wrap the whole map with operations. Add security, observability, reliability, and cost around the path. For each one, write a single “why it exists” sentence. Use the lesson table: compute, networking, IaC, CI/CD, IAM, observability, reliability, FinOps.

6. Run the senior thinking pattern on one piece only. Pick Terraform or CI/CD. Write Why, What, How, What can go wrong, How do I know, and How do I fix it. Keep each line short. Do not turn this into a tool manual.

7. Add an Azure to AWS mapping table with at least five rows from the lesson. Use the same concept in both columns. This trains the habit: learn the concept first, then the service name.

8. Write a failure note titled “Application cannot connect to the database.” List the path in order: DNS, route, port, firewall, credentials, database health. Next to each step, write the evidence you would collect before you change anything.

---

## Verify

Read the map out loud as if you are in an interview. You should be able to start at the user and reach the database without jumping to a product name first.

Check these points:

- Every lesson area from the table appears once on the map.
- CI/CD and Terraform have different jobs. One moves code. The other creates infrastructure.
- The failure note follows the path. It does not start with “restart the app” or “open the portal and click.”
- The Azure to AWS table uses concepts as the left column, not tool slogans.

If any box is only a tool name with no “why,” add the reason before you stop.

---

## Break and fix

Do this on purpose. Remove the networking boxes from your map (DNS, load balancer, routes, firewall). Try to explain how the user reaches the application, and how the application reaches the database.

You will not be able to explain the path. That is the point. The failure is not “Java is down.” The failure is that the map no longer has a path.

Put the networking boxes back. Then add one sentence under the map: “If I cannot name the path, I do not yet understand the system.” Keep that sentence. It is the habit this Day is training.

---

## Clean up

You created no cloud resources. Keep `day-01-system-map.md` in your notes. Do not commit secrets; this file should not contain passwords, keys, or account IDs.

If you opened a cloud console out of habit, close it. Create nothing. There is no resource group, VPC, or cluster to delete today.

---

## Interview story

I start from one system map, not from a tool list. Code moves through CI/CD. Terraform creates the platform. The user reaches the app through DNS, load balancing, and the network path, while security, observability, reliability, and cost sit around the whole flow. If the app cannot reach the database, I walk that path with evidence — DNS, route, port, firewall, credentials, then database health — before I change anything.
