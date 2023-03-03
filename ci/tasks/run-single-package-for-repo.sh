#!/bin/bash

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "$here/repo-package.sh"

set -euo pipefail

echo "$USERNAME" "$API_KEY" > apiKeyFile

build_repo_osm_manifest \
  "$REPO" \
  'Distributed - Calling Existing Classes' \
  "repo_osm_manifest.yaml"

declare -a osstp_dry_run_flag
if [ "${OSSTP_LOAD_DRY_RUN+defined}" = defined ] && [ "$OSSTP_LOAD_DRY_RUN" = 'true' ]; then
  osstp_dry_run_flag=('-n')
  echo "Dry run mode enabled for osstp-load"
fi

set -x

osstp-load.py \
  "${osstp_dry_run_flag[@]}" \
  -S "$OSM_ENVIRONMENT" \
  -R "$PRODUCT"/"$VERSION" \
  -A apiKeyFile \
  --other-dir '/' \
  -a 'Other' \
  -gn "$OSM_PACKAGE_GROUP_NAME" \
  -gv "$OSM_PACKAGE_GROUP_VERSION" \
  -gl 'norsk-to-osspi' \
  --noinput \
  "repo_osm_manifest.yaml"

set +x
