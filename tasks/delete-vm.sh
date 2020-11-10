#!/usr/bin/env bash
# code_snippet delete-vm-script start bash

cat /var/version && echo ""
set -eux

vars_files_args=("")
for vf in ${VARS_FILES}; do
  vars_files_args+=("--vars-file ${vf}")
done

# '$timestamp' must be a literal, because envsubst uses it as a filter
# this allows us to avoid accidentally interpolating anything else.
# shellcheck disable=SC2016
input_state_file="$(echo "${STATE_FILE}" | env timestamp='*' envsubst '$timestamp')"

# '$timestamp' must be a literal, because envsubst uses it as a filter
# this allows us to avoid accidentally interpolating anything else.
# shellcheck disable=SC2016
output_file_name="$(echo "${STATE_FILE}" | env timestamp="$(date '+%Y%m%d.%-H%M.%S+%Z')" envsubst '$timestamp')"
generated_state_file_name="$(basename "${output_file_name}")"

# ${vars_files_args[@] needs to be globbed to split properly (SC2068)
# input_state_file need to be globbed (SC2086)
# shellcheck disable=SC2068,SC2086
om vm-lifecycle delete-vm \
  --config "config/${OPSMAN_CONFIG_FILE}" \
  --state-file state/${input_state_file} \
  ${vars_files_args[@]}

# input_state_file need to be globbed (SC2086)
# shellcheck disable=SC2086
cp state/${input_state_file} "generated-state/${generated_state_file_name}"

# code_snippet delete-vm-script end
