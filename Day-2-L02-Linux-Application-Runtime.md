

# Day 2 · L02 · Linux & Application Runtime

> **Goal:** Understand what happens between your application and the server it runs on — and build a simple troubleshooting approach.

| | |
|---|---|
| ⏱️ Time | 45–60 min |
| 🎯 Level | Senior DevOps |
| ☁️ Cost | ₹0 |
| 🧪 Hands-on | Local Linux / Linux VM |

---

## 01 · What Actually Runs? · 7 min

When you deploy a Spring Boot application to a Linux server, you are not simply “running the application.” The application runs inside the **JVM**, which itself runs as a **Linux process** on a machine.

```text
Spring Boot application
        ↓
       JVM
        ↓
   Linux process
        ↓
   Linux operating system
        ↓
      Server
```

The important idea is that each layer can fail independently. Your Java code might be healthy while the JVM is out of memory, the process might have stopped, the OS might be out of disk space, or the server might be unreachable over the network.

> **DevOps view:** Don't treat “the application is down” as a diagnosis. It is only a symptom.

---

## 02 · Linux as the Application's Environment · 8 min

Linux provides the environment in which your application operates. It manages **processes, memory, CPU, files, users, permissions and network connections**. You don't need to become a Linux administrator for this course, but you should understand enough to inspect these areas when an application behaves unexpectedly.

For example, if a Spring Boot application suddenly stops responding, useful questions are: Is its process still running? Is the expected port listening? Is the server out of memory? Is the disk full? Did the application write an error to its logs?

### A small DevOps command set

| What you want to know | Command |
|---|---|
| Current directory | `pwd` |
| Files | `ls -la` |
| Search text | `grep` |
| Find files | `find` |
| Running processes | `ps` |
| CPU / processes | `top` |
| Memory | `free -h` |
| Disk | `df -h` |
| Listening ports | `ss -lntp` |

You don't need to memorize every option. Focus on the **question each command answers**.

---

## 03 · Processes · 7 min

A **process** is a running instance of a program. When you start a Spring Boot application, the JVM runs as a Linux process and receives a unique **PID (Process ID)**. The PID allows you to identify and inspect that particular process.

```bash
ps aux | grep java
```

You might see something like:

```text
java ... myapp.jar
```

The important distinction is:

```text
Application code
      ↓
JVM process
      ↓
PID
```

If the process is gone, the application cannot serve requests. If it exists but is consuming excessive CPU or memory, the application may still be technically “running” while being unhealthy.

> **Senior habit:** “Process exists” does not automatically mean “application is healthy.”

---

## 04 · Services & systemd · 10 min

A process is simply a running program, but production applications usually need something to **manage that process**. This is where a Linux service comes in. A service describes how an application should be started, stopped and managed by the operating system instead of requiring someone to manually run a command every time.

On most modern Linux distributions, **systemd** is the service manager. It starts services during boot, keeps track of their state, can restart them after failures, and provides a consistent way to inspect their status and logs.

Think of the relationship like this:

```text
systemd
   ↓
Service definition
   ↓
Starts / manages
   ↓
Application process
```

For example, a Spring Boot application might have a service called `myapp`. The service can tell Linux to run something like `java -jar myapp.jar`, which user should run it, which working directory to use, what environment variables are required, and whether the service should restart if it crashes.

A simplified service definition might look like:

```ini
[Service]
User=appuser
WorkingDirectory=/opt/myapp
ExecStart=/usr/bin/java -jar /opt/myapp/myapp.jar
Restart=on-failure
```

You don't need to memorize service-file syntax yet. The important idea is that **the service definition describes how the application should run**, while systemd is responsible for managing it.

### Useful commands

```bash
systemctl status myapp
systemctl start myapp
systemctl stop myapp
systemctl restart myapp
systemctl enable myapp
journalctl -u myapp
```

`status` tells you whether the service is running and often shows recent failure information. `start`, `stop` and `restart` control the service, while `enable` configures it to start automatically when the system boots. `journalctl -u myapp` lets you inspect logs associated with that service.

There is an important difference between **`start` and `enable`**: `start` affects the service now, while `enable` affects what happens during future system boots. A service can therefore be running now without being configured to start automatically after a reboot.

### What happens when the application crashes?

If the service is configured with:

```ini
Restart=on-failure
```

systemd can start the application again after an unexpected failure. This improves availability, but it does **not** mean the underlying problem has been fixed. Repeated crashes can simply result in repeated restarts.

> **Senior habit:** A restart can restore service, but logs and the service configuration explain **why it failed and whether the restart is actually safe**.

### A practical troubleshooting flow

If `myapp` is unavailable:

```text
systemctl status myapp
        ↓
Read service / application logs
        ↓
Check process
        ↓
Check port
        ↓
Check resources
        ↓
Investigate the actual failure
```

This is why understanding systemd matters in DevOps: it gives you a standard control and observation layer between **Linux and the application**.

---

## 05 · Ports & Application Runtime · 7 min

An application can be running without being reachable. A Spring Boot application may have a healthy Java process but still be unavailable because it is not listening on the expected port.

For example, if the application is configured to listen on port `8080`:

```bash
ss -lntp
```

You are looking for something similar to:

```text
LISTEN ... :8080 ... java
```

This creates an important troubleshooting distinction:

```text
Process running
      ↓
Application listening
      ↓
Network can reach it
      ↓
Application responds correctly
```

Each step answers a different question. A problem at one step should not be confused with a problem at another.

---

## 06 · Logs & Resources · 7 min

Logs tell you **what the application or service observed**, while resource checks tell you whether the operating environment has enough capacity to keep it running. Both are essential evidence during troubleshooting.

For example:

```bash
journalctl -u myapp
free -h
df -h
```

If the application suddenly stopped, the logs might show an exception while `free -h` reveals severe memory pressure and `df -h` shows that the disk is 100% full.

> **Key idea:** Don't guess from the symptom. Collect evidence from **logs, process state, resources and network state**.

---

## 07 · Mini Exercise · 10–15 min

Use any Linux environment.

### Step A — Inspect the server

```bash
uname -a
free -h
df -h
```

Identify the OS/kernel, available memory and disk usage.

### Step B — Inspect processes

```bash
ps aux
```

Find a process you recognize and note its PID.

### Step C — Inspect listening ports

```bash
ss -lntp
```

Identify which ports are listening and, where available, which process owns them.

### Step D — Inspect logs

Pick a service or application and inspect its logs.

Ask yourself:

> **If this application stopped working right now, what evidence would I collect before changing anything?**

---

## 08 · Break & Reason · 5 min

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

---

## 09 · Azure ↔ AWS · 3 min

The underlying Linux concepts remain largely the same whether the server is in Azure or AWS.

| Concept | Azure | AWS |
|---|---|---|
| Virtual machine | Azure VM | EC2 |
| Network firewall | NSG + OS firewall | Security Group + OS firewall |
| Monitoring | Azure Monitor | CloudWatch |
| Linux logs | OS / application logs | OS / application logs |
| Remote access | SSH | SSH |

The cloud provider gives you the infrastructure around the operating system, but the fundamentals of **processes, ports, memory, disk and logs** still apply.

---

## 10 · Cost Check · 1 min

No cloud resources are required.

**AWS:** ₹0  
**Azure:** ₹0

---

## 11 · Cleanup · <1 min

Nothing to clean up if you used your local machine.

If you created a temporary VM specifically for this exercise, delete it after completing the lab.

---

## 12 · Exit Check · 3–5 min

Answer without looking:

1. What is the relationship between a Spring Boot application, JVM, process and Linux OS?
2. What is a PID and why is it useful?
3. How do you determine whether an application is actually listening on its expected port?
4. Why shouldn't you immediately restart a failed service?
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

> **Takeaway:** A Senior DevOps engineer doesn't just know commands. They know **which question to ask, what evidence to collect, and which layer to investigate next.**

---

## Next

### Day 3 · L03 — Networking Fundamentals

We'll connect today's runtime concepts to:

**IP → DNS → Port → Routing → Firewall → Load Balancer**
