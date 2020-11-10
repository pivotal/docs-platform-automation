#!/usr/bin/env bash
# code_snippet update-runtime-config-script start bash

cat /var/version && echo ""
set -eu

if [ -z "${NAME}" ]; then
    { printf "\nError: 'NAME' parameter is required"; } 2> /dev/null
    exit 1
fi

if [ -n "${OPSMAN_SSH_PRIVATE_KEY}" ]; then
  eval "$(om --env env/"${ENV_FILE}" bosh-env)"
  host="$(om --env env/"${ENV_FILE}" interpolate -c env/"${ENV_FILE}" --path /target)"
  host=${host#http://}
  host=${host#https://}

  eval "$(ssh-agent -s)"

  function cleanup() {
    pkill ssh || true
    pkill ssh-agent || true
  }
  trap cleanup EXIT

  echo "${OPSMAN_SSH_PRIVATE_KEY}" | ssh-add -
  ssh -o StrictHostKeyChecking=no -4 -D 12345 -fNC "${OPSMAN_SSH_USERNAME}"@"${host}"

  export BOSH_ALL_PROXY=socks5://localhost:12345
else
  eval "$(om --env env/"${ENV_FILE}" bosh-env)"
fi

# $RELEASES_GLOB needs to be globbed to pass through properly
# shellcheck disable=SC2086
RELEASE_FILES="$(find releases/$RELEASES_GLOB 2>/dev/null)"
if [ -n "${RELEASE_FILES}" ]; then
  for rf in ${RELEASE_FILES}
  do
    bosh upload-release "${rf}"
  done
fi

vars_files_args=("")
for vf in ${VARS_FILES}
do
  vars_files_args+=("--vars-file ${vf}")
done

# ${vars_files_args[@] needs to be globbed to pass through properly
# shellcheck disable=SC2068
bosh -n update-config \
  --type runtime \
  --name "${NAME}" \
  config/"${CONFIG_FILE}" \
  ${vars_files_args[@]}

# code_snippet update-runtime-config-script end
