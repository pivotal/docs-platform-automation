#!/usr/bin/env bash
# code_snippet delete-certificate-authority start bash

cat /var/version && echo ""
set -eux

om --env env/"${ENV_FILE}" delete-certificate-authority --all-inactive
# code_snippet delete-certificate-authority end
