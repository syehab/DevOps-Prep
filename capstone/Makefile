# Helpers for the course clone. The product Makefile lives in shopsphere-starter/.
# Run those targets after you copy the starter into your ShopSphere repo.

.PHONY: help check-versions

help:
	@echo "ShopSphere capstone lives in this folder."
	@echo "Copy shopsphere-starter/ into a repo you own, then run make help there."
	@echo "See README.md, STAGE-MAP.md, COST.md, and VERSIONS.md."

check-versions:
	@echo "Pinned versions are documented in VERSIONS.md"
	@command -v terraform >/dev/null && terraform version | head -n 1 || echo "terraform: not installed"
	@command -v docker >/dev/null && docker version --format '{{.Server.Version}}' || echo "docker: not installed"
	@command -v kind >/dev/null && kind version || echo "kind: not installed"
	@command -v kubectl >/dev/null && kubectl version --client --output=yaml | head -n 4 || echo "kubectl: not installed"
	@command -v helm >/dev/null && helm version --short || echo "helm: not installed"
	@python3 --version
