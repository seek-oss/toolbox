#!/usr/bin/env bash

# Tell shellcheck we'll be referencing definitions in the source file but don't
# actually source anything as all sourcing takes place up in bin.sh.
# shellcheck source=lib/common.sh
# shellcheck disable=SC1091
source /dev/null

# Get the current pipeline slug.
_bk_pipeline_slug="${BUILDKITE_PIPELINE_SLUG:-$(basename "$(pwd)")}"

# Version of https://github.com/buildkite-plugins/artifacts-buildkite-plugin to use.
_bk_artifacts_plugin_version=v1.9.3

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
  local msg="${1}"
  local protected_branches="${2}"
  cat << EOF
- block: ":rocket: ${msg}"
  blocked_state: running
  branches: "${protected_branches}"
EOF
}

##
## Print either a wait step or a block step depending on the value
## of the buildkite.deploy_pause_type configuration property.
##
_bk_pause_step() {
  local msg="${1}"
  local protected_branches="${2}"
  local pause_type
  pause_type="$(config_value buildkite.deploy_pause_type block)"
  case "${pause_type}" in
    wait) _bk_wait_step ;;
    *) _bk_block_step "${msg}" "${protected_branches}" ;;
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
## Print the APM environment variables.
##
_bk_apm_environment_vars() {
  local workspace_filter="${1}"
  local deployment_service
  deployment_service="$(config_value apm.service_name null)"

  if [[ "${deployment_service}" != null ]]; then
    local environment="development"
    local is_production

    while IFS=$'\t' read -r is_production; do
    if [[ "${is_production}" == true ]]; then
      environment="production"
    fi
  cat << EOF
  env:
    DD_DEPLOYMENT_ENVIRONMENT: ${environment}
    DD_DEPLOYMENT_SERVICE: ${deployment_service}
EOF
    done < <(jq -r \
      '.terraform.workspaces // []
      | map(select(.name == "'"${workspace_filter}"'"))
      | map([.is_production])[]
      | @tsv' <<< "${config_json}")
  fi
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
##
##
_bk_tf_artifacts_plugin() {
  local workspace="${1}"
  local step_type="${2}"

  local upload_defaults='[]'
  local download_defaults='[]'
  if [[ "${step_type}" == plan ]]; then
    upload_defaults='[{
      "from": "'"${build_dir}/terraform.tfplan"'",
      "to": "'"${build_dir}/${workspace}.tfplan"'"
    }]'
  else
    download_defaults='[{
      "from": "'"${build_dir}/${workspace}.tfplan"'",
      "to": "'"${build_dir}/terraform.tfplan"'"
    }]'
  fi

  jq -c \
    --arg workspace "${workspace}" \
    --arg step_type "${step_type}" \
    --arg plugin_version "${_bk_artifacts_plugin_version}" \
    --argjson upload_defaults "${upload_defaults}" \
    --argjson download_defaults "${download_defaults}" \
    -f "${TOOLBOX_HOME}/lib/artifacts.jq" \
    <<< "${config_json}"
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

  local workspace queue protected_branches unprotected_branches artifact_plugin
  while IFS=$'\t' read -r workspace queue; do
    protected_branches="$(_bk_tf_protected_branches_for_workspace "${workspace}")"
    unprotected_branches="$(_bk_tf_unprotected_branches_for_workspace "${workspace}")"
    artifact_plugin="$(_bk_tf_artifacts_plugin "${workspace}" plan)"

    cat << EOF
- label: ":terraform: Plan [${workspace}]"
  branches: "${protected_branches}"
  command:
  - make terraform-plan WORKSPACE=${workspace}
  - make buildkite-plan-annotate WORKSPACE=${workspace}
  plugins:
  - ${artifact_plugin}
  agents:
    queue: ${queue}
  retry:
    manual:
      permit_on_passed: true
  concurrency: 1
  concurrency_group: ${_bk_pipeline_slug}/${workspace}
- label: ":terraform: Tentative plan [${workspace}]"
  branches: "${unprotected_branches}"
  command:
  - make terraform-plan-local WORKSPACE=${workspace}
  - make buildkite-plan-annotate WORKSPACE=${workspace}
  plugins:
  - ${artifact_plugin}
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

  # If there are any workspaces earmarked as non-production, then we wait for the previous
  # plan steps to complete and apply the non-production plans.
  local total_non_production_workspaces
  total_non_production_workspaces="$(_bk_tf_total_non_production_workspaces)"
  if [[ "${total_non_production_workspaces}" != 0 ]]; then
    local non_production_protected_branches
    non_production_protected_branches="$(_bk_tf_protected_branches_filter '.is_production != true')"
    _bk_pause_step "Deploy pre-production" "${non_production_protected_branches}"

    # Apply non-production workspaces.
    _bk_tf_apply_steps_filter '.is_production != true'
  fi

  # If there are any workspaces earmarked as production, then we wait for the previous
  # steps to complete and apply the production plans.
  local total_production_workspaces
  total_production_workspaces="$(_bk_tf_total_production_workspaces)"
  if [[ "${total_production_workspaces}" != 0 ]]; then
    local production_protected_branches
    production_protected_branches="$(_bk_tf_protected_branches_filter '.is_production == true')"
    _bk_pause_step "Deploy production" "${production_protected_branches}"

    # Apply production workspaces.
    _bk_tf_apply_steps_filter '.is_production == true'
  fi
}

##
## Print a Terraform apply step for each workspace using the optionally specified jq match filter.
##
_bk_tf_apply_steps_filter() {
  local match_condition="${1:-}"
  local match_filter=
  if [[ -n "${match_condition}" ]]; then
    match_filter="| map(select(${match_condition}))"
  fi

  local workspace queue protected_branches artifact_plugin
  while IFS=$'\t' read -r workspace queue; do
    protected_branches="$(_bk_tf_protected_branches_for_workspace "${workspace}")"
    artifact_plugin="$(_bk_tf_artifacts_plugin "${workspace}" apply)"

    cat << EOF
- label: ":terraform: Apply [${workspace}]"
  branches: "${protected_branches}"
  command: make terraform-apply WORKSPACE=${workspace}
  plugins:
  - ${artifact_plugin}
  agents:
    queue: ${queue}
  retry:
    manual:
      permit_on_passed: true
  concurrency: 1
  concurrency_group: ${_bk_pipeline_slug}/${workspace}
EOF
  _bk_apm_environment_vars "${workspace}"
  done < <(jq -r \
    '.terraform.workspaces // []
    '"${match_filter}"'
    | map(select(.queue != null))
    | map([.name, .queue])[]
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
_bk_tf_protected_branches_filter() {
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
## jq filter condition returning the result as branch name patterns.
##
# shellcheck disable=SC2120
_bk_tf_unprotected_branches_filter() {
  _bk_tf_protected_branches_filter "${1:-}" | jq -Rr 'split(" ") | map("!" + .) | join(" ")'
}

##
## Return the set of branches that can be deployed for the specified workspace.
##
_bk_tf_protected_branches_for_workspace() {
  local workspace="${1}"
  local name_match="^${workspace}$"
  _bk_tf_protected_branches_filter ".name | test(\"${name_match}\")"
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
    protected_branches="$(_bk_tf_protected_branches_filter)"
    unprotected_branches="$(_bk_tf_unprotected_branches_filter)"

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

##
## Generate an annotation for the build based on the plan result.
##
## This function looks for a plan file at "${build_dir}/terraform.tfplan".
## If there is no file, we assume the plan failed, and we create an error annotation with a link to the failed job.
## If there is a file, we inspect the .resource_changes[].change.actions fields for each resource.
## If there is no .resource_changes array, that indicate that this is a new workspace with no resources, so a clean plan.
## If all of these fields are "no-op", the plan has succeeded with no changes.
## If any of these fields are not "no-op", the plan has succeeded with changes, and we link to the job for further
## inspection.
##
bk_plan_annotate() {
  # Ensure that a workspace argument (-w/--workspace) was specified.
  if [[ -z "${_arg_workspace:-}" ]]; then
    die "No Terraform workspace specified. This command requires a --workspace argument."
  fi

  info_msg "Annotating build with plan output"

  local tf_plan_file="${build_dir}/terraform.tfplan"
  if [[ -f "${tf_plan_file}" ]]; then
    local is_all_no_ops
    is_all_no_ops=$(terraform show -json "${tf_plan_file}" | jq 'if .resource_changes == null then true else [.resource_changes[].change.actions] | flatten | all(. == "no-op") end')
    if [[ "${is_all_no_ops}" == "true" ]]; then
      buildkite-agent annotate "**${_arg_workspace}**: Successful plan with no changes" --style success --context "${_arg_workspace}"
    else
      buildkite-agent annotate "**${_arg_workspace}**: Successful plan with changes" --style info --context "${_arg_workspace}"
      {
        echo -e "**${_arg_workspace}**: Successful plan with changes"
        echo -e ''
        echo -e "Consult [the job](#${BUILDKITE_JOB_ID}) for more information"
      } | buildkite-agent annotate --context "${_arg_workspace}" --style info
    fi
  else
    {
      echo -e "**${_arg_workspace}**: Error while planning"
      echo -e ''
      echo -e "Consult [the failing job](#${BUILDKITE_JOB_ID}) for more information"
    } | buildkite-agent annotate --style error --context "${_arg_workspace}"
  fi
}
