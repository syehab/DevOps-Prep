# Day 39 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 39 teaches Disaster Recovery as a restore you can prove, not as a backup file you hope exists. ShopSphere’s business numbers in the lesson are an RPO of 15 minutes and an RTO of 60 minutes. This lab makes those numbers concrete. You write one RPO line and one RTO line. You take a backup. You then delete the marker on purpose. You restore. You prove the marker is back. A backup that has never been restored is only an assumption.

Work only in a temporary directory that you create for this lab. Do not run Docker or write backup archives inside this course repository. You do not need AWS, Azure, Kubernetes, or a paid database.

---

## Goal

Create one durable marker. If Docker Engine is on your `PATH`, the marker is a PostgreSQL row in a named volume. You back it up with `pg_dump`, and you also tar the volume. If Docker is missing, the marker is a file in a local data directory. You back it up with `tar`. Then you delete the marker. You restore from the backup. You prove the row or the file returns.

Write two one-line statements before you restore: one for RPO, one for RTO. After restore, record whether the marker came back and how long the restore took. When you finish, you can explain backup versus restore testing without a cloud account.

Time box: 45 to 75 minutes. Cost stays at ₹0. Stop when the notes contain both one-liners, the restore proof, and cleanup has removed the lab directory and any lab containers or volumes.

---

## What you need

You need a shell and `tar`. Check them first:

```bash
command -v tar
tar --version
```

Then check Docker. Use the result to choose a track. Do not invent a third tool.

```bash
command -v docker
docker version
```

If `docker version` works, follow **Track A**. You will use `docker volume create`, `docker run`, `docker exec`, `pg_dump`, and `tar` against the volume. The image names `postgres:16` and `alpine` are real. The environment variable `POSTGRES_PASSWORD` is required by the official PostgreSQL image. Do not skip it. Do not add flags you have not seen in this file.

If `docker` is missing, follow **Track B**. You still create the data directory, take a `tar` backup, delete a file, and restore. Track B is the lab on this machine when Docker is not installed. Do not wait for Docker. Do not skip the files.

You do not need `psql` on the host. Track A runs `psql` and `pg_dump` inside the `postgres:16` container through `docker exec`. Track B uses only `tar`, `mkdir`, and a text file.

Create the lab under `/tmp`, not under this course clone. Docker writes volumes on the host. `tar` writes archives in the working directory. You must be able to delete both when you clean up.

Keep a notes file named `day-39-dr-lab.md` in that temp directory. Record command output, the RPO line, the RTO line, the delete, and the restore proof. The lab password below is for this directory only. Do not reuse it. Do not paste production secrets. This lab should not create any.

---

## Steps

1. Create a throwaway directory and enter it. Use a unique folder name so you do not collide with another lab. Confirm the path is under `/tmp`.

```bash
LAB_DIR="/tmp/day-39-dr-lab-$$"
mkdir -p "$LAB_DIR"
cd "$LAB_DIR"
pwd
```

2. Start the notes file. Record the date, the lab directory, and whether `docker version` succeeded. You will add the RPO and RTO lines after the first backup exists.

```bash
{
  echo "# Day 39 DR lab"
  echo "LAB_DIR=$LAB_DIR"
  date -u
} > day-39-dr-lab.md
command -v docker >> day-39-dr-lab.md || echo "docker missing" >> day-39-dr-lab.md
```

3. Choose the track. If `command -v docker` printed a path and `docker version` ran, continue with Track A from step 4. If not, skip to Track B at step 12. Do not mix tracks. One marker, one backup, one restore.

---

### Track A — Docker volume, PostgreSQL, `pg_dump`, and volume tar

4. Create a named volume. This volume is the durable store. The container is replaceable. The volume is not.

```bash
docker volume create day39-pg
docker volume ls
```

`docker volume ls` should list `day39-pg`. Copy that line into the notes.

5. Start PostgreSQL with that volume. `-d` runs the container in the background. `--name` sets `day39-pg`. `-e POSTGRES_PASSWORD=day39lab` satisfies the image. `-e POSTGRES_DB=shopsphere` creates that database on first start. `-v day39-pg:/var/lib/postgresql/data` mounts the named volume at the data directory the image uses.

```bash
docker run -d --name day39-pg \
  -e POSTGRES_PASSWORD=day39lab \
  -e POSTGRES_DB=shopsphere \
  -v day39-pg:/var/lib/postgresql/data \
  postgres:16
```

6. Wait until PostgreSQL accepts connections. `pg_isready -U postgres` is the readiness command in this image. Repeat until it prints `accepting connections`.

```bash
until docker exec day39-pg pg_isready -U postgres
do
  sleep 2
done
```

7. Create the marker row. The table is `orders`. The note is `day-39-marker`. This row is the proof you will restore later.

```bash
docker exec day39-pg \
  psql -U postgres -d shopsphere -c \
  "CREATE TABLE orders (id integer PRIMARY KEY, note text); INSERT INTO orders (id, note) VALUES (39, 'day-39-marker'); SELECT * FROM orders;"
```

The `SELECT` should show `39` and `day-39-marker`. Copy that output into the notes. That is the known-good row.

8. Take a logical backup with `pg_dump`. `-U postgres` is the superuser. `-d shopsphere` is the database you created. The dump lands on the host as `backup.sql`. This is the restore-tested backup for Track A.

```bash
docker exec day39-pg pg_dump -U postgres -d shopsphere > backup.sql
wc -l backup.sql
grep day-39-marker backup.sql
```

`grep` must find `day-39-marker` in `backup.sql`. If it does not, the dump is empty. Do not continue until the marker is in the file.

9. Take a filesystem backup of the volume as well. Stop the container first so PostgreSQL is not writing files during `tar`. Then run a one-shot `alpine` container that mounts the volume at `/data` and the lab directory at `/backup`. `tar -czf` writes `pgdata.tar.gz`. `-C /data .` archives the volume contents.

```bash
docker stop day39-pg
docker run --rm \
  -v day39-pg:/data \
  -v "$LAB_DIR":/backup \
  alpine tar -czf /backup/pgdata.tar.gz -C /data .
ls -l pgdata.tar.gz
docker start day39-pg
until docker exec day39-pg pg_isready -U postgres
do
  sleep 2
done
```

You now have two backup artifacts: `backup.sql` and `pgdata.tar.gz`. Neither has been restore-tested yet. Write that sentence in the notes. That is the failure this Day trains.

10. Write the RPO and RTO one-liners in the notes. Use the ShopSphere numbers from the lesson. RPO is how much data you can lose. RTO is how quickly you must restore service. Then continue. Do not restore yet.

```text
RPO: 15 minutes — the dump is only as fresh as the last successful pg_dump.
RTO: 60 minutes — restore is done when SELECT returns day-39-marker.
```

Append those two lines to `day-39-dr-lab.md` in your own words if you prefer. Keep them to one line each. Do not mix RPO and RTO.

11. Break the data. Delete the marker row. Confirm it is gone. The backup files still exist. This is the untested-backup moment: you have artifacts, and you do not yet know they restore.

```bash
docker exec day39-pg \
  psql -U postgres -d shopsphere -c \
  "DELETE FROM orders; SELECT * FROM orders;"
```

The `SELECT` should return no rows. Copy that empty result into the notes. Skip to **Verify** after you restore in the Break and fix section. Track A restore is there so you practice the failure on purpose.

---

### Track B — Local data directory and `tar`

12. Create a local data directory and two marker files. `orders.txt` is the file you will delete. `customers.txt` stays so you can see that restore does not require a full rebuild of every file.

```bash
mkdir -p data
printf 'day-39-marker\n' > data/orders.txt
printf 'customer-39\n' > data/customers.txt
cat data/orders.txt
ls data
```

13. Take a `tar` backup. `-czf` writes `backup.tar.gz`. `-C data .` archives the directory contents without storing the `data/` prefix. List the archive with `-tzf` so you can see `orders.txt` inside it.

```bash
tar -czf backup.tar.gz -C data .
tar -tzf backup.tar.gz
```

You should see `./orders.txt` and `./customers.txt`, or `orders.txt` and `customers.txt`. Copy the list into the notes. Write this sentence: the archive exists and has not been restore-tested.

14. Write the RPO and RTO one-liners in the notes. Use the ShopSphere numbers from the lesson. Then delete the marker file.

```text
RPO: 15 minutes — the tar is only as fresh as the last successful archive.
RTO: 60 minutes — restore is done when data/orders.txt contains day-39-marker.
```

```bash
rm data/orders.txt
ls data
test ! -f data/orders.txt && echo "orders.txt gone"
```

`customers.txt` should still exist. `orders.txt` should be gone. Copy `ls data` into the notes. Skip to **Verify** after you restore in the Break and fix section.

---

## Verify

Read the notes as if you are on a call. You should say the RPO line, the RTO line, what you deleted, and what command proved the marker returned.

Check these points:

- The notes contain one RPO sentence and one RTO sentence. They are not the same sentence.
- Track A: `backup.sql` contains `day-39-marker`, `pgdata.tar.gz` exists, and `SELECT` showed no rows after `DELETE`.
- Track B: `tar -tzf backup.tar.gz` listed `orders.txt`, and `data/orders.txt` was missing after `rm`.
- After Break and fix, Track A `SELECT` shows `39` and `day-39-marker` again, or Track B `cat data/orders.txt` prints `day-39-marker`.
- You did not treat “the backup file exists” as proof. Proof is the restored row or file.

If the marker is still missing after restore, do not take a new backup of the empty data. Restore again from the original `backup.sql` or `backup.tar.gz`. A second dump of the deleted state would overwrite the only good copy.

---

## Break and fix

The delete in Track A step 11 or Track B step 14 is the break. The backup was never restore-tested. Restore now. Prove the marker returns.

Track A restore. Feed `backup.sql` into `psql` on standard input. `-i` on `docker exec` keeps stdin open. `-d shopsphere` is the same database you dumped.

```bash
docker exec -i day39-pg psql -U postgres -d shopsphere < backup.sql
docker exec day39-pg \
  psql -U postgres -d shopsphere -c "SELECT * FROM orders;"
```

The `SELECT` must show `39` and `day-39-marker`. Copy that output into the notes. That is the restore test. Record a start and end time around these two commands if you want a measured RTO for the lab. The lesson number is 60 minutes. This restore should be far inside that window.

Track B restore. Extract the archive into `data`. `-xzf` reads `backup.tar.gz`. `-C data` writes into that directory. Then print the marker file.

```bash
tar -xzf backup.tar.gz -C data
cat data/orders.txt
ls data
```

`cat data/orders.txt` must print `day-39-marker`. Copy that line into the notes. `customers.txt` should still be present. Restore replaced the missing file. It did not require you to rebuild the whole directory by hand.

If Track A restore fails because PostgreSQL is not ready, run `pg_isready` again, then retry the `psql` stdin restore. Do not `docker rm` the container before the `SELECT` succeeds. The volume still holds the broken empty table until `psql` replays the dump.

Do not skip the proof. A listed archive is not a recovered order.

---

## Clean up

Stop the lab process, then remove the temp directory. Track B has no containers. Track A must remove the container and the named volume.

Track A:

```bash
docker stop day39-pg
docker rm day39-pg
docker volume rm day39-pg
docker volume ls
```

`docker volume ls` should no longer list `day39-pg`. Do not run a broad prune. Do not remove `postgres:16` or `alpine` unless you know nothing else on the machine needs them.

Then, for both tracks, leave the lab directory and delete it.

```bash
cd /tmp
rm -rf "$LAB_DIR"
```

If you copied notes you want to keep, move `day-39-dr-lab.md` out before `rm -rf`. You created no AWS RDS instance, no EBS snapshot, and no Azure resource, so there is no cloud backup to delete.

---

## Interview story

I do not treat a backup file as disaster recovery. Recovery is a restore I have tested. On a laptop I put a marker in PostgreSQL on a Docker volume, or in a local data directory when Docker is missing. I take `pg_dump` and a volume `tar`, or a directory `tar`. I write RPO and RTO as one line each: fifteen minutes of data loss, sixty minutes to restore. I delete the marker on purpose. Then I restore and prove the row or the file is back. An untested dump is an assumption. The `SELECT` or the restored file is the evidence.
