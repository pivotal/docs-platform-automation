#!/bin/bash

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

set -euo pipefail

echo "$USERNAME" "$API_KEY" > apiKeyFile

url_list="$REPO/$URL_LIST_FILE"

ruby "$here/download-url-list.rb" \
  "$url_list" \
  'Distributed - Calling Existing Classes' \
  'url_list_osm_manifest.yaml'

if [ ! -s url_list_osm_manifest.yaml ]; then
  echo "Manifest is empty, assume no packages, exiting..."
  exit
fi

declare -a osstp_dry_run_flag
if [ "${OSSTP_LOAD_DRY_RUN+defined}" = defined ] && [ "$OSSTP_LOAD_DRY_RUN" = 'true' ]; then
  osstp_dry_run_flag=('-n')
  echo "Dry run mode enabled for osstp-load"
fi

declare -a osstp_force_load_flag
if [ "${OSSTP_LOAD_FORCE_LOAD+defined}" = defined ] && [ "$OSSTP_LOAD_FORCE_LOAD" = 'true' ]; then
  osstp_force_load_flag=('-F')
  echo "Force load enabled for osstp-load"
fi

set -x

osstp-load.py \
  "${osstp_dry_run_flag[@]}" \
  "${osstp_force_load_flag[@]}" \
  -S "$OSM_ENVIRONMENT" \
  -R "$PRODUCT"/"$VERSION" \
  -A apiKeyFile \
  --other-dir '/' \
  -a 'Other' \
  -gn "$OSM_PACKAGE_GROUP_NAME" \
  -gv "$OSM_PACKAGE_GROUP_VERSION" \
  -gl 'norsk-to-osspi' \
  --noinput \
  "url_list_osm_manifest.yaml"

set +x
