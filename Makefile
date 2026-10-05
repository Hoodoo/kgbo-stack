# Container image for the stack's services (deploy/container) and its push to
# the GCP project's Artifact Registry (deploy/gcp, docs/gcp.md).
CONTAINER ?= docker
IMAGE ?= kgbo-stack
TAG ?= $(shell git describe --always --dirty)
REGION ?= europe-west2
PROJECT ?=
REGISTRY = $(REGION)-docker.pkg.dev/$(PROJECT)/kgbo

.PHONY: image push

image:
	$(CONTAINER) build -f deploy/container/Dockerfile -t $(IMAGE):$(TAG) .

push: image
	@test -n "$(PROJECT)" || { echo "set PROJECT=<gcp project id>"; exit 1; }
	gcloud auth print-access-token | $(CONTAINER) login -u oauth2accesstoken --password-stdin $(REGION)-docker.pkg.dev
	$(CONTAINER) tag $(IMAGE):$(TAG) $(REGISTRY)/$(IMAGE):$(TAG)
	$(CONTAINER) push $(REGISTRY)/$(IMAGE):$(TAG)
	@echo 'image_tag = "$(TAG)"   # for deploy/gcp/terraform.tfvars'
