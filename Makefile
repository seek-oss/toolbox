# Include toolbox.mk so that Toolbox targets can be tested locally.
include toolbox.mk

# Version of the Toolbox Docker image to build/push.
RELEASE_VERSION ?= latest

# Release archive file that's uploaded to GitHub.
RELEASE_ARCHIVE ?= $(build_dir)/toolbox.mk

##
## Build a new Toolbox Docker image.
##
.PHONY: build
build:
	@$(call banner,$@)
	@docker build \
		--build-arg TOOLBOX_VERSION=$(RELEASE_VERSION) \
		-t ghcr.io/seek-oss/toolbox:$(RELEASE_VERSION) .

##
## Pushes the Toolbox image to GitHub Container Registry.
##
.PHONY: push
push:
	@$(call banner,$@)
	@docker push ghcr.io/seek-oss/toolbox:$(RELEASE_VERSION)

##
## Tags and pushes a latest tag for the Toolbox image.
##
.PHONY: push-latest
push-latest:
	@$(call banner,$@)
	@docker tag ghcr.io/seek-oss/toolbox:$(RELEASE_VERSION) ghcr.io/seek-oss/toolbox:latest
	@docker push ghcr.io/seek-oss/toolbox:latest

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
