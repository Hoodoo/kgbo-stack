# Container image for the stack's services (deploy/container).
CONTAINER ?= docker
IMAGE ?= kgbo-stack
TAG ?= latest

.PHONY: image

image:
	$(CONTAINER) build -f deploy/container/Dockerfile -t $(IMAGE):$(TAG) .
