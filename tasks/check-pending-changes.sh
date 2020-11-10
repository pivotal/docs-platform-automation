#!/usr/bin/env bash
# code_snippet check-pending-changes-script start bash

cat /var/version && echo ""
set -eux

flags=("")
if [ "$ALLOW_PENDING_CHANGES" == "false" ]; then
  flags+=("--check")
fi

# ${flags[@] needs to be globbed to pass through properly
# shellcheck disable=SC2068
om --env env/"${ENV_FILE}" pending-changes \
   ${flags[@]}
# code_snippet check-pending-changes-script end
