#!/usr/bin/env bash
# code_snippet configure-opsman-script start bash

cat /var/version && echo ""
om vm-lifecycle -v
set -eux

vars_files_args=("")
for vf in ${VARS_FILES}; do
  vars_files_args+=("--vars-file ${vf}")
done

# ${vars_files_args[@] needs to be globbed to pass through properly
# shellcheck disable=SC2068
om --env env/"${ENV_FILE}" configure-opsman \
  --config "config/${OPSMAN_CONFIG_FILE}" \
  ${vars_files_args[@]}

# code_snippet configure-opsman-script end
