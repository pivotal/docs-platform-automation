#!/usr/bin/env bash
# code_snippet apply-changes-script start bash

cat /var/version && echo ""
set -eux

flags=("--reattach")

if [ "${RECREATE}" == "true" ]; then
  flags+=("--recreate-vms")
fi

if [ "${IGNORE_WARNINGS}" == "true" ]; then
  flags+=("--ignore-warnings")
fi

if [ -n "${ERRAND_CONFIG_FILE}" ]; then
  flags+=("--config" "${ERRAND_CONFIG_FILE}")
fi

if [ -n "${SELECTIVE_DEPLOY_PRODUCTS}" ]; then
  # convert comma-separated variable into bash-native space-separated
  for PRODUCT in ${SELECTIVE_DEPLOY_PRODUCTS//,/ }; do
    flags+=("--product-name" "${PRODUCT}")
  done
fi

# ${flags[@] needs to be globbed to pass through properly
# shellcheck disable=SC2068
om --env env/"${ENV_FILE}" apply-changes \
  ${flags[@]}
# code_snippet apply-changes-script end
