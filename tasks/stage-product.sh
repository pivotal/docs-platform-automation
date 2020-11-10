#!/usr/bin/env bash
# code_snippet stage-product-script start bash

cat /var/version && echo ""
set -eux

PRODUCT_FILE="$(find product/*.pivotal 2>/dev/null | head -n1)"
if [ -f "$PRODUCT_FILE" ]; then
  if [ -n "$CONFIG_FILE" ]; then
    { printf "\nError: Cannot use both product file and 'CONFIG_FILE'"; } 2> /dev/null
    { printf "\nTo fix: If using 'stage-product', either remove the product input or unset the 'CONFIG_FILE' param"; } 2> /dev/null
    { printf "\nTo fix: If using 'stage-configure-apply', either remove the product input or unset the 'STAGE_PRODUCT_CONFIG_FILE' param"; } 2> /dev/null
    exit 1
  fi

  PRODUCT_METADATA_NAME="$(om product-metadata \
  --product-path "${PRODUCT_FILE}" \
  --product-name)"

  PRODUCT_METADATA_VERSION="$(om product-metadata \
  --product-path "${PRODUCT_FILE}" \
  --product-version)"
    
  om --env env/"${ENV_FILE}" stage-product \
   --product-name "$PRODUCT_METADATA_NAME" \
   --product-version "$PRODUCT_METADATA_VERSION"
else
  if [ -z "$CONFIG_FILE" ]; then
    { printf "\nError: If using 'stage-product', both 'CONFIG_FILE' and the config input OR just the product input must be provided"; } 2> /dev/null
    { printf "\nError: If using 'stage-configure-apply', both 'STAGE_PRODUCT_CONFIG_FILE' and the config input OR just the product input must be provided"; } 2> /dev/null
    exit 1
  fi

  om --env env/"${ENV_FILE}" stage-product \
   --config config/"$CONFIG_FILE"
fi


# code_snippet stage-product-script end
