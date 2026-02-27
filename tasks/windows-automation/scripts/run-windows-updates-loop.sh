#!/usr/bin/env bash
# Windows Updates Automation Loop
# Usage: run-windows-updates-loop.sh <vm-name> <username> <password> [max-iterations]
#
# Uses govc guest.start (not guest.run) so Windows guests work with standard VMware Tools.
# guest.run uses /bin/bash and fails with "File /bin/bash was not found".

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

# Wait for VM to respond: run cmd.exe /c "echo READY" via guest.start, wait, check exit code. Timeout 600s.
wait_for_vm_ready() {
    local elapsed=0
    while [[ $elapsed -lt 600 ]]; do
        sleep 10
        elapsed=$((elapsed + 10))
        local pid
        pid=$(govc guest.start "${GOVC_OPTS[@]}" "$CMD_EXE" "/c" "echo READY" 2>/dev/null) || true
        if [[ -z "$pid" ]]; then
            continue
        fi
        govc guest.ps "${GOVC_OPTS[@]}" -p "$pid" -X >/dev/null 2>&1
        local code
        code=$(govc guest.ps "${GOVC_OPTS[@]}" -p "$pid" -x 2>/dev/null | awk -v p="$pid" '$1==p {print $2; exit}')
        if [[ "${code:-1}" == "0" ]]; then
            echo "VM is ready"
            return 0
        fi
    done
    echo "VM did not become ready within timeout"
    return 1
}

# Run a PowerShell -Command on guest via guest.start; return exit code. Output is discarded.
guest_ps_run_exit() {
    local cmd="$1"
    local pid
    pid=$(govc guest.start "${GOVC_OPTS[@]}" "$PS_EXE" "-ExecutionPolicy" "Bypass" "-NoProfile" "-Command" "$cmd" 2>/dev/null) || { echo "1"; return; }
    [[ -z "$pid" ]] && { echo "1"; return; }
    govc guest.ps "${GOVC_OPTS[@]}" -p "$pid" -X >/dev/null 2>&1
    local code
    code=$(govc guest.ps "${GOVC_OPTS[@]}" -p "$pid" -x -json 2>/dev/null | grep -o '"exitCode":[0-9]*' | head -1 | sed 's/"exitCode"://')
    [[ -z "$code" ]] && code=$(govc guest.ps "${GOVC_OPTS[@]}" -p "$pid" -x 2>/dev/null | awk -v p="$pid" '$1==p {print $2; exit}')
    echo "${code:-0}"
}

# Run PowerShell -Command and capture output to a guest temp file; output is printed to stdout, exit code is in global GUEST_PS_EXIT (or last line).
guest_ps_run_capture() {
    local cmd="$1"
    local out_path
    out_path=$(govc guest.mktemp "${GOVC_OPTS[@]}" 2>/dev/null) || { echo ""; GUEST_PS_EXIT=1; return 1; }
    local run_cmd="& { $cmd *>&1 } | Out-File -FilePath '$out_path' -Encoding utf8"
    local pid
    pid=$(govc guest.start "${GOVC_OPTS[@]}" "$PS_EXE" "-ExecutionPolicy" "Bypass" "-NoProfile" "-Command" "$run_cmd" 2>/dev/null) || { GUEST_PS_EXIT=1; return 1; }
    [[ -z "$pid" ]] && { GUEST_PS_EXIT=1; return 1; }
    govc guest.ps "${GOVC_OPTS[@]}" -p "$pid" -X >/dev/null 2>&1
    local code
    code=$(govc guest.ps "${GOVC_OPTS[@]}" -p "$pid" -x -json 2>/dev/null | grep -o '"exitCode":[0-9]*' | head -1 | sed 's/"exitCode"://')
    [[ -z "$code" ]] && code=$(govc guest.ps "${GOVC_OPTS[@]}" -p "$pid" -x 2>/dev/null | awk -v p="$pid" '$1==p {print $2; exit}')
    GUEST_PS_EXIT=${code:-0}
    govc guest.download "${GOVC_OPTS[@]}" "$out_path" - 2>/dev/null || true
    local pid_del
    pid_del=$(govc guest.start "${GOVC_OPTS[@]}" "$CMD_EXE" "/c" "del /f /q \"$out_path\"" 2>/dev/null) || true
    [[ -n "$pid_del" ]] && govc guest.ps "${GOVC_OPTS[@]}" -p "$pid_del" -X >/dev/null 2>&1 || true
    # Caller can use GUEST_PS_EXIT if needed
    return 0
}

iteration=0

while [[ $iteration -lt $MAX_ITER ]]; do
    iteration=$((iteration + 1))
    echo "=========================================="
    echo "Iteration $iteration"
    echo "=========================================="

    # Check for pending reboot via guest.start
    echo "Checking for pending reboot..."
    REBOOT_CMD="Test-Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\WindowsUpdate\\Auto Update\\RebootRequired'"
    REBOOT_OUTPUT=$(guest_ps_run_capture "$REBOOT_CMD" 2>/dev/null)
    if [[ "${GUEST_PS_EXIT:-1}" == "0" ]] && echo "$REBOOT_OUTPUT" | grep -qi "True"; then
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

    # Delete existing scripts on guest via guest.start
    echo "Uploading PowerShell scripts..."
    PID_DEL=$(govc guest.start "${GOVC_OPTS[@]}" "$CMD_EXE" "/c" "del /f /q C:\\Windows\\Temp\\install-windows-updates.ps1 C:\\Windows\\Temp\\check-updates-after-reboot.ps1" 2>/dev/null) || true
    [[ -n "$PID_DEL" ]] && govc guest.ps "${GOVC_OPTS[@]}" -p "$PID_DEL" -X >/dev/null 2>&1 || true

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

    # Check for updates via guest.start (run script, capture exit code)
    echo "Checking for updates..."
    CHECK_EXIT=$(guest_ps_run_exit "& { & 'C:\\Windows\\Temp\\check-updates-after-reboot.ps1'; exit \$LASTEXITCODE }")

    if [[ "${CHECK_EXIT:-1}" == "0" ]]; then
        echo "No updates pending - complete"
        exit 0
    fi

    # Install updates via guest.start (run script, get exit code).
    # Note: Output is not captured; on failure check VM or logs if you need install output.
    echo "Installing updates..."
    INSTALL_EXIT=$(guest_ps_run_exit "& { & 'C:\\Windows\\Temp\\install-windows-updates.ps1'; exit \$LASTEXITCODE }")

    if [[ "$INSTALL_EXIT" == "3010" ]]; then
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
            exit 1
        fi
        sleep 30
        continue
    fi

    if [[ "$INSTALL_EXIT" == "0" ]]; then
        echo "Updates finished. No reboot needed."
        exit 0
    fi

    echo "Update script failed with code $INSTALL_EXIT"
    exit "${INSTALL_EXIT:-1}"
done

echo "Reached max iterations"
exit 1
