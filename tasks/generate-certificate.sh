#!/usr/bin/env bash
# code_snippet generate-certificate-script start bash

cat /var/version && echo ""
set -eux

om --env env/"${ENV_FILE}" generate-certificate -d "${DOMAINS}" > /tmp/certificate.json
om interpolate -c /tmp/certificate.json --path /certificate > certificate/certificate.pem
om interpolate -c /tmp/certificate.json --path /key > certificate/privatekey.pem
# code_snippet generate-certificate-script end
