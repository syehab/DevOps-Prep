#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "== 01 bash-strict =="
set +e
bash "${root}/01-bash-strict/broken.sh" >/tmp/script-01-broken.out
broken_ec=$?
bash "${root}/01-bash-strict/fixed.sh" >/tmp/script-01-fixed-empty.out
fixed_empty_ec=$?
set -e
bash "${root}/01-bash-strict/fixed.sh" shopsphere-tfstate >/tmp/script-01-fixed.out
test "${broken_ec}" -eq 0
test "${fixed_empty_ec}" -eq 2
grep -qx 'bucket=shopsphere-tfstate' /tmp/script-01-fixed.out

echo "== 02 bash-retry =="
rm -f /tmp/flaky-count
FLAKY_COUNT=/tmp/flaky-count RETRY_SLEEP=0 \
  bash "${root}/02-bash-retry/retry.sh" \
  bash "${root}/02-bash-retry/flaky.sh" >/tmp/script-02.out
grep -q 'flaky: ok 3' /tmp/script-02.out

echo "== 03 bash-log-count =="
bash "${root}/03-bash-log-count/count.sh" "${root}/03-bash-log-count/access.log" >/tmp/script-03.out
grep -qx '200 4' /tmp/script-03.out
grep -qx '503 2' /tmp/script-03.out
grep -qx 'total 8' /tmp/script-03.out

echo "== 04 k8s-restarts =="
python3 "${root}/04-k8s-restarts/find_restarts.py" "${root}/04-k8s-restarts/pods.json" >/tmp/script-04.out
grep -qx 'shopsphere/catalog-b restarts=12' /tmp/script-04.out
test "$(wc -l < /tmp/script-04.out)" -eq 1

echo "== 05 boto3-s3 fixture =="
python3 "${root}/05-boto3-s3/list_buckets.py" --fixture "${root}/05-boto3-s3/buckets.json" >/tmp/script-05.out
grep -qx 'shopsphere-images-dev' /tmp/script-05.out
grep -qx 'shopsphere-tfstate-lab-example' /tmp/script-05.out

echo "== 06 azure-rg fixture =="
python3 "${root}/06-azure-rg/list_groups.py" --fixture "${root}/06-azure-rg/groups.json" >/tmp/script-06.out
grep -qx 'rg-shopsphere-dev' /tmp/script-06.out
grep -qx 'rg-shopsphere-tfstate' /tmp/script-06.out

echo "== 07 jq-plan =="
bash "${root}/07-jq-plan/summary.sh" "${root}/07-jq-plan/plan.json" >/tmp/script-07.out
grep -q 'create 2' /tmp/script-07.out
grep -q 'aws_nat_gateway.this\[0\]' /tmp/script-07.out

echo "== 08 go-health =="
python3 -m http.server --bind 127.0.0.1 8765 >/tmp/script-08-http.log 2>&1 &
http_pid=$!
trap 'kill "${http_pid}" 2>/dev/null || true' EXIT
for _ in 1 2 3 4 5; do
  if curl -fsS "http://127.0.0.1:8765/" >/dev/null 2>&1; then
    break
  fi
  sleep 0.2
done
go run "${root}/08-go-health/main.go" "http://127.0.0.1:8765/" >/tmp/script-08.out
grep -q 'status=200' /tmp/script-08.out
kill "${http_pid}"
trap - EXIT

echo "run-all: ok"
