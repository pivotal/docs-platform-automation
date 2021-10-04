#!/usr/bin/env bash
# code_snippet download-product-script start bash

cat /var/version && echo ""
set -eux

if [ -z "${SOURCE}" ]; then
  echo "No source was provided."
  echo "Please provide pivnet, s3, gcs, or azure."
  exit 1
fi

vars_files_args=("")
for vf in ${VARS_FILES}; do
  vars_files_args+=("--vars-file ${vf}")
done

export CACHE_CLEANUP="I acknowledge this will delete files in the output directories"

echo "---
pivnet-api-token: ${pivnet_token}
pivnet-file-glob: \"pivotal-container-service-*.pivotal\"
pivnet-product-slug: pivotal-container-service
product-version: '1.11.4'
stemcell-version: '621.154'
stemcell-iaas: vsphere
" > $CONFIG_FILE

# ${vars_files_args[@] needs to be globbed to pass through properly
# shellcheck disable=SC2068
om download-product \
  --config "${CONFIG_FILE}" ${vars_files_args[@]} \
  --output-directory downloaded-product \
  --stemcell-output-directory downloaded-stemcell \
  --source "${SOURCE}"

{ printf "\nChecking if product needs winfs injected..."; } 2>/dev/null
# shellcheck disable=SC2068
product_slug=$(om interpolate \
  --config "${CONFIG_FILE}" ${vars_files_args[@]} \
  --path /pivnet-product-slug)

if [ "${product_slug}" == "pas-windows" ] && [ "${SOURCE}" == "pivnet" ]; then
  product_file=$(om interpolate \
    --config downloaded-product/download-file.json \
    --path /product_path)

  # The winfs-injector determines the necessary windows image,
  # and uses the CF-foundation dockerhub repo
  # to pull the appropriate Microsoft-hosted foreign layer.
  winfs-injector \
    --input-tile "${product_file}" \
    --output-tile "${product_file}"
fi

if [ -e downloaded-product/assign-stemcell.yml ]; then
  mv downloaded-product/assign-stemcell.yml assign-stemcell-config/config.yml
fi

rm -f downloaded-product/download-file.json
# code_snippet download-product-script end
