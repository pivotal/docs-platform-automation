#!/usr/bin/env bash
# code_snippet prepare-tasks-with-secrets-script start bash

cat /var/version && echo ""
set -eux

config_file_args=("")
for cp in ${CONFIG_PATHS}; do
  config_file_args+=("--config-dir ${cp}")
done

if [[ -d "vars" && -z "${VARS_PATHS}" ]]; then
  VARS_PATHS=vars
fi

vars_file_args=("")
for vf in ${VARS_PATHS}; do
  vars_file_args+=("--var-dir ${vf}")
done

# ${config_file_args[@] needs to be globbed to pass through properly
# ${vars_paths_args[@] needs to be globbed to pass through properly
# shellcheck disable=SC2068
om vm-lifecycle prepare-tasks-with-secrets \
  --task-dir tasks \
  ${config_file_args[@]} \
  ${vars_file_args[@]}

# code_snippet prepare-tasks-with-secrets-script end
