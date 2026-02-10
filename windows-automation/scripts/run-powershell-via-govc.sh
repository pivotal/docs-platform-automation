#!/usr/bin/env bash
# Run PowerShell script on VM using govc
# Usage: run-powershell-via-govc.sh <vm-name> <script-path>

VM_NAME="${1:-}"
SCRIPT_PATH="${2:-}"

if [[ -z "$VM_NAME" ]] || [[ -z "$SCRIPT_PATH" ]] || ! command -v govc >/dev/null 2>&1; then
    echo "Usage: $0 <vm-name> <script-path>"
    exit 1
fi

# Read script content
if [[ ! -f "$SCRIPT_PATH" ]]; then
    echo "Error: Script not found: $SCRIPT_PATH"
    exit 1
fi

# Read environment variables and inject them into the script
ENV_SETUP=""
for var in STATIC_IP SUBNET_MASK GATEWAY DNS_SERVERS ENABLE_UPDATES LOG_LEVEL; do
    if [[ -n "${!var:-}" ]]; then
        ENV_SETUP="${ENV_SETUP}\$env:$var='${!var}'; "
    fi
done

# Read script content
SCRIPT_CONTENT=$(cat "$SCRIPT_PATH")

# Build PowerShell command with environment variables and script
# Use base64 encoding to avoid escaping issues
FULL_SCRIPT="${ENV_SETUP}${SCRIPT_CONTENT}"
SCRIPT_B64=$(echo -n "$FULL_SCRIPT" | base64 | tr -d '\n')

POWERSHELL_CMD="powershell.exe -ExecutionPolicy Bypass -NoProfile -EncodedCommand $SCRIPT_B64"

# Run via govc
echo "Running PowerShell script via govc on VM: $VM_NAME"
echo "Script: $SCRIPT_PATH"

govc vm.guest.run -vm "$VM_NAME" "$POWERSHELL_CMD" 2>&1

EXIT_CODE=$?
if [[ $EXIT_CODE -eq 0 ]]; then
    echo "Script executed successfully"
else
    echo "Script execution failed with exit code: $EXIT_CODE"
fi

exit $EXIT_CODE
