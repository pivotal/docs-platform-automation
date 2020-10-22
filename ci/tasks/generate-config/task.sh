#!/usr/bin/env bash

set -eu

function add_terraform_env {
  pushd deployments/platform-automation/"$IAAS"
    terraform output -json | jq 'to_entries | map( {"key": .key, "value": ([.value.value] | flatten | .[0] | tostring) }) | from_entries' > /tmp/tf-vars.yml
  popd
}

add_terraform_env

echo "Attempting to copy optional files to outputs..."
cp deployments/platform-automation/"$IAAS"/state/*.yml state/ || true
cp deployments/platform-automation/"$IAAS"/vars/*.yml vars/ || true
cp deployments/platform-automation/"$IAAS"/config/*.yml config/

echo "Interpolating configs..."
bosh int -l /tmp/tf-vars.yml deployments/platform-automation/"$IAAS"/config/opsman.yml > config/opsman.yml
bosh int -l /tmp/tf-vars.yml --vars-env=TF_VARS deployments/platform-automation/"$IAAS"/config/director.yml > config/director.yml
bosh int -l /tmp/tf-vars.yml --vars-env=TF_VARS deployments/platform-automation/"$IAAS"/env/env.yml > env/env.yml

echo "Config generation nominal"
