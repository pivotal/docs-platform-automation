#!/usr/bin/env bash
# code_snippet generate-certificate start bash

cat /var/version && echo ""
set -eux

om --env env/"${ENV_FILE}" generate-certificate -d "${DOMAINS}" > /tmp/certificate.json
om interpolate -c /tmp/certificate.json --path /certificate > certificate.pem
om interpolate -c /tmp/certificate.json --path /key > privatekey.pem
# code_snippet generate-certificate end
