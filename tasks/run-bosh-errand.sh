#!/usr/bin/env bash
# code_snippet run-bosh-errand-script start bash
cat /var/version && echo ""
set -eux

# shellcheck source=./setup-bosh-env.sh
source ./platform-automation-tasks/tasks/setup-bosh-env.sh

# ensure desired product is actually deployed, provide list of errands
{ echo "About to try to run your errand." ; } 2> /dev/null
{ echo "If it doesn't work, here is a list of errand names:" ; } 2> /dev/null

om --env "env/${ENV_FILE}" errands --product-name "${PRODUCT_NAME}"
set -x

# determine deployment name, including generated id
staged_products=$(mktemp)
om --env "env/${ENV_FILE}" curl -p /api/v0/staged/products  > "${staged_products}"
installation="$(bosh int "${staged_products}" --path "/type=${PRODUCT_NAME}/installation_name")"


if [ -z "${INSTANCE}" ]; then
  bosh -d "${installation}" run-errand "${ERRAND_NAME}"
else
  bosh -d "${installation}" run-errand "${ERRAND_NAME}" --instance "${INSTANCE}"
fi
# code_snippet run-bosh-errand-script end
