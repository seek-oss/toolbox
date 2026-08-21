# Include toolbox.mk so that Toolbox targets can be tested locally.
include toolbox.mk

# Version of the Toolbox Docker image to build/push.
RELEASE_VERSION ?= latest
IMAGE_REPO ?= ghcr.io/seek-oss/toolbox
DOCKER_PLATFORMS ?= linux/amd64,linux/arm64
BUILDX_BUILDER ?= toolbox-multiarch

# Release archive file that's uploaded to GitHub.
RELEASE_ARCHIVE ?= $(build_dir)/toolbox.mk

##
## Build a new Toolbox Docker image.
##
.PHONY: build
build: buildx-ensure
	@$(call banner,$@)
	@docker buildx build \
		--builder "$(BUILDX_BUILDER)" \
		--load \
		--build-arg TOOLBOX_VERSION=$(RELEASE_VERSION) \
		-t $(IMAGE_REPO):$(RELEASE_VERSION) .

##
## Ensure docker buildx is configured.
##
.PHONY: buildx-ensure
buildx-ensure:
	@docker buildx inspect "$(BUILDX_BUILDER)" >/dev/null 2>&1 || docker buildx create --name "$(BUILDX_BUILDER)" --driver docker-container --use >/dev/null
	@docker buildx use "$(BUILDX_BUILDER)" >/dev/null

##
## Pushes the Toolbox image to GitHub Container Registry.
##
.PHONY: push
push: buildx-ensure
	@$(call banner,$@)
	@docker buildx build \
		--builder "$(BUILDX_BUILDER)" \
		--platform "$(DOCKER_PLATFORMS)" \
		--build-arg TOOLBOX_VERSION=$(RELEASE_VERSION) \
		-t $(IMAGE_REPO):$(RELEASE_VERSION) \
		--push .

##
## Tags and pushes a latest tag for the Toolbox image.
##
.PHONY: push-latest
push-latest:
	@$(call banner,$@)
	@docker buildx imagetools create \
		--tag $(IMAGE_REPO):latest \
		$(IMAGE_REPO):$(RELEASE_VERSION)

##
## Creates a pinned version of toolbox.mk.
##
.PHONY: pin
pin: $(build_dir)
	@$(call banner,$@)
	@sed "s/TOOLBOX_VERSION ?= .*/TOOLBOX_VERSION ?= $(RELEASE_VERSION)/" toolbox.mk > $(build_dir)/toolbox.mk
	@echo "Created $(RELEASE_ARCHIVE) pinned to version $(RELEASE_VERSION)" >&2

##
## Update argbash arguments.
##
.PHONY: argbash
argbash: $(build_dir)
	@$(call banner,Running argbash)
	@docker run --rm \
		-v "$$(pwd):/work" -w /work -u "$$(id -u):$$(id -g)" \
		matejak/argbash \
		lib/args.m4 -o lib/args.sh --strip user-content
