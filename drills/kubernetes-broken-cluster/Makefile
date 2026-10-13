KIND_CLUSTER ?= drill-k8s
NS = drill-01 drill-02 drill-03 drill-05 drill-06 drill-07 drill-08 drill-09 drill-10 drill-11

.PHONY: help apply-all reset reset-dns

help:
	@echo "Kubernetes broken-cluster drills (kind, USD 0.00)"
	@echo "  make reset       Delete drill namespaces"
	@echo "  make reset-dns   Restore CoreDNS replicas to 2"

reset:
	kubectl delete ns $(NS) --ignore-not-found

reset-dns:
	kubectl -n kube-system scale deploy/coredns --replicas=2
