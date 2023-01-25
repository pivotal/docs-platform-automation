#!/usr/bin/env bash
# code_snippet create-certificate-authority start bash

cat /var/version && echo ""
set -eux

om --env env/"${ENV_FILE}" create-certificate-authority \
   --format json \
   --certificate-pem "$(<certs/certificate.pem)" \
   --private-key-pem "$(<certs/privatekey.pem)" > CA.json
om interpolate -c CA.json --path /guid > new-ca/guid
# code_snippet create-certificate-authority end
