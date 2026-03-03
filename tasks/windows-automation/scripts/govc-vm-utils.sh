#!/usr/bin/env bash
# Find VM inventory path via govc. Requires GOVC_* env and govc in PATH.
# Source from scripts that need to resolve a VM name to an inventory path.

# Usage: find_vm_inventory_path <vm_name> [datacenter]
# Outputs absolute path (e.g. /dc/vm/folder/vmname) to stdout; return 1 if not found.
# If output starts with "govc:", it is an error line (do not use as path).
find_vm_inventory_path() {
    local vm_name="${1:?}" datacenter="${2:-}" path=""
    if [[ -n "$datacenter" ]]; then
        path=$(govc find / -type m -name "$vm_name" -dc "$datacenter" 2>&1 | head -n1)
    fi
    if [[ -z "$path" ]] || [[ "$path" == govc:* ]]; then
        path=$(govc find / -type m -name "$vm_name" 2>&1 | head -n1)
    fi
    if [[ -z "$path" ]] || [[ "$path" == govc:* ]]; then
        path=$(govc find vm -name "$vm_name" 2>&1 | head -n1)
    fi
    if [[ -z "$path" ]] || [[ "$path" == govc:* ]]; then
        echo "VM not found: $vm_name" >&2
        return 1
    fi
    # Ensure absolute path (govc find usually returns /dc/vm/...)
    if [[ "$path" != /* ]] && [[ -n "$datacenter" ]]; then
        path="/$datacenter/$path"
    fi
    echo "$path"
}
