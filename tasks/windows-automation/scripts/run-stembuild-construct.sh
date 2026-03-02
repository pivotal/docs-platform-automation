#!/usr/bin/env bash
# Run stembuild construct on VM
# This script automates the construction of the BOSH stemcell

set -euo pipefail
set -x

# Required Arguments
VM_NAME="${1:-}"
VM_IP="${2:-}"
VM_USER="${3:-}"
VM_PASS="${4:-}"
STEMBUILD_BINARY="${5:-}"
DATACENTER="${6:-}"
LOG_FILE="${7:-}"

# Setup logging
if [[ -n "$LOG_FILE" ]]; then
    exec > >(tee -a "$LOG_FILE") 2>&1
fi

# Validation
if [[ -z "$VM_NAME" ]] || [[ -z "$VM_IP" ]] || [[ -z "$VM_USER" ]] || [[ -z "$VM_PASS" ]] || [[ -z "$STEMBUILD_BINARY" ]]; then
    echo "Usage: $0 <vm-name> <vm-ip> <vm-username> <vm-password> <stembuild-binary> [datacenter] [log-file]"
    exit 1
fi

if ! command -v govc >/dev/null 2>&1; then
    echo "Error: govc command not found. Ensure PATH includes the directory containing govc (e.g. export PATH=\"\$HOME:\$PATH\" if govc is in \$HOME)."
    exit 1
fi
GOVC_CMD=$(command -v govc)
echo "Using govc: $GOVC_CMD"

if [[ -z "${GOVC_URL:-}" ]] || [[ -z "${GOVC_USERNAME:-}" ]] || [[ -z "${GOVC_PASSWORD:-}" ]]; then
    echo "Error: GOVC_URL, GOVC_USERNAME, and GOVC_PASSWORD must be set (export them before running this script)."
    echo "govc find will not work without vCenter connection."
    exit 1
fi
echo "GOVC_* are set (vCenter: ${GOVC_URL})"

# Verify govc can run and connect to vCenter (catches PATH/connection issues early)
echo "Checking govc connection to vCenter..."
govc_about_rc=0
govc_about_out=$(govc about 2>&1) || govc_about_rc=$?
echo "$govc_about_out"
if [[ $govc_about_rc -ne 0 ]]; then
    echo "Error: govc about failed (exit $govc_about_rc). Check GOVC_* and network connectivity to vCenter."
    exit 1
fi

echo "=========================================="
echo "Running stembuild construct"
echo "VM Name: $VM_NAME"
echo "VM IP:   $VM_IP"
echo "Timestamp: $(date)"
echo "=========================================="

# Find VM inventory path using govc (use -dc to scope to datacenter and avoid "matches N objects" from /dc/...)
VM_PATH=""
if [[ -n "$DATACENTER" ]]; then
    # -dc scopes the search to this datacenter; / as root works (user-confirmed)
    VM_PATH=$(govc find / -type m -name "$VM_NAME" -dc "$DATACENTER" 2>&1 | head -n1)
    # If govc printed an error line (e.g. "govc: ..."), clear VM_PATH so we don't use it
    if [[ -n "$VM_PATH" ]] && [[ "$VM_PATH" == govc:* ]]; then
        echo "govc find stderr: $VM_PATH"
        VM_PATH=""
    fi
fi
if [[ -z "$VM_PATH" ]]; then
    VM_PATH=$(govc find / -type m -name "$VM_NAME" 2>&1 | head -n1)
    if [[ -n "$VM_PATH" ]] && [[ "$VM_PATH" == govc:* ]]; then
        echo "govc find stderr: $VM_PATH"
        VM_PATH=""
    fi
fi
if [[ -z "$VM_PATH" ]]; then
    VM_PATH=$(govc find vm -name "$VM_NAME" 2>&1 | head -n1)
    if [[ -n "$VM_PATH" ]] && [[ "$VM_PATH" == govc:* ]]; then
        echo "govc find stderr: $VM_PATH"
        VM_PATH=""
    fi
fi
if [[ -z "$VM_PATH" ]]; then
    echo "Error: VM not found in vCenter: $VM_NAME"
    echo "Tip: Set GOVC_DATACENTER to your datacenter (e.g. $DATACENTER) or ensure GOVC_URL points to the right vCenter."
    exit 1
fi

# govc find returns path like /datacenter/vm/folder/vmname; use as-is if absolute
if [[ "$VM_PATH" == /* ]]; then
    VM_INVENTORY_PATH="$VM_PATH"
else
    VM_INVENTORY_PATH="/$DATACENTER/$VM_PATH"
fi

echo "VM Inventory Path: $VM_INVENTORY_PATH"

# Array-based invocation (no eval): build args and run stembuild construct
CONSTRUCT_ARGS=(
    -vm-ip "$VM_IP"
    -vm-username "$VM_USER"
    -vm-password "$VM_PASS"
    -vcenter-url "$GOVC_URL"
    -vcenter-username "$GOVC_USERNAME"
    -vcenter-password "$GOVC_PASSWORD"
    -vm-inventory-path "$VM_INVENTORY_PATH"
)
if [[ -n "${VCENTER_CA_CERTS:-}" ]] && [[ -f "${VCENTER_CA_CERTS}" ]]; then
    CONSTRUCT_ARGS+=( -vcenter-ca-certs "$VCENTER_CA_CERTS" )
fi

echo "Executing stembuild construct..."
echo "This process involves running preparation scripts on the guest VM."
echo ""

"$STEMBUILD_BINARY" construct "${CONSTRUCT_ARGS[@]}"

echo ""
echo "=========================================="
echo "stembuild construct completed successfully"
echo "Timestamp: $(date)"
echo "=========================================="