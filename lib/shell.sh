#!/usr/bin/env bash

# Tell shellcheck we'll be referencing definitions in the source file but don't
# actually source anything as all sourcing takes place up in bin.sh.
# shellcheck source=lib/common.sh
# shellcheck disable=SC1091
source /dev/null

##
## Run shfmt and shellcheck.
##
sh_lint() {
  local has_errors=false
  if ! sh_shfmt; then
    has_errors=true
  fi

  if ! sh_shellcheck; then
    has_errors=true
  fi

  if [[ "${has_errors}" == true ]]; then
    return 1
  fi
}

##
## Run shfmt.
##
sh_shfmt() {
  local includes
  readarray -t includes < <(_sh_includes shfmt)
  if [[ "${#includes[@]}" != 0 ]]; then
    info_msg "Running Shfmt"
    shfmt -i 2 -ci -sr -bn -d "${includes[@]}"
  fi
}

##
## Run shellcheck.
##
sh_shellcheck() {
  local includes
  readarray -t includes < <(_sh_includes shellcheck)
  if [[ "${#includes[@]}" != 0 ]]; then
    info_msg "Running Shellcheck"
    shellcheck "${includes[@]}"
  fi
}

##
## Returns the set of files to be included in either shfmt or shellcheck linting as
## determined by an argument which must be either "shfmt" or "shellcheck".
##
_sh_includes() {
  local type="${1}"
  local args ignore_patterns
  readarray -t ignore_patterns < <(jq -r \
    ".shell.lint.${type}.ignore // [] | .[]" <<< "${config_json}")
  for p in "${ignore_patterns[@]}"; do
    args+=(-not -path "${p}")
  done
  find . -type f -name '*.sh' "${args[@]}"
}
