#!/usr/bin/env bash

# set -x

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
  local protected_branches="${1}"
  cat << EOF
- block: ":rocket: Deploy"
  blocked_state: running
  branches: "${protected_branches}"
EOF
}

##
## Print either a wait step or a block step depending on the value
## of the buildkite.deploy_pause_type configuration property.
##
_bk_pause_step() {
  local protected_branches="${1}"
  local pause_type
  pause_type="$(config_value buildkite.deploy_pause_type block)"
  case "${pause_type}" in
    wait) _bk_wait_step ;;
    *) _bk_block_step "${protected_branches}" ;;
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
  local total_workspaces
  total_workspaces="$(_bk_tf_total_workspaces)"
  if [[ "${total_workspaces}" == 0 ]]; then
    return 0
  fi

  local workspace queue uploads downloads protected_branches unprotected_branches
  while IFS=$'\t' read -r workspace queue; do
    protected_branches="$(_bk_tf_protected_branches_for_workspace "${workspace}")"
    unprotected_branches="$(_bk_tf_unprotected_branches_for_workspace "${workspace}")"

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
    '.terraform.workspaces // []
    | map(select(.queue != null))
    | map([.name, .queue])[]
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
  local total_workspaces
  total_workspaces="$(_bk_tf_total_workspaces)"
  if [[ "${total_workspaces}" == 0 ]]; then
    return 0
  fi

  # Wait for the plan steps to complete. Here, the pause step should run for all protected
  # branches there must be at least one workspace that gets deployed via Buildkite (due to
  # condition above), and we would have output a plan step for that workspace prior to this
  # function being called.
  local all_protected_branches
  all_protected_branches="$(_bk_tf_protected_branches)"
  _bk_pause_step "${all_protected_branches}"

  # Apply non-production workspaces.
  # TODO: Make filtering the same across branches and steps i.e., ".is_production == true".
  _bk_tf_apply_steps_filter false

  # At this point, we have printed apply steps for all non-production workspaces. If there
  # are no workspaces earmarked as production then return early.
  local total_production_workspaces
  total_production_workspaces="$(_bk_tf_total_production_workspaces)"
  if [[ "${total_production_workspaces}" == 0 ]]; then
    return 0
  fi

  # At this point, we have printed apply steps for all non-production workspaces. Any remaining
  # workspaces must therefore be production workspaces. We print a pause step at this point which
  # only targets the production workspaces. If the pause step were to be applied more broadly,
  # we'd end up with a dangling wait/block step for branches which aren't deployed to production.
  local production_protected_branches
  production_protected_branches="$(_bk_tf_protected_branches '.is_production == true')"
  _bk_pause_step "${production_protected_branches}"

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

    protected_branches="$(_bk_tf_protected_branches_for_workspace "${workspace}")"

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
    '.terraform.workspaces // []
    | map(select(.queue != null))
    | map([.name, .queue, .is_production])[]
    | @tsv' <<< "${config_json}")
}

##
## Returns the total number of Terraform workspaces that specify a Buildkite queue.
##
_bk_tf_total_workspaces() {
  jq '.terraform.workspaces // []
    | map(select(.queue != null))
    | length' <<< "${config_json}"
}

##
## Returns the total number of Terraform workspaces that specify a Buildkite queue
## and correspond to production environments.
##
_bk_tf_total_production_workspaces() {
  jq '.terraform.workspaces // []
    | map(select(.queue != null and .is_production == true))
    | length' <<< "${config_json}"
}

##
## Returns the total number of Terraform workspaces that specify a Buildkite queue
## and do not correspond to production environments.
##
_bk_tf_total_non_production_workspaces() {
  local total_workspaces total_production_workspaces
  total_workspaces="$(_bk_tf_total_workspaces)"
  total_production_workspaces="$(_bk_tf_total_production_workspaces)"
  echo $((total_workspaces - total_production_workspaces))
}

##
## Return the set of branches that can be deployed applying an optionally specified
## jq match condition.
##
_bk_tf_protected_branches() {
  local match_condition="${1:-}"
  local match_filter=
  if [[ -n "${match_condition}" ]]; then
    match_filter="| map(select(${match_condition}))"
  fi

  jq -r \
    '.terraform.workspaces // []
    '"${match_filter}"'
    | map(select(.queue != null))
    | map(.branches // ["master", "main"])
    | flatten
    | unique
    | join(" ")' <<< "${config_json}"
}

##
## Return the set of branches that should not be deployed applying an optionally specified
## jq match condition returning the result as branch name patterns.
##
_bk_tf_unprotected_branches() {
  _bk_tf_protected_branches "${1:-}" | jq -Rr 'split(" ") | map("!" + .) | join(" ")'
}

##
## Return the set of branches that can be deployed for the specified workspace.
##
_bk_tf_protected_branches_for_workspace() {
  local workspace="${1}"
  local name_match="^${workspace}$"
  _bk_tf_protected_branches ".name | test(\"${name_match}\")"
}

##
## Return the set of branches that should not be deployed for the specified
## workspace as branch name patterns.
##
_bk_tf_unprotected_branches_for_workspace() {
  _bk_tf_protected_branches_for_workspace "${1:-}" | jq -Rr 'split(" ") | map("!" + .) | join(" ")'
}

##
## Print steps that run Snyk.
##
_bk_snyk_steps() {
  local queue
  queue="$(config_value snyk.app_test.queue null)"
  if [[ "${queue}" != null ]]; then
    local protected_branches unprotected_branches
    protected_branches="$(_bk_tf_protected_branches)"
    unprotected_branches="$(_bk_tf_unprotected_branches)"

    cat << EOF
- label: ":mag: Snyk App Test"
  branches: "${protected_branches}"
  commands:
  - make snyk-project
  - make snyk-app-test
  agents:
    queue: ${queue}
- label: ":mag: Snyk App Test"
  branches: "${unprotected_branches}"
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
