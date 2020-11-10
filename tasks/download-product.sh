#!/usr/bin/env bash
# code_snippet download-product-script start bash

cat /var/version && echo ""
set -eux

if [ -z "$SOURCE" ]; then
  echo "No source was provided."
  echo "Please provide pivnet, s3, gcs, or azure."
  exit 1
fi

vars_files_args=("")
for vf in ${VARS_FILES}
do
  vars_files_args+=("--vars-file ${vf}")
done

# ${vars_files_args[@] needs to be globbed to pass through properly
# shellcheck disable=SC2068
om download-product \
   --config config/"${CONFIG_FILE}" ${vars_files_args[@]} \
   --output-directory downloaded-files \
   --source "$SOURCE"

{ printf "\nReading product details..."; } 2> /dev/null
# shellcheck disable=SC2068
product_slug=$(om interpolate \
  --config config/"${CONFIG_FILE}" ${vars_files_args[@]} \
  --path /pivnet-product-slug)

product_file=$(om interpolate \
  --config downloaded-files/download-file.json \
  --path /product_path)

stemcell_file=$(om interpolate \
  --config downloaded-files/download-file.json \
  --path /stemcell_path?)

{ printf "\nChecking if product needs winfs injected..."; } 2> /dev/null
if [ "$product_slug" == "pas-windows" ] && [ "$SOURCE" == "pivnet" ]; then
  TILE_FILENAME="$(basename "$product_file")"

  # The winfs-injector determines the necessary windows image,
  # and uses the CF-foundation dockerhub repo
  # to pull the appropriate Microsoft-hosted foreign layer.
  winfs-injector \
  --input-tile "$product_file" \
  --output-tile "downloaded-product/${TILE_FILENAME}"
else
  cp "$product_file" downloaded-product
fi

if [ -e "$stemcell_file" ]; then
  cp "$stemcell_file" downloaded-stemcell
fi

if [ -e downloaded-files/assign-stemcell.yml ]; then
  cp downloaded-files/assign-stemcell.yml assign-stemcell-config/config.yml
fi
# code_snippet download-product-script end
