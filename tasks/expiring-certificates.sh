#!/usr/bin/env bash
# code_snippet expiring-certificates-script start bash

cat /var/version && echo ""
set -eux

if [ -z "${EXPIRES_WITHIN}" ]; then
  echo "The parameter EXPIRES_WITHIN is required"
  exit 1
fi

om --env env/"${ENV_FILE}" expiring-certificates \
  --expires-within "${EXPIRES_WITHIN}"
# code_snippet expiring-certificates-script end
