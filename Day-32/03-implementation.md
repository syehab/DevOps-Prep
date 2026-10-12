# Day 32 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 32 teaches who can talk to whom, and why that path is allowed. A public subnet has a route to an Internet Gateway. A private database has no such path. This lab uses Docker Compose as a local stand-in. You run an app service and PostgreSQL on one Compose network. You do not publish PostgreSQL to the host. The app reaches the database by the Compose service name `db`. That is private connectivity.

Work only in a temporary directory. Do not run Compose inside this course repository. Do not create an AWS VPC, a NAT Gateway, or a load balancer. The Compose file is the lab even if Docker is missing on this machine.

---

## Goal

Write `compose.yaml` with two services: `app` and `db`. Put both on one user-defined Compose network named `shopsphere`. Publish host port `8080` only on `app`. Do not add a `ports` key on `db`. PostgreSQL must listen inside the Compose network on TCP `5432`. It must not listen on the host.

The app resolves `db` through Compose DNS and opens TCP `5432`. A request to `http://127.0.0.1:8080/` from the host should report that the database is reachable. A direct connection from the host to `127.0.0.1:5432` should fail. Then you add `5432:5432` on `db` on purpose, prove the host can now reach PostgreSQL, remove that mapping, and explain public versus private.

Time box: 45 to 75 minutes. Cost stays at ₹0. Stop when the notes file records the private path, the public break, the restore, and Compose has been taken down.

---

## What you need

You need a shell and a text editor. Check Docker Compose first:

```bash
docker compose version
```

If that command fails, still write every file in Steps. Copy the same commands into your notes. Run them when `docker compose` is on your `PATH`. Do not invent a substitute tool. Do not skip `compose.yaml`.

You do not need AWS, Azure, Terraform, Kubernetes, or a Spring Boot project. The app is a small Python HTTP process. It uses the standard library only. The images `python:3.12-slim` and `postgres:16` are real. Do not replace them.

Create the lab under `/tmp`, not under this course clone. Compose writes containers, a network, and a volume on the host. You must be able to delete them.

Keep a notes file named `day-32-network-lab.md` in that temp directory. Record command output and the public versus private sentence. The lab password below is for this directory only. Do not reuse it. Do not paste production secrets. This lab should not create any.

Use only these real Compose keys: `services`, `build`, `ports`, `environment`, `depends_on`, `networks`, `image`. On `db`, omit `ports`. Do not add a `version` key. Do not invent Compose keys.

---

## Steps

1. Create a throwaway directory and enter it. Use a unique folder name so you do not collide with another lab. Confirm the path is under `/tmp`.

```bash
LAB_DIR="/tmp/day-32-compose-lab-$$"
mkdir -p "$LAB_DIR"
cd "$LAB_DIR"
pwd
```

2. Write `app.py`. This process listens on TCP `8080`. On each GET request it opens a TCP connection to `DATABASE_HOST` on `DATABASE_PORT`. It does not need a PostgreSQL driver. A successful TCP handshake is enough to prove the path.

```python
import os
import socket
from http.server import BaseHTTPRequestHandler, HTTPServer

db_host = os.environ.get("DATABASE_HOST", "db")
db_port = int(os.environ.get("DATABASE_PORT", "5432"))


def db_reachable():
    try:
        with socket.create_connection((db_host, db_port), timeout=3):
            return True
    except OSError:
        return False


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        ok = db_reachable()
        body = b"db reachable\n" if ok else b"db unreachable\n"
        self.send_response(200 if ok else 503)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        return


if __name__ == "__main__":
    HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
```

3. Write `Dockerfile`. `FROM` starts from `python:3.12-slim`. `COPY` adds `app.py`. `EXPOSE 8080` documents the listen port. It does not publish a host port. `CMD` starts the process.

```dockerfile
FROM python:3.12-slim

WORKDIR /app

COPY app.py .

EXPOSE 8080

CMD ["python", "app.py"]
```

4. Write `compose.yaml`. Both services join the `shopsphere` network. The app publishes `8080:8080`. The `db` service has no `ports` key. Compose DNS names the database `db`. That name is how the app finds PostgreSQL.

```yaml
services:
  app:
    build: .
    ports:
      - "8080:8080"
    environment:
      DATABASE_HOST: db
      DATABASE_PORT: "5432"
    depends_on:
      - db
    networks:
      - shopsphere
  db:
    image: postgres:16
    environment:
      POSTGRES_USER: shopsphere
      POSTGRES_PASSWORD: lab-only
      POSTGRES_DB: shopsphere
    networks:
      - shopsphere
networks:
  shopsphere:
```

Confirm the three files exist:

```bash
ls
cat compose.yaml
```

You should see `app.py`, `Dockerfile`, and `compose.yaml`. `compose.yaml` must not list `ports` under `db`.

5. If `docker compose version` failed, copy that fact into the notes. Keep the three files. Skip the remaining run commands. Continue at Verify and write the public versus private sentence from the file itself. Do not invent another runtime.

6. Start the stack. Compose builds the app image, pulls `postgres:16` if needed, creates the `shopsphere` network, and starts both services.

```bash
docker compose up -d --build
```

Wait a few seconds so PostgreSQL can accept connections. Then list the services.

```bash
docker compose ps
```

Both `app` and `db` should be running. Copy the names into the notes.

7. Read the rendered Compose config. Confirm `app` has a host port and `db` does not.

```bash
docker compose config
```

Look at `ports` under each service. `app` should map `8080`. `db` should have no host mapping. That missing mapping is the private database. Record that observation.

8. Prove Compose DNS from the app container. The name `db` must resolve on the `shopsphere` network.

```bash
docker compose exec app python -c "import socket; print(socket.getaddrinfo('db', 5432)[0][4])"
```

You should see a private container IP, not `127.0.0.1` on the host. DNS success is only the first layer. Copy the IP into the notes.

9. Prove TCP `5432` from the app to that name. This is the application-to-database path.

```bash
docker compose exec app python -c "import socket; socket.create_connection(('db', 5432), timeout=5); print('app to db ok')"
```

Print `app to db ok` in the notes. If this fails, read `docker compose logs db` and wait for PostgreSQL to finish startup. Then run the same command again. Do not add `ports` on `db` to make this work.

10. Request the app from the host. The host talks to the published app port. The app talks to PostgreSQL on the private network.

```bash
curl -sS http://127.0.0.1:8080/
```

You should see `db reachable`. If host port `8080` is already in use, stop. Change the app `ports` value to `"18080:8080"` and curl `http://127.0.0.1:18080/` instead. Write the host port you used.

11. Prove the forbidden path. From the host, try TCP `5432` on localhost. Do not use ping. ICMP does not prove PostgreSQL.

```bash
python3 -c "import socket; socket.create_connection(('127.0.0.1', 5432), timeout=2)"
```

This command should fail. Connection refused or a timeout is the expected result. PostgreSQL is on the Compose network. It is not published to the host. Copy the error into the notes. That is evidence that the database is private.

---

## Verify

Read the notes as if you are on a call. You should name the Compose network, the service name `db`, the published app port, and the missing database `ports` key.

Check these points:

- `compose.yaml` exists even if Docker Compose was missing.
- `db` has no `ports` key in the private design.
- `app` and `db` share the `shopsphere` network.
- If Compose ran, `docker compose exec` reached `db:5432` from `app`.
- If Compose ran, `curl` from the host returned `db reachable`.
- If Compose ran, the host could not open `127.0.0.1:5432`.
- You did not treat a successful ping as database connectivity.

If Compose is missing, the notes must say so. The files are still the lab. The private design is the missing `ports` key on `db`, not a cloud security group.

---

## Break and fix

The working stack keeps PostgreSQL private because `db` has no `ports` mapping. Now make it public on purpose. Add a host mapping on `db` only. Do not change the app. Do not change security groups. There are none here.

Replace `compose.yaml` with this broken file. The only change is `ports` on `db`:

```yaml
services:
  app:
    build: .
    ports:
      - "8080:8080"
    environment:
      DATABASE_HOST: db
      DATABASE_PORT: "5432"
    depends_on:
      - db
    networks:
      - shopsphere
  db:
    image: postgres:16
    ports:
      - "5432:5432"
    environment:
      POSTGRES_USER: shopsphere
      POSTGRES_PASSWORD: lab-only
      POSTGRES_DB: shopsphere
    networks:
      - shopsphere
networks:
  shopsphere:
```

Apply the change:

```bash
docker compose up -d
```

From the host, open TCP `5432` again:

```bash
python3 -c "import socket; socket.create_connection(('127.0.0.1', 5432), timeout=2); print('host to db ok')"
```

This time the command should print `host to db ok`. The database is still on the Compose network. `ports: "5432:5432"` also published it to the host. That is the public path. It is the local analog of an Internet Gateway route plus a public address on the database. Copy the success into the notes.

The app path should still work:

```bash
curl -sS http://127.0.0.1:8080/
docker compose exec app python -c "import socket; socket.create_connection(('db', 5432), timeout=5); print('app to db still ok')"
```

Public exposure did not improve the app path. The app already reached `db` by service name. Publishing `5432` only widened who else can connect.

If Compose is missing, still save the broken `compose.yaml` in the notes. Write that `ports` on `db` publishes PostgreSQL to the host. That is public. Omitting `ports` keeps it on the Compose network. That is private.

Fix the design. Remove `ports` from `db`. Restore the original `compose.yaml` from Step 4. Recreate the stack:

```bash
docker compose up -d
```

Test both paths again:

```bash
curl -sS http://127.0.0.1:8080/
python3 -c "import socket; socket.create_connection(('127.0.0.1', 5432), timeout=2)"
docker compose exec app python -c "import socket; socket.create_connection(('db', 5432), timeout=5); print('app to db ok')"
```

`curl` and the app-to-`db` check should succeed. The host connection to `127.0.0.1:5432` should fail again. Write one sentence in the notes: omitting `ports` on `db` is private connectivity; adding `5432:5432` is public exposure.

Do not leave the broken file as the running design. The restored file must have no `ports` key on `db`.

---

## Clean up

If you never started Compose, leave the notes if you want them, then delete the temp directory.

```bash
cd /tmp
rm -rf "$LAB_DIR"
```

If you started Compose, take the stack down from `$LAB_DIR`. `-v` removes the PostgreSQL volume. `--rmi local` removes the app image this lab built.

```bash
cd "$LAB_DIR"
docker compose down -v --rmi local
docker compose ps -a
```

`docker compose ps -a` should show no lab containers. Do not run a broad prune. Do not remove `python:3.12-slim` or `postgres:16` unless you know nothing else on the machine needs them.

Then delete the temp directory.

```bash
cd /tmp
rm -rf "$LAB_DIR"
```

If you want to keep the notes, copy `day-32-network-lab.md` out before `rm -rf`. You created no AWS VPC, NAT Gateway, load balancer, or RDS instance, so there is no cloud resource to delete.

---

## Interview story

I keep ShopSphere PostgreSQL private. The application reaches it by name on a private path. The internet does not. On a laptop I model that with Docker Compose. `app` and `db` share the `shopsphere` network. `app` publishes `8080:8080`. `db` has no `ports` key. The app resolves `db` and opens TCP `5432`. The host cannot open `127.0.0.1:5432`. When I add `5432:5432`, the host can connect. That mapping is public exposure. It is the same idea as an Internet Gateway route on a database subnet. I remove `ports` from `db` so only the app path remains. Routing and publish rules decide who can reach the database. A security group is a later allow. It does not replace a private path.
