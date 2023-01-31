#!/usr/bin/env bash
# code_snippet generate-certificate-authority-script start bash

cat /var/version && echo ""
set -eux

om --env env/"${ENV_FILE}" generate-certificate-authority
# code_snippet generate-certificate-authority-script end
