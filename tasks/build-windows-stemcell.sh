#!/usr/bin/env bash

set -eux

# Verify required tools
if ! command -v packer &> /dev/null; then
  echo "ERROR: Packer not found"
  exit 1
fi

if ! command -v govc &> /dev/null; then
  echo "ERROR: govc not found"
  exit 1
fi

if ! command -v stembuild &> /dev/null; then
  echo "ERROR: stembuild not found"
  exit 1
fi
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

pushd $SCRIPT_DIR/windows-automation
export PACKER_PLUGIN_PATH=/root/.packer.d/plugins

mkdir -p ${PACKER_PLUGIN_PATH}/github.com/hashicorp/vsphere
mv $PACKER_PLUGIN_PATH/packer-plugin-vsphere_v1.4.0_x5.0_linux_amd64 $PACKER_PLUGIN_PATH/github.com/hashicorp/vsphere/packer-plugin-vsphere_v1.4.0_x5.0_linux_amd64
OLD_PWD=$OLDPWD

# Generate variables file from Concourse task inputs
VARS_FILE="variables.pkrvars.hcl"

cat > "$VARS_FILE" <<EOF
# Generated from Concourse task inputs
# vCenter Configuration
vcenter_server              = "${VCENTER_SERVER}"
vcenter_username            = "${VCENTER_USERNAME}"
vcenter_password            = "${VCENTER_PASSWORD}"
vcenter_insecure_connection = ${VCENTER_INSECURE_CONNECTION:-true}
windows_version = "${WINDOWS_VERSION:-2019}"

EOF

# Proxy Configuration (Optional)
if [ -n "${HTTP_PROXY:-}" ]; then
  cat >> "$VARS_FILE" <<EOF
http_proxy     = "${HTTP_PROXY}"
EOF
fi

if [ -n "${HTTPS_PROXY:-}" ]; then
  cat >> "$VARS_FILE" <<EOF
https_proxy    = "${HTTPS_PROXY}"
EOF
fi

if [ -n "${NO_PROXY:-}" ]; then
  cat >> "$VARS_FILE" <<EOF
no_proxy       = "${NO_PROXY}"
EOF
fi

cat >> "$VARS_FILE" <<EOF

# vSphere Infrastructure
vcenter_datacenter    = "${VCENTER_DATACENTER}"
EOF

if [ -n "${VCENTER_CLUSTER:-}" ]; then
  cat >> "$VARS_FILE" <<EOF
vcenter_cluster       = "${VCENTER_CLUSTER}"
EOF
else
  cat >> "$VARS_FILE" <<EOF
vcenter_cluster       = ""
EOF
fi

if [ -n "${VCENTER_HOST:-}" ]; then
  cat >> "$VARS_FILE" <<EOF
vcenter_host          = "${VCENTER_HOST}"
EOF
else
  cat >> "$VARS_FILE" <<EOF
vcenter_host          = ""
EOF
fi

cat >> "$VARS_FILE" <<EOF
vcenter_datastore     = "${VCENTER_DATASTORE}"
vcenter_network       = "${VCENTER_NETWORK}"
EOF

if [ -n "${VCENTER_FOLDER:-}" ]; then
  cat >> "$VARS_FILE" <<EOF
vcenter_folder        = "${VCENTER_FOLDER}"
EOF
fi

if [ -n "${VCENTER_RESOURCE_POOL:-}" ]; then
  cat >> "$VARS_FILE" <<EOF
vcenter_resource_pool = "${VCENTER_RESOURCE_POOL}"
EOF
fi

cat >> "$VARS_FILE" <<EOF

# VM Configuration
vm_name         = "windows-base-vm"
vm_cpu_count    = ${VM_CPU_COUNT:-8}
vm_memory_mb    = ${VM_MEMORY_MB:-16384}
vm_disk_size_gb = ${VM_DISK_SIZE_GB:-100}

# Build Mode Configuration
EOF

# Build Mode: ISO or Template
if [ -n "${TEMPLATE_PATH:-}" ]; then
  cat >> "$VARS_FILE" <<EOF
# Template Mode: Clone from existing template
template_path = "${TEMPLATE_PATH}"
EOF
  echo "Using template mode: ${TEMPLATE_PATH}"
elif [ -n "${ISO_PATH_LOCAL:-}" ]; then
  cat >> "$VARS_FILE" <<EOF
# ISO Mode: Upload local ISO file
iso_path_local = "${ISO_PATH_LOCAL}"
EOF
  echo "Using ISO mode (local): ${ISO_PATH_LOCAL}"
elif [ -d "../windows-iso" ] && [ -n "$(find ../windows-iso -name '*.iso' -type f 2>/dev/null | head -1)" ]; then
  ISO_FILE=$(find ../windows-iso -name '*.iso' -type f 2>/dev/null | head -1)
  cat >> "$VARS_FILE" <<EOF
# ISO Mode: Upload local ISO file from windows-iso input
iso_path_local = "${ISO_FILE}"
EOF
  echo "Using ISO mode (windows-iso input): ${ISO_FILE}"
elif [ -n "${ISO_PATH:-}" ]; then
  cat >> "$VARS_FILE" <<EOF
# ISO Mode: Use ISO from datastore
iso_path = "${ISO_PATH}"
EOF
  echo "Using ISO mode (datastore): ${ISO_PATH}"
else
  echo "ERROR: Either TEMPLATE_PATH, ISO_PATH_LOCAL, ISO_PATH, or windows-iso input must be provided"
  exit 1
fi

cat >> "$VARS_FILE" <<EOF

# Windows Configuration
windows_username = "${WINDOWS_USERNAME:-Administrator}"
windows_password = "${WINDOWS_PASSWORD}"

# Network Configuration
static_ip    = "${STATIC_IP}"
subnet_mask  = "${SUBNET_MASK}"
gateway      = "${GATEWAY}"
dns_servers  = [$(echo "${DNS_SERVERS}" | sed 's/,/", "/g' | sed 's/^/"/' | sed 's/$/"/')]

# Stemcell Configuration
patch_version = "${PATCH_VERSION}"

# Build Options
enable_windows_updates = ${ENABLE_WINDOWS_UPDATES:-true}
log_level              = "${LOG_LEVEL:-INFO}"
EOF

# Optional: Template name (for final template after stemcell)
if [ -n "${TEMPLATE_NAME:-}" ]; then
  cat >> "$VARS_FILE" <<EOF

# Template Configuration
template_name = "${TEMPLATE_NAME}"
EOF
fi

echo "Generated variables file: $VARS_FILE"
echo "=========================================="
echo "Variables parsed from file (for build.sh):"
echo "=========================================="
cat "$VARS_FILE"
echo "---"
echo "Base VM name: windows-base-vm"
TARGET_VM_TS=$(date -u +%Y%m%d%H%M%S 2>/dev/null || date +%Y%m%d%H%M%S)
echo "Target VM name: windows-target-vm-${TARGET_VM_TS}"
echo "All arguments passed to build.sh: ./build.sh -f $VARS_FILE ${JUMPER_ARGS[*]}"
echo "=========================================="

# Set HTTP_PROXY, HTTPS_PROXY, NO_PROXY for Packer and govc
if [ -n "${HTTP_PROXY:-}" ]; then
  export HTTP_PROXY="${HTTP_PROXY}"
fi
if [ -n "${HTTPS_PROXY:-}" ]; then
  export HTTPS_PROXY="${HTTPS_PROXY}"
fi
if [ -n "${NO_PROXY:-}" ]; then
  export NO_PROXY="${NO_PROXY}"
fi

declare -a JUMPER_ARGS=()

if [[ -n "${JUMPER_HOST:-}" && -n "${JUMPER_USER:-}" && -n "${JUMPER_PASSWORD:-}" ]]; then
    JUMPER_ARGS+=(
        "--jumper-ip" "$JUMPER_HOST"
        "--jumper-user" "$JUMPER_USER"
        "--jumper-password" "$JUMPER_PASSWORD"
    )
    echo "Jumper flags added to execution (--jumper-ip, --jumper-user, --jumper-password)."
fi

# Run build script
echo "Starting Windows stemcell creation..."
./build.sh -v "$VARS_FILE" "${JUMPER_ARGS[@]}" --skip-packer-init

# Copy logs to output
mkdir -p $OLD_PWD/logs
cp -r logs/* $OLD_PWD/logs 2>/dev/null || true

# Copy stemcell file to output
echo "Looking for generated stemcell file..."
STEMCELL_FILE=$(find . -name "bosh-stemcell-*-vsphere-esxi-*-go_agent.tgz" -type f 2>/dev/null | head -1)
if [ -n "$STEMCELL_FILE" ]; then
  echo "Found stemcell file: $STEMCELL_FILE"
  mkdir -p $OLD_PWD/stemcell
  cp "$STEMCELL_FILE" $OLD_PWD/stemcell
  echo "Stemcell file copied to output: $OLD_PWD/stemcell/$(basename "$STEMCELL_FILE")"
  ls -lh $OLD_PWD/stemcell
else
  echo "WARNING: Stemcell file not found. Expected pattern: bosh-stemcell-*-vsphere-esxi-windows2019-go_agent.tgz"
  echo "Searching for any .tgz files:"
  find . -name "*.tgz" -type f 2>/dev/null || echo "No .tgz files found"
fi

popd