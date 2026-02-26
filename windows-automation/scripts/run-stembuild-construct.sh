#!/usr/bin/env bash
# Run stembuild construct on VM
# This script automates the construction of the BOSH stemcell

set -euo pipefail

# Required Arguments
VM_NAME="${1:-}"
VM_IP="${2:-}"
VM_USER="${3:-}"
VM_PASS="${4:-}"
STEMBUILD_BINARY="${5:-}"
LOG_FILE="${6:-}"

# Setup logging
if [[ -n "$LOG_FILE" ]]; then
    exec > >(tee -a "$LOG_FILE") 2>&1
fi

# Validation
if [[ -z "$VM_NAME" ]] || [[ -z "$VM_IP" ]] || [[ -z "$VM_USER" ]] || [[ -z "$VM_PASS" ]] || [[ -z "$STEMBUILD_BINARY" ]]; then
    echo "Usage: $0 <vm-name> <vm-ip> <vm-username> <vm-password> <stembuild-binary> [log-file]"
    exit 1
fi

if ! command -v govc >/dev/null 2>&1; then
    echo "Error: govc command not found. Ensure GOVC_URL, GOVC_USERNAME, and GOVC_PASSWORD are set."
    exit 1
fi

echo "=========================================="
echo "Running stembuild construct"
echo "VM Name: $VM_NAME"
echo "VM IP:   $VM_IP"
echo "Timestamp: $(date)"
echo "=========================================="

# Find VM inventory path using govc
VM_INVENTORY_PATH=$(govc find vm -name "$VM_NAME" 2>/dev/null | head -n1)
if [[ -z "$VM_INVENTORY_PATH" ]]; then
    echo "Error: VM not found in vCenter: $VM_NAME"
    exit 1
fi

echo "VM Inventory Path: $VM_INVENTORY_PATH"

# Build stembuild construct command
# Note: Using env vars for vCenter credentials to keep the command call cleaner
CONSTRUCT_CMD="$STEMBUILD_BINARY construct \
    -vm-ip \"$VM_IP\" \
    -vm-username \"$VM_USER\" \
    -vm-password \"$VM_PASS\" \
    -vcenter-url \"$GOVC_URL\" \
    -vcenter-username \"$GOVC_USERNAME\" \
    -vcenter-password \"$GOVC_PASSWORD\" \
    -vm-inventory-path \"$VM_INVENTORY_PATH\""

# Add CA Certs if the environment variable is provided
if [[ -n "${VCENTER_CA_CERTS:-}" ]] && [[ -f "${VCENTER_CA_CERTS}" ]]; then
    CONSTRUCT_CMD="$CONSTRUCT_CMD -vcenter-ca-certs \"$VCENTER_CA_CERTS\""
fi

echo "Executing stembuild construct..."
echo "This process involves running preparation scripts on the guest VM."
echo ""

# Execute
eval "$CONSTRUCT_CMD"

echo ""
echo "=========================================="
echo "stembuild construct completed successfully"
echo "Timestamp: $(date)"
echo "=========================================="