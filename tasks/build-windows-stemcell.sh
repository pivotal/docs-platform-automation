#!/usr/bin/env bash
# Concourse entrypoint: generate vars file from task inputs, install Packer vsphere plugin, run build.sh.
# Invoked by build-windows-stemcell.yml. All required inputs come from Concourse params/inputs.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
WINDOWS_DIR="${SCRIPT_DIR}/windows-automation"
VARS_FILE_NAME="variables.pkrvars.hcl"

# ---- Required tools ----
require_cmd() {
    if ! command -v "$1" &> /dev/null; then
        echo "ERROR: $1 not found"
        exit 1
    fi
}
require_cmd packer
require_cmd govc
require_cmd stembuild

# ---- Helpers for vars file ----
# Append a single line to the vars file (key = "value").
append_var() {
    local key="$1" value="$2"
    echo "${key} = \"${value}\"" >> "$VARS_FILE"
}

# Build NO_PROXY: user value (if any) + "github.com,github.com:443" so plugin download can bypass proxy.
no_proxy_with_github() {
    local user="${1:-}"
    user="${user#"${user%%[![:space:]]*}"}"
    user="${user%"${user##*[![:space:]]}"}"
    user="${user%,}"
    user="${user#,}"
    if [[ -n "$user" ]]; then
        echo "${user},github.com,github.com:443"
    else
        echo "github.com,github.com:443"
    fi
}

# Resolve ISO/template source and set BUILD_SOURCE_LINE for the heredoc below.
resolve_build_source() {
    if [[ -n "${TEMPLATE_PATH:-}" ]]; then
        BUILD_SOURCE_LINE="# Template Mode: Clone from existing template
template_path = \"${TEMPLATE_PATH}\""
        echo "Using template mode: ${TEMPLATE_PATH}"
    elif [[ -n "${ISO_PATH_LOCAL:-}" ]]; then
        BUILD_SOURCE_LINE="# ISO Mode: Upload local ISO file
iso_path_local = \"${ISO_PATH_LOCAL}\""
        echo "Using ISO mode (local): ${ISO_PATH_LOCAL}"
    elif [[ -d "${SCRIPT_DIR}/windows-iso" ]] && [[ -n "$(find "${SCRIPT_DIR}/windows-iso" -name '*.iso' -type f 2>/dev/null | head -1)" ]]; then
        ISO_FILE=$(find "${SCRIPT_DIR}/windows-iso" -name '*.iso' -type f 2>/dev/null | head -1)
        BUILD_SOURCE_LINE="# ISO Mode: Upload local ISO file from windows-iso input
iso_path_local = \"${ISO_FILE}\""
        echo "Using ISO mode (windows-iso input): ${ISO_FILE}"
    elif [[ -n "${ISO_PATH:-}" ]]; then
        BUILD_SOURCE_LINE="# ISO Mode: Use ISO from datastore
iso_path = \"${ISO_PATH}\""
        echo "Using ISO mode (datastore): ${ISO_PATH}"
    else
        echo "ERROR: Either TEMPLATE_PATH, ISO_PATH_LOCAL, ISO_PATH, or windows-iso input must be provided"
        exit 1
    fi
}

# ---- Generate variables file ----
pushd "$WINDOWS_DIR"
VARS_FILE="$VARS_FILE_NAME"
OLD_PWD="${OLDPWD}"

cat > "$VARS_FILE" <<EOF
# Generated from Concourse task inputs
# vCenter Configuration
vcenter_server              = "${VCENTER_SERVER}"
vcenter_username            = "${VCENTER_USERNAME}"
vcenter_password            = "${VCENTER_PASSWORD}"
vcenter_insecure_connection = ${VCENTER_INSECURE_CONNECTION:-true}
windows_version = "${WINDOWS_VERSION:-2019}"

EOF

# Proxy (optional); NO_PROXY always includes github.com,github.com:443 so plugin download can bypass proxy when env has proxy set
[[ -n "${HTTP_PROXY:-}" ]] && append_var "http_proxy" "${HTTP_PROXY}"
[[ -n "${HTTPS_PROXY:-}" ]] && append_var "https_proxy" "${HTTPS_PROXY}"
[[ -n "${NO_PROXY:-}" ]] && append_var "no_proxy" "$(no_proxy_with_github "${NO_PROXY:-}")"

cat >> "$VARS_FILE" <<EOF

# vSphere Infrastructure
vcenter_datacenter    = "${VCENTER_DATACENTER}"
EOF
if [[ -n "${VCENTER_CLUSTER:-}" ]]; then
    append_var "vcenter_cluster" "${VCENTER_CLUSTER}"
else
    echo 'vcenter_cluster       = ""' >> "$VARS_FILE"
fi
if [[ -n "${VCENTER_HOST:-}" ]]; then
    append_var "vcenter_host" "${VCENTER_HOST}"
else
    echo 'vcenter_host          = ""' >> "$VARS_FILE"
fi
cat >> "$VARS_FILE" <<EOF
vcenter_datastore     = "${VCENTER_DATASTORE}"
vcenter_network       = "${VCENTER_NETWORK}"
EOF

[[ -n "${VCENTER_FOLDER:-}" ]] && append_var "vcenter_folder" "${VCENTER_FOLDER}"
[[ -n "${VCENTER_RESOURCE_POOL:-}" ]] && append_var "vcenter_resource_pool" "${VCENTER_RESOURCE_POOL}"

cat >> "$VARS_FILE" <<EOF

# VM Configuration
vm_name         = "windows-base-vm"
vm_cpu_count    = ${VM_CPU_COUNT:-8}
vm_memory_mb    = ${VM_MEMORY_MB:-16384}
vm_disk_size_gb = ${VM_DISK_SIZE_GB:-100}

# Build Mode Configuration
EOF

resolve_build_source
echo "$BUILD_SOURCE_LINE" >> "$VARS_FILE"

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

if [[ -n "${TEMPLATE_NAME:-}" ]]; then
    echo "" >> "$VARS_FILE"
    echo "# Template Configuration" >> "$VARS_FILE"
    append_var "template_name" "${TEMPLATE_NAME}"
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
declare -a BUILD_ARGS=()
[[ "${DEBUG_MODE:-}" == "true" ]] && BUILD_ARGS+=(--debug) && echo "DEBUG_MODE=true: enabling set -x for build.sh and all scripts it calls"
declare -a JUMPER_ARGS=()
[[ -n "${JUMPER_HOST:-}" && -n "${JUMPER_USER:-}" && -n "${JUMPER_PASSWORD:-}" ]] && JUMPER_ARGS+=(--jumper-ip "$JUMPER_HOST" --jumper-user "$JUMPER_USER" --jumper-password "$JUMPER_PASSWORD") && echo "Jumper flags added."
echo "All arguments passed to build.sh: ./build.sh -v $VARS_FILE ${BUILD_ARGS[*]} ${JUMPER_ARGS[*]}"
echo "=========================================="

# Set NO_PROXY before curl/packer init so GitHub bypasses proxy (user value + github.com,github.com:443).
export NO_PROXY="$(no_proxy_with_github "${NO_PROXY:-}")"

# ---- Packer vsphere plugin ----
# HTTP_PROXY/HTTPS_PROXY are set only after this block so plugin download is direct or uses NO_PROXY.
VERSION="1.4.2"
PLUGIN_NAME="vsphere"
SOURCE="github.com/hashicorp/vsphere"
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
[[ "$ARCH" == "x86_64" ]] && ARCH="amd64"
[[ "$ARCH" == "aarch64" ]] && ARCH="arm64"
BINARY_NAME="packer-plugin-${PLUGIN_NAME}_v${VERSION}_x5.0_${OS}_${ARCH}"
ZIP_NAME="${BINARY_NAME}.zip"
SUMS_NAME="packer-plugin-${PLUGIN_NAME}_v${VERSION}_SHA256SUMS"

echo "--- Downloading v${VERSION} for ${OS}/${ARCH} ---"
curl -L -O "https://github.com/hashicorp/packer-plugin-vsphere/releases/download/v${VERSION}/${ZIP_NAME}"
curl -L -O "https://github.com/hashicorp/packer-plugin-vsphere/releases/download/v${VERSION}/${SUMS_NAME}"
echo "--- Extracting ---"
unzip -o "$ZIP_NAME"
chmod +x "$BINARY_NAME"
echo "--- Registering Plugin with Packer ---"
packer plugins install --path "./${BINARY_NAME}" "$SOURCE"
rm -f "$ZIP_NAME" "$SUMS_NAME" "$BINARY_NAME"
echo "--- Success! Running Packer Init ---"
PACKER_LOG=1 packer init windows-vm.pkr.hcl

# Set HTTP_PROXY/HTTPS_PROXY after packer init (for Packer build and govc). NO_PROXY already set above.
[[ -n "${HTTP_PROXY:-}" ]] && export HTTP_PROXY="${HTTP_PROXY}"
[[ -n "${HTTPS_PROXY:-}" ]] && export HTTPS_PROXY="${HTTPS_PROXY}"

# ---- Run build ----
echo "Starting Windows stemcell creation..."
./build.sh -v "$VARS_FILE" "${BUILD_ARGS[@]}" "${JUMPER_ARGS[@]}"

# ---- Copy outputs ----
mkdir -p "$OLD_PWD/logs"
cp -r logs/* "$OLD_PWD/logs" 2>/dev/null || true
echo "Looking for generated stemcell file..."
STEMCELL_FILE=$(find . -name "bosh-stemcell-*-vsphere-esxi-*-go_agent.tgz" -type f 2>/dev/null | head -1)
if [[ -n "$STEMCELL_FILE" ]]; then
    echo "Found stemcell file: $STEMCELL_FILE"
    mkdir -p "$OLD_PWD/stemcell"
    cp "$STEMCELL_FILE" "$OLD_PWD/stemcell"
    echo "Stemcell file copied to output: $OLD_PWD/stemcell/$(basename "$STEMCELL_FILE")"
    ls -lh "$OLD_PWD/stemcell"
else
    echo "WARNING: Stemcell file not found. Expected pattern: bosh-stemcell-*-vsphere-esxi-windows2019-go_agent.tgz"
    find . -name "*.tgz" -type f 2>/dev/null || echo "No .tgz files found"
fi

popd
