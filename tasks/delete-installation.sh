#!/usr/bin/env bash
# code_snippet delete-installation-script start bash

cat /var/version && echo ""
set -eux
om --env env/"${ENV_FILE}" delete-installation --force
# code_snippet delete-installation-script end
