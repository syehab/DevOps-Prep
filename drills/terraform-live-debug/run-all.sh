#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "== 01 lock =="
bash "${root}/01-lock-stuck/setup.sh" /tmp/tf-debug-lock >/dev/null
cd /tmp/tf-debug-lock
terraform init -input=false >/dev/null
terraform apply -auto-approve -input=false >/tmp/tf-debug-lock-1.log 2>&1 &
pid=$!
sleep 3
set +e
terraform apply -auto-approve -input=false >/tmp/tf-debug-lock-2.log 2>&1
ec=$?
set -e
wait "${pid}" || true
test "${ec}" -ne 0
grep -q 'Error acquiring the state lock' /tmp/tf-debug-lock-2.log

echo "== 02 drift =="
bash "${root}/02-drift/setup.sh" /tmp/tf-debug-drift >/dev/null
cd /tmp/tf-debug-drift
terraform plan -input=false -no-color >/tmp/tf-debug-drift-plan.log
grep -q 'local_file.note' /tmp/tf-debug-drift-plan.log
grep -q 'drifted' note.txt
printf 'expected\n' > note.txt
terraform plan -input=false -no-color >/tmp/tf-debug-drift-fixed.log
grep -q 'No changes' /tmp/tf-debug-drift-fixed.log

echo "== 03 import =="
bash "${root}/03-import/setup.sh" /tmp/tf-debug-import >/dev/null
cd /tmp/tf-debug-import
terraform plan -input=false -no-color >/tmp/tf-debug-import-before.log
grep -q 'will be created' /tmp/tf-debug-import-before.log
terraform import -input=false 'random_id.note' "$(cat existing.id)" >/tmp/tf-debug-import.log
terraform plan -input=false -no-color >/tmp/tf-debug-import-after.log
grep -q 'No changes' /tmp/tf-debug-import-after.log

echo "== 04 moved =="
bash "${root}/04-moved/setup.sh" /tmp/tf-debug-moved >/dev/null
cd /tmp/tf-debug-moved
terraform plan -input=false -no-color >/tmp/tf-debug-moved-plan.log
grep -q 'local_file.new' /tmp/tf-debug-moved-plan.log
terraform apply -auto-approve -input=false >/tmp/tf-debug-moved-apply.log
terraform state list | grep -qx 'local_file.new'
test "$(cat note.txt)" = "shopsphere"

echo "== 05 state mv =="
bash "${root}/05-state-mv/setup.sh" /tmp/tf-debug-state-mv >/dev/null
cd /tmp/tf-debug-state-mv
terraform state mv 'local_file.old' 'local_file.new' >/tmp/tf-debug-state-mv.log
terraform plan -input=false -no-color >/tmp/tf-debug-state-mv-plan.log
grep -q 'No changes' /tmp/tf-debug-state-mv-plan.log
terraform state list | grep -qx 'local_file.new'

echo "== 06 provider =="
bash "${root}/06-provider-conflict/setup.sh" /tmp/tf-debug-provider >/dev/null
cd /tmp/tf-debug-provider
set +e
terraform init -input=false >/tmp/tf-debug-provider-init.log 2>&1
ec=$?
set -e
test "${ec}" -ne 0
grep -Eq '2\.5\.3|2\.4\.0' /tmp/tf-debug-provider-init.log
cat > child/main.tf << 'EOF'
terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = ">= 2.4.0, < 3.0.0"
    }
  }
}
EOF
terraform init -input=false >/tmp/tf-debug-provider-fixed.log
grep -q 'Terraform has been successfully initialized' /tmp/tf-debug-provider-fixed.log

echo "run-all: ok"
