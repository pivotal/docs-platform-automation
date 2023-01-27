#!/usr/bin/env bash
# code_snippet clean-certificates-script start bash

cat /var/version && echo ""
set -eux

local inactive_ca_guid="$(om --env env/"${ENV_FILE}"  certificate-authorities -- -f json | jq -r '.[] | select(.active == false).guid')"

om --env env/"${ENV_FILE}" delete-certificate-authority --id "$inactive_ca_guid"
# code_snippet clean-certificates-script end
