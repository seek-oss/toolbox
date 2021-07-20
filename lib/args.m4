#!/bin/bash

# shellcheck disable=SC2034

_command1_help() {
  cat << EOF
Top-level command. Must be one of:
            - internal
            - terraform
            - buildkite
            - shell
            - snyk
EOF
}

_command2_help() {
  cat << EOF
Second-level command.
          The 'internal' command accepts the following:
            - version
          The 'terraform' command accepts the following:
            - init
            - workspace
            - validate
            - output
            - output-json
            - plan
            - plan-local
            - apply
            - refresh
            - destroy
            - console
            - lint
          The 'buildkite' command accepts the following:
            - pipeline
          The 'shell' command accepts the following:
            - shfmt
            - shellcheck
            - lint
          The 'snyk' command accepts the following:
            - project
            - test-app
            - test-iac
EOF
}

# m4_ignore(
echo "This is just a parsing library template, not the library - pass this file to 'argbash' to fix this." >&2
exit 11  #)Created by argbash-init v2.10.0
# ARG_OPTIONAL_SINGLE([config], [c], [Config file for toolbox])
# ARG_OPTIONAL_SINGLE([workspace], [w], [Terraform workspace name])
# ARG_OPTIONAL_SINGLE([skip-init], [s], [Whether to skip Terraform initialisation], [false])
# ARG_POSITIONAL_SINGLE([command1], [$(_command1_help)])
# ARG_POSITIONAL_SINGLE([command2], [$(_command2_help)])
# ARG_DEFAULTS_POS
# ARG_HELP([The toolbox provides common infrastructure functionality])
# ARGBASH_GO
