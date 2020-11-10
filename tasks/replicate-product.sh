#!/usr/bin/env bash
# code_snippet replicate-product-script start bash
cat /var/version && echo ""
set -eux

if [[ -z "${REPLICATED_NAME}" ]]; then
  echo "REPLICATED_NAME is a required param"
  exit 1
fi

iso-replicator -name "${REPLICATED_NAME}" \
  -output "replicated-product/${REPLICATED_NAME}.pivotal" \
  -path product/*.pivotal
# code_snippet replicate-product-script end bash
