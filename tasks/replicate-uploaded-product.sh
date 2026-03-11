#!/usr/bin/env bash
# code_snippet replicate-uploaded-product-script start bash

cat /var/version && echo ""
set -eux

product_file="$(find product/*.pivotal 2>/dev/null | head -n1)"
if [ -f "${product_file}" ]; then
  if [ -n "${CONFIG_FILE}" ]; then
    { printf "\nError: Cannot use both product file and 'CONFIG_FILE'"; } 2>/dev/null
    { printf "\nTo fix: Either remove the product input or unset the 'CONFIG_FILE' param"; } 2>/dev/null
    exit 1
  fi

  if [[ -z "${REPLICA_SUFFIX}" ]]; then
    echo "REPLICA_SUFFIX is required when using the product input"
    exit 1
  fi

  product_metadata_name="$(om product-metadata \
    --product-path "${product_file}" \
    --product-name)"

  product_metadata_version="$(om product-metadata \
    --product-path "${product_file}" \
    --product-version)"

  om --env env/"${ENV_FILE}" replicate-product \
    --product-name "${product_metadata_name}" \
    --product-version "${product_metadata_version}" \
    --replica-suffix "${REPLICA_SUFFIX}"
else
  if [ -z "${CONFIG_FILE}" ]; then
    { printf "\nError: Either the product input or CONFIG_FILE (with the config input) must be provided"; } 2>/dev/null
    exit 1
  fi

  om --env env/"${ENV_FILE}" replicate-product \
    --config config/"${CONFIG_FILE}"
fi

# code_snippet replicate-uploaded-product-script end bash
