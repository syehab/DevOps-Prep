# Day 2 — Questions and answers

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Then answer each item below before you open the Answer block. After that, do the lab in [03-implementation.md](03-implementation.md).

Write your own answer first. Open the Answer block only after you try. Keep the original numbering.

---

## 1. Mini Exercise — Step A — Inspect the server

# 07 · Mini Exercise · 10–15 min

Use any Linux environment.

### Step A — Inspect the server

```bash
uname -a
free -h
df -h
```

Identify the OS/kernel, available memory and disk usage.

<details>
<summary>Answer</summary>

`uname -a` shows the OS and kernel. Read the kernel name, hostname, kernel version, and architecture so you know which Linux environment the application runs on. `free -h` shows memory in a human-readable form. Look at total, used, and available memory, because low available memory can stop the JVM even while the Java process still exists.

`df -h` shows disk usage per filesystem. Look at the Use% column. A disk at 100% can stop logs, block writes, and crash the application. Together these three commands answer: which OS and kernel, how much memory remains, and whether the disk is full.

</details>

---

## 2. Mini Exercise — Step B — Inspect processes

### Step B — Inspect processes

```bash
ps aux
```

Find a process you recognize and note its PID.

<details>
<summary>Answer</summary>

`ps aux` lists running processes. Find a process you recognize, such as `java` for a Spring Boot application, and note its PID. The PID is the unique Process ID Linux gives that running instance, so you can inspect that process and no other.

If the process is gone, the application cannot serve requests. If it exists but uses too much CPU or memory, it can still be unhealthy. “Process exists” does not mean “application is healthy.”

</details>

---

## 3. Mini Exercise — Step C — Inspect listening ports

### Step C — Inspect listening ports

```bash
ss -lntp
```

Identify which ports are listening and, where available, which process owns them.

<details>
<summary>Answer</summary>

`ss -lntp` lists listening TCP ports and, where available, the process that owns each port. Find a line such as `LISTEN ... :8080 ... java`. That proves a process opened the port. It does not prove that the application is healthy or that clients can reach it.

An application can run without being reachable. Keep these steps separate: process running, application listening, network can reach it, application responds correctly.

</details>

---

## 4. Mini Exercise — Step D — Inspect logs

### Step D — Inspect logs

Pick a service or application and inspect its logs.

Ask yourself:

> **If this application stopped working right now, what evidence would I collect before changing anything?**

<details>
<summary>Answer</summary>

Pick a service and read its logs with `journalctl -u myapp` (or the application log files). Logs show what the application or service observed, such as an exception. Also check resources with `free -h` and `df -h`. Do not guess from the symptom.

If the application stopped right now, collect this evidence before you change anything: service status (`systemctl status myapp`), logs, process list (`ps aux`), listening ports (`ss -lntp`), memory, and disk. Then form a hypothesis. Restart only after you have that evidence, because a restart can hide the cause.

</details>

---

## 5. Scenario — Spring Boot is unreachable and you can SSH in

# 08 · Break & Reason · 5 min

### Scenario

Your Spring Boot application is unreachable from the client.

You can SSH into the server.

Don't immediately restart the application. Walk through the system:

```text
Is the process running?
        ↓
Is the application listening?
        ↓
Is the application healthy?
        ↓
Can the OS/network reach the required endpoint?
        ↓
Can the application reach its dependency?
```

For example, if the process is running and port `8080` is listening, the next question is not “Why is Java broken?” It may be a firewall, security group, routing, load balancer, DNS or application-level problem.

> **Senior habit:** Move from **evidence → hypothesis → test → conclusion**.

<details>
<summary>Answer</summary>

Do not restart first. You can SSH, so the server is reachable. Move from evidence to hypothesis to test.

1. Check whether the process runs. Use `ps aux | grep java` or `systemctl status myapp`.
2. Check whether the application listens. Use `ss -lntp` and look for `:8080` owned by java.
3. Read logs. Use `journalctl -u myapp` to find the failure.
4. Check OS resources. Use `free -h` and `df -h` for memory and disk.
5. If the process runs and the port listens, move to network: firewall, security group, routing, load balancer, or DNS.
6. Then check whether the application can reach its dependency.

If the process runs and port `8080` listens, the next question is not “Why is Java broken?” The failure may sit outside the JVM.

</details>

---

## 6. Relationship between a Spring Boot application, JVM, process, and Linux OS

# 12 · Exit Check · 3–5 min

Answer without looking:

1. What is the relationship between a Spring Boot application, JVM, process and Linux OS?

<details>
<summary>Answer</summary>

The Spring Boot application runs inside the JVM. The JVM runs as a Linux process on the operating system, and the OS runs on the server. Each layer can fail on its own.

Java code can be healthy while the JVM is out of memory. The process can stop, the OS can run out of disk, or the server can be unreachable. “The application is down” is a symptom, not a diagnosis. Walk the layers: application → JVM / process → port → OS / resources → network → dependencies.

</details>

---

## 7. What a PID is and why it is useful

2. What is a PID and why is it useful?

<details>
<summary>Answer</summary>

A PID (Process ID) is the unique number Linux gives a running process. When you start a Spring Boot application, the JVM becomes a Linux process and receives a PID. Use that PID to identify and inspect that exact instance.

Find it with `ps aux | grep java`. If the process is gone, the application cannot serve requests. The PID lets you check CPU, memory, and open ports for that process instead of guessing among other Java processes.

</details>

---

## 8. How to determine whether an application is listening on its expected port

3. How do you determine whether an application is actually listening on its expected port?

<details>
<summary>Answer</summary>

Run `ss -lntp` and look for the expected port in LISTEN state, for example `:8080` owned by `java`. That command answers “is anything listening?” A running process is not enough. The application must bind the port before clients can connect.

Listening still does not prove health or that the full path works. After the port listens, check whether the network can reach it and whether the application responds correctly.

</details>

---

## 9. Why you should not immediately restart a failed service

4. Why shouldn't you immediately restart a failed service?

<details>
<summary>Answer</summary>

A restart can restore service, but it does not fix the underlying problem. Collect status, logs, process, port, and resource evidence first so you know why it failed. `systemctl status myapp` and `journalctl -u myapp` often show the cause.

If the service uses `Restart=on-failure`, systemd may already restart it after a crash. Repeated crashes then become repeated restarts. Restart only when you know it is safe, and keep the logs that explain the failure.

</details>

---

## 10. Evidence to collect before you decide where the failure is

5. What evidence would you collect before deciding where the failure is?

### Exit criteria

You should be able to reason through:

```text
Application
    ↓
JVM / Process
    ↓
Port
    ↓
OS / Resources
    ↓
Network
    ↓
Dependencies
```

<details>
<summary>Answer</summary>

Collect evidence from four places: logs, process state, resources, and network state. Check `systemctl status myapp`, then read `journalctl -u myapp`. Confirm the process with `ps aux` and the port with `ss -lntp`. Check memory with `free -h` and disk with `df -h`.

Use that evidence to pick the layer: application, JVM / process, port, OS / resources, network, or a dependency. Do not guess from the symptom. Move from evidence to hypothesis to test to conclusion.

</details>
