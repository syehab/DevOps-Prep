# 09 — Certificate expiry

**Timer:** 15 minutes.

kind control-plane certs are usually valid. This drill mounts a **workload** TLS secret that is expired or about to expire. You prove it with `openssl x509 -dates`.

## Symptom

A client that verifies TLS rejects the certificate (`certificate has expired` or `notAfter` is in the past). nginx itself still starts. The secret is the fault.

## Setup

```bash
bash drills/kubernetes-broken-cluster/scenarios/09-cert-expiry/setup.sh
```

Needs `openssl` on your machine.

## Hints

1. `kubectl -n drill-09 get secret expired-tls`
2. `kubectl -n drill-09 exec tls-check -- openssl x509 -in /certs/tls.crt -noout -dates -subject`
3. Compare `notAfter` to `date -u`.

## Solution

<details>
<summary>Open after you tried.</summary>

`setup.sh` creates an x509 certificate. When your OpenSSL supports `-not_after`, the cert expired in 2020. Otherwise it is a 1-day cert. Either way you read dates from the mounted file.

Fix: mint a new cert (valid 30 days), replace the secret, restart the Pod so it remounts.

```bash
WORKDIR=$(mktemp -d)
openssl req -x509 -newkey rsa:2048 -keyout "$WORKDIR/tls.key" -out "$WORKDIR/tls.crt" \
  -days 30 -nodes -subj "/CN=expired.shopsphere.local"
kubectl -n drill-09 create secret tls expired-tls \
  --cert="$WORKDIR/tls.crt" --key="$WORKDIR/tls.key" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n drill-09 delete pod tls-check
# re-apply the Pod from setup.sh
```

In production you watch `notAfter` with a controller or a Prometheus exporter. You do not wait for users to report TLS errors.

If `setup.sh` could not force an expired `notAfter`, treat a 1-day cert as the drill and write the date you would rotate.

</details>
