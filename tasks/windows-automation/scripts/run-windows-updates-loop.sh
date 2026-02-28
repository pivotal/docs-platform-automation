#!/usr/bin/env bash
# Uses govc guest.start for all guest operations (no guest.run).
#
# Usage: run-windows-updates-loop.sh <vm-name> <username> <password> [max-iterations]

VM_NAME="${1:-}"
USERNAME="${2:-Administrator}"
PASSWORD="${3:-}"
MAX_ITER="${4:-10}"

[[ "${DEBUG_MODE:-}" == "true" ]] && set -x

if [[ -z "$VM_NAME" ]] || [[ -z "$PASSWORD" ]]; then
    echo "Usage: $0 <vm-name> <username> <password> [max-iterations]"
    exit 1
fi

# Script directory (must be set before sourcing libs; path is where this script lives)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VM_POWER_UTILS="$SCRIPT_DIR/vm-power-utils.sh"
[[ -f "$VM_POWER_UTILS" ]] || { echo "ERROR: vm-power-utils.sh not found: $VM_POWER_UTILS" >&2; exit 1; }
source "$VM_POWER_UTILS"

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
        local raw
        raw=$(govc guest.ps "${GOVC_OPTS[@]}" -p "$pid" -X -x 2>/dev/null)
        local code
        # govc guest.ps -x outputs a table: UID PID STIME XTIME XCODE CMD (not JSON)
        code=$(echo "$raw" | awk -v p="$pid" 'NR>1 && $2+0==p+0 {print $5; exit}')
        [[ -z "$code" ]] && code=$(echo "$raw" | grep -o '"exitCode":[0-9]*' | head -1 | sed 's/"exitCode"://')
        if [[ "${code:-1}" == "0" ]]; then
            echo "VM is ready"
            return 0
        fi
    done
    echo "VM did not become ready within timeout"
    return 1
}

# After a reboot, wait until the system is ready for the next commands (guest ops + settle + PowerShell responsive).
# Uses wait_for_vm_ready(), then a settle sleep, then retries a simple PowerShell command until it succeeds.
wait_for_system_ready_after_reboot() {
    local settle_sec="${REBOOT_SETTLE_SECONDS:-60}"
    echo "Waiting for VM to boot (guest ops)..."
    if ! wait_for_vm_ready; then
        return 1
    fi
    echo "Guest ops responsive; waiting ${settle_sec}s for system to settle after reboot..."
    sleep "$settle_sec"
    # Ensure PowerShell is responsive (Windows may still be "Configuring updates" for a while)
    local probe_attempts=0
    local max_probes=12
    while [[ $probe_attempts -lt $max_probes ]]; do
        probe_attempts=$((probe_attempts + 1))
        local probe_exit
        probe_exit=$(guest_ps_run_exit "Get-Date | Out-Null; exit 0")
        if [[ "${probe_exit:-1}" == "0" ]]; then
            echo "System ready (PowerShell responsive after ${probe_attempts} probe(s))."
            return 0
        fi
        echo "PowerShell not ready yet, waiting 30s before retry ($probe_attempts/$max_probes)..."
        sleep 30
    done
    echo "System did not become ready within probe timeout"
    return 1
}

# Run a PowerShell -Command on guest via guest.start; return exit code. Output is discarded.
# Use -X -x in one call so we wait and get exit code without a second query (avoids race with reaped process).
guest_ps_run_exit() {
    local cmd="$1"
    local pid
    pid=$(govc guest.start "${GOVC_OPTS[@]}" "$PS_EXE" "-ExecutionPolicy" "Bypass" "-NoProfile" "-NoLogo" "-NonInteractive" "-Command" "$cmd" 2>/dev/null) || { echo "1"; return; }
    [[ -z "$pid" ]] && { echo "1"; return; }
    local raw
    raw=$(govc guest.ps "${GOVC_OPTS[@]}" -p "$pid" -X -x 2>/dev/null)
    local code
    # govc guest.ps -x outputs a table: UID PID STIME XTIME XCODE CMD (not JSON)
    code=$(echo "$raw" | awk -v p="$pid" 'NR>1 && $2+0==p+0 {print $5; exit}')
    [[ -z "$code" ]] && code=$(echo "$raw" | grep -o '"exitCode":[0-9]*' | head -1 | sed 's/"exitCode"://')
    echo "${code:-0}"
}

# Run PowerShell -Command and capture output to a guest temp file; output is printed to stdout, exit code is in global GUEST_PS_EXIT (or last line).
# We must run the command, capture its exit code, write output to file, then exit with that code - otherwise a pipeline (cmd | Out-File)
# would make the process exit 0 (Out-File) and we'd lose 3010 (reboot required) and other script exit codes.
guest_ps_run_capture() {
    local cmd="$1"
    local out_path
    out_path=$(govc guest.mktemp "${GOVC_OPTS[@]}" 2>/dev/null) || { echo ""; GUEST_PS_EXIT=1; return 1; }
    local run_cmd="& { \$out = ( & { $cmd } 2>&1 ); \$code = \$LASTEXITCODE; \$out | Out-File -FilePath '$out_path' -Encoding utf8; exit \$code }"
    local pid
    pid=$(govc guest.start "${GOVC_OPTS[@]}" "$PS_EXE" "-ExecutionPolicy" "Bypass" "-NoProfile" "-NoLogo" "-NonInteractive" "-Command" "$run_cmd" 2>/dev/null) || { GUEST_PS_EXIT=1; return 1; }
    [[ -z "$pid" ]] && { GUEST_PS_EXIT=1; return 1; }
    local raw
    raw=$(govc guest.ps "${GOVC_OPTS[@]}" -p "$pid" -X -x 2>/dev/null)
    local code
    # govc guest.ps -x outputs a table: UID PID STIME XTIME XCODE CMD (not JSON)
    code=$(echo "$raw" | awk -v p="$pid" 'NR>1 && $2+0==p+0 {print $5; exit}')
    [[ -z "$code" ]] && code=$(echo "$raw" | grep -o '"exitCode":[0-9]*' | head -1 | sed 's/"exitCode"://')
    GUEST_PS_EXIT=${code:-0}
    govc guest.download "${GOVC_OPTS[@]}" "$out_path" - 2>/dev/null || true
    local pid_del
    pid_del=$(govc guest.start "${GOVC_OPTS[@]}" "$CMD_EXE" "/c" "del /f /q \"$out_path\"" 2>/dev/null) || true
    [[ -n "$pid_del" ]] && govc guest.ps "${GOVC_OPTS[@]}" -p "$pid_del" -X >/dev/null 2>&1 || true
    # Caller can use GUEST_PS_EXIT if needed
    return 0
}

iteration=0

# Flow: each iteration we (1) if reboot pending, reboot and continue (2) check for updates; if none, exit 0 (3) install updates;
# if exit 3010 or output contains REBOOT_REQUIRED, reboot and continue (4) if exit 0, done; else fail. Repeat until no updates or max iterations.
while [[ $iteration -lt $MAX_ITER ]]; do
    iteration=$((iteration + 1))
    echo "=========================================="
    echo "Iteration $iteration"
    echo "=========================================="

    # Check for pending reboot via guest.start (run in current shell so GUEST_PS_EXIT is set)
    echo "Checking for pending reboot..."
    REBOOT_CMD="Test-Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\WindowsUpdate\\Auto Update\\RebootRequired'"
    reboot_output_file=$(mktemp)
    guest_ps_run_capture "$REBOOT_CMD" > "$reboot_output_file" 2>/dev/null
    REBOOT_OUTPUT=$(cat "$reboot_output_file" 2>/dev/null)
    rm -f "$reboot_output_file"
    if [[ "${GUEST_PS_EXIT:-1}" == "0" ]] && echo "$REBOOT_OUTPUT" | grep -qi "True"; then
        echo "Pending reboot detected - rebooting VM first (shutdown then power on)..."
        vm_reboot_shutdown_poweron "$VM_NAME" 120 || exit 1
        echo "Waiting for VM to boot after reboot..."
        if ! wait_for_system_ready_after_reboot; then
            exit 1
        fi
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

    # Install updates via guest.start; capture output so we can print it on failure (Concourse has no log file access).
    # Run guest_ps_run_capture in the current shell (not in a subshell) so GUEST_PS_EXIT is set correctly (3010 = reboot required).
    # If we used INSTALL_OUTPUT=$(guest_ps_run_capture ...), GUEST_PS_EXIT would be set only in the subshell and lost.
    echo "Installing updates..."
    install_output_file=$(mktemp)
    guest_ps_run_capture "& { & 'C:\\Windows\\Temp\\install-windows-updates.ps1'; exit \$LASTEXITCODE }" > "$install_output_file" 2>/dev/null
    INSTALL_EXIT="${GUEST_PS_EXIT:-1}"
    INSTALL_OUTPUT=$(cat "$install_output_file" 2>/dev/null)
    rm -f "$install_output_file"

    if [[ "$INSTALL_EXIT" == "3010" ]]; then
        # 3010 = Windows Update "reboot required" success; we reboot and continue the loop
        echo "Reboot required (exit 3010). Restarting VM (shutdown then power on)..."
        vm_reboot_shutdown_poweron "$VM_NAME" 120 || exit 1
        echo "Waiting for VM to boot..."
        if ! wait_for_system_ready_after_reboot; then
            exit 1
        fi
        continue
    fi

    # Fallback: script may have exited 3010 but process reported 0 (e.g. pipeline swallowed exit code).
    # If output contains REBOOT_REQUIRED, treat as success and reboot.
    if echo "${INSTALL_OUTPUT:-}" | grep -qi "REBOOT_REQUIRED"; then
        echo "Reboot required (found REBOOT_REQUIRED in output; exit code was $INSTALL_EXIT). Restarting VM (shutdown then power on)..."
        vm_reboot_shutdown_poweron "$VM_NAME" 120 || exit 1
        echo "Waiting for VM to boot..."
        if ! wait_for_system_ready_after_reboot; then
            exit 1
        fi
        continue
    fi

    if [[ "$INSTALL_EXIT" == "0" ]]; then
        echo "Updates finished. No reboot needed."
        exit 0
    fi

    echo "ERROR: Windows Update install failed with exit code $INSTALL_EXIT"
    echo "--- Captured script output (so you see it in Concourse) ---"
    if [[ -n "$INSTALL_OUTPUT" ]]; then
        echo "$INSTALL_OUTPUT"
    else
        echo "(no output captured)"
    fi
    echo "--- End of script output ---"
    exit "${INSTALL_EXIT:-1}"
done

echo "Reached max iterations"
exit 1
