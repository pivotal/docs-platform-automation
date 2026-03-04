#!/usr/bin/env bash
# Unit tests for Autounattend.xml processing (process_autounattend_template).
# Covers: Windows version (2019/2022/2025), SConfig block, DNS, required vars, placeholders.
# Run from repo root or windows-automation: ./scripts/test-autounattend-processing.sh

set -euo pipefail
TEST_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$(cd "$TEST_SCRIPT_DIR/.." && pwd)"
PROCESSED_FILE="$BUILD_DIR/http/Autounattend.processed.xml"

# Common test helpers (same pattern as build.sh sourcing scripts)
TEST_UTILS="$TEST_SCRIPT_DIR/test-utils.sh"
[[ -f "$TEST_UTILS" ]] || { echo "ERROR: test-utils.sh not found: $TEST_UTILS" >&2; exit 1; }
source "$TEST_UTILS"

# Minimal vars required for successful processing (single DNS)
minimal_vars() {
    local win_ver="${1:-2019}"
    cat << EOF
windows_username = "Administrator"
windows_password = "Pass123!"
static_ip = "192.168.1.100"
subnet_mask = "255.255.255.0"
gateway = "192.168.1.1"
dns_servers = ["192.168.1.10"]
windows_version = "$win_ver"
EOF
}

# Vars with two DNS servers
minimal_vars_two_dns() {
    local win_ver="${1:-2019}"
    cat << EOF
windows_username = "Administrator"
windows_password = "Pass123!"
static_ip = "192.168.1.100"
subnet_mask = "255.255.255.0"
gateway = "192.168.1.1"
dns_servers = ["192.168.1.10", "192.168.1.11"]
windows_version = "$win_ver"
EOF
}

pass=0
fail=0

run_processing() {
    local vars_file="$1"
    rm -f "$PROCESSED_FILE"
    (cd "$BUILD_DIR" && process_autounattend_template "$vars_file")
}

echo "=========================================="
echo "  Autounattend processing unit tests"
echo "=========================================="
echo "Build dir: $BUILD_DIR"
echo ""

# Load build.sh (defines process_autounattend_template)
export AUTOUNATTEND_TEST=1
# shellcheck source=../build.sh
source "$BUILD_DIR/build.sh"

# Use temp dir for vars files
TMPDIR_VARS=$(mktemp -d)
cleanup_tmp() { rm -rf "$TMPDIR_VARS"; rm -f "$PROCESSED_FILE"; }
trap cleanup_tmp EXIT

# Run process_autounattend_template in subshell so return 1 doesn't exit test script (set -e)
run_process_expect_fail() {
    (cd "$BUILD_DIR" && process_autounattend_template "$1")
}

echo "=== 1. Failure cases (missing/invalid inputs) ==="
# Missing vars file
assert_exit1 "process_autounattend_template with empty path fails" run_process_expect_fail ""
assert_exit1 "process_autounattend_template with nonexistent file fails" run_process_expect_fail /nonexistent/vars.hcl

# Missing required vars
minimal_vars 2019 | grep -v "^windows_username" > "$TMPDIR_VARS/no_user.hcl"
assert_exit1 "missing windows_username fails" run_process_expect_fail "$TMPDIR_VARS/no_user.hcl"

minimal_vars 2019 | grep -v "^windows_password" > "$TMPDIR_VARS/no_pass.hcl"
assert_exit1 "missing windows_password fails" run_process_expect_fail "$TMPDIR_VARS/no_pass.hcl"

minimal_vars 2019 | grep -v "^static_ip" > "$TMPDIR_VARS/no_static_ip.hcl"
assert_exit1 "missing static_ip fails" run_process_expect_fail "$TMPDIR_VARS/no_static_ip.hcl"

minimal_vars 2019 | grep -v "^subnet_mask" > "$TMPDIR_VARS/no_subnet_mask.hcl"
assert_exit1 "missing subnet_mask fails" run_process_expect_fail "$TMPDIR_VARS/no_subnet_mask.hcl"

minimal_vars 2019 | grep -v "^gateway" > "$TMPDIR_VARS/no_gateway.hcl"
assert_exit1 "missing gateway fails" run_process_expect_fail "$TMPDIR_VARS/no_gateway.hcl"

minimal_vars 2019 | grep -v "^dns_servers" > "$TMPDIR_VARS/no_dns.hcl"
assert_exit1 "missing dns_servers fails" run_process_expect_fail "$TMPDIR_VARS/no_dns.hcl"

echo "windows_username = \"u\"
windows_password = \"p\"
static_ip = \"1.2.3.4\"
subnet_mask = \"255.255.255.0\"
gateway = \"1.2.3.1\"
dns_servers = [\"1.2.3.10\"]
windows_version = \"2020\"
" > "$TMPDIR_VARS/bad_version.hcl"
assert_exit1 "unsupported windows_version (2020) fails" run_process_expect_fail "$TMPDIR_VARS/bad_version.hcl"

echo ""
echo "=== 2. Windows version and image name ==="
minimal_vars 2019 > "$TMPDIR_VARS/v2019.hcl"
run_processing "$TMPDIR_VARS/v2019.hcl" || { echo "FAIL: process 2019"; ((fail++)); }
assert_file_contains "2019 image name" "$PROCESSED_FILE" "Windows Server 2019 SERVERSTANDARDCORE"
assert_file_not_contains "2019 has no SConfig block" "$PROCESSED_FILE" "Disable SConfig Auto-launch"

minimal_vars 2022 > "$TMPDIR_VARS/v2022.hcl"
run_processing "$TMPDIR_VARS/v2022.hcl" || { echo "FAIL: process 2022"; ((fail++)); }
assert_file_contains "2022 image name" "$PROCESSED_FILE" "Windows Server 2022 SERVERSTANDARDCORE"
assert_file_contains "2022 has SConfig block" "$PROCESSED_FILE" "Disable SConfig Auto-launch"
assert_file_contains "2022 SConfig reg key" "$PROCESSED_FILE" "HKCU\\\\Software\\\\Microsoft\\\\ServerConfig"

minimal_vars 2025 > "$TMPDIR_VARS/v2025.hcl"
run_processing "$TMPDIR_VARS/v2025.hcl" || { echo "FAIL: process 2025"; ((fail++)); }
assert_file_contains "2025 image name" "$PROCESSED_FILE" "Windows Server 2025 SERVERSTANDARDCORE"
assert_file_contains "2025 has SConfig block" "$PROCESSED_FILE" "Disable SConfig Auto-launch"

echo ""
echo "=== 3. Default windows_version (omit key) ==="
minimal_vars 2019 | grep -v "^windows_version" > "$TMPDIR_VARS/no_version.hcl"
run_processing "$TMPDIR_VARS/no_version.hcl" || { echo "FAIL: process with no windows_version"; ((fail++)); }
assert_file_contains "default image is 2019" "$PROCESSED_FILE" "Windows Server 2019 SERVERSTANDARDCORE"

echo ""
echo "=== 4. DNS: single vs two servers ==="
minimal_vars 2019 > "$TMPDIR_VARS/single_dns.hcl"
run_processing "$TMPDIR_VARS/single_dns.hcl" || true
# Single DNS: DNSServer2_XML placeholder line is removed, so no keyValue="2"
assert_file_not_contains "single DNS has no second IP line" "$PROCESSED_FILE" 'keyValue="2"'

minimal_vars_two_dns 2019 > "$TMPDIR_VARS/two_dns.hcl"
run_processing "$TMPDIR_VARS/two_dns.hcl" || true
assert_file_contains "two DNS has second IP" "$PROCESSED_FILE" "192.168.1.11"
assert_file_contains "two DNS keyValue 2" "$PROCESSED_FILE" 'keyValue="2"'

echo ""
echo "=== 5. All placeholders replaced ==="
run_processing "$TMPDIR_VARS/v2019.hcl" || true
assert_no_placeholders "no {{.}} placeholders in output" "$PROCESSED_FILE"

echo ""
echo "=== 6. Required values present in output ==="
assert_file_contains "Username in output" "$PROCESSED_FILE" "Administrator"
assert_file_contains "StaticIP in output" "$PROCESSED_FILE" "192.168.1.100"
assert_file_contains "Gateway in output" "$PROCESSED_FILE" "192.168.1.1"
assert_file_contains "DNSServer1 in output" "$PROCESSED_FILE" "192.168.1.10"
assert_file_contains "SubnetPrefix in output" "$PROCESSED_FILE" "/24"
assert_file_contains "FirstLogonCommands WinRM" "$PROCESSED_FILE" "winrm quickconfig"
assert_file_contains "Order 2 for WinRM" "$PROCESSED_FILE" "<Order>2</Order>"

echo ""
echo "=== 7. FirstLogonCommands order (2022: SConfig Order 1, WinRM Order 2) ==="
run_processing "$TMPDIR_VARS/v2022.hcl" || true
assert_file_contains "SConfig Order 1" "$PROCESSED_FILE" "Disable SConfig Auto-launch"
assert_file_contains "WinRM Order 2 after SConfig" "$PROCESSED_FILE" "<Order>2</Order>"

echo ""
echo "=== 8. ProductKey: omitted when product_key empty; injected when product_key set in vars ==="
run_processing "$TMPDIR_VARS/v2019.hcl" || true
assert_file_not_contains "2019 no product_key: no ProductKey" "$PROCESSED_FILE" "<ProductKey>"
assert_file_not_contains "2019 no ProductKeyXML placeholder" "$PROCESSED_FILE" "ProductKeyXML"
run_processing "$TMPDIR_VARS/v2022.hcl" || true
assert_file_not_contains "2022 no product_key: no ProductKey" "$PROCESSED_FILE" "<ProductKey>"
assert_file_not_contains "2022 no ProductKeyXML placeholder" "$PROCESSED_FILE" "ProductKeyXML"
run_processing "$TMPDIR_VARS/v2025.hcl" || true
assert_file_not_contains "2025 no product_key: no ProductKey" "$PROCESSED_FILE" "<ProductKey>"
assert_file_not_contains "2025 no ProductKeyXML placeholder" "$PROCESSED_FILE" "ProductKeyXML"

# When product_key is set in vars file, ProductKey block is added
minimal_vars 2022 > "$TMPDIR_VARS/v2022_with_key.hcl"
echo 'product_key = "VDYBN-27WPP-V4HQT-9VMD4-VMK7H"' >> "$TMPDIR_VARS/v2022_with_key.hcl"
run_processing "$TMPDIR_VARS/v2022_with_key.hcl" || true
assert_file_contains "2022 with product_key: has ProductKey block" "$PROCESSED_FILE" "<ProductKey>"
assert_file_contains "2022 with product_key: key value" "$PROCESSED_FILE" "VDYBN-27WPP-V4HQT-9VMD4-VMK7H"
assert_file_contains "2022 with product_key: WillShowUI Never" "$PROCESSED_FILE" "WillShowUI>Never</WillShowUI>"
assert_file_not_contains "2022 with product_key: no placeholder" "$PROCESSED_FILE" "ProductKeyXML"

echo ""
print_test_results
