#!/usr/bin/env bash
# code_snippet backup-product-script start bash

cat /var/version && echo ""
set -eu

if [ -z "${PRODUCT_NAME}" ]; then
  { printf "\nError: 'PRODUCT_NAME' parameter is required"; } 2>/dev/null
  exit 1
fi

# shellcheck source=./setup-bosh-env.sh
source ./platform-automation-tasks/tasks/setup-bosh-env.sh
set -x

# exported for use in other tasks
export DEPLOYMENT_NAME
DEPLOYMENT_NAME="$(om --env env/"${ENV_FILE}" curl -p /api/v0/deployed/products | om interpolate --path "/type=${PRODUCT_NAME}/guid")"

pushd backup
  bbr deployment \
      --deployment "${DEPLOYMENT_NAME}" \
    backup-cleanup

  bbr deployment \
      --deployment "${DEPLOYMENT_NAME}" \
    backup --with-manifest

  tar -zcvf product_"${PRODUCT_NAME}"_"$( date +"%Y-%m-%d-%H-%M-%S" )".tgz --remove-files -- */*
popd
# code_snippet backup-product-script end
