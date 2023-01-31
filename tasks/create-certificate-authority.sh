#!/usr/bin/env bash
# code_snippet create-certificate-authority-script start bash

cat /var/version && echo ""
set -eux

om --env env/"${ENV_FILE}" create-certificate-authority \
   --format json \
   --certificate-pem "$(<certs/certificate.pem)" \
   --private-key-pem "$(<certs/privatekey.pem)"
# code_snippet create-certificate-authority-script end
