#!/usr/bin/env bash
# code_snippet activate-certificate-authority-script start bash

cat /var/version && echo ""
set -eux

om --env env/"${ENV_FILE}" activate-certificate-authority --id "$(</new-ca/guid)"
# code_snippet activate-certificate-authority-script end
