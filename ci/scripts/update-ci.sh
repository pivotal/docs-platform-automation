#!/usr/bin/env bash

set -euo pipefail

which ytt || (
  echo "This requires ytt to be installed"
  exit 1
)
which fly || (
  echo "This requires fly to be installed"
  exit 1
)

echo "Setting CI pipeline..."

fly -t ci sp -p ci -c <(ytt -f ci/) \
  --check-creds

fly -t ci sp -p docs -c <(ytt -f docs/) \
  --check-creds

fly -t ci sp -p python-mitigation-support -c <(ytt -f python-mitigation-support/) \
  --check-creds

if [ -d ../../concourse-for-platform-automation/ ]; then
  fly -t ci sp -p concourse-for-platform-automation \
    --check-creds \
    -c <(ytt -f ../../concourse-for-platform-automation/pipeline.yml -f cpa/deployments.yml)
fi

fly -t ci sp -p om -c <(ytt -f om/) \
  --check-creds

echo "Setting support pipeline..."

fly -t ci sp -p support-pipeline -c <(ytt -f opsman-support) \
  --check-creds
