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

if [ -n "${PRODUCTS}" ]; then
  IFS=':' read -ra product_names <<< "${PRODUCTS}"
  for product_name in "${product_names[@]}"; do
    flags+=("--product-name" "${product_name}")
  done
fi

# ${flags[@] needs to be globbed to pass through properly
# shellcheck disable=SC2068
om --env env/"${ENV_FILE}" apply-changes \
  ${flags[@]}
# code_snippet apply-changes-script end
