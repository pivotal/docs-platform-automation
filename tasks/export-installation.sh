#!/usr/bin/env bash
# code_snippet export-installation-script start bash

cat /var/version && echo ""
set -eux

timestamp="$(date '+%Y%m%d.%-H%M.%S+%Z')"
export timestamp

# '$timestamp' must be a literal, because envsubst uses it as a filter
# this allows us to avoid accidentally interpolating anything else.
# shellcheck disable=SC2016
output_file_name="$(echo "${INSTALLATION_FILE}" | envsubst '$timestamp')"

om --env env/"${ENV_FILE}" export-installation \
  --output-file installation/"${output_file_name}"
# code_snippet export-installation-script end
