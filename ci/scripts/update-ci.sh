#!/usr/bin/env bash

set -euo pipefail

WORKING_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

TARGET=${1:-platform-automation}

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
  --check-creds

echo "Setting support pipeline..."

fly -t $TARGET sp -p support-pipeline -c <(ytt -f $WORKING_DIR/../opsman-support) \
  --check-creds
