#!/usr/bin/env bash
# Run stembuild construct on VM
# Based on: https://techdocs.broadcom.com/us/en/vmware-tanzu/platform/elastic-application-runtime/6-0/eart/create-vsphere-stemcell-automatically.html
# This script automates Step 4: Constructing the BOSH stemcell

set -euo pipefail

VM_NAME="${1:-}"
PATCH_VERSION="${2:-}"
STEMBUILD_BINARY="${3:-}"
LOG_FILE="${4:-}"

# Setup logging
if [[ -n "$LOG_FILE" ]]; then
    exec > >(tee -a "$LOG_FILE") 2>&1
fi

if [[ -z "$VM_NAME" ]] || [[ -z "$PATCH_VERSION" ]] || [[ -z "$STEMBUILD_BINARY" ]]; then
    echo "Usage: $0 <vm-name> <patch-version> <stembuild-binary> [log-file]"
    exit 1
fi

if ! command -v govc >/dev/null 2>&1; then
    echo "Error: govc command not found"
    exit 1
fi

echo "=========================================="
echo "Running stembuild construct"
echo "VM: $VM_NAME"
echo "Patch Version: $PATCH_VERSION"
echo "Timestamp: $(date)"
echo "=========================================="

# Find VM inventory path
VM_INVENTORY_PATH=$(govc find vm -name "$VM_NAME" 2>/dev/null | head -n1)
if [[ -z "$VM_INVENTORY_PATH" ]]; then
    echo "Error: VM not found: $VM_NAME"
    exit 1
fi

echo "VM Inventory Path: $VM_INVENTORY_PATH"

# Build stembuild construct command
# According to documentation, construct requires:
# - vcenter-url
# - vcenter-username (can use GOVC_USERNAME env var)
# - vcenter-password (can use GOVC_PASSWORD env var)
# - patch-version
# - vm-inventory-path
# - vcenter-ca-certs (optional)

CONSTRUCT_CMD="$STEMBUILD_BINARY construct"
CONSTRUCT_CMD="$CONSTRUCT_CMD -vcenter-url \"$GOVC_URL\""
CONSTRUCT_CMD="$CONSTRUCT_CMD -vcenter-username \"$GOVC_USERNAME\""
CONSTRUCT_CMD="$CONSTRUCT_CMD -vcenter-password \"$GOVC_PASSWORD\""
CONSTRUCT_CMD="$CONSTRUCT_CMD -patch-version \"$PATCH_VERSION\""
CONSTRUCT_CMD="$CONSTRUCT_CMD -vm-inventory-path \"$VM_INVENTORY_PATH\""

if [[ -n "${VCENTER_CA_CERTS:-}" ]] && [[ -f "${VCENTER_CA_CERTS}" ]]; then
    CONSTRUCT_CMD="$CONSTRUCT_CMD -vcenter-ca-certs \"$VCENTER_CA_CERTS\""
fi

echo "Running stembuild construct..."
echo "This may take 30-60 minutes to complete..."
echo ""

# Execute construct command
eval "$CONSTRUCT_CMD"
EXIT_CODE=$?

if [[ $EXIT_CODE -ne 0 ]]; then
    echo "Error: stembuild construct failed with exit code: $EXIT_CODE"
    exit $EXIT_CODE
fi

echo ""
echo "=========================================="
echo "stembuild construct completed successfully"
echo "VM is ready for packaging"
echo "Timestamp: $(date)"
echo "=========================================="
exit 0
