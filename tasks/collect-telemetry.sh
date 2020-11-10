#!/bin/bash
# code_snippet collect-telemetry-script start bash
set -eux

cat config/"$CONFIG_FILE" env/"$ENV_FILE" > combined-config.yml
sed 's/---//g' combined-config.yml > clean-config.yml

# Creating a named pipe so that the interpolated config isn't written to disk.
# We would normally use the <() syntax to do this,
# but the the telemetry collector requires a file extension.
mkfifo /tmp/pipe.yml

function finish {
  rm /tmp/pipe.yml
}
trap finish EXIT

om interpolate -c clean-config.yml --vars-env OM_VAR > /tmp/pipe.yml &

./telemetry-collector-binary/telemetry-collector-linux-amd64 --version

om --env env/"$ENV_FILE" curl --path /api/v0/info > /dev/null 2>&1

./telemetry-collector-binary/telemetry-collector-linux-amd64 collect \
  --output-dir ./collected-telemetry-data \
  --config /tmp/pipe.yml
# code_snippet collect-telemetry-script end bash
