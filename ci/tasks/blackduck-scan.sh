#!/bin/bash
# Run Black Duck Detect SIGNATURE_SCAN against the packaged release artifact.
# Invoked by ci/tasks/blackduck-scan.yml as a stage between submit-release-sboms-*
# and publish-release-* in the minor-bump and patch-bump pipeline groups.

usage() {
  cat <<'EOF'
blackduck-scan.sh — run Black Duck Detect SIGNATURE_SCAN on the release artifact.

Usage:
  blackduck-scan.sh [--help|-h]

Configuration is read from environment variables and Concourse inputs:

  Required env vars (provided by ci/tasks/blackduck-scan.yml):
    BLACKDUCK_URL            Black Duck server URL
    BLACKDUCK_API_TOKEN      BD API token (passed straight to detect.sh)
    BLACKDUCK_PROJECT_NAME   Detect project name

  Required inputs (Concourse mount points / files at $PWD):
    version/version                       Plain text current version
    packaged-product/artifacts-*.tar.gz   Release artifact to scan

The scan runs SIGNATURE_SCAN with snippet matching, source upload mode, verbose
output, and DEBUG logging on com.blackduck.integration. Detect itself accepts
many --detect.* / --blackduck.* flags; see https://documentation.blackduck.com.
EOF
}

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
  '')
    ;;
  *)
    echo "Unknown argument: $1" >&2
    usage >&2
    exit 2
    ;;
esac

set -eux

VERSION="$(cat version/version)"

# Extract release artifact (same shape submit-release-sboms uses).
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
