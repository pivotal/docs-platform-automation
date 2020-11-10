#!/usr/bin/env bash
# code_snippet revert-staged-changes-script start bash

cat /var/version && echo ""
set -eux

om --env env/"${ENV_FILE}" revert-staged-changes
# code_snippet revert-staged-changes-script end
