#!/usr/bin/env bash

# Tell shellcheck we'll be referencing definitions in the source file but don't
# actually source anything as all sourcing takes place up in bin.sh.
# shellcheck source=lib/common.sh
# shellcheck disable=SC1091
source /dev/null

# Get the current pipeline slug.
_bk_pipeline_slug="${BUILDKITE_PIPELINE_SLUG:-$(basename "$(pwd)")}"

# Version of https://github.com/buildkite-plugins/artifacts-buildkite-plugin to use.
_bk_artifacts_plugin_version=v1.3.0

##
## Print the Buildkite pipeline to stdout.
##
bk_pipeline() {
  _bk_begin_steps
  _bk_tf_lint_step
  _bk_sh_lint_step
  _bk_tf_validate_step
  _bk_snyk_steps
  _bk_wait_step
  _bk_tf_plan_steps
  _bk_tf_apply_steps
}

##
## Print beginning of the Buildkite pipeline steps.
##
_bk_begin_steps() {
  echo 'steps:'
}

##
## Print wait step.
##
_bk_wait_step() {
  echo '- wait'
}

##
## Print block step.
##
_bk_block_step() {
  local protected_branches
  protected_branches="$(_bk_tf_protected_branches)"
  cat << EOF
- block: ":rocket: Deploy"
  branches: "${protected_branches}"
EOF
}

##
## Print either a wait step or a block step depending on the value
## of the buildkite.deploy_pause_type configuration property.
##
_bk_pause_step() {
  local pause_type
  pause_type="$(config_value buildkite.deploy_pause_type block)"
  case "${pause_type}" in
    wait) _bk_wait_step ;;
    *) _bk_block_step ;;
  esac
}

##
## Print step that lints shell files.
##
_bk_sh_lint_step() {
  # Don't perform shell lint step if no queue was specified.
  local queue
  queue="$(config_value shell.lint.queue null)"
  if [[ "${queue}" == null ]]; then
    return 0
  fi

  cat << EOF
- label: ":shell: Lint"
  command: make shell-lint
  agents:
    queue: ${queue}
EOF
}

##
## Print step that lints Terraform files.
##
_bk_tf_lint_step() {
  # Don't perform Terraform lint step if no queue was specified.
  local queue
  queue="$(config_value terraform.lint.queue null)"
  if [[ "${queue}" == null ]]; then
    return 0
  fi

  cat << EOF
- label: ":terraform: Lint"
  command: make terraform-lint
  agents:
    queue: ${queue}
EOF
}

##
## Print step that validates Terraform files.
##
_bk_tf_validate_step() {
  # Don't perform Terraform validation step if no queue was specified.
  local queue
  queue="$(config_value terraform.validate.queue null)"
  if [[ "${queue}" == null ]]; then
    return 0
  fi

  cat << EOF
- label: ":terraform: Validate"
  command: make terraform-validate
  agents:
    queue: ${queue}
EOF
}

##
## Print a Terraform plan step for each workspace.
##
_bk_tf_plan_steps() {
  if [[ "$(_bk_tf_total_workspace_steps)" == 0 ]]; then
    return 0
  fi

  local workspace queue uploads downloads protected_branches unprotected_branches
  while IFS=$'\t' read -r workspace queue; do
    protected_branches="$(_bk_tf_protected_branches "${workspace}")"
    unprotected_branches="$(_bk_tf_unprotected_branches "${workspace}")"

    uploads="$(jq -c '[{
      "from": "'"${build_dir}/terraform.tfplan"'",
      "to": "'"${build_dir}/${workspace}.tfplan"'"
    }] + .buildkite.artifacts.upload // []' <<< "${config_json}")"
    downloads="$(jq -c \
      '.buildkite.artifacts.download // []' <<< "${config_json}")"

    cat << EOF
- label: ":terraform: Plan [${workspace}]"
  branches: "${protected_branches}"
  command: make terraform-plan WORKSPACE=${workspace}
  plugins:
  - artifacts#${_bk_artifacts_plugin_version}:
      upload: ${uploads}
      download: ${downloads}
  agents:
    queue: ${queue}
  retry:
    manual:
      permit_on_passed: true
  concurrency: 1
  concurrency_group: ${_bk_pipeline_slug}/${workspace}
- label: ":terraform: Plan [${workspace}]"
  branches: "${unprotected_branches}"
  command: make terraform-plan-local WORKSPACE=${workspace}
  plugins:
  - artifacts#${_bk_artifacts_plugin_version}:
      upload: ${uploads}
      download: ${downloads}
  agents:
    queue: ${queue}
  retry:
    manual:
      permit_on_passed: true
EOF
  done < <(jq -r \
    '.terraform.workspaces[]
    | [.name, .queue]
    | @tsv' <<< "${config_json}")
}

##
## Print a Terraform apply step for each workspace. This function will first print a
## wait or block step, followed by apply steps for each non-production workspace,
## followed by another wait or block step, followed by apply steps for each production
## workspace. This sequence looks as follows:
##
## Wait/Block -> Apply Non-Prod -> Wait/Block -> Apply Prod
##
_bk_tf_apply_steps() {
  if [[ "$(_bk_tf_total_workspace_steps)" == 0 ]]; then
    return 0
  fi

  # Wait for the plan steps to complete.
  _bk_pause_step

  # Apply non-production workspaces.
  _bk_tf_apply_steps_filter false

  # Only print a pause step if there are non-production workspaces. In the odd case that
  # all workspaces have been marked production we don't want to print a pause step at this
  # point otherwise there will have been two in a row.
  local total_non_prod_workspaces
  total_non_prod_workspaces="$(jq '.terraform.workspaces | map(select(.is_production != true)) | length' <<< "${config_json}")"
  if [[ "${total_non_prod_workspaces}" != 0 ]]; then
    _bk_pause_step
  fi

  # Apply production workspaces.
  _bk_tf_apply_steps_filter true
}

##
## Print a Terraform apply step for each workspace that matches the specified
## is_production filter. I.e., `_bk_tf_apply_steps_filter false` will print apply
## steps for each non-production workspace, while `_bk_tf_apply_steps_filter true`
## will print apply steps for each production workspace.
##
_bk_tf_apply_steps_filter() {
  local is_production_filter="${1}"

  local workspace queue is_production uploads downloads protected_branches
  while IFS=$'\t' read -r workspace queue is_production; do
    if [[ "${is_production}" != "${is_production_filter}" ]]; then
      continue
    fi

    protected_branches="$(_bk_tf_protected_branches "${workspace}")"

    uploads="$(jq -c \
      '.buildkite.artifacts.upload // []' <<< "${config_json}")"
    downloads="$(jq -c '[{
      "from": "'"${build_dir}/${workspace}.tfplan"'",
      "to": "'"${build_dir}/terraform.tfplan"'"
    }] + .buildkite.artifacts.download // []' <<< "${config_json}")"

    cat << EOF
- label: ":terraform: Apply [${workspace}]"
  branches: "${protected_branches}"
  command: make terraform-apply WORKSPACE=${workspace}
  plugins:
  - artifacts#${_bk_artifacts_plugin_version}:
      upload: ${uploads}
      download: ${downloads}
  agents:
    queue: ${queue}
  retry:
    manual:
      permit_on_passed: true
  concurrency: 1
  concurrency_group: ${_bk_pipeline_slug}/${workspace}
EOF
  done < <(jq -r \
    '.terraform.workspaces[]
    | [.name, .queue, .is_production]
    | @tsv' <<< "${config_json}")
}

##
## Returns the total number of Terraform workspaces that specify a Buildkite queue.
##
_bk_tf_total_workspace_steps() {
  jq '.terraform.workspaces // [] | map(select(.queue != null)) | length' <<< "${config_json}"
}

##
## Return the set of branches that can be deployed.
##
_bk_tf_protected_branches() {
  local workspace="${1:-}"
  if [[ -n "${workspace}" ]]; then
    jq -r '.terraform.workspaces // []
      | map(select(.name == "'"${workspace}"'"))
      | .[].branches // ["master", "main"]
      | unique
      | join(" ")' <<< "${config_json}"
  else
    jq -r '.terraform.workspaces // []
      | map(.branches // ["master", "main"])
      | flatten
      | unique
      | join(" ")' <<< "${config_json}"
  fi
}

##
## Return the set of branches should not be deployed.
##
_bk_tf_unprotected_branches() {
  _bk_tf_protected_branches "${1:-}" | jq -Rr 'split(" ") | map("!" + .) | join(" ")'
}

##
## Print steps that run Snyk.
##
_bk_snyk_steps() {
  local queue
  queue="$(config_value snyk.app_test.queue null)"
  if [[ "${queue}" != null ]]; then
    cat << EOF
- label: ":mag: Snyk App Test"
  if: "build.branch == 'master' || build.branch == 'main'"
  commands:
  - make snyk-project
  - make snyk-app-test
  agents:
    queue: ${queue}
- label: ":mag: Snyk App Test"
  if: "build.branch != 'master' && build.branch != 'main'"
  command: make snyk-app-test
  agents:
    queue: ${queue}
EOF
  fi

  queue="$(config_value snyk.iac_test.queue null)"
  if [[ "${queue}" != null ]]; then
    cat << EOF
- label: ":mag: Snyk Infrastructure Test"
  command: make snyk-iac-test
  agents:
    queue: ${queue}
EOF
  fi
}
