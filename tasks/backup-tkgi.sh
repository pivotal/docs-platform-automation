#!/usr/bin/env bash
# code_snippet backup-tkgi-script start bash

cat /var/version && echo ""
set -eu

export PRODUCT_NAME="pivotal-container-service"

# shellcheck source=./setup-bosh-env.sh
source ./platform-automation-tasks/tasks/setup-bosh-env.sh

# shellcheck disable=SC2016
echo 'Backing up TKGI, the `pks` CLI may be unavailable'

# shellcheck source=./backup-product.sh
source ./platform-automation-tasks/tasks/backup-product.sh

bosh_team_creds="$(om --env env/"${ENV_FILE}" curl -p /api/v0/deployed/products/"${DEPLOYMENT_NAME}"/uaa_client_credentials)"
bosh_team_client="$(echo "${bosh_team_creds}" | om interpolate --path /uaa_client_name)"
bosh_team_client_secret="$(echo "${bosh_team_creds}" | om interpolate --path /uaa_client_secret)"

pushd backup
  bbr deployment \
    --username "${bosh_team_client}" \
    --password "${bosh_team_client_secret}" \
    --all-deployments \
    backup-cleanup
    
  bbr deployment \
    --username "${bosh_team_client}" \
    --password "${bosh_team_client_secret}" \
    --all-deployments \
    backup --with-manifest

  tar -zcvf "${PRODUCT_NAME}"_clusters_"$( date +"%Y-%m-%d-%H-%M-%S" )".tgz \
    --exclude "${PRODUCT_NAME}"_*.tgz \
    --remove-files -- */*
popd
# code_snippet backup-tkgi-script end
