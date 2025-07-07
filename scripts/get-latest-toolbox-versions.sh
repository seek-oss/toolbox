#!/bin/bash

# Checks latests versions of different packages

bold=$(tput bold)
normal=$(tput sgr0)

VERSIONS_TO_CHECK_JSON='[
  { "name": "hashicorp/terraform", "url": "https://api.github.com/repos/<name>/releases/latest" },
  { "name": "koalaman/shellcheck", "url": "https://api.github.com/repos/<name>/releases/latest" },
  { "name": "mvdan/sh", "url": "https://api.github.com/repos/<name>/releases/latest" },
  { "name": "mikefarah/yq", "url": "https://api.github.com/repos/<name>/releases/latest" },
  { "name": "seek-oss/schma", "url": "https://api.github.com/repos/<name>/releases/latest" },
  { "name": "snyk/cli", "url": "https://api.github.com/repos/<name>/releases/latest" },
  { "name": "buildkite/agent", "url": "https://api.github.com/repos/<name>/releases/latest" }
]'

echo "$VERSIONS_TO_CHECK_JSON" | jq -c '.[]' | while read -r i; do
  # do stuff with $i
  NAME="$(echo "$i" | jq -r '.name')"
  URL="$(echo "$i" | jq -r '.url')"

  if grep -q "api.github.com" <<< "$URL"; then
    URL="${URL//<name>/$NAME}"
    GITHUB_TAG=$(curl -s "$URL" | jq -r '.tag_name')
    echo "GITHUB - $NAME: ${bold}$GITHUB_TAG${normal}"
  elif grep -q "npmjs.com" <<< "$URL"; then
    URL="${URL//<name>/$NAME}"
    NPM_TAG=$(curl -s "$URL" | jq -r '.version')
    echo "NPNJS  - $NAME: ${bold}$NPM_TAG${normal}"
  else
    echo "Unsupported URL"
  fi
done
