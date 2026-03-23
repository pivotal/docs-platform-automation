#!/usr/bin/env bash
# code_snippet assign-kubernetes-distribution-script start bash

cat /var/version && echo ""
set -eux
om --env env/"${ENV_FILE}" assign-kubernetes-distribution \
  --config config/"${CONFIG_FILE}"
# code_snippet assign-kubernetes-distribution-script end
