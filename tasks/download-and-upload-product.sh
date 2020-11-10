#!/usr/bin/env bash
# code_snippet download-and-upload-product-script start bash

cat /var/version && echo ""
set -eux

if [ -z "${ENV_FILE}" ]; then
  echo "No env file was provided."
  echo "Please provide and env file to talk to the Ops Manager."
  exit 1
fi

vars_files_args=("")
for vf in ${VARS_FILES}; do
  vars_files_args+=("--vars-file ${vf}")
done

mkdir -p downloaded-product
mkdir -p downloaded-stemcell

# ${vars_files_args[@] needs to be globbed to pass through properly
# shellcheck disable=SC2068
om --env env/"${ENV_FILE}" download-product \
  --config config/"${CONFIG_FILE}" ${vars_files_args[@]} \
  --output-directory downloaded-product \
  --stemcell-output-directory downloaded-stemcell \
  --check-already-uploaded

downloaded_product="$(find downloaded-product/*.pivotal 2>/dev/null | head -n1)"
if [ "${downloaded_product}" != "" ]; then
  om --env env/"${ENV_FILE}" upload-product \
    --product "${downloaded_product}"
fi

downloaded_product="$(find downloaded-product/*.tgz 2>/dev/null | head -n1)"
if [ "${downloaded_product}" != "" ]; then
  om --env env/"${ENV_FILE}" upload-stemcell \
    --stemcell "${downloaded_product}"
fi

downloaded_stemcell="$(find downloaded-stemcell/*.tgz 2>/dev/null | head -n1)"
if [ "${downloaded_stemcell}" != "" ]; then
  floatingArg=""
  if [ "${FLOATING_STEMCELL}" == "true" ] || [ "${FLOATING_STEMCELL}" == "false" ]; then
    floatingArg="--floating=${FLOATING_STEMCELL}"
  fi

  om --env env/"${ENV_FILE}" upload-stemcell \
    --stemcell "${downloaded_stemcell}" "${floatingArg}"
fi
# code_snippet download-and-upload-product-script end
