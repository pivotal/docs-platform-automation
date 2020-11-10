#!/usr/bin/env bash
# code_snippet test-interpolate-script start bash

cat /var/version && echo ""
set -eux

flags=("")
for vf in ${VARS_FILES}; do
  flags+=("--vars-file ${vf}")
done

if [ "${SKIP_MISSING}" == "true" ]; then
  flags+=("--skip-missing")
fi

# ${flags[@] needs to be globbed to pass through properly
# ${vars_files_args[@] needs to be globbed to pass through properly
# shellcheck disable=SC2068
om interpolate --config "config/${CONFIG_FILE}" ${flags[@]}
# code_snippet test-interpolate-script end
