#!/usr/bin/env bash
set -euo pipefail
dir="${1:-/tmp/tf-debug-drift}"
rm -rf "${dir}"
mkdir -p "${dir}"
cat > "${dir}/main.tf" << 'EOF'
terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "2.5.3"
    }
  }
}

resource "local_file" "note" {
  content  = "expected\n"
  filename = "${path.module}/note.txt"
}
EOF
cd "${dir}"
terraform init -input=false >/dev/null
terraform apply -auto-approve -input=false >/dev/null
printf 'drifted\n' > note.txt
echo "${dir}"
