#!/usr/bin/env bash

cat /var/version 2>/dev/null && echo "" || true
set -eux

# Validate required parameters
if [ -z "${SOURCE:-}" ]; then
  echo "No source was provided."
  echo "Please provide pivnet, s3, gcs, or azure."
  exit 1
fi

if [ -z "${PROXY_URL:-}" ]; then
  echo "PROXY_URL is required for SPNEGO proxy authentication."
  exit 1
fi

if [ -z "${PROXY_USERNAME:-}" ]; then
  echo "PROXY_USERNAME is required for SPNEGO proxy authentication."
  exit 1
fi

if [ -z "${PROXY_PASSWORD:-}" ]; then
  echo "PROXY_PASSWORD is required for SPNEGO proxy authentication."
  exit 1
fi

# Set up Kerberos configuration
KRB5_CONFIG_FILE="${KRB5_CONFIG_FILE:-krb5.conf}"
KRB5_CONFIG_PATH="krb5-config/${KRB5_CONFIG_FILE}"

if [ ! -f "${KRB5_CONFIG_PATH}" ]; then
  echo "Kerberos config file not found: ${KRB5_CONFIG_PATH}"
  exit 1
fi

echo "Using Kerberos config: ${KRB5_CONFIG_PATH}"

# Build vars files arguments
vars_files_args=("")
for vf in ${VARS_FILES:-}; do
  vars_files_args+=("--vars-file ${vf}")
done

export CACHE_CLEANUP="I acknowledge this will delete files in the output directories"

# Run download-product with SPNEGO proxy authentication
# shellcheck disable=SC2068
om download-product \
  --config config/"${CONFIG_FILE}" ${vars_files_args[@]} \
  --output-directory downloaded-product \
  --stemcell-output-directory downloaded-stemcell \
  --source "${SOURCE}" \
  --proxy-url "${PROXY_URL}" \
  --proxy-username "${PROXY_USERNAME}" \
  --proxy-password "${PROXY_PASSWORD}" \
  --proxy-auth-type spnego \
  --proxy-krb5-config "${KRB5_CONFIG_PATH}"

{ printf "\nSPNEGO proxy authentication completed successfully.\n"; } 2>/dev/null

# Handle assign-stemcell config
if [ -e downloaded-product/assign-stemcell.yml ]; then
  mv downloaded-product/assign-stemcell.yml assign-stemcell-config/config.yml
fi

rm -f downloaded-product/download-file.json
