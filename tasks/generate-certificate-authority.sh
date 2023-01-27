#!/usr/bin/env bash
# code_snippet generate-certificate-authority-script start bash

cat /var/version && echo ""
set -eux

om --env env/"${ENV_FILE}" generate-certificate-authority --format json > CA.json
om interpolate -c CA.json --path /guid > new-ca/guid
# code_snippet generate-certificate-authority-script end
