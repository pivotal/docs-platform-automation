set +x
if [ -n "${OPSMAN_SSH_PRIVATE_KEY}" ]; then
  eval "$(om --env env/"${ENV_FILE}" bosh-env)"
  host="$(om --env env/"${ENV_FILE}" interpolate -c env/"${ENV_FILE}" --path /target)"
  host=${host#http://}
  host=${host#https://}

  eval "$(ssh-agent -s)"

# This is in bash, but it's meant to be sourced,
# so shellcheck can't tell we have function,
# because it has no shebang to read.
# shellcheck disable=2112
  function cleanup() {
    pkill ssh || true
    pkill ssh-agent || true
  }
  trap cleanup EXIT

  OPSMAN_SSH_TARGET=${OPSMAN_SSH_TARGET:-$host}

  echo "${OPSMAN_SSH_PRIVATE_KEY}" | ssh-add -
  ssh -o StrictHostKeyChecking=no -4 -D 12345 -fNC "${OPSMAN_SSH_USERNAME}"@"${OPSMAN_SSH_TARGET}"

  export BOSH_ALL_PROXY=socks5://localhost:12345
else
  eval "$(om --env env/"${ENV_FILE}" bosh-env)"
fi
