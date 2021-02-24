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

echo "Setting Docs CI pipeline on Runway..."
fly -t runway sp -p platform-automation -c <(ytt -f "$WORKING_DIR/../docs/") \
  --check-creds
