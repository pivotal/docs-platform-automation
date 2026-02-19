#!/usr/bin/env bash
# Run PowerShell script on VM using govc guest.run
# This is a generic script that can execute any PowerShell script on a VM
# Usage: run-powershell-via-govc.sh <vm-name> <script-path> <username> <password> [log-file] [env-vars]
#
# Parameters:
#   vm-name:      Name of the VM
#   script-path:  Path to PowerShell script file
#   username:     Guest OS username (default: Administrator)
#   password:     Guest OS password
#   log-file:     Optional log file path
#   env-vars:     Optional comma-separated list of environment variable names to pass through
#                 If not specified, automatically passes through all uppercase environment variables
#                 that don't start with special prefixes (PATH, HOME, USER, etc.)
#
# Environment Variables:
#   The script automatically passes through environment variables to the PowerShell script.
#   You can control which variables are passed:
#   1. Specify via env-vars parameter: ./script.sh vm script.ps1 user pass log "VAR1,VAR2,VAR3"
#   2. Set PS_ENV_VARS environment variable: export PS_ENV_VARS="VAR1,VAR2,VAR3"
#   3. Auto-detect: All uppercase variables (excluding system vars) are passed automatically
#
# Examples:
#   # Pass specific variables
#   STATIC_IP=192.168.1.100 GATEWAY=192.168.1.1 \
#   ./run-powershell-via-govc.sh vm-name script.ps1 user pass log "STATIC_IP,GATEWAY"
#
#   # Auto-detect all uppercase variables
#   STATIC_IP=192.168.1.100 DNS_SERVERS=8.8.8.8 \
#   ./run-powershell-via-govc.sh vm-name script.ps1 user pass log
#
#   # Use environment variable to specify which vars to pass
#   export PS_ENV_VARS="STATIC_IP,SUBNET_MASK,GATEWAY"
#   ./run-powershell-via-govc.sh vm-name script.ps1 user pass log

VM_NAME="${1:-}"
SCRIPT_PATH="${2:-}"
GUEST_USERNAME="${3:-Administrator}"
GUEST_PASSWORD="${4:-}"
LOG_FILE="${5:-}"
ENV_VARS_PARAM="${6:-${PS_ENV_VARS:-}}"

# Setup logging - create log file if provided
if [[ -n "$LOG_FILE" ]]; then
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE" 2>/dev/null || {
        echo "WARNING: Could not create log file: $LOG_FILE" >&2
        LOG_FILE=""
    }
fi

if [[ -z "$VM_NAME" ]] || [[ -z "$SCRIPT_PATH" ]] || [[ -z "$GUEST_PASSWORD" ]] || ! command -v govc >/dev/null 2>&1; then
    echo "Usage: $0 <vm-name> <script-path> <username> <password> [log-file] [env-vars]"
    echo ""
    echo "Examples:"
    echo "  # Auto-detect environment variables"
    echo "  STATIC_IP=192.168.1.100 ./$0 vm-name script.ps1 user pass log"
    echo ""
    echo "  # Specify which variables to pass"
    echo "  ./$0 vm-name script.ps1 user pass log \"STATIC_IP,GATEWAY,DNS_SERVERS\""
    echo ""
    echo "  # Use PS_ENV_VARS environment variable"
    echo "  export PS_ENV_VARS=\"STATIC_IP,SUBNET_MASK\""
    echo "  ./$0 vm-name script.ps1 user pass log"
    exit 1
fi

# Read script content
if [[ ! -f "$SCRIPT_PATH" ]]; then
    echo "Error: Script not found: $SCRIPT_PATH"
    exit 1
fi

# Determine which environment variables to pass through
ENV_VARS_TO_PASS=""

if [[ -n "$ENV_VARS_PARAM" ]]; then
    # Use explicitly specified variables (comma-separated list)
    IFS=',' read -ra VAR_ARRAY <<< "$ENV_VARS_PARAM"
    for var in "${VAR_ARRAY[@]}"; do
        var=$(echo "$var" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')  # Trim whitespace
        if [[ -n "$var" ]]; then
            ENV_VARS_TO_PASS="${ENV_VARS_TO_PASS}${ENV_VARS_TO_PASS:+ }$var"
        fi
    done
else
    # Auto-detect: Pass through all uppercase environment variables
    # Exclude common system variables and internal bash variables
    EXCLUDE_PATTERNS="^(PATH|HOME|USER|SHELL|PWD|OLDPWD|SHLVL|_|BASH_|PS1|PS2|PS3|PS4|HIST|TERM|LANG|LC_|TMPDIR|TEMP|TMP|DISPLAY|SSH_|GOVC_|PKR_VAR_|PKR_|PACKER_)"
    
    while IFS='=' read -r var_name var_value; do
        # Skip if variable name contains '=' (invalid format)
        if [[ "$var_name" == *"="* ]]; then
            continue
        fi
        
        # Only include uppercase variable names
        if [[ "$var_name" =~ ^[A-Z][A-Z0-9_]*$ ]]; then
            # Exclude system variables
            if ! [[ "$var_name" =~ $EXCLUDE_PATTERNS ]]; then
                ENV_VARS_TO_PASS="${ENV_VARS_TO_PASS}${ENV_VARS_TO_PASS:+ }$var_name"
            fi
        fi
    done < <(env)
fi

# Inject environment variables into the script
# Put each assignment on its own line for better PowerShell parsing
ENV_SETUP=""
if [[ -n "$ENV_VARS_TO_PASS" ]]; then
    for var in $ENV_VARS_TO_PASS; do
        if [[ -n "${!var:-}" ]]; then
            # Escape single quotes by doubling them using Python to avoid bash parser issues
            escaped_value=$(python3 -c "import sys; print(sys.stdin.read().replace(\"'\", \"''\"))" <<< "${!var}")
            # Build PowerShell environment variable assignment - one per line
            if [[ -n "$ENV_SETUP" ]]; then
                ENV_SETUP="${ENV_SETUP}"$'\n'
            fi
            ENV_SETUP="${ENV_SETUP}\$env:${var}=\"${escaped_value}\""
        fi
    done
    # Add a blank line after environment setup for clean separation
    if [[ -n "$ENV_SETUP" ]]; then
        ENV_SETUP="${ENV_SETUP}"$'\n'
    fi
fi

# Read script content
SCRIPT_CONTENT=$(cat "$SCRIPT_PATH" 2>/dev/null || {
    echo "ERROR: Failed to read script file: $SCRIPT_PATH" >&2
    exit 1
})

if [[ -z "$SCRIPT_CONTENT" ]]; then
    echo "ERROR: Script file is empty: $SCRIPT_PATH" >&2
    exit 1
fi

# Build the full script with environment variables and script content
# Environment variables are already on separate lines with proper formatting
FULL_SCRIPT="${ENV_SETUP}${SCRIPT_CONTENT}"

# Create temporary script file on host
TEMP_SCRIPT_FILE=$(mktemp /tmp/powershell-script-XXXXXX.ps1)
trap "rm -f '$TEMP_SCRIPT_FILE'" EXIT INT TERM

# Write script to temporary file
printf '%s' "$FULL_SCRIPT" > "$TEMP_SCRIPT_FILE" || {
    echo "ERROR: Failed to write script to temporary file: $TEMP_SCRIPT_FILE" >&2
    exit 1
}

# Upload script to VM using govc guest.upload
# Target path on VM: C:\Windows\Temp\powershell-script-<timestamp>.ps1
VM_SCRIPT_PATH="C:\\Windows\\Temp\\powershell-script-$(date +%s).ps1"

echo "Uploading script to VM: $VM_SCRIPT_PATH" >&2
govc guest.upload -vm "$VM_NAME" -l "${GUEST_USERNAME}:${GUEST_PASSWORD}" "$TEMP_SCRIPT_FILE" "$VM_SCRIPT_PATH" || {
    echo "ERROR: Failed to upload script to VM" >&2
    exit 1
}

# Build PowerShell command to execute the script file
POWERSHELL_CMD="C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe -ExecutionPolicy Bypass -NoProfile -NoLogo -NonInteractive -File \"$VM_SCRIPT_PATH\""

# Setup logging
if [[ -n "$LOG_FILE" ]]; then
    exec > >(tee -a "$LOG_FILE") 2>&1
fi

echo "=========================================="
echo "Running PowerShell script via govc guest.run"
echo "VM: $VM_NAME"
echo "Script: $SCRIPT_PATH"
echo "Guest User: $GUEST_USERNAME"
if [[ -n "$ENV_VARS_TO_PASS" ]]; then
    echo "Environment variables: $ENV_VARS_TO_PASS"
fi
echo "Timestamp: $(date)"
echo "=========================================="

# Pre-flight check: Verify VM is accessible
if ! govc vm.info "$VM_NAME" >/dev/null 2>&1; then
    echo "ERROR: VM not found or not accessible: $VM_NAME"
    exit 1
fi

# Run via govc guest.run
OUTPUT=$(govc guest.run -vm "$VM_NAME" -l "${GUEST_USERNAME}:${GUEST_PASSWORD}" "$POWERSHELL_CMD" 2>&1)
EXIT_CODE=$?

# Clean up script file on VM
echo "Cleaning up script file on VM..." >&2
govc guest.run -vm "$VM_NAME" -l "${GUEST_USERNAME}:${GUEST_PASSWORD}" "cmd.exe /c del /f /q \"$VM_SCRIPT_PATH\"" >/dev/null 2>&1 || true

# Filter CLIXML output (same as test-backslash-escape.sh)
# CLIXML is PowerShell's XML serialization format - filter it but keep actual output
FILTERED_OUTPUT=$(echo "$OUTPUT" | grep -v "^#< CLIXML$" | grep -v "^<Objs" | grep -v "^</Objs>" | grep -v "^<Obj" | grep -v "^<.*>$" | grep -v "^#<" || echo "$OUTPUT")

# Trim whitespace from output
FILTERED_OUTPUT=$(echo "$FILTERED_OUTPUT" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

echo "Output:"
if [[ -n "$FILTERED_OUTPUT" ]]; then
    echo "$FILTERED_OUTPUT"
else
    echo "(no output after filtering)"
    echo ""
    echo "DEBUG: Showing raw output (may contain CLIXML):"
    echo "$OUTPUT"
fi
echo ""
echo "Exit code: $EXIT_CODE"
echo "=========================================="

# Validate execution: fail only if exit code is non-zero
# Exit code is the primary indicator of success/failure
# (Some scripts may not produce output but still succeed)
if [[ $EXIT_CODE -ne 0 ]]; then
    echo "ERROR: PowerShell script failed with exit code: $EXIT_CODE" >&2
    echo "Full raw output:" >&2
    echo "$OUTPUT" >&2
    exit $EXIT_CODE
fi

# Success - exit code is 0
exit 0
