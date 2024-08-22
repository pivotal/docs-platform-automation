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

interpolation_args=("--vars-file /tmp/tf-vars.yml")

if [[ -n "${BOSH_ENV_PREFIX}" ]]; then
  interpolation_args+=("--vars-env=${BOSH_ENV_PREFIX}")
fi

echo "Interpolating configs..."
bosh interpolate ${interpolation_args[@]} deployments/platform-automation/"$IAAS"/config/opsman.yml > config/opsman.yml
bosh interpolate ${interpolation_args[@]} --vars-env=TF_VARS deployments/platform-automation/"$IAAS"/config/director.yml > config/director.yml
bosh interpolate ${interpolation_args[@]} --vars-env=TF_VARS deployments/platform-automation/"$IAAS"/env/env.yml > env/env.yml

echo "Config generation nominal"
