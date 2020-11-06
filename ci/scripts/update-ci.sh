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

echo "Setting CI pipeline..."

fly -t ci sp -p ci -c <(ytt -f $WORKING_DIR/../ci/) \
  --check-creds

fly -t ci sp -p docs -c <(ytt -f $WORKING_DIR/../docs/) \
  --check-creds

fly -t ci sp -p python-mitigation-support -c <(ytt -f $WORKING_DIR/../python-mitigation-support/) \
  --check-creds

if [ -d $WORKING_DIR/../../../concourse-for-platform-automation/ ]; then
  fly -t ci sp -p concourse-for-platform-automation \
    --check-creds \
    -c <(ytt -f $WORKING_DIR/../../../concourse-for-platform-automation/pipeline.yml -f $WORKING_DIR/../cpa/deployments.yml)
fi

echo "Setting support pipeline..."

fly -t ci sp -p support-pipeline -c <(ytt -f $WORKING_DIR/../opsman-support) \
  --check-creds
