#!/usr/bin/env bash
# Test script: run only the sshpass SSH (and optional SCP) to execute stembuild construct on the jumper.
# Run from repo root, or set SCRIPT_DIR and ensure LGPO.zip and binaries are available.
#
# Exit code 126 on the jumper usually means "cannot execute" - the binary is wrong OS/arch.
# If the jumper is Linux, you must use Linux stembuild and govc. When running this from a Mac,
# set STEMBUILD_PATH and GOVC_PATH to Linux binaries (e.g. download from GitHub or copy from a Linux box).
# Usage: ./tasks/windows-automation/scripts/test-jumper-construct.sh
set -x
set -euo pipefail

# --- Jumper connection ---
jumper_ip="10.144.36.86"
jumper_user="root"
jumper_password="VMware1!"

# --- VM / build context (same as in build.sh) ---
vm_name="windows-target-vm-20260301060922"
static_ip="192.168.121.101"
windows_username="Administrator"
windows_password="Admin123!"
datacenter="tanzu-dc01"

# --- vCenter (GOVC_* are used in the remote export) ---
GOVC_URL="vcenter.tanzu.lab"
GOVC_USERNAME="administrator@vsphere.local"
GOVC_PASSWORD="VMware1!"
GOVC_INSECURE="true"

# --- Optional: vCenter CA cert (leave empty to skip) ---
VCENTER_CA_CERTS=""

# --- Paths (defaults: script is in tasks/windows-automation/scripts/, SCRIPT_DIR = tasks/windows-automation) ---
SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
scripts_dir="${SCRIPT_DIR}/scripts"
# Where to find stembuild/govc (default: current PATH)
STEMBUILD_PATH="${STEMBUILD_PATH:-$(which stembuild 2>/dev/null || echo "")}"
GOVC_PATH="${GOVC_PATH:-$(which govc 2>/dev/null || echo "")}"
# LGPO.zip: often in current dir or windows-automation dir
LGPO_ZIP="${LGPO_ZIP:-$SCRIPT_DIR/LGPO.zip}"
if [[ ! -f "$LGPO_ZIP" ]]; then
    LGPO_ZIP="./LGPO.zip"
fi

# --- Remote stembuild path (must match where we scp the binary) ---
# Set after validation so STEMBUILD_PATH is final; remote path = $HOME/<basename of STEMBUILD_PATH>
stembuild_remote='$HOME/'"$(basename "$STEMBUILD_PATH")"

# --- Output ---
construct_log="${construct_log:-$SCRIPT_DIR/logs/stembuild-construct-test-$(date +%Y%m%d-%H%M%S).log}"

# ========== Edit the variables above, then run ==========

if [[ -z "$jumper_ip" ]] || [[ -z "$jumper_user" ]] || [[ -z "$jumper_password" ]]; then
    echo "Set jumper_ip, jumper_user, jumper_password at the top of this script."
    exit 1
fi
if [[ -z "$vm_name" ]] || [[ -z "$static_ip" ]] || [[ -z "$windows_password" ]] || [[ -z "$datacenter" ]]; then
    echo "Set vm_name, static_ip, windows_password, datacenter at the top of this script."
    exit 1
fi
if [[ -z "$GOVC_URL" ]] || [[ -z "$GOVC_USERNAME" ]] || [[ -z "$GOVC_PASSWORD" ]]; then
    echo "Set GOVC_URL, GOVC_USERNAME, GOVC_PASSWORD at the top of this script."
    exit 1
fi
if [[ -z "$GOVC_PATH" ]] || [[ ! -x "$GOVC_PATH" ]]; then
    echo "Set GOVC_PATH to a valid govc binary, or ensure govc is in PATH."
    exit 1
fi
if [[ ! -f "$scripts_dir/run-stembuild-construct.sh" ]]; then
    echo "run-stembuild-construct.sh not found at $scripts_dir/run-stembuild-construct.sh. Set SCRIPT_DIR if needed."
    exit 1
fi
if [[ ! -f "$LGPO_ZIP" ]]; then
    echo "LGPO.zip not found at $LGPO_ZIP. Set LGPO_ZIP or run from a dir that has LGPO.zip."
    exit 1
fi

mkdir -p "$(dirname "$construct_log")"

echo "Copying run-stembuild-construct.sh, stembuild, govc, LGPO.zip to jumper..."
if ! sshpass -p "$jumper_password" scp -o StrictHostKeyChecking=no \
    "$scripts_dir/run-stembuild-construct.sh" \
    "$LGPO_ZIP" \
    "$jumper_user@$jumper_ip:~/"; then
    echo "SCP failed."
    exit 1
fi

vcenter_ca_remote=""
if [[ -n "${VCENTER_CA_CERTS:-}" ]] && [[ -f "${VCENTER_CA_CERTS}" ]]; then
    echo "Copying vCenter CA cert to jumper..."
    if sshpass -p "$jumper_password" scp -o StrictHostKeyChecking=no "$VCENTER_CA_CERTS" "$jumper_user@$jumper_ip:~/vcenter-ca-certs.pem"; then
        vcenter_ca_remote='$HOME/vcenter-ca-certs.pem'
    fi
fi

# Write GOVC_* to a file and scp it so the jumper has them set (avoids quoting issues in SSH command)
govc_env_file=$(mktemp)
trap 'rm -f "$govc_env_file"' EXIT
{
    echo "export PATH=\"\$HOME:\$PATH\""
    echo "export GOVC_URL='${GOVC_URL//\'/\'\\\'\'}'"
    echo "export GOVC_USERNAME='${GOVC_USERNAME//\'/\'\\\'\'}'"
    echo "export GOVC_PASSWORD='${GOVC_PASSWORD//\'/\'\\\'\'}'"
    echo "export GOVC_INSECURE='${GOVC_INSECURE:-true}'"
    [[ -n "$vcenter_ca_remote" ]] && echo "export VCENTER_CA_CERTS=$vcenter_ca_remote"
} > "$govc_env_file"
sshpass -p "$jumper_password" scp -o StrictHostKeyChecking=no "$govc_env_file" "$jumper_user@$jumper_ip:~/govc.env"

stembuild_basename='stembuild'
echo "Starting SSH session on jumper ($jumper_user@$jumper_ip); output below and in $construct_log"
sshpass -p "$jumper_password" ssh -o StrictHostKeyChecking=no "$jumper_user@$jumper_ip" \
    "echo '--- SSH session started on jumper, running stembuild construct ---'; source ~/govc.env; chmod +x ~/run-stembuild-construct.sh ~/$stembuild_basename ~/govc; bash ~/run-stembuild-construct.sh \"$vm_name\" \"$static_ip\" \"$windows_username\" \"$windows_password\" \"\$HOME/$stembuild_basename\" \"$datacenter\"" 2>&1 | tee "$construct_log"

exit_code=${PIPESTATUS[0]}
if [[ $exit_code -ne 0 ]]; then
    echo "SSH/construct exited with code $exit_code. Log: $construct_log"
    exit $exit_code
fi
echo "Done. Log: $construct_log"
