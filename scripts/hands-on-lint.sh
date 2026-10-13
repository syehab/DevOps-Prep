#!/usr/bin/env bash
# Lint markdown-adjacent artifacts in this course repo.
# Skip a tool when its file type is absent. Do not invent a pass.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

fail=0

yaml_files=$(find . -type f \( -name '*.yml' -o -name '*.yaml' \) \
  -not -path './.git/*' -not -path './.terraform/*' | sort || true)
tf_dirs=$(find . -type f -name '*.tf' -printf '%h\n' 2>/dev/null | sort -u || true)
sh_files=$(find . -type f -name '*.sh' -not -path './.git/*' | sort || true)
k8s_files=$(find . -type f \( -name '*.yml' -o -name '*.yaml' \) \
  -path '*/k8s/*' -o -path '*/drills/kubernetes-broken-cluster/*/*.yaml' \
  | sort || true)

if [[ -n "$yaml_files" ]] && command -v yamllint >/dev/null; then
  echo "== yamllint =="
  # shellcheck disable=SC2086
  yamllint -c .yamllint.yaml $yaml_files || fail=1
elif [[ -n "$yaml_files" ]]; then
  echo "yamllint not installed — skipped"
else
  echo "no YAML files — skipped yamllint"
fi

if [[ -n "$tf_dirs" ]] && command -v terraform >/dev/null; then
  echo "== terraform fmt / validate =="
  while read -r dir; do
    [[ -z "$dir" ]] && continue
    terraform fmt -check -recursive "$dir" || fail=1
    if [[ -f "$dir/main.tf" ]]; then
      (cd "$dir" && terraform init -backend=false -input=false >/dev/null && terraform validate) || fail=1
    fi
  done <<< "$tf_dirs"
elif [[ -n "$tf_dirs" ]]; then
  echo "terraform not installed — skipped"
else
  echo "no Terraform files — skipped"
fi

if [[ -n "$sh_files" ]] && command -v shellcheck >/dev/null; then
  echo "== shellcheck =="
  # shellcheck disable=SC2086
  shellcheck $sh_files || fail=1
elif [[ -n "$sh_files" ]]; then
  echo "shellcheck not installed — skipped"
else
  echo "no shell scripts — skipped"
fi

if [[ -n "$k8s_files" ]] && command -v kubeconform >/dev/null; then
  echo "== kubeconform =="
  # shellcheck disable=SC2086
  kubeconform -strict -ignore-missing-schemas $k8s_files || fail=1
elif [[ -n "$k8s_files" ]]; then
  echo "kubeconform not installed — skipped"
else
  echo "no Kubernetes YAML — skipped kubeconform"
fi

if command -v markdownlint >/dev/null; then
  echo "== markdownlint (Day and drills README only) =="
  markdownlint 'Day-*/03-implementation.md' 'drills/**/README.md' 'capstone/**/*.md' || fail=1
else
  echo "markdownlint not installed — skipped"
fi

exit "$fail"
