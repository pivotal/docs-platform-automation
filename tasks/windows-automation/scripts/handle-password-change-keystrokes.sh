#!/usr/bin/env bash
# Handle password change screen using govc vm.keystrokes (guest ops need Tools + login, so we inject keystrokes instead).
# Runs after Windows install and first boot. Usage: handle-password-change-keystrokes.sh <vm-name> <password> [log-file] [windows_version]
# Optional windows_version (2019, 2022, 2025): if 2022 or 2025, after login sends keystrokes to exit SConfig (option 15). No VMware Tools required for keystrokes.
#
# Reliability: Keystrokes depend on screen state, focus, and timing. For slow or busy VMs, increase sleeps via env:
#   KEYSTROKE_WAIT_INITIAL=30  (default 25) - wait before sending ANY keys (let password/login screen appear)
#   KEYSTROKE_SLEEP_SHORT=2    (default 2) - after single key/type
#   KEYSTROKE_SLEEP_MEDIUM=5   (default 4) - after Ctrl+Alt+Del or dialog action
#   KEYSTROKE_SLEEP_LONG=6     (default 5) - after login or confirm
#   KEYSTROKE_SLEEP_SCONFIG=8  (default 8) - wait before sending SConfig exit (2022/2025)
# Assumes US keyboard and default focus order (OK focused, then password field, Tab to confirm, etc.).

VM_NAME="${1:-}"
PASSWORD="${2:-}"
LOG_FILE="${3:-}"
WINDOWS_VERSION="${4:-}"

# Configurable sleeps for slow/busy VMs (seconds). Defaults are conservative to avoid timing failures.
KEYSTROKE_WAIT_INITIAL="${KEYSTROKE_WAIT_INITIAL:-25}"
KEYSTROKE_SLEEP_SHORT="${KEYSTROKE_SLEEP_SHORT:-2}"
KEYSTROKE_SLEEP_MEDIUM="${KEYSTROKE_SLEEP_MEDIUM:-4}"
KEYSTROKE_SLEEP_LONG="${KEYSTROKE_SLEEP_LONG:-5}"
KEYSTROKE_SLEEP_SCONFIG="${KEYSTROKE_SLEEP_SCONFIG:-8}"

# Setup logging
if [[ -n "$LOG_FILE" ]]; then
    exec > >(tee -a "$LOG_FILE") 2>&1
fi

[[ "${DEBUG_MODE:-}" == "true" ]] && set -x

if [[ -z "$VM_NAME" ]] || [[ -z "$PASSWORD" ]]; then
    echo "Usage: $0 <vm-name> <password> [log-file] [windows_version]"
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

# Wait for the password change / login screen to be ready before sending any keystrokes.
# Without this, keys can be lost or applied to the wrong window (e.g. still at boot).
echo "Waiting ${KEYSTROKE_WAIT_INITIAL}s for password/login screen to be ready..."
sleep "$KEYSTROKE_WAIT_INITIAL"

# Step 0: Send Ctrl+Alt+Del to unlock/login screen
# This is required because VM provisioning is done and we need to unlock the screen
echo "Step 0: Sending Ctrl+Alt+Del to unlock login screen..."
govc vm.keystrokes -vm "$VM_NAME" -lc=true -la=true -c=0x4c || {
    echo "Error: Failed to send Ctrl+Alt+Del"
    exit 1
}
sleep "$KEYSTROKE_SLEEP_MEDIUM"
echo "Ctrl+Alt+Del sent successfully"

# Step 1: Handle the OK/Cancel dialog for password reset
echo "Step 1: Handling OK/Cancel dialog for password reset..."
# OK button is focused by default, so just press Enter
govc vm.keystrokes -vm "$VM_NAME" -c=KEY_ENTER || {
    echo "Error: Failed to handle OK/Cancel dialog"
    exit 1
}
sleep "$KEYSTROKE_SLEEP_MEDIUM"
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
sleep "$KEYSTROKE_SLEEP_SHORT"

# Tab to confirm password field
echo "Moving to confirm password field..."
govc vm.keystrokes -vm "$VM_NAME" -c=KEY_TAB || {
    echo "Error: Failed to tab to confirm password field"
    exit 1
}
sleep "$KEYSTROKE_SLEEP_SHORT"

# Type password in confirm field
echo "Typing password in confirm field..."
govc vm.keystrokes -vm "$VM_NAME" -s="$PASSWORD" || {
    echo "Error: Failed to type password in confirm field"
    exit 1
}
sleep "$KEYSTROKE_SLEEP_SHORT"

# Press Enter to confirm
echo "Confirming password change..."
govc vm.keystrokes -vm "$VM_NAME" -c=KEY_ENTER || {
    echo "Error: Failed to confirm password change"
    exit 1
}
sleep "$KEYSTROKE_SLEEP_LONG"

# Step 3: Handle login screen (if it appears after password change)
echo "Step 3: Handling login screen (if needed)..."
# Send Ctrl+Alt+Del again to unlock login screen
govc vm.keystrokes -vm "$VM_NAME" -lc=true -la=true -c=0x4c || {
    echo "Warning: Failed to send Ctrl+Alt+Del for login (may not be needed)"
}
sleep "$KEYSTROKE_SLEEP_MEDIUM"

# Type password to login
echo "Typing password to login..."
govc vm.keystrokes -vm "$VM_NAME" -s="$PASSWORD" || {
    echo "Error: Failed to type password for login"
    exit 1
}
sleep "$KEYSTROKE_SLEEP_SHORT"

# Press Enter to login
echo "Pressing Enter to login..."
govc vm.keystrokes -vm "$VM_NAME" -c=KEY_ENTER || {
    echo "Error: Failed to press Enter for login"
    exit 1
}
sleep "$KEYSTROKE_SLEEP_LONG"

# Step 4: Exit SConfig (2022/2025 only). SConfig may appear after first logon; option 15 = Exit to command prompt. Keystrokes work without VMware Tools.
if [[ "$WINDOWS_VERSION" == "2022" ]] || [[ "$WINDOWS_VERSION" == "2025" ]]; then
    echo "Step 4: Exiting SConfig (Windows $WINDOWS_VERSION)..."
    sleep "$KEYSTROKE_SLEEP_SCONFIG"
    govc vm.keystrokes -vm "$VM_NAME" -s="15" || {
        echo "Warning: Failed to send SConfig option 15"
    }
    sleep "$KEYSTROKE_SLEEP_SHORT"
    govc vm.keystrokes -vm "$VM_NAME" -c=KEY_ENTER || {
        echo "Warning: Failed to send Enter to exit SConfig"
    }
    sleep "$KEYSTROKE_SLEEP_MEDIUM"
    echo "SConfig exit keystrokes sent."
fi

echo "=========================================="
echo "Password change and login completed successfully"
echo "Timestamp: $(date)"
echo "=========================================="
exit 0
