# Include toolbox.mk so that Toolbox targets can be tested locally.
include toolbox.mk

# Version of the Toolbox Docker image to build/push.
RELEASE_VERSION ?= latest

# Release archive file that's uploaded to GitHub.
RELEASE_ARCHIVE ?= $(build_dir)/toolbox.zip

# Files that are included in the release archive.
release_files := toolbox.mk .gitignore .editorconfig

##
## Build a new Toolbox Docker image.
##
.PHONY: build
build:
	@$(call banner,$@)
	@docker build \
		--build-arg TOOLBOX_VERSION=$(RELEASE_VERSION) \
		-t seek/toolbox:$(RELEASE_VERSION) .

##
## Pushes the Toolbox image to DockerHub.
##
.PHONY: push
push:
	@$(call banner,$@)
	@docker push seek/toolbox:$(RELEASE_VERSION)

##
## Tags and pushes a latest tag for the Toolbox image.
##
.PHONY: push-latest
push-latest:
	@$(call banner,$@)
	@docker tag seek/toolbox:$(RELEASE_VERSION) seek/toolbox:latest
	@docker push seek/toolbox:latest

##
## Creates release archive to be uploaded to GitHub.
##
.PHONY: package
package: $(build_dir) $(release_files)
	@$(call banner,$@)
	@rm -rf $(RELEASE_ARCHIVE) $(build_dir)/release
	@mkdir -p $(build_dir)/release
	@cp $(release_files) $(build_dir)/release
	@sed "s/TOOLBOX_VERSION := .*/TOOLBOX_VERSION := $(RELEASE_VERSION)/" toolbox.mk > $(build_dir)/release/toolbox.mk
	@cd $(build_dir)/release && zip toolbox.zip $(release_files)
	@mv $(build_dir)/release/toolbox.zip $(RELEASE_ARCHIVE)
	@echo "Created $(RELEASE_ARCHIVE)" >&2

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
