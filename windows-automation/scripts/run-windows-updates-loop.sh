#!/usr/bin/env bash
# Windows Updates Automation Loop
# Usage: run-windows-updates-loop.sh <vm-name> <username> <password> [max-iterations]

VM_NAME="${1:-}"
USERNAME="${2:-Administrator}"
PASSWORD="${3:-}"
MAX_ITER="${4:-10}"

if [[ -z "$VM_NAME" ]] || [[ -z "$PASSWORD" ]]; then
    echo "Usage: $0 <vm-name> <username> <password> [max-iterations]"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
iteration=0

while [[ $iteration -lt $MAX_ITER ]]; do
    iteration=$((iteration + 1))
    echo "=========================================="
    echo "Iteration $iteration"
    echo "=========================================="
    
    # Check for pending reboot BEFORE uploading scripts
    echo "Checking for pending reboot..."
    REBOOT_CHECK_CMD="powershell.exe -Command \"Test-Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\WindowsUpdate\\Auto Update\\RebootRequired'\""
    REBOOT_OUTPUT=$(govc guest.run -vm "$VM_NAME" -l "${USERNAME}:${PASSWORD}" "$REBOOT_CHECK_CMD" 2>&1)
    
    if echo "$REBOOT_OUTPUT" | grep -qi "True"; then
        echo "Pending reboot detected - rebooting VM first..."
        govc vm.power -r "$VM_NAME" >/dev/null 2>&1 || {
            echo "Failed to reboot, trying shutdown and power on..."
            govc vm.power -s "$VM_NAME" >/dev/null 2>&1
            sleep 30
            govc vm.power -on "$VM_NAME" >/dev/null 2>&1
        }
        
        # Wait for VM to boot
        echo "Waiting for VM to boot after reboot..."
        elapsed=0
        while [[ $elapsed -lt 600 ]]; do
            sleep 10
            elapsed=$((elapsed + 10))
            TEST=$(govc guest.run -vm "$VM_NAME" -l "${USERNAME}:${PASSWORD}" "cmd.exe /c echo READY" 2>/dev/null)
            if [[ $? -eq 0 ]] && echo "$TEST" | grep -q "READY"; then
                echo "VM is ready after reboot"
                break
            fi
        done
        
        if [[ $elapsed -ge 600 ]]; then
            echo "VM did not boot within timeout"
            exit 1
        fi
        
        sleep 30
    fi
    
    # Upload scripts (after reboot check/reboot, if needed)
    # Delete existing files first to force overwrite, then upload
    echo "Uploading PowerShell scripts..."
    
    # Delete existing files if they exist (to force overwrite)
    govc guest.run -vm "$VM_NAME" -l "${USERNAME}:${PASSWORD}" \
        "cmd.exe /c del /f /q C:\\Windows\\Temp\\install-windows-updates.ps1 C:\\Windows\\Temp\\check-updates-after-reboot.ps1" >/dev/null 2>&1 || true
    
    # Upload scripts (will overwrite if they exist)
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
    
    # Check for updates
    echo "Checking for updates..."
    CHECK_CMD="C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe -ExecutionPolicy Bypass -NoProfile -File C:\\Windows\\Temp\\check-updates-after-reboot.ps1"
    CHECK_OUTPUT=$(govc guest.run -vm "$VM_NAME" -l "${USERNAME}:${PASSWORD}" "$CHECK_CMD" 2>&1)
    CHECK_EXIT=$?
    
    if [[ $CHECK_EXIT -eq 0 ]]; then
        echo "No updates pending - complete"
        exit 0
    fi
    
    # Install updates
    echo "Installing updates..."
    INSTALL_CMD="C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe -ExecutionPolicy Bypass -NoProfile -File C:\\Windows\\Temp\\install-windows-updates.ps1"
    govc guest.run -vm "$VM_NAME" -l "${USERNAME}:${PASSWORD}" "$INSTALL_CMD" >/dev/null 2>&1
    INSTALL_EXIT=$?
    
    if [[ $INSTALL_EXIT -ne 0 ]]; then
        echo "Update installation failed"
        exit 1
    fi
    
    # Wait a bit for updates to complete
    echo "Waiting for updates to complete..."
    sleep 60
    
    # Shutdown VM using govc
    echo "Shutting down VM..."
    govc vm.power -s "$VM_NAME" >/dev/null 2>&1 || {
        echo "Failed to shutdown VM gracefully, forcing power off..."
        govc vm.power -off "$VM_NAME" >/dev/null 2>&1
    }
    
    # Wait for VM to shutdown
    echo "Waiting for VM to shutdown..."
    sleep 30
    
    # Power on
    echo "Powering on VM..."
    govc vm.power -on "$VM_NAME" >/dev/null 2>&1
    
    # Wait for boot (10 minutes max, poll every 10 seconds)
    echo "Waiting for VM to boot..."
    elapsed=0
    while [[ $elapsed -lt 600 ]]; do
        sleep 10
        elapsed=$((elapsed + 10))
        TEST=$(govc guest.run -vm "$VM_NAME" -l "${USERNAME}:${PASSWORD}" "cmd.exe /c echo READY" 2>/dev/null)
        if [[ $? -eq 0 ]] && echo "$TEST" | grep -q "READY"; then
            echo "VM is ready"
            break
        fi
    done
    
    if [[ $elapsed -ge 600 ]]; then
        echo "VM did not boot within timeout"
        exit 1
    fi
    
    sleep 30
done

echo "Reached max iterations"
exit 1
