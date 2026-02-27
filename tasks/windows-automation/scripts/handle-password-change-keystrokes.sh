#!/usr/bin/env bash
# Handle password change screen using govc vm.keystrokes (guest ops need Tools + login, so we inject keystrokes instead).
# Runs after Windows install and first boot. Usage: handle-password-change-keystrokes.sh <vm-name> <password> [log-file]

VM_NAME="${1:-}"
PASSWORD="${2:-}"
LOG_FILE="${3:-}"

# Setup logging
if [[ -n "$LOG_FILE" ]]; then
    exec > >(tee -a "$LOG_FILE") 2>&1
fi

[[ "${DEBUG_MODE:-}" == "true" ]] && set -x

if [[ -z "$VM_NAME" ]] || [[ -z "$PASSWORD" ]]; then
    echo "Usage: $0 <vm-name> <password> [log-file]"
    exit 1
fi

if ! command -v govc >/dev/null 2>&1; then
    echo "Error: govc command not found"
    exit 1
fi

echo "=========================================="
echo "Handling password change for VM: $VM_NAME"
echo "Timestamp: $(date)"
echo "=========================================="

# Step 0: Send Ctrl+Alt+Del to unlock/login screen
# This is required because VM provisioning is done and we need to unlock the screen
echo "Step 0: Sending Ctrl+Alt+Del to unlock login screen..."
govc vm.keystrokes -vm "$VM_NAME" -lc=true -la=true -c=0x4c || {
    echo "Error: Failed to send Ctrl+Alt+Del"
    exit 1
}
sleep 2
echo "Ctrl+Alt+Del sent successfully"

# Step 1: Handle the OK/Cancel dialog for password reset
echo "Step 1: Handling OK/Cancel dialog for password reset..."
# OK button is focused by default, so just press Enter
govc vm.keystrokes -vm "$VM_NAME" -c=KEY_ENTER || {
    echo "Error: Failed to handle OK/Cancel dialog"
    exit 1
}
sleep 2
echo "OK/Cancel dialog handled"

# Step 2: Handle the password entry screen
echo "Step 2: Handling password entry screen..."
# Password entry screen has:
# - New password field (should be focused automatically)
# - Confirm password field
# - OK/Next button
# Type password in first field
echo "Typing password in first field..."
govc vm.keystrokes -vm "$VM_NAME" -s="$PASSWORD" || {
    echo "Error: Failed to type password in first field"
    exit 1
}
sleep 1

# Tab to confirm password field
echo "Moving to confirm password field..."
govc vm.keystrokes -vm "$VM_NAME" -c=KEY_TAB || {
    echo "Error: Failed to tab to confirm password field"
    exit 1
}
sleep 1

# Type password in confirm field
echo "Typing password in confirm field..."
govc vm.keystrokes -vm "$VM_NAME" -s="$PASSWORD" || {
    echo "Error: Failed to type password in confirm field"
    exit 1
}
sleep 1

# Press Enter to confirm
echo "Confirming password change..."
govc vm.keystrokes -vm "$VM_NAME" -c=KEY_ENTER || {
    echo "Error: Failed to confirm password change"
    exit 1
}
sleep 3

# Step 3: Handle login screen (if it appears after password change)
echo "Step 3: Handling login screen (if needed)..."
# Send Ctrl+Alt+Del again to unlock login screen
govc vm.keystrokes -vm "$VM_NAME" -lc=true -la=true -c=0x4c || {
    echo "Warning: Failed to send Ctrl+Alt+Del for login (may not be needed)"
}
sleep 2

# Type password to login
echo "Typing password to login..."
govc vm.keystrokes -vm "$VM_NAME" -s="$PASSWORD" || {
    echo "Error: Failed to type password for login"
    exit 1
}
sleep 1

# Press Enter to login
echo "Pressing Enter to login..."
govc vm.keystrokes -vm "$VM_NAME" -c=KEY_ENTER || {
    echo "Error: Failed to press Enter for login"
    exit 1
}
sleep 3

echo "=========================================="
echo "Password change and login completed successfully"
echo "Timestamp: $(date)"
echo "=========================================="
exit 0
