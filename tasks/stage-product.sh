#!/usr/bin/env bash
# code_snippet stage-product-script start bash

cat /var/version && echo ""
set -eux

product_file="$(find product/*.pivotal 2>/dev/null | head -n1)"
if [ -f "${product_file}" ]; then
  if [ -n "${CONFIG_FILE}" ]; then
    { printf "\nError: Cannot use both product file and 'CONFIG_FILE'"; } 2>/dev/null
    { printf "\nTo fix: If using 'stage-product', either remove the product input or unset the 'CONFIG_FILE' param"; } 2>/dev/null
    { printf "\nTo fix: If using 'stage-configure-apply', either remove the product input or unset the 'STAGE_PRODUCT_CONFIG_FILE' param"; } 2>/dev/null
    exit 1
  fi

  product_metadata_name="$(om product-metadata \
    --product-path "${product_file}" \
    --product-name)"

  product_metadata_version="$(om product-metadata \
    --product-path "${product_file}" \
    --product-version)"

  om --env env/"${ENV_FILE}" stage-product \
    --product-name "${product_metadata_name}" \
    --product-version "${product_metadata_version}"
else
  if [ -z "${CONFIG_FILE}" ]; then
    { printf "\nError: If using 'stage-product', both 'CONFIG_FILE' and the config input OR just the product input must be provided"; } 2>/dev/null
    { printf "\nError: If using 'stage-configure-apply', both 'STAGE_PRODUCT_CONFIG_FILE' and the config input OR just the product input must be provided"; } 2>/dev/null
    exit 1
  fi

  om --env env/"${ENV_FILE}" stage-product \
    --config config/"${CONFIG_FILE}"
fi

# code_snippet stage-product-script end
