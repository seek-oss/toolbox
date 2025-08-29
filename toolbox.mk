# Version of Toolbox to use.
TOOLBOX_VERSION ?= latest

# Toolbox Docker image. Default image is exposed as a separate variable to
# allow importing Makefiles to override TOOLBOX_IMAGE but still retain a
# reference to the default to use to specify as a base image build arg.
DEFAULT_TOOLBOX_IMAGE := seek/toolbox:$(TOOLBOX_VERSION)
TOOLBOX_IMAGE         ?= $(DEFAULT_TOOLBOX_IMAGE)

# The TOOLBOX_CONFIG_FILE variable can be specified by the caller to override
# the default config file locations.
TOOLBOX_CONFIG_FILE ?=

# The WORKSPACE variable is required by certain targets and should be
# provided by the caller in the form `make target WORKSPACE=workspace`.
WORKSPACE ?=

# Whether Toolbox should skip Terraform initialisation. To save time,
# this variable may be set to true when working locally and you know that
# Terraform has already been initialised for the project.
SKIP_INIT ?= false

# The PRE_TOOLBOX_HOOK can be used to specify a Makefile rule that should be
# run prior to the Toolbox container being run. This can be used to do things
# like build a local custom Toolbox image or log in to a Docker registry so
# that a remote custom Toolbox image can be used.
PRE_TOOLBOX_HOOK ?=

# The Buildkite pipeline slug is used when generating the pipeline document.
# When running on an agent the BUILDKITE_PIPELINE_SLUG will be present.
# A default value is set for local testing purposes.
export BUILDKITE_PIPELINE_SLUG ?= $(shell basename $(shell pwd))

export TOOLBOX_BUILDKITE_PLAN_ONLY ?= false

# Local build artifacts directory.
build_dir := target

# Pretty printing.
ifneq ($(TERM),)
ifneq ($(TERM),dumb)
color_on  := $(shell tput setaf 4)
color_off := $(shell tput sgr0)
endif
endif

# Macro for printing a pretty banner.
banner = \
	printf "\n$(color_on)=> Executing target: $1$(color_off)\n" >&2

# Macros for executing running a command in the toolbox container.
_toolbox = \
	docker run --rm $2 \
		-e HOST_WORK_DIR=$(shell pwd) \
		-e HOST_HOME_DIR=$(HOME) \
		-e TOOLBOX_CONFIG_FILE \
		-e BUILDKITE_PIPELINE_SLUG \
		-e BUILDKITE_JOB_ID \
		-e BUILDKITE_AGENT_ACCESS_TOKEN \
		-e TERM \
		-e TOOLBOX_BUILDKITE_PLAN_ONLY \
		-v "$$(pwd):/work" \
		-v "$(HOME)/.aws:/root/.aws" \
		-v "/var/run/docker.sock:/var/run/docker.sock" \
		-w /work \
		"$(TOOLBOX_IMAGE)" $1
toolbox     = $(call _toolbox,$1)
toolbox_tty = $(call _toolbox,$1,-ti)

# Help message printed by the help target.
define HELP
+------------------------------+----------------------------------------------------------------------------------+
| Make Target                  | Description                                                                      |
|------------------------------+----------------------------------------------------------------------------------|
| help                         | Displays this help message.                                                      |
| clean                        | Deletes the target/ and .terraform/ directories.                                 |
|------------------------------+----------------------------------------------------------------------------------|
| toolbox-version              | Prints Toolbox version information.                                              |
| toolbox-upgrade              | Upgrades the version of Toolbox to the latest versioned release.                 |
| toolbox-bash                 | Launch an interactive Bash shell in the Toolbox container.                       |
|------------------------------+----------------------------------------------------------------------------------|
| terraform-lint               | Lints Terraform files in the current repository.                                 |
| terraform-init               | Initialises Terraform.                                                           |
| terraform-validate           | Validates Terraform files in the current repository.                             |
| terraform-workspace          | Selects the Terraform workspace. WORKSPACE must be specified.                    |
| terraform-output             | Prints Terraform outputs in HCL format. WORKSPACE must be specified.             |
| terraform-output-json        | Prints Terraform outputs in JSON format. WORKSPACE must be specified.            |
| terraform-plan               | Creates a Terraform plan using remote state. WORKSPACE must be specified.        |
| terraform-plan-destroy-local | Creates a Terraform destroy plan using local state. WORKSPACE must be specified. |
| terraform-plan-local         | Creates a Terraform plan using local state. WORKSPACE must be specified.         |
| terraform-apply              | Applies previously created Terraform plan. WORKSPACE must be specified.          |
| terraform-refresh            | Refreshes remote Terraform state. WORKSPACE must be specified.                   |
| terraform-destroy            | Destroys Terraform-managed infrastructure. WORKSPACE must be specified.          |
| terraform-console            | Launches a Terraform console. WORKSPACE must be specified.                       |
| terraform-unlock             | Force unlocks the Terraform state. WORKSPACE must be specified.                  |
|------------------------------+----------------------------------------------------------------------------------|
| buildkite-pipeline           | Prints the generated Buildkite pipeline to stdout.                               |
| buildkite-plan-annotate      | Annotates the current Buildkite pipeline with details of the Terraform plan.     |
|------------------------------+----------------------------------------------------------------------------------|
| shell-shfmt                  | Runs shfmt against shell files in the current repository.                        |
| shell-shellcheck             | Runs shellcheck against shell files in the current repository.                   |
| shell-lint                   | Runs shfmt and shellcheck against shell files in the current repository.         |
|------------------------------+----------------------------------------------------------------------------------|
| snyk-project                 | Creates a project on the Snyk website for the current repository.                |
| snyk-app-test                | Runs a Snyk application test.                                                    |
| snyk-iac-test                | Runs a Snyk infrastructure test.                                                 |
+------------------------------+----------------------------------------------------------------------------------+
endef
export HELP

##
## Print a help message.
##
.PHONY: help
help:
	@$(call banner,$@)
	@echo "$${HELP}"

##
## Ensure that the build directory exists.
##
$(build_dir):
	@mkdir -p $(build_dir)

##
## Clean local temporary files.
##
.PHONY: clean
clean:
	@$(call banner,$@)
	@rm -rf ./$(build_dir) ./.terraform

##
## Toolbox internal targets.
##
.PHONY: toolbox-version toolbox-update toolbox-upgrade
toolbox-update: toolbox-upgrade
toolbox-version toolbox-upgrade: $(PRE_TOOLBOX_HOOK)
	@$(call banner,$@)
	@$(call toolbox,toolbox internal "$(@:toolbox-%=%)")

##
## Run a Toolbox Bash shell.
##
.PHONY: toolbox-bash
toolbox-bash: $(PRE_TOOLBOX_HOOK)
	@$(call banner,$@)
	@$(call toolbox_tty,bash)

##
## Terraform targets that DON'T require a workspace.
##
.PHONY: terraform-init terraform-validate terraform-lint
terraform-init terraform-validate terraform-lint: $(PRE_TOOLBOX_HOOK)
	@$(call banner,$@)
	@$(call toolbox,toolbox -s "$(SKIP_INIT)" terraform "$(@:terraform-%=%)")

##
## Ensures that a WORKSPACE variable has been specified.
##
.PHONY: terraform-ensure-workspace
terraform-ensure-workspace:
ifeq ($(WORKSPACE),)
	@$(error WORKSPACE variable must be specified)
endif

##
## Terraform targets that DO require a workspace (non-interactive).
##
.PHONY: terraform-workspace terraform-plan terraform-plan-destroy-local terraform-plan-local terraform-apply terraform-refresh terraform-unlock terraform-output terraform-output-json
terraform-workspace terraform-plan terraform-plan-destroy-local terraform-plan-local terraform-apply terraform-refresh terraform-unlock terraform-output terraform-output-json: terraform-ensure-workspace $(PRE_TOOLBOX_HOOK)
	@$(call banner,$@)
	@$(call toolbox,toolbox -w "$(WORKSPACE)" -s "$(SKIP_INIT)" terraform "$(@:terraform-%=%)")

##
## Terraform targets that DO require a workspace (interactive).
##
.PHONY: terraform-destroy terraform-console
terraform-destroy terraform-console: terraform-ensure-workspace $(PRE_TOOLBOX_HOOK)
	@$(call banner,$@)
	@$(call toolbox_tty,toolbox -w "$(WORKSPACE)" -s "$(SKIP_INIT)" terraform "$(@:terraform-%=%)")

##
## Buildkite targets that DO require a workspace
##
.PHONY: buildkite-pipeline
buildkite-pipeline: $(PRE_TOOLBOX_HOOK)
	@$(call banner,$@)
	@$(call toolbox,toolbox buildkite "$(@:buildkite-%=%)")

##
## Buildkite targets that DON'T require a workspace
##
.PHONY: buildkite-plan-annotate
buildkite-plan-annotate: $(PRE_TOOLBOX_HOOK)
	@$(call banner,$@)
	@$(call toolbox,toolbox -w "$(WORKSPACE)" buildkite "$(@:buildkite-%=%)")

##
## Shell targets.
##
.PHONY: shell-shfmt shell-shellcheck shell-lint
shell-shfmt shell-shellcheck shell-lint: $(PRE_TOOLBOX_HOOK)
	@$(call banner,$@)
	@$(call toolbox,toolbox shell "$(@:shell-%=%)")

##
## Snyk targets.
##
.PHONY: snyk-project snyk-app-test snyk-iac-test
snyk-project snyk-app-test snyk-iac-test: $(PRE_TOOLBOX_HOOK)
	@$(call banner,$@)
	@$(call toolbox,toolbox snyk "$(@:snyk-%=%)")
