#!/usr/bin/env bash
# code_snippet assign-multi-stemcell-script start bash

cat /var/version && echo ""
set -eux
om --env env/"${ENV_FILE}" assign-multi-stemcell \
  --config config/"${CONFIG_FILE}"
# code_snippet assign-multi-stemcell-script end
