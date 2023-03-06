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

echo "Getting ct tracker master package if exists. If not, create it and return the ID."
MASTER_PACKAGE_URL="$ENDPOINT/api/public/v1/master_package/?name=ct-tracker-$CT_TRACKER_OS&version=none&repository=Other&resolution=APPROVED"
echo "MASTER_PACKAGE_URL: '${MASTER_PACKAGE_URL}'"
MASTER_PACKAGE_REQUEST=$(curl -H "Authorization: ApiKey $USERNAME:$API_KEY" "$MASTER_PACKAGE_URL")
if [ $(echo "$MASTER_PACKAGE_REQUEST" | jq .count) == 1 ]; then
  echo "Master package found"
  MASTER_PACKAGE_ID=$(echo "$MASTER_PACKAGE_REQUEST" | jq ".results[].id")
else
  echo "Master package not found. Creating package."
  CT_TRACKER_DATA_PAYLOAD="{\"name\":\"ct-tracker-${CT_TRACKER_OS}\",\"version\":\"none\",\"repository\":\"Other\"}"
  echo "CT_TRACKER_DATA_PAYLOAD: '${CT_TRACKER_DATA_PAYLOAD}'"
  MASTER_PACKAGE_REQUEST=$(curl --request POST -H "Authorization: ApiKey $USERNAME:$API_KEY" --data "$CT_TRACKER_DATA_PAYLOAD" "$ENDPOINT/api/public/v1/master_package/")
  MASTER_PACKAGE_ID=$(echo "$MASTER_PACKAGE_REQUEST" | jq ".results[].id")
fi
echo "MASTER_PACKAGE_ID: '${MASTER_PACKAGE_ID}'"

echo "Attaching the ct-tracker-${CT_TRACKER_OS} master package to the osm release ID and returning the ct tracker ID."
CT_TRACKER_REQUEST=$(curl --request POST -H "Authorization: ApiKey $USERNAME:$API_KEY" -H "Content-Type: application/json" --data "{\"release_id\":\"$RELEASE_ID\",\"master_package_id\":\"$MASTER_PACKAGE_ID\",\"interaction_type_id\":[\"1\"],\"modified\":\"No\"}" "$ENDPOINT/api/public/v1/package/")
echo "CT_TRACKER_REQUEST results: '${CT_TRACKER_REQUEST}'"
if [ $(echo "$CT_TRACKER_REQUEST" | jq -r ".err_code") == 40904  ]; then
  ERROR_MESSAGE=$(echo "$CT_TRACKER_REQUEST" | jq -r ".err_msg")
  CT_TRACKER_ID=$(echo ${ERROR_MESSAGE##* })
else
  CT_TRACKER_ID=$(echo "$CT_TRACKER_REQUEST" | jq ".id")
fi
echo "CT_TRACKER_ID: '${CT_TRACKER_ID}'"

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