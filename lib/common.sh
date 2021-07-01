#!/usr/bin/env bash

# Tell shellcheck we'll be referencing definitions in the source file but don't
# actually source anything as all sourcing takes place up in bin/toolbox.sh.
# shellcheck source=lib/args.sh
# shellcheck disable=SC1091
source /dev/null

# Variable stores the full config JSON document.
config_json=

# Toolbox 'internal' commands are exempt from requiring a config file.
if [[ "${_arg_command1}" != internal ]]; then
  # Default config file locations.
  _default_config_files=(toolbox.yaml .toolbox.yaml)

  # Determine the location of the config file to use.
  _config_file=
  if [[ -n "${_arg_config}" ]]; then
    # Config file was specified on the command line - ensure it exists.
    if [[ ! -f "${_arg_config}" ]]; then
      die "Config file ${_arg_config} specified by -c/--config argument does not exist."
    fi
    _config_file="${_arg_config}"
  else
    # No config file was specified on the command line. First, check TOOLBOX_CONFIG_FILE variable.
    if [[ -n "${TOOLBOX_CONFIG_FILE:-}" ]]; then
      if [[ ! -f "${TOOLBOX_CONFIG_FILE}" ]]; then
        die "Config file ${TOOLBOX_CONFIG_FILE} specified by TOOLBOX_CONFIG_FILE variable does not exist."
      fi
      _config_file="${TOOLBOX_CONFIG_FILE}"
    fi

    # Search the default locations.
    for f in "${_default_config_files[@]}"; do
      if [[ -f "${f}" ]]; then
        _config_file="${f}"
        break
      fi
    done

    # Ensure a config file has been found.
    if [[ -z "${_config_file}" ]]; then
      die "No config file could be found."
    fi
  fi

  # Ensure that the config file complies with the schema.
  if ! res="$(schma validate --schema "${TOOLBOX_HOME}/lib/schema.json" --data "${_config_file}")"; then
    printf "%s\n\n" "${res}" >&2
    die "Configuration file is invalid. See schema violations above."
  fi

  # Read the config file
  config_json="$(yq eval -j "${_config_file}")"
fi

##
## Pretty prints an info message.
##
info_msg() {
  local msg="${1}"
  local color_on color_off
  if [[ -n "${TERM:-}" && "${TERM}" != dumb ]]; then
    color_on="$(tput setaf 4)"
    color_off="$(tput sgr0)"
  fi
  printf "%s\n" "${color_on:-}=> => ${msg}${color_off:-}" >&2
}

##
## Reads a config property from the config file or returns a default value (if provided).
## The property argument should be specified relative to the top-level "toolbox" property
## and should not include a leading "." character.
##
config_value() {
  local property="${1}"
  local default="${2:-}"
  if [[ -z "${default}" ]]; then
    jq -er ".toolbox.${property}" <<< "${config_json}"
  else
    jq -r ".toolbox.${property} // \"${default}\"" <<< "${config_json}"
  fi
}

##
## Returns the current AWS account ID.
##
current_aws_account_id() {
  aws sts get-caller-identity --query Account --output text
}

##
## Returns Toolbox version information.
##
toolbox_version_info() {
  local version
  version="$(toolbox_version)"
  echo "Toolbox version: ${version:-unknown}"
}

##
## Toolboxs Toolbox version semantic version string.
##
toolbox_version() {
  echo "${TOOLBOX_VERSION:-}"
}

##
## Upgrades Toolbox to the latest released version.
##
toolbox_upgrade() {
  local latest_version
  latest_version="$(curl -s "https://api.github.com/repos/seek-oss/toolbox/releases/latest" \
    | jq -r .tag_name \
    | sed 's/^v//')"

  curl -so toolbox.mk \
    "https://github.com/seek-oss/toolbox/releases/download/v${latest_version}/toolbox.mk"
}

# Common variables.
# shellcheck disable=SC2034
build_dir="$(config_value build_dir target)"
