#!/usr/bin/env bash

set -euo pipefail

WORKING_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

TARGET=tpe

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
 -v eos_date=03/20/2027

# echo "Setting support pipeline..."

# fly -t $TARGET sp -p support-pipeline -c <(ytt -f $WORKING_DIR/../opsman-support) \
#   --check-creds

# # echo "Setting Docs CI pipeline on TPE CI..."
# # 
# # fly -t $TARGET sp -p platform-automation-docs -c <(ytt -f "$WORKING_DIR/../docs/") \
# #   --check-creds

# echo "Setting OSSPI pipeline on TPE CI..."

# fly -t $TARGET sp -p osspi-platform-automation -c <(ytt -f "$WORKING_DIR/../osspi-tpe-ci/") \
#   --check-creds
