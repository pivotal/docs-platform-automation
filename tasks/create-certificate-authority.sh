#!/usr/bin/env bash
# code_snippet create-certificate-authority start bash

cat /var/version && echo ""
set -eux

om --env env/"${ENV_FILE}" create-certificate-authority --certificate-pem "${CERTIFICATE_PEM}" --private-key-pem "${PRIVATE_KEY_PEM}"
# code_snippet create-certificate-authority end
