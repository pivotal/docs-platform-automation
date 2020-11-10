#!/usr/bin/env bash
# code_snippet pre-deploy-check-script start bash

cat /var/version && echo ""
set -eux

om --env env/"${ENV_FILE}" pre-deploy-check
# code_snippet pre-deploy-check-script end
