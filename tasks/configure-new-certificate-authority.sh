#!/usr/bin/env bash
# code_snippet configure-new-certificate-authority-script start bash

cat /var/version && echo ""
set -eux

if [[ -f "certs/certificate.pem" && -f "certs/privatekey.pem" ]]; then
  om --env env/"${ENV_FILE}" create-certificate-authority \
   --format json \
   --certificate-pem "$(<certs/certificate.pem)" \
   --private-key-pem "$(<certs/privatekey.pem)"
else
  om --env env/"${ENV_FILE}" generate-certificate-authority
fi
# code_snippet configure-new-certificate-authority-script end
