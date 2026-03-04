#!/usr/bin/env bash
# Install VMware Tools using govc vm.keystrokes (no guest.run/guest.start — Tools not installed yet).
# We send keystrokes to run setup64.exe; the installer then runs in the guest. Script exits after sending keys.
# Usage: install-vmware-tools-keystrokes.sh <vm-name> [log-file]
#
# Reliability: Depends on console focus (e.g. cmd or desktop). If D: drive or setup doesn't run, increase sleeps:
#   KEYSTROKE_SLEEP_SHORT=2   (default 1)
#   KEYSTROKE_SLEEP_MEDIUM=5  (default 3) - after "d:" and before typing setup command
#   KEYSTROKE_WAIT_BEFORE=15  (default 10) - seconds to wait after first-boot wait before sending Tools install keystrokes

VM_NAME="${1:-}"
LOG_FILE="${2:-}"

# Configurable sleeps for slow/busy VMs (seconds)
KEYSTROKE_SLEEP_SHORT="${KEYSTROKE_SLEEP_SHORT:-1}"
KEYSTROKE_SLEEP_MEDIUM="${KEYSTROKE_SLEEP_MEDIUM:-3}"
KEYSTROKE_WAIT_BEFORE="${KEYSTROKE_WAIT_BEFORE:-10}"

# Setup logging
if [[ -n "$LOG_FILE" ]]; then
    exec > >(tee -a "$LOG_FILE") 2>&1
fi

[[ "${DEBUG_MODE:-}" == "true" ]] && set -x

if [[ -z "$VM_NAME" ]]; then
    echo "Usage: $0 <vm-name> [log-file]"
    exit 1
fi

if ! command -v govc >/dev/null 2>&1; then
    echo "Error: govc command not found"
    exit 1
fi

echo "=========================================="
echo "Installing VMware Tools on VM: $VM_NAME"
echo "Timestamp: $(date)"
echo "=========================================="

echo "Waiting ${KEYSTROKE_WAIT_BEFORE} seconds after first-boot wait for system to be ready..."
sleep "$KEYSTROKE_WAIT_BEFORE"

echo "Step 1: Navigating to D: drive"
# Navigate to D: drive
govc vm.keystrokes -vm "$VM_NAME" -s='d:' || {
    echo "Error: Failed to type 'd:'"
    exit 1
}
govc vm.keystrokes -vm "$VM_NAME" -c=KEY_ENTER || {
    echo "Error: Failed to press Enter after 'd:'"
    exit 1
}
sleep "$KEYSTROKE_SLEEP_SHORT"

echo "Step 2: Running setup64.exe"
# Run setup64.exe with silent flag
govc vm.keystrokes -vm "$VM_NAME" -s='setup64.exe /v"/qn REBOOT=R"' || {
    echo "Error: Failed to type setup command"
    exit 1
}
govc vm.keystrokes -vm "$VM_NAME" -c=KEY_ENTER || {
    echo "Error: Failed to press Enter after setup command"
    exit 1
}
sleep "$KEYSTROKE_SLEEP_MEDIUM"

echo "=========================================="
echo "VMware Tools installation command sent successfully"
echo "Installation should be running in background"
echo "Note: Installation may take several minutes. Check VM console for progress."
echo "Timestamp: $(date)"
echo "=========================================="
exit 0
