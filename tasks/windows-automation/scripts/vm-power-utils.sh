#!/usr/bin/env bash
# Common VM power operations for govc (shutdown, wait for poweredOff, reboot via shutdown+powerOn).
# Source using SCRIPT_DIR so the path works from any working directory:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "$SCRIPT_DIR/vm-power-utils.sh"        # when caller is in scripts/
#   source "$SCRIPT_DIR/scripts/vm-power-utils.sh"   # when caller is in windows-automation/
# Callers should set SCRIPT_DIR to the directory containing the *caller* script.
# Optional: [[ -f "$SCRIPT_DIR/.../vm-power-utils.sh" ]] || { echo "ERROR: not found" >&2; exit 1; } before source.

# Returns 0 if VM exists (govc vm.info succeeds), 1 otherwise.
vm_exists() {
    local vm="${1:?usage: vm_exists vm_name}"
    govc vm.info "$vm" >/dev/null 2>&1
}

# Get VM power state (poweredOn, poweredOff, etc.). Output to stdout.
get_vm_power_state() {
    local vm="${1:?usage: get_vm_power_state vm_name}"
    govc vm.info -json "$vm" 2>/dev/null | jq -r '.virtualMachines[0].runtime.powerState' 2>/dev/null || echo "unknown"
}

# Wait for VM to reach poweredOff. Returns 0 when poweredOff, 1 on timeout.
# Usage: wait_for_vm_powered_off vm_name [timeout_sec]
wait_for_vm_powered_off() {
    local vm="${1:?usage: wait_for_vm_powered_off vm_name [timeout_sec]}"
    local timeout_sec="${2:-120}"
    local elapsed=0
    while [[ $elapsed -lt $timeout_sec ]]; do
        local power_state
        power_state=$(get_vm_power_state "$vm")
        if [[ "$power_state" == "poweredOff" ]]; then
            return 0
        fi
        sleep 5
        elapsed=$((elapsed + 5))
    done
    return 1
}

# Power off VM: graceful shutdown (-s), then force (-off) if needed; wait for poweredOff.
# Does NOT destroy or delete the VM — power-off only. Callers may destroy separately if needed.
# Usage: vm_power_off vm_name [timeout_sec] [strict]
#   strict: 1 (default) = return 1 on timeout; 0 = return 0 anyway (e.g. cleanup before destroy)
vm_power_off() {
    local vm="${1:?usage: vm_power_off vm_name [timeout_sec] [strict]}"
    local timeout_sec="${2:-300}"
    local strict="${3:-1}"
    local power_state
    power_state=$(get_vm_power_state "$vm")
    if [[ "$power_state" == "poweredOff" ]]; then
        return 0
    fi
    govc vm.power -s "$vm" >/dev/null 2>&1 || {
        govc vm.power -off "$vm" >/dev/null 2>&1 || return 1
    }
    if ! wait_for_vm_powered_off "$vm" "$timeout_sec"; then
        [[ "$strict" == "0" ]] && return 0
        return 1
    fi
    return 0
}

# Reboot VM using shutdown -> wait for poweredOff -> power on (no -r).
# Usage: vm_reboot_shutdown_poweron vm_name [timeout_sec]
vm_reboot_shutdown_poweron() {
    local vm="${1:?usage: vm_reboot_shutdown_poweron vm_name [timeout_sec]}"
    local timeout_sec="${2:-120}"
    govc vm.power -s "$vm" >/dev/null 2>&1 || govc vm.power -off "$vm" >/dev/null 2>&1
    if ! wait_for_vm_powered_off "$vm" "$timeout_sec"; then
        return 1
    fi
    sleep 5
    govc vm.power -on "$vm" >/dev/null 2>&1
    return 0
}
