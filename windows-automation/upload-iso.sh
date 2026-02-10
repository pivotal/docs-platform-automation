#!/bin/bash
# Helper script to upload Windows Server 2019 ISO to vSphere datastore
# Usage: ./upload-iso.sh <local-iso-path> <datastore-name> [iso-folder]

set -e

LOCAL_ISO="$1"
DATASTORE="$2"
ISO_FOLDER="${3:-ISOs}"

if [ -z "$LOCAL_ISO" ] || [ -z "$DATASTORE" ]; then
    echo "Usage: $0 <local-iso-path> <datastore-name> [iso-folder]"
    echo "Example: $0 ./windows-server-2019.iso datastore1 ISOs"
    exit 1
fi

if [ ! -f "$LOCAL_ISO" ]; then
    echo "Error: ISO file not found: $LOCAL_ISO"
    exit 1
fi

ISO_NAME=$(basename "$LOCAL_ISO")

echo "Uploading $LOCAL_ISO to datastore $DATASTORE..."
echo "Target path: [$DATASTORE]/$ISO_FOLDER/$ISO_NAME"

# Check if govc is available
if ! command -v govc &> /dev/null; then
    echo "Error: govc is required but not found. Please install govc first."
    echo "Download from: https://github.com/vmware/govmomi/releases"
    exit 1
fi

# Upload ISO
govc datastore.upload \
    -ds "$DATASTORE" \
    "$LOCAL_ISO" \
    "$ISO_FOLDER/$ISO_NAME"

echo ""
echo "✓ ISO uploaded successfully!"
echo "Update your variables.pkrvars.hcl with:"
echo "  iso_path = \"[$DATASTORE]/$ISO_FOLDER/$ISO_NAME\""
