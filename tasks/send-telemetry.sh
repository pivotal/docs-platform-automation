#!/bin/bash
# code_snippet send-telemetry-script start bash
set -eux

./telemetry-collector-binary/telemetry-collector-linux-amd64 --version

# DATA_FILE_PATH needs to be globbed (SC2086)
# shellcheck disable=SC2086
./telemetry-collector-binary/telemetry-collector-linux-amd64 send \
  --path ${DATA_FILE_PATH}
# code_snippet send-telemetry-script end
