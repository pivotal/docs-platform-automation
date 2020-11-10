#!/usr/bin/env bash
# code_snippet upload-product-script start bash

cat /var/version && echo ""
set -eux

export OPTIONAL_CONFIG_FLAG=""
if [ -n "${CONFIG_FILE}" ]; then
  export OPTIONAL_CONFIG_FLAG="--config config/${CONFIG_FILE}"
fi
# shellcheck disable=SC2086
om --env env/"${ENV_FILE}" upload-product \
  --product product/*.pivotal \
  ${OPTIONAL_CONFIG_FLAG}
# code_snippet upload-product-script end
