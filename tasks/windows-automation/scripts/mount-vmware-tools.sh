#!/usr/bin/env bash
# Mount VMware Tools ISO on VM using standard vSphere path
# Usage: mount-vmware-tools.sh <vm-name> [log-file]

VM_NAME="${1:-}"
LOG_FILE="${2:-}"

# Setup logging
if [[ -n "$LOG_FILE" ]]; then
    exec > >(tee -a "$LOG_FILE") 2>&1
fi

if [[ -z "$VM_NAME" ]]; then
    echo "ERROR: VM name is required"
    echo "Usage: $0 <vm-name> [log-file]"
    exit 1
fi

if ! command -v govc >/dev/null 2>&1; then
    echo "ERROR: govc command not found"
    exit 1
fi

echo "=========================================="
echo "Mounting VMware Tools ISO"
echo "VM Name: $VM_NAME"
echo "Timestamp: $(date)"
echo "=========================================="

# Verify VM exists before attempting mount
echo "Step 1: Verifying VM exists..."
if ! govc vm.info "$VM_NAME" >/dev/null 2>&1; then
    echo "ERROR: VM not found: $VM_NAME"
    echo "Available VMs (first 10):"
    govc ls / -t VirtualMachine 2>/dev/null | head -10 || echo "Could not list VMs"
    exit 1
fi
echo "✓ VM found: $VM_NAME"

# Get VM power state
echo "Step 2: Checking VM power state..."
VM_POWER_STATE=$(govc vm.info "$VM_NAME" 2>/dev/null | grep -i "powered" | head -1 || echo "")
echo "VM Power State: $VM_POWER_STATE"

# Mount VMware Tools ISO using govc (without specifying ISO path)
# govc will automatically use the standard VMware Tools ISO from vSphere
echo "Step 3: Mounting VMware Tools ISO..."
MOUNT_OUTPUT=$(govc vm.guest.tools -mount "$VM_NAME" 2>&1)
MOUNT_EXIT_CODE=$?

if [[ $MOUNT_EXIT_CODE -ne 0 ]]; then
    echo "ERROR: Failed to mount VMware Tools ISO"
    echo "Exit code: $MOUNT_EXIT_CODE"
    echo "Output: $MOUNT_OUTPUT"
    exit 1
fi

echo "Mount command output: $MOUNT_OUTPUT"
echo "✓ Mount command executed successfully"

# Wait for mount to complete
echo "Step 4: Waiting for mount to complete..."
sleep 10

# Verify mount using PowerShell via govc guest.start (or guest.run when guest is detected as Windows).
# When the guest is not detected as Windows, guest.run uses /bin/bash and fails.
# Note: This requires VMware Tools to be installed, so it may not work on first mount
echo "Step 5: Verifying mount status..."
if [[ -n "${GOVC_USERNAME:-}" ]] && [[ -n "${GOVC_PASSWORD:-}" ]]; then
    GOVC_OPTS=(-vm "$VM_NAME" -l "${GOVC_USERNAME}:${GOVC_PASSWORD}")
    PS_EXE="C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe"
    VERIFY_CMD="if (Test-Path 'D:\\setup64.exe') { Write-Host 'SUCCESS: D:\\setup64.exe found' } else { Write-Host 'WARNING: D:\\setup64.exe not found yet' }"
    OUT_PATH=$(govc guest.mktemp "${GOVC_OPTS[@]}" 2>/dev/null) || true
    if [[ -n "$OUT_PATH" ]]; then
        RUN_CMD="& { $VERIFY_CMD *>&1 } | Out-File -FilePath '$OUT_PATH' -Encoding utf8"
        PID_PS=$(govc guest.start "${GOVC_OPTS[@]}" "$PS_EXE" "-ExecutionPolicy" "Bypass" "-NoProfile" "-NoLogo" "-NonInteractive" "-Command" "$RUN_CMD" 2>/dev/null) || true
        if [[ -n "$PID_PS" ]]; then
            govc guest.ps "${GOVC_OPTS[@]}" -p "$PID_PS" -X >/dev/null 2>&1
            VERIFY_OUTPUT=$(govc guest.download "${GOVC_OPTS[@]}" "$OUT_PATH" - 2>/dev/null) || VERIFY_OUTPUT="VERIFY_FAILED"
            PID_DEL=$(govc guest.start "${GOVC_OPTS[@]}" "C:\\Windows\\System32\\cmd.exe" "/c" "del /f /q \"$OUT_PATH\"" 2>/dev/null) || true
            [[ -n "$PID_DEL" ]] && govc guest.ps "${GOVC_OPTS[@]}" -p "$PID_DEL" -X >/dev/null 2>&1 || true
        else
            VERIFY_OUTPUT="VERIFY_FAILED"
        fi
    else
        VERIFY_OUTPUT="VERIFY_FAILED"
    fi

    if [[ "$VERIFY_OUTPUT" == *"SUCCESS"* ]]; then
        echo "✓ Verification: VMware Tools ISO is mounted (D:\setup64.exe found)"
    elif [[ "$VERIFY_OUTPUT" == *"VERIFY_FAILED"* ]]; then
        echo "⚠ Verification: Could not verify mount (VMware Tools may not be installed yet)"
        echo "  This is expected on first mount - mount should still be successful"
    else
        echo "⚠ Verification: D:\setup64.exe not found yet (may need more time)"
        echo "  Mount command succeeded, but verification inconclusive"
    fi
else
    echo "⚠ Verification: Guest credentials not available, skipping verification"
    echo "  Mount command succeeded, but cannot verify mount status"
fi

echo "=========================================="
echo "VMware Tools ISO mount completed"
echo "VM: $VM_NAME"
echo "Timestamp: $(date)"
echo "=========================================="
exit 0
