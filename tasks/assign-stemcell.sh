#!/usr/bin/env bash
# code_snippet assign-stemcell-script start bash

cat /var/version && echo ""
set -eux
om --env env/"${ENV_FILE}" assign-stemcell \
  --config config/"${CONFIG_FILE}"
# code_snippet assign-stemcell-script end
