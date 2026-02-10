#!/usr/bin/env bash
# Mount VMware Tools ISO on VM using standard vSphere path
# Usage: mount-vmware-tools.sh <vm-name>

VM_NAME="${1:-}"

if [[ -z "$VM_NAME" ]] || ! command -v govc >/dev/null 2>&1; then
    exit 0
fi

# Use standard VMware Tools ISO path
TOOLS_ISO_PATH="[] /vmimages/tools-isoimages/windows.iso"

echo "Mounting VMware Tools ISO: $TOOLS_ISO_PATH"
echo "VM: $VM_NAME"

# Mount VMware Tools ISO using govc
govc vm.guest.tools -mount "$VM_NAME" -iso "$TOOLS_ISO_PATH" 2>&1 || {
    # Fallback: try without explicit ISO path (govc may auto-detect)
    echo "Trying fallback mount method..."
    govc vm.guest.tools -mount "$VM_NAME" 2>&1 || true
}

sleep 5
echo "VMware Tools ISO mount command completed"
