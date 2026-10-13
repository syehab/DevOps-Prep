#!/usr/bin/env bash
# Breaks cluster DNS. Run only on a disposable kind cluster.
set -euo pipefail
kubectl create namespace drill-04 --dry-run=client -o yaml | kubectl apply -f -
kubectl -n kube-system scale deploy/coredns --replicas=0
echo "CoreDNS replicas are 0. Start the 15-minute timer."
echo "Reset: kubectl -n kube-system scale deploy/coredns --replicas=2"
