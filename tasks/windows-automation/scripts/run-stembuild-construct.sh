#!/usr/bin/env bash
# Run stembuild construct on a Windows VM. Requires GOVC_*. govc and stembuild: use passed path if given, else from PATH.

set -euo pipefail
set -x

VM_NAME="${1:-}"
VM_IP="${2:-}"
VM_USER="${3:-}"
VM_PASS="${4:-}"
STEMBUILD_BINARY="${5:-}"
DATACENTER="${6:-}"
LOG_FILE="${7:-}"
GOVC_BINARY="${8:-}"

# Normalize VM name (CI may capture stray quotes/newlines)
VM_NAME=$(printf '%s' "$VM_NAME" | tr -d '\r\n' | sed -e 's/^[[:space:]"'\'']*//' -e 's/[[:space:]"'\'']*$//')

[[ -n "$LOG_FILE" ]] && exec > >(tee -a "$LOG_FILE") 2>&1

# --- Resolve govc: use passed path or govc from PATH ---
if [[ -n "$GOVC_BINARY" ]]; then
    export PATH="$(dirname "$GOVC_BINARY"):$PATH"
fi
command -v govc >/dev/null 2>&1 || { echo "Error: govc not found (set GOVC_BINARY or ensure govc in PATH)." >&2; exit 1; }

# --- Resolve stembuild: use passed path or stembuild from PATH ---
if [[ -z "$STEMBUILD_BINARY" ]]; then
    STEMBUILD_BINARY=$(command -v stembuild 2>/dev/null) || true
    [[ -n "$STEMBUILD_BINARY" ]] || { echo "Error: stembuild not found (pass stembuild path or ensure stembuild in PATH)." >&2; exit 1; }
fi

# --- Validate required args ---
missing=""
[[ -z "$VM_NAME" ]] && missing="vm-name"
[[ -z "$VM_IP" ]] && missing="$missing vm-ip"
[[ -z "$VM_USER" ]] && missing="$missing vm-username"
[[ -z "$VM_PASS" ]] && missing="$missing vm-password"
if [[ -n "$missing" ]]; then
    echo "Usage: $0 <vm-name> <vm-ip> <vm-username> <vm-password> [stembuild-binary] [datacenter] [log-file] [govc-binary]"
    exit 1
fi
[[ -n "${GOVC_URL:-}" ]] && [[ -n "${GOVC_USERNAME:-}" ]] && [[ -n "${GOVC_PASSWORD:-}" ]] || {
    echo "Error: GOVC_URL, GOVC_USERNAME, GOVC_PASSWORD must be set." >&2
    exit 1
}

govc about >/dev/null 2>&1 || { echo "Error: govc cannot reach vCenter. Check GOVC_* and network." >&2; exit 1; }

# --- Resolve VM inventory path ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=govc-vm-utils.sh
source "$SCRIPT_DIR/govc-vm-utils.sh"
VM_INVENTORY_PATH=$(find_vm_inventory_path "$VM_NAME" "$DATACENTER") || exit 1

echo "=== stembuild construct ==="
echo "VM: $VM_NAME | IP: $VM_IP | $(date)"

# --- Run stembuild construct ---
CONSTRUCT_ARGS=(
    -vm-ip "$VM_IP"
    -vm-username "$VM_USER"
    -vm-password "$VM_PASS"
    -vcenter-url "$GOVC_URL"
    -vcenter-username "$GOVC_USERNAME"
    -vcenter-password "$GOVC_PASSWORD"
    -vm-inventory-path "$VM_INVENTORY_PATH"
)
[[ -n "${VCENTER_CA_CERTS:-}" ]] && [[ -f "${VCENTER_CA_CERTS}" ]] && CONSTRUCT_ARGS+=( -vcenter-ca-certs "$VCENTER_CA_CERTS" )

"$STEMBUILD_BINARY" construct "${CONSTRUCT_ARGS[@]}"
echo "=== stembuild construct completed ==="
