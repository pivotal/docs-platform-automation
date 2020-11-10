#!/usr/bin/env bash
# code_snippet apply-director-changes-script start bash

cat /var/version && echo ""
set -eux

flags=("--skip-deploy-products" "--reattach")

if [ "${IGNORE_WARNINGS}" == "true" ]; then
  flags+=("--ignore-warnings")
fi

# ${flags[@] needs to be globbed to pass through properly
# shellcheck disable=SC2068
om --env env/"${ENV_FILE}" apply-changes \
  ${flags[@]}
# code_snippet apply-director-changes-script end
