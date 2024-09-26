#!/usr/bin/env bash

set -euo pipefail

WORKING_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

which ytt || (
  echo "This requires ytt to be installed"
  exit 1
)
which fly || (
  echo "This requires fly to be installed"
  exit 1
)

echo "Setting Docs CI pipeline on TPE CI..."
fly -t tpe-ci sp -p platform-automation-docs -c <(ytt -f "$WORKING_DIR/../docs/") \
  --check-creds

echo "Setting OSSPI pipeline on TPE CI..."
fly -t tpe-ci sp -p osspi-platform-automation -c <(ytt -f "$WORKING_DIR/../osspi-tpe-ci/") \
  --check-creds
