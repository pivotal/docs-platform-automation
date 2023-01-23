#!/usr/bin/env bash
# code_snippet regenerate-certificates start bash

cat /var/version && echo ""
set -eux

om --env env/"${ENV_FILE}" regenerate-certificates
# code_snippet regenerate-certificates end
