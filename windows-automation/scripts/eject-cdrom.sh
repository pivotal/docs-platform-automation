#!/usr/bin/env bash
# Eject CD/DVD drive from VM
# Usage: eject-cdrom.sh <vm-name> <vcenter-server> <username> <password> <insecure>

VM_NAME="${1:-}"
VCENTER_SERVER="${2:-}"
VCENTER_USER="${3:-}"
VCENTER_PASS="${4:-}"
VCENTER_INSECURE="${5:-false}"

if [[ -z "$VM_NAME" ]] || ! command -v govc >/dev/null 2>&1; then
    exit 0
fi

export GOVC_URL="$VCENTER_SERVER"
export GOVC_USERNAME="$VCENTER_USER"
export GOVC_PASSWORD="$VCENTER_PASS"
export GOVC_INSECURE="$VCENTER_INSECURE"

cdrom_device=$(govc device.ls -vm "$VM_NAME" 2>/dev/null | grep -iE 'cdrom|ide-cdrom|sata-cdrom' | head -1 | awk '{print $1}' || echo '')
if [[ -n "$cdrom_device" ]]; then
    govc device.cdrom.eject -vm "$VM_NAME" -device "$cdrom_device" 2>&1 || true
fi
