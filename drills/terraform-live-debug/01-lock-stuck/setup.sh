#!/usr/bin/env bash
set -euo pipefail
dir="${1:-/tmp/tf-debug-lock}"
rm -rf "${dir}"
mkdir -p "${dir}"
cat > "${dir}/main.tf" << 'EOF'
resource "terraform_data" "hold" {
  input = "shopsphere"
  provisioner "local-exec" {
    command = "sleep 20"
  }
}
EOF
echo "${dir}"
