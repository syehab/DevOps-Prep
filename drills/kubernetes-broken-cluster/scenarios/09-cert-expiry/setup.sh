#!/usr/bin/env bash
set -euo pipefail
NS=drill-09
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
WORKDIR=$(mktemp -d)
openssl req -x509 -newkey rsa:2048 -keyout "$WORKDIR/tls.key" -out "$WORKDIR/tls.crt" \
  -days 1 -nodes -subj "/CN=expired.shopsphere.local" \
  -addext "subjectAltName=DNS:expired.shopsphere.local" >/dev/null 2>&1
# Force notBefore/notAfter in the past using -startdate if supported; else touch dates via faketime.
# Portable fallback: create a cert that expired yesterday when openssl allows -not_after.
if openssl req -help 2>&1 | grep -q -- '-not_after'; then
  openssl req -x509 -newkey rsa:2048 -keyout "$WORKDIR/tls.key" -out "$WORKDIR/tls.crt" \
    -nodes -subj "/CN=expired.shopsphere.local" \
    -not_before 20200101000000Z -not_after 20200102000000Z >/dev/null 2>&1
fi
kubectl -n "$NS" create secret tls expired-tls \
  --cert="$WORKDIR/tls.crt" --key="$WORKDIR/tls.key" \
  --dry-run=client -o yaml | kubectl apply -f -
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: tls-check
  namespace: drill-09
spec:
  containers:
    - name: nginx
      image: nginx:1.27
      volumeMounts:
        - name: certs
          mountPath: /certs
          readOnly: true
  volumes:
    - name: certs
      secret:
        secretName: expired-tls
EOF
echo "Secret expired-tls is mounted at /certs. Run: kubectl -n drill-09 exec tls-check -- openssl x509 -in /certs/tls.crt -noout -dates"
rm -rf "$WORKDIR"
