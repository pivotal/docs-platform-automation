#!/usr/bin/env bash
# code_snippet backup-director-script start bash

cat /var/version && echo ""
set -eu

# shellcheck source=./setup-bosh-env.sh
source ./platform-automation-tasks/tasks/setup-bosh-env.sh

bosh_username="bbr"
bosh_private_key="$(om --env env/"${ENV_FILE}" curl -p /api/v0/deployed/director/credentials/bbr_ssh_credentials | om interpolate --path /credential/value/private_key_pem)"

pushd backup
  bbr director \
    --host "${BOSH_ENVIRONMENT}" \
    --username "${bosh_username}" \
    --private-key-path <(echo "${bosh_private_key}") \
    backup-cleanup

  bbr director \
    --host "${BOSH_ENVIRONMENT}" \
    --username "${bosh_username}" \
    --private-key-path <(echo "${bosh_private_key}") \
    backup

  tar -zcvf director_"$( date +"%Y-%m-%d-%H-%M-%S" )".tgz --remove-files -- */*
popd
# code_snippet backup-director-script end
