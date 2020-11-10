#!/usr/bin/env bash
# code_snippet delete-vm-script start bash

cat /var/version && echo ""
set -eux

vars_files_args=("")
for vf in ${VARS_FILES}
do
  vars_files_args+=("--vars-file ${vf}")
done

# '$timestamp' must be a literal, because envsubst uses it as a filter
# this allows us to avoid accidentally interpolating anything else.
# shellcheck disable=SC2016
INPUT_STATE_FILE="$(echo "$STATE_FILE" | env timestamp='*' envsubst '$timestamp')"

# '$timestamp' must be a literal, because envsubst uses it as a filter
# this allows us to avoid accidentally interpolating anything else.
# shellcheck disable=SC2016
OUTPUT_FILE_NAME="$(echo "$STATE_FILE" | env timestamp="$(date '+%Y%m%d.%-H%M.%S+%Z')" envsubst '$timestamp')"
GENERATED_STATE_FILE_NAME="$(basename "$OUTPUT_FILE_NAME")"

# ${vars_files_args[@] needs to be globbed to split properly (SC2068)
# INPUT_STATE_FILE need to be globbed (SC2086)
# shellcheck disable=SC2068,SC2086
om vm-lifecycle delete-vm \
--config "config/${OPSMAN_CONFIG_FILE}" \
--state-file state/${INPUT_STATE_FILE} \
${vars_files_args[@]}

# INPUT_STATE_FILE need to be globbed (SC2086)
# shellcheck disable=SC2086
cp state/${INPUT_STATE_FILE} "generated-state/${GENERATED_STATE_FILE_NAME}"

# code_snippet delete-vm-script end
