#!/usr/bin/env bash
# Windows Updates Automation Loop
# Usage: run-windows-updates-loop.sh <vm-name> <username> <password> [max-iterations]
#
# Uses array-based govc guest.run (absolute PATH + separate ARGs) throughout.

VM_NAME="${1:-}"
USERNAME="${2:-Administrator}"
PASSWORD="${3:-}"
MAX_ITER="${4:-10}"

if [[ -z "$VM_NAME" ]] || [[ -z "$PASSWORD" ]]; then
    echo "Usage: $0 <vm-name> <username> <password> [max-iterations]"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GOVC_OPTS=(-vm "$VM_NAME" -l "${USERNAME}:${PASSWORD}")
PS_EXE="C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe"
CMD_EXE="C:\\Windows\\System32\\cmd.exe"

# Wait for VM to respond to guest.run (poll cmd.exe /c echo READY), timeout 600s
wait_for_vm_ready() {
    local elapsed=0
    local ready_cmd=("$CMD_EXE" "/c" "echo READY")
    while [[ $elapsed -lt 600 ]]; do
        sleep 10
        elapsed=$((elapsed + 10))
        local test_out
        test_out=$(govc guest.run "${GOVC_OPTS[@]}" "${ready_cmd[@]}" 2>/dev/null)
        local govc_ret=$?
        if [[ $govc_ret -eq 0 ]] && echo "$test_out" | grep -q "READY"; then
            echo "VM is ready"
            return 0
        fi
    done
    echo "VM did not become ready within timeout"
    return 1
}

iteration=0

while [[ $iteration -lt $MAX_ITER ]]; do
    iteration=$((iteration + 1))
    echo "=========================================="
    echo "Iteration $iteration"
    echo "=========================================="

    # Check for pending reboot BEFORE uploading scripts (array-based)
    echo "Checking for pending reboot..."
    REBOOT_CHECK_CMD=(
        "$PS_EXE"
        "-NoProfile"
        "-Command"
        "Test-Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\WindowsUpdate\\Auto Update\\RebootRequired'"
    )
    REBOOT_OUTPUT=$(govc guest.run "${GOVC_OPTS[@]}" "${REBOOT_CHECK_CMD[@]}" 2>&1) || true

    if echo "$REBOOT_OUTPUT" | grep -qi "True"; then
        echo "Pending reboot detected - rebooting VM first..."
        govc vm.power -r "$VM_NAME" >/dev/null 2>&1 || {
            echo "Failed to reboot, trying shutdown and power on..."
            govc vm.power -s "$VM_NAME" >/dev/null 2>&1
            sleep 30
            govc vm.power -on "$VM_NAME" >/dev/null 2>&1
        }
        echo "Waiting for VM to boot after reboot..."
        if ! wait_for_vm_ready; then
            exit 1
        fi
        sleep 30
    fi

    # Delete existing scripts then upload (array-based cleanup)
    echo "Uploading PowerShell scripts..."
    DEL_SCRIPTS_CMD=(
        "$CMD_EXE"
        "/c"
        "del /f /q C:\\Windows\\Temp\\install-windows-updates.ps1 C:\\Windows\\Temp\\check-updates-after-reboot.ps1"
    )
    govc guest.run "${GOVC_OPTS[@]}" "${DEL_SCRIPTS_CMD[@]}" >/dev/null 2>&1 || true

    govc guest.upload -vm "$VM_NAME" -l "${USERNAME}:${PASSWORD}" \
        "$SCRIPT_DIR/install-windows-updates.ps1" \
        "C:\\Windows\\Temp\\install-windows-updates.ps1" 2>&1 || {
        echo "Failed to upload install-windows-updates.ps1"
        exit 1
    }
    govc guest.upload -vm "$VM_NAME" -l "${USERNAME}:${PASSWORD}" \
        "$SCRIPT_DIR/check-updates-after-reboot.ps1" \
        "C:\\Windows\\Temp\\check-updates-after-reboot.ps1" 2>&1 || {
        echo "Failed to upload check-updates-after-reboot.ps1"
        exit 1
    }
    echo "Scripts uploaded"

    # Check for updates (array-based; capture exit code via temp file)
    echo "Checking for updates..."
    CHECK_CMD=(
        "$PS_EXE"
        "-ExecutionPolicy" "Bypass"
        "-NoProfile"
        "-File" "C:\\Windows\\Temp\\check-updates-after-reboot.ps1"
    )
    TEMP_CHECK=$(mktemp /tmp/govc-check-updates.XXXXXX)
    trap 'rm -f "$TEMP_CHECK"' EXIT INT TERM
    govc guest.run "${GOVC_OPTS[@]}" "${CHECK_CMD[@]}" > "$TEMP_CHECK" 2>&1
    CHECK_EXIT=$?

    if [[ $CHECK_EXIT -eq 0 ]]; then
        echo "No updates pending - complete"
        rm -f "$TEMP_CHECK"
        exit 0
    fi

    # Install updates (array-based; capture exit code)
    echo "Installing updates..."
    INSTALL_CMD=(
        "$PS_EXE"
        "-ExecutionPolicy" "Bypass"
        "-NoProfile"
        "-File" "C:\\Windows\\Temp\\install-windows-updates.ps1"
    )
    TEMP_INSTALL=$(mktemp /tmp/govc-install-updates.XXXXXX)
    trap 'rm -f "$TEMP_CHECK" "$TEMP_INSTALL"' EXIT INT TERM
    govc guest.run "${GOVC_OPTS[@]}" "${INSTALL_CMD[@]}" > "$TEMP_INSTALL" 2>&1
    INSTALL_EXIT=$?

    if [[ $INSTALL_EXIT -eq 3010 ]]; then
        echo "Reboot required. Restarting VM..."
        govc vm.power -s "$VM_NAME" >/dev/null 2>&1 || {
            echo "Failed to shutdown VM gracefully, forcing power off..."
            govc vm.power -off "$VM_NAME" >/dev/null 2>&1
        }
        echo "Waiting for VM to shutdown..."
        sleep 30
        echo "Powering on VM..."
        govc vm.power -on "$VM_NAME" >/dev/null 2>&1
        echo "Waiting for VM to boot..."
        if ! wait_for_vm_ready; then
            rm -f "$TEMP_CHECK" "$TEMP_INSTALL"
            exit 1
        fi
        rm -f "$TEMP_CHECK" "$TEMP_INSTALL"
        sleep 30
        continue
    fi

    if [[ $INSTALL_EXIT -eq 0 ]]; then
        echo "Updates finished. No reboot needed."
        rm -f "$TEMP_CHECK" "$TEMP_INSTALL"
        exit 0
    fi

    echo "Update script failed with code $INSTALL_EXIT"
    cat "$TEMP_INSTALL" >&2
    rm -f "$TEMP_CHECK" "$TEMP_INSTALL"
    exit "$INSTALL_EXIT"
done

echo "Reached max iterations"
exit 1
