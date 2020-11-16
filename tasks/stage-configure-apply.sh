#!/usr/bin/env bash
# code_snippet stage-configure-apply-script start bash

cat /var/version && echo ""
set -eux

platform-automation-tasks/tasks/check-pending-changes.sh

if ls stemcell/* 1>/dev/null 2>&1; then
  CONFIG_FILE="${UPLOAD_STEMCELL_CONFIG_FILE}" platform-automation-tasks/tasks/upload-stemcell.sh
fi

CONFIG_FILE="${STAGE_PRODUCT_CONFIG_FILE}" platform-automation-tasks/tasks/stage-product.sh

if [ -n "${ASSIGN_STEMCELL_CONFIG_FILE}" ]; then
  om --env env/"${ENV_FILE}" assign-stemcell \
  --config assign-stemcell-config/"$ASSIGN_STEMCELL_CONFIG_FILE"
fi

platform-automation-tasks/tasks/configure-product.sh

product_file="$(find product/*.pivotal 2>/dev/null | head -n1)"
if [ -f "${product_file}" ]; then
  if [ -n "${STAGE_PRODUCT_CONFIG_FILE}" ]; then
    { printf "\nError: Cannot use both product file and 'STAGE_PRODUCT_CONFIG_FILE'"; } 2>/dev/null
    { printf "\nTo fix: Either remove the product input or unset the 'STAGE_PRODUCT_CONFIG_FILE' param"; } 2>/dev/null
    exit 1
  fi

  product_name="$(om product-metadata \
    --product-path product/*.pivotal \
    --product-name)"
else
  if [ -z "${STAGE_PRODUCT_CONFIG_FILE}" ]; then
    { printf "\nError: Both 'STAGE_PRODUCT_CONFIG_FILE' and the config input OR just the product input must be provided"; } 2>/dev/null
    exit 1
  fi

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
  product_name="$(om interpolate \
    -c config/"$STAGE_PRODUCT_CONFIG_FILE" \
    --path /product-name \
    ${vars_files_args[@]} \
    ${ops_files_args[@]}
  )"
fi

flags=()

if [ "${RECREATE}" == "true" ]; then
  flags+=("--recreate-vms")
fi

if [ "${IGNORE_WARNINGS}" == "true" ]; then
  flags+=("--ignore-warnings")
fi

if [ -n "${ERRAND_CONFIG_FILE}" ]; then
  flags+=("--config" "${ERRAND_CONFIG_FILE}")
fi

# ${flags[@] needs to be globbed to pass through properly
# shellcheck disable=SC2068
om --env env/"${ENV_FILE}" \
  apply-changes \
  --product-name "${product_name}" \
  ${flags[@]}
# code_snippet stage-configure-apply-script end
