#!/usr/bin/env bash
# code_snippet generate-certificate-authority start bash

cat /var/version && echo ""
set -eux

om --env env/"${ENV_FILE}" generate-certificate-authority --json > /tmp/CA.json
om interpolate -c /tmp/CA --path /guid > new-ca-guid
    # | jq .guid > new-ca/guid
    # | awk 'NR==4 { print $2 }' > new-ca/guid
    # | grep 'BEGIN CERTIFICATE' | awk '{ print $2 }' > new-ca/guid
# code_snippet generate-certificate-authority end
