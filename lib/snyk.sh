#!/usr/bin/env bash

##
## Creates a monitored project on the Snyk website.
##
snyk_create_project() {
  local org token
  org="$(_snyk_org)"
  token="$(_snyk_token)"

  SNYK_TOKEN="${token}" snyk monitor --org="${org}"
}

##
## Run Snyk application test.
##
snyk_app_test() {
  local org token always_pass
  org="$(_snyk_org)"
  token="$(_snyk_token)"
  always_pass="$(config_value snyk.app_test.always_pass false)"

  if ! SNYK_TOKEN="${token}" snyk test --org="${org}"; then
    if [[ "${always_pass}" != true ]]; then
      return 1
    fi
  fi
}

##
## Run Snyk IaC (Infrastructure as Code) test.
##
snyk_iac_test() {
  local token always_pass
  token="$(_snyk_token)"
  always_pass="$(config_value snyk.iac_test.always_pass false)"

  if ! SNYK_TOKEN="${token}" snyk iac test; then
    if [[ "${always_pass}" != true ]]; then
      return 1
    fi
  fi
}

##
## Returns the Snyk token.
##
_snyk_token() {
  local secret_id
  secret_id="$(config_value snyk.secret_id)"

  aws secretsmanager get-secret-value --secret-id "${secret_id}" --query SecretString --output text
}

##
## Returns the Snyk organisation name.
##
_snyk_org() {
  config_value snyk.org
}
