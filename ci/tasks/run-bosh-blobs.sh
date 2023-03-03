#!/bin/bash

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "$here/bosh.sh"

set -euo pipefail

echo "$USERNAME" "$API_KEY" > apiKeyFile

source "$here/add-key.sh"

if [ "${BLOB_SOURCES_CONFIG+defined}" = defined ] && [ -n "$BLOB_SOURCES_CONFIG" ]; then
  printf "%s" "$BLOB_SOURCES_CONFIG" > '/blob_sources.yaml'
  printf "Using BLOB_SOURCES_CONFIG:\n%s\n\n" "$BLOB_SOURCES_CONFIG"
else
  echo "BLOB_SOURCES_CONFIG not set" >&2
  return 1
fi

pushd "$REPO"
  if [ "${PREPARE+defined}" = defined ] && [ -n "$PREPARE" ]; then
    printf "Running Prepare Command:\n%s\n\n" "$PREPARE"
    bash -c "$PREPARE"
  fi
popd

build_blobs_osm_manifest \
  "$REPO/config/blobs.yml" \
  '/blob_sources.yaml' \
  'blobs_osm_manifest.yaml'

number_of_objects=$(yq length blobs_osm_manifest.yaml)

if [ "$number_of_objects" -eq 0 ]; then
  echo "Blobs manifest empty, exiting..."
  exit 0
fi

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
  "blobs_osm_manifest.yaml"

set +x
