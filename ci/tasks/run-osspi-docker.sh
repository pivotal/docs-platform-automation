#!/usr/bin/env bash
set -euo pipefail

echo "Running OSSPI with CT_TRACKER_OS '${CT_TRACKER_OS}'"

#Pass in append
declare -a baseos_append_flag
if [ "${APPEND+defined}" = defined ] && [ "$APPEND" = 'true' ]; then
  baseos_append_flag=('--baseos-append')
  echo "Using --baseos-append flag"
fi

declare -a ignore_package_flag
if [ "${OSSPI_IGNORE_RULES+defined}" = defined ] && [ -n "$OSSPI_IGNORE_RULES" ]; then
  printf "%s" "$OSSPI_IGNORE_RULES" > "/ignore-rules.yaml"
  ignore_package_flag=("--ignore-package-file" "/ignore-rules.yaml")
  printf "Using configured OSSPI_IGNORE_RULES:\n%s\n\n" "$OSSPI_IGNORE_RULES"
fi

declare -a image_flag
if [ "${TAR_PATH+defined}" = defined ] && [ -n "$TAR_PATH" ]; then
  echo "Using tar path: '$TAR_PATH'"
  image_flag=("--image-tar" "$TAR_PATH")
else
  echo "Using image: '$IMAGE:$TAG'"
  image_flag=("--image" "$IMAGE:$TAG")
fi

set -x
osspi scan docker \
  "${ignore_package_flag[@]}" \
  "${image_flag[@]}" \
  --format manifest \
  --output-dir docker_scan
set +x

number_of_objects=$(yq length docker_scan/osspi_docker_detect_result.manifest)

if [ "$number_of_objects" -eq 0 ]; then
  echo "Scan report empty, exiting..."
  exit 0
fi