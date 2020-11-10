#!/usr/bin/env bash
# code_snippet configure-product-script start bash

cat /var/version && echo ""
set -eux

vars_files_args=("")
for vf in ${VARS_FILES}; do
  vars_files_args+=("--vars-file ${vf}")
done

ops_files_args=("")
for of in ${OPS_FILES}; do
  ops_files_args+=("--ops-file ${of}")
done

# ${vars_files_args[@] needs to be globbed to pass through properly
# ${ops_files_args[@] needs to be globbed to pass through properly
# shellcheck disable=SC2068
om --env env/"${ENV_FILE}" configure-product \
  --config "config/${CONFIG_FILE}" \
  ${vars_files_args[@]} \
  ${ops_files_args[@]}
# code_snippet configure-product-script end
