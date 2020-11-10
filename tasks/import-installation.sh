#!/usr/bin/env bash
# code_snippet import-installation-script start bash

cat /var/version && echo ""
set -eux

# INSTALLATION_FILE needs to be globbed
# shellcheck disable=SC2086
om --env env/"${ENV_FILE}" --skip-ssl-validation import-installation \
  --installation installation/${INSTALLATION_FILE}
# code_snippet import-installation-script end
