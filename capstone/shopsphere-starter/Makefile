PYTHON ?= python3
IMAGE ?= shopsphere-api:dev
INFRA_DIR ?= infra/azure/environments/dev
KIND_CLUSTER ?= shopsphere
SHOPSPHERE_RG ?= rg-shopsphere-dev

.PHONY: help run test image destroy destroy-kind destroy-azure destroy-aws fmt-tf

help:
	@echo "ShopSphere starter targets:"
	@echo "  make run            Start the catalog API on 127.0.0.1:8080"
	@echo "  make test           Run API checks"
	@echo "  make image          Build $(IMAGE) (needs Docker and Day 13 Dockerfile)"
	@echo "  make destroy        terraform destroy in $(INFRA_DIR)"
	@echo "  make destroy-kind   kind delete cluster --name $(KIND_CLUSTER)"
	@echo "  make destroy-azure  az group delete --name $(SHOPSPHERE_RG)"
	@echo "  make destroy-aws    terraform destroy in infra/aws/environments/dev"

run:
	$(PYTHON) app/main.py

test:
	cd app && $(PYTHON) test_api.py

image:
	docker build -t $(IMAGE) -f app/Dockerfile app

fmt-tf:
	terraform -chdir=$(INFRA_DIR) fmt -recursive

destroy:
	terraform -chdir=$(INFRA_DIR) destroy

destroy-kind:
	kind delete cluster --name $(KIND_CLUSTER)

destroy-azure:
	az group delete --name $(SHOPSPHERE_RG) --yes --no-wait

destroy-aws:
	terraform -chdir=infra/aws/environments/dev destroy
