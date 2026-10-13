#!/usr/bin/env bash
set -euo pipefail
dir="${1:-/tmp/tf-debug-provider}"
rm -rf "${dir}"
mkdir -p "${dir}/child"
cat > "${dir}/main.tf" << 'EOF'
terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "2.5.3"
    }
  }
}

module "child" {
  source = "./child"
}
EOF
cat > "${dir}/child/main.tf" << 'EOF'
terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "2.4.0"
    }
  }
}
EOF
echo "${dir}"
