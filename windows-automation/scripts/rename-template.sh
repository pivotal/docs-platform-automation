#!/usr/bin/env bash
# Rename template after conversion
# Usage: rename-template.sh <vm-name> <template-name> <vcenter-server> <username> <password> <insecure>

VM_NAME="${1:-}"
TEMPLATE_NAME="${2:-}"
VCENTER_SERVER="${3:-}"
VCENTER_USER="${4:-}"
VCENTER_PASS="${5:-}"
VCENTER_INSECURE="${6:-false}"

if [[ -z "$VM_NAME" ]] || [[ -z "$TEMPLATE_NAME" ]] || ! command -v govc >/dev/null 2>&1; then
    exit 0
fi

export GOVC_URL="$VCENTER_SERVER"
export GOVC_USERNAME="$VCENTER_USER"
export GOVC_PASSWORD="$VCENTER_PASS"
export GOVC_INSECURE="$VCENTER_INSECURE"

if govc vm.info "$VM_NAME" 2>/dev/null | grep -q 'Template: true'; then
    govc vm.rename -vm "$VM_NAME" "$TEMPLATE_NAME" 2>&1 || true
fi
