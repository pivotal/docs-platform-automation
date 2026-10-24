#!/usr/bin/env bash

set -euo pipefail

WORKING_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

TARGET=${1:-platform-automation}

# Only for an exception release, i.e. one that has to bypass the release train:
# `EXCEPTION=true ci/scripts/update-ci.sh` makes publish-release-* pass
# `--exception` to `rmt release-create`. Agree it with your TPM first, and
# re-run this script without EXCEPTION afterwards so the next release goes out
# on its normal train.
# See https://github.gwd.broadcom.net/TNZ/gormt?tab=readme-ov-file#--exception-flag
EXCEPTION=${EXCEPTION:-false}

which ytt || (
  echo "This requires ytt to be installed"
  exit 1
)
which fly || (
  echo "This requires fly to be installed"
  exit 1
)

echo "Setting CI pipeline..."

fly -t $TARGET sp -p platform-automation-ci -c <(ytt -f $WORKING_DIR/../ci/) \
  -v exception="$EXCEPTION" \
  --check-creds

echo "Setting support pipeline..."

fly -t $TARGET sp -p support-pipeline -c <(ytt -f $WORKING_DIR/../opsman-support) \
  --check-creds

# echo "Setting Docs CI pipeline on TPE CI..."
# 
# fly -t $TARGET sp -p platform-automation-docs -c <(ytt -f "$WORKING_DIR/../docs/") \
#   --check-creds

echo "Setting OSSPI pipeline on TPE CI..."

fly -t $TARGET sp -p osspi-platform-automation -c <(ytt -f "$WORKING_DIR/../osspi-tpe-ci/") \
  --check-creds
