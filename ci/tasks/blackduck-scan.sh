#!/bin/bash
set -eux

VERSION="$(cat version/version)"

# Extract release artifact (same shape submit-release-sboms uses)
mkdir -p platform-automation-product
tar -xf packaged-product/artifacts-*.tar.gz -C platform-automation-product

SCAN_ROOT="$PWD/platform-automation-product"

detect.sh \
  --blackduck.url="${BLACKDUCK_URL}" \
  --blackduck.api.token="${BLACKDUCK_API_TOKEN}" \
  --detect.project.name="${BLACKDUCK_PROJECT_NAME}" \
  --detect.project.version.name="${VERSION}" \
  --detect.source.path="${SCAN_ROOT}" \
  --detect.excluded.directories=.git,work,sboms,node_modules,ci \
  --detect.tools=SIGNATURE_SCAN \
  --detect.blackduck.signature.scanner.snippet.matching=SNIPPET_MATCHING \
  --detect.blackduck.signature.scanner.upload.source.mode=true \
  --detect.cleanup=false \
  --detect.blackduck.signature.scanner.verbose.mode=true \
  --logging.level.com.blackduck.integration=DEBUG
