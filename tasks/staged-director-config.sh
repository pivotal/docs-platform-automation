#!/usr/bin/env bash
# code_snippet staged-director-config-script start bash

cat /var/version && echo ""
set -eux
om --env env/"${ENV_FILE}" staged-director-config \
  --include-placeholders >generated-config/director.yml
# code_snippet staged-director-config-script end
