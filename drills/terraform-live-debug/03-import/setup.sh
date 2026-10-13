#!/usr/bin/env bash
set -euo pipefail
dir="${1:-/tmp/tf-debug-import}"
rm -rf "${dir}"
mkdir -p "${dir}"
cat > "${dir}/main.tf" << 'EOF'
terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "3.7.2"
    }
  }
}

resource "random_id" "note" {
  byte_length = 4
}
EOF
cd "${dir}"
terraform init -input=false >/dev/null
terraform apply -auto-approve -input=false >/dev/null
terraform state show -no-color random_id.note | awk '/^ *id *=/ {print $3; exit}' | tr -d '"' > existing.id
terraform state rm -lock=false random_id.note >/dev/null
echo "${dir}"
