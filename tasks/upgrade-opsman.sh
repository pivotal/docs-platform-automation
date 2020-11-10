#!/usr/bin/env bash
# code_snippet upgrade-opsman-script start bash

cat /var/version && echo ""
om -v
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

export IMAGE_FILE
IMAGE_FILE="$(find image/*.{yml,ova,raw} 2>/dev/null | head -n1)"

if [ -z "${IMAGE_FILE}" ]; then
  echo "No image file found in image input."
  echo "Contents of image input:"
  ls -al image
  exit 1
fi

# ${vars_files_args[@] needs to be globbed to split properly (SC2068)
# INSTALLATION_FILE and input_state_file need to be globbed (SC2086)
# shellcheck disable=SC2068,SC2086
om vm-lifecycle upgrade-opsman \
  --config "config/${OPSMAN_CONFIG_FILE}" \
  --image-file "${IMAGE_FILE}" \
  --state-file state/${input_state_file} \
  --installation installation/${INSTALLATION_FILE} \
  --env-file env/"${ENV_FILE}" \
  ${vars_files_args[@]}

# input_state_file could have a "*", and needs to be expanded by the shell
# shellcheck disable=SC2086
cp state/${input_state_file} "generated-state/${generated_state_file_name}"

# ${vars_files_args[@] needs to be globbed to pass through properly
# shellcheck disable=SC2068
om --env env/"${ENV_FILE}" configure-opsman \
  --config "config/${OPSMAN_CONFIG_FILE}" \
  ${vars_files_args[@]}

# code_snippet upgrade-opsman-script end
