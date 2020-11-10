#!/usr/bin/env bash
# code_snippet upload-and-stage-product-script start bash

cat /var/version && echo ""
set -eux

if [ -z "${CONFIG_FILE}" ]; then
  om --env env/"${ENV_FILE}" upload-product \
    --product product/*.pivotal
else
  om --env env/"${ENV_FILE}" upload-product \
    --product product/*.pivotal --config "config/${CONFIG_FILE}"
fi

product_name="$(om product-metadata \
  --product-path product/*.pivotal \
  --product-name)"
product_version="$(om product-metadata \
  --product-path product/*.pivotal \
  --product-version)"

om --env env/"${ENV_FILE}" stage-product \
  --product-name "${product_name}" \
  --product-version "${product_version}"
# code_snippet upload-and-stage-product-script end
