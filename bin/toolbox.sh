#!/usr/bin/env bash

set -eou pipefail
shopt -s inherit_errexit

# Configure the TOOLBOX_HOME variable if not already set. When running in a
# container TOOLBOX_HOME will be set to toolbox's home location.
if [[ -z "${TOOLBOX_HOME:-}" ]]; then
  TOOLBOX_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

# shellcheck source=lib/args.sh
source "${TOOLBOX_HOME}/lib/args.sh"

# shellcheck source=lib/common.sh
source "${TOOLBOX_HOME}/lib/common.sh"

# shellcheck source=lib/terraform.sh
source "${TOOLBOX_HOME}/lib/terraform.sh"

# shellcheck source=lib/shell.sh
source "${TOOLBOX_HOME}/lib/shell.sh"

# shellcheck source=lib/snyk.sh
source "${TOOLBOX_HOME}/lib/snyk.sh"

# shellcheck source=lib/buildkite.sh
source "${TOOLBOX_HOME}/lib/buildkite.sh"

# Execute the command.
case "${_arg_command1}" in
  internal)
    case "${_arg_command2}" in
      version) toolbox_version_info ;;
      upgrade) toolbox_upgrade ;;
      *)
        die "Unrecognised internal Toolbox command: ${_arg_command2}"
        ;;
    esac
    ;;
  terraform)
    case "${_arg_command2}" in
      init) tf_init ;;
      workspace) tf_workspace ;;
      lint) tf_lint ;;
      validate) tf_validate ;;
      plan) tf_plan ;;
      plan-destroy-local) tf_plan_destroy_local ;;
      plan-local) tf_plan_local ;;
      apply) tf_apply ;;
      refresh) tf_refresh ;;
      destroy) tf_destroy ;;
      console) tf_console ;;
      unlock) tf_unlock ;;
      output) tf_output ;;
      output-json) tf_output_json ;;
      *)
        die "Unrecognised Terraform command: ${_arg_command2}"
        ;;
    esac
    ;;
  buildkite)
    case "${_arg_command2}" in
      pipeline) bk_pipeline ;;
      plan-annotate) bk_plan_annotate ;;
      *)
        die "Unrecognised Buildkite command: ${_arg_command2}"
        ;;
    esac
    ;;
  shell)
    case "${_arg_command2}" in
      shfmt) sh_shfmt ;;
      shellcheck) sh_shellcheck ;;
      lint) sh_lint ;;
      *)
        die "Unrecognised shell command: ${_arg_command2}"
        ;;
    esac
    ;;
  snyk)
    case "${_arg_command2}" in
      project) snyk_create_project ;;
      app-test) snyk_app_test ;;
      iac-test) snyk_iac_test ;;
      *)
        die "Unrecognised shell command: ${_arg_command2}"
        ;;
    esac
    ;;
  *)
    die "Unrecognised top-level command: ${_arg_command1}"
    ;;
esac
