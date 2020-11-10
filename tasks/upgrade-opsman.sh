#!/usr/bin/env bash
# code_snippet upgrade-opsman-script start bash

cat /var/version && echo ""
om vm-lifecycle -v
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

export IMAGE_FILE
IMAGE_FILE="$(find image/*.{yml,ova,raw} 2>/dev/null | head -n1)"

if [ -z "$IMAGE_FILE" ]; then
  echo "No image file found in image input."
  echo "Contents of image input:"
  ls -al image
  exit 1
fi

# ${vars_files_args[@] needs to be globbed to split properly (SC2068)
# INSTALLATION_FILE and INPUT_STATE_FILE need to be globbed (SC2086)
# shellcheck disable=SC2068,SC2086
om vm-lifecycle upgrade-opsman \
--config "config/${OPSMAN_CONFIG_FILE}" \
--image-file "${IMAGE_FILE}"  \
--state-file state/${INPUT_STATE_FILE} \
--installation installation/${INSTALLATION_FILE} \
--env-file env/"${ENV_FILE}" \
${vars_files_args[@]}

# INPUT_STATE_FILE could have a "*", and needs to be expanded by the shell
# shellcheck disable=SC2086
cp state/${INPUT_STATE_FILE} "generated-state/${GENERATED_STATE_FILE_NAME}"

# ${vars_files_args[@] needs to be globbed to pass through properly
# shellcheck disable=SC2068
om --env env/"${ENV_FILE}" configure-opsman \
--config "config/${OPSMAN_CONFIG_FILE}" \
${vars_files_args[@]}

# code_snippet upgrade-opsman-script end
