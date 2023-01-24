#!/usr/bin/env bash
# code_snippet create-certificate-authority start bash

cat /var/version && echo ""
set -eux

om --env env/"${ENV_FILE}" create-certificate-authority --certificate-pem cert.pem --private-key-pem privatekey.pem
# code_snippet create-certificate-authority end
