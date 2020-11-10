#!/usr/bin/env bash
# code_snippet credhub-interpolate-script start bash

cat /var/version && echo ""
set -euo pipefail

# NOTE: The credhub cli does not ignore empty/null environment variables.
# https://github.com/cloudfoundry-incubator/credhub-cli/issues/68
if [ -z "${CREDHUB_CA_CERT}" ]; then
  unset CREDHUB_CA_CERT
fi

credhub --version

if [ -z "${PREFIX}" ]; then
  echo "Please specify a PREFIX. It is required."
  exit 1
fi

# $INTERPOLATION_PATHS needs to be globbed to read multiple files
# shellcheck disable=SC2086
files=$(cd files && find ${INTERPOLATION_PATHS} -type f -name '*.yml' -follow)

flags=("")
if [ "${SKIP_MISSING}" == "true" ]; then
  flags+=("--skip-missing")
fi

for file in ${files}; do
  echo "interpolating files/${file}"
  mkdir -p interpolated-files/"$(dirname "${file}")"

  # ${flags[@] needs to be globbed to pass through properly
  # shellcheck disable=SC2068
  credhub interpolate --prefix "${PREFIX}" \
    --file files/"${file}" ${flags[@]} \
    >interpolated-files/"${file}"
done

# code_snippet credhub-interpolate-script end
