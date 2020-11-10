#!/usr/bin/env bash
# code_snippet test-script start bash

echo "Platform Automation for PCF version:"
cat /var/version && echo ""

printf "\\nom version:"
om -v

set -eux
om vm-lifecycle --help
om --help
{ echo "Successfully validated tasks and image!"; } 2> /dev/null
# code_snippet test-script end
