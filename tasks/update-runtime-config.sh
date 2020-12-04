#!/usr/bin/env bash
# code_snippet update-runtime-config-script start bash

cat /var/version && echo ""
set -eu

if [ -z "${NAME}" ]; then
  { printf "\nError: 'NAME' parameter is required"; } 2>/dev/null
  exit 1
fi

# shellcheck source=./setup-bosh-env.sh
source ./platform-automation-tasks/tasks/setup-bosh-env.sh
set -x

if [ -e "releases/" ]; then
  # $RELEASES_GLOB needs to be globbed to pass through properly
  # shellcheck disable=SC2086
  release_files="$(find releases/${RELEASES_GLOB} 2>/dev/null)"
  if [ -n "${release_files}" ]; then
    for rf in ${release_files}; do
      bosh upload-release "${rf}"
    done
  fi
fi

vars_files_args=("")
for vf in ${VARS_FILES}; do
  vars_files_args+=("--vars-file ${vf}")
done

# ${vars_files_args[@] needs to be globbed to pass through properly
# shellcheck disable=SC2068
bosh -n update-config \
  --type runtime \
  --name "${NAME}" \
  config/"${CONFIG_FILE}" \
  ${vars_files_args[@]}

# code_snippet update-runtime-config-script end
