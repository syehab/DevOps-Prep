# Day 2 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 2 teaches the Linux runtime around an application. This lab inspects a real machine. You collect evidence from the kernel, memory, disk, processes, listening ports, and logs. You do not create cloud resources.

---

## Goal

Inspect the Linux environment on the machine you already use. Record what the operating system is, how much memory and disk remain, which processes run, and which TCP ports listen. Then write a short evidence note as if an application on this host had stopped.

When you finish, you can walk the layers from process to port to resources to logs. You can also explain why a missing listen on port `8080` is not the same problem as a missing process.

---

## What you need

You need a local Linux shell, a Linux VM you already have, or WSL. You do not need Azure, AWS, Docker, or a Spring Boot jar. Use the commands from the lesson. Do not invent extra tools.

Create a notes file named `day-02-runtime-inspect.md` in a folder you control. You will paste command output into that file. Do not put passwords, keys, or account IDs in the file.

Time box: 45 to 75 minutes. Cost stays at ₹0. Work only on this machine. Do not start or stop production services.

---

## Steps

1. Open your notes file. Write the hostname and the date at the top. Write one sentence that names the host role, for example “local study laptop” or “dev VM”. Stay in this file for the rest of the lab.

2. Identify the OS and kernel. Run the command below. Copy the full line into the notes. Mark the kernel name, hostname, kernel version, and architecture.

```bash
uname -a
```

3. Check memory. Run the command below. Record total, used, and available memory. Write one sentence that says whether available memory looks healthy for a JVM.

```bash
free -h
```

4. Check disk. Run the command below. Look at the Use% column. Record the fullest filesystem. Write one sentence that says what happens if a disk reaches 100%.

```bash
df -h
```

5. List processes. Run the command below. Find a process you recognize, such as `bash`, `sshd`, or `java`. Note its PID. If you see Java, also run the grep form from the lesson. Record the PID and the command name.

```bash
ps aux
ps aux | grep java
```

6. List listening TCP ports. Run the command below. Copy two LISTEN lines into the notes. Where the output shows a process, write which process owns the port. If process names are blank, you still have the port numbers. That is enough evidence for this lab.

```bash
ss -lntp
```

7. Inspect logs. Run the lesson command first. If `myapp` is not installed, the command fails. That is expected. Then list log files. Do not start, stop, restart, or enable any service.

```bash
journalctl -u myapp
ls -la /var/log
```

Copy a few log lines, or the names of two files under `/var/log`, into the notes. Write one sentence: logs show what the service observed; they do not by themselves show memory or disk.

8. Write a troubleshooting order in the notes, using this path from the lesson:

```text
systemctl status (if a service exists)
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

Next to each step, paste the command you already ran, or write “not present on this host” if `systemctl` is missing. Do not restart anything.

---

## Verify

Read the notes out loud as if you are on a call. You should be able to name the OS, one PID, one listening port, memory available, disk Use%, and one log observation without opening extra tools.

Check these points:

- `uname -a`, `free -h`, `df -h`, `ps aux`, and `ss -lntp` each have a result in the notes.
- One PID is recorded. The note says that a living process is not the same as a healthy application.
- At least one LISTEN line is recorded. The note says listening is not the same as “clients can reach it”.
- Logs came from `journalctl` or from files under `/var/log`. The note does not guess a root cause from a symptom.

If any layer is missing, run that command again and add the evidence before you stop.

---

## Break and fix

Do this on purpose. Look for port `8080` in the `ss -lntp` output. On most study machines nothing listens there. That is the safe failure.

Write three short lines in the notes:

1. Process: is a `java` process present in `ps aux`? Yes or no, with the PID if you found one.
2. Listen: does `ss -lntp` show `LISTEN` on `:8080`? On this host the answer is usually no.
3. Gap: a missing listen is not proof that “Java is broken”, and it is not proof that the network is broken. It only answers “is anything listening on this port?”

Do not start a dummy service to make the port appear. Do not run `systemctl start`, `stop`, or `restart`. Put the three lines next to the troubleshooting path. That gap is the habit this Day trains: collect evidence at the listen layer before you change anything.

---

## Clean up

You created no cloud resources. Keep `day-02-runtime-inspect.md` in your notes. Remove any pasted output that shows private IPs you do not want to keep, if that matters for your environment.

Do not disable services. Do not delete `/var/log` files. If you opened a cloud console out of habit, close it. There is no resource group, VPC, or VM to delete unless you created a temporary VM only for this lab. If you did, delete that VM now.

---

## Interview story

I do not treat “the application is down” as a diagnosis. I inspect the Linux runtime first: `uname -a` for the kernel, `free -h` and `df -h` for capacity, `ps aux` for the PID, `ss -lntp` for the listen, and logs with `journalctl` or the files under `/var/log`. If the process exists but port 8080 does not listen, I stay on that layer. A restart can hide the cause, so I collect evidence before I change anything.
