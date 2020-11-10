#!/usr/bin/env bash
# code_snippet staged-config-script start bash

cat /var/version && echo ""
set -eux

flag=$(
  if "${SUBSTITUTE_CREDENTIALS_WITH_PLACEHOLDERS}"; then
    echo '--include-placeholders'
  else
    echo '--include-credentials'
  fi
)

om --env env/"${ENV_FILE}" staged-config \
  --product-name "${PRODUCT_NAME}" \
  "${flag}" >generated-config/"${PRODUCT_NAME}".yml
# code_snippet staged-config-script end
