#!/usr/bin/env bash
# Test get_var and trim_var against your vars file.
# Usage: ./test-get-var-trim.sh [path/to/vars_file]
# Example: ./test-get-var-trim.sh ../variables.pkrvars.hcl
# If no path given, uses variables.pkrvars.hcl in current dir or parent.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/vars-file-utils.sh"

# Common test helpers (same pattern as build.sh sourcing scripts)
TEST_UTILS="$SCRIPT_DIR/test-utils.sh"
[[ -f "$TEST_UTILS" ]] || { echo "ERROR: test-utils.sh not found: $TEST_UTILS" >&2; exit 1; }
source "$TEST_UTILS"

# Match build.sh definition
trim_var() { printf '%s' "${1:-}" | tr -d '\r\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }

# Resolve vars file: arg, or variables.pkrvars.hcl in cwd or parent
VARS_FILE="${1:-}"
if [[ -z "$VARS_FILE" ]]; then
    if [[ -f "variables.pkrvars.hcl" ]]; then
        VARS_FILE="variables.pkrvars.hcl"
    elif [[ -f "$SCRIPT_DIR/../variables.pkrvars.hcl" ]]; then
        VARS_FILE="$SCRIPT_DIR/../variables.pkrvars.hcl"
    else
        echo "Usage: $0 [path/to/vars_file]"
        echo "No vars file given and variables.pkrvars.hcl not found in . or .."
        exit 1
    fi
fi
[[ -f "$VARS_FILE" ]] || { echo "Vars file not found: $VARS_FILE"; exit 1; }
echo "Using vars file: $VARS_FILE"
echo "---"

pass=0
fail=0

echo "=== trim_var only ==="
assert_equals "trim empty"    "" "$(trim_var "")"
assert_equals "trim spaces"   "" "$(trim_var "  ")"
assert_equals "trim newline"   "" "$(trim_var $'\n')"
assert_equals "trim no change" "foo" "$(trim_var "foo")"
assert_equals "trim both sides" "foo" "$(trim_var "  foo  ")"
assert_equals "trim quotes in value" "\"bar\"" "$(trim_var "  \"bar\"  ")"

echo ""
echo "=== get_var return code (missing key must not fail under set -e) ==="
assert_exit0 "get_var missing key" get_var "$VARS_FILE" "_nonexistent_key_"
assert_exit0 "get_var empty file path" get_var "" "any"

echo ""
echo "=== get_var + trim_var with your vars file ==="
# Keys that might exist in your vars file (we only check behavior: missing = empty, existing = value)
for key in template_path existing_base_vm_name iso_path iso_path_local vcenter_server vm_name; do
    raw=$(get_var "$VARS_FILE" "$key")
    trimmed=$(trim_var "$raw")
    # Show value (mask if sensitive)
    if [[ "$key" == *password* ]] || [[ "$key" == *pass* ]]; then
        display="[REDACTED]"
    else
        display="$trimmed"
        [[ -z "$display" ]] && display="(empty)"
    fi
    echo "  $key => $display"
    # get_var must not have failed (set -e would have exited)
    assert_exit0 "get_var $key" get_var "$VARS_FILE" "$key"
done

echo ""
echo "=== build-mode style (first non-empty wins: iso > template > existing_base) ==="
iso_path_val=$(trim_var "$(get_var "$VARS_FILE" "iso_path")")
iso_path_local_val=$(trim_var "$(get_var "$VARS_FILE" "iso_path_local")")
template_path_early=$(trim_var "$(get_var "$VARS_FILE" "template_path")")
existing_base_vm_name=$(trim_var "$(get_var "$VARS_FILE" "existing_base_vm_name")")
# Treat empty-like values as unset (e.g. '' or "" from vars file)
[[ "$iso_path_val" == "''" ]] || [[ "$iso_path_val" == '""' ]] && iso_path_val=""
[[ "$iso_path_local_val" == "''" ]] || [[ "$iso_path_local_val" == '""' ]] && iso_path_local_val=""
[[ "$template_path_early" == "''" ]] || [[ "$template_path_early" == '""' ]] && template_path_early=""
[[ "$existing_base_vm_name" == "''" ]] || [[ "$existing_base_vm_name" == '""' ]] && existing_base_vm_name=""
if [[ -n "$iso_path_val" ]] || [[ -n "$iso_path_local_val" ]]; then
    mode="iso"
elif [[ -n "$template_path_early" ]]; then
    mode="template"
elif [[ -n "$existing_base_vm_name" ]]; then
    mode="existing_base"
else
    mode="(none set)"
fi
echo "  iso_path => '${iso_path_val:-(empty)}'"
echo "  iso_path_local => '${iso_path_local_val:-(empty)}'"
echo "  template_path => '${template_path_early:-(empty)}'"
echo "  existing_base_vm_name => '${existing_base_vm_name:-(empty)}'"
echo "  Detected mode: $mode"
assert_exit0 "mode detection used get_var/trim_var without exit" true

echo ""
echo "=== Template mode: template_path used as-is (no extra value added) ==="
# Use temp vars file so we control exact content. build.sh reads template_path via trim_var(get_var()) and uses it as-is when path is absolute.
TMP_TEMPLATE=$(mktemp -t "vars-template-XXXXXX.pkrvars.hcl")
TMP_FILES="$TMP_TEMPLATE"
trap 'rm -f $TMP_FILES' EXIT
# Case 1: Absolute path – must come back exactly
echo 'template_path = "/datacenter/vm/MyTemplate"' > "$TMP_TEMPLATE"
template_path_read=$(trim_var "$(get_var "$TMP_TEMPLATE" "template_path")")
assert_equals "template_path absolute path as-is" "/datacenter/vm/MyTemplate" "$template_path_read"
# Mode with only template_path set must be template
iso_t=$(trim_var "$(get_var "$TMP_TEMPLATE" "iso_path")")
iso_local_t=$(trim_var "$(get_var "$TMP_TEMPLATE" "iso_path_local")")
tpl_t=$(trim_var "$(get_var "$TMP_TEMPLATE" "template_path")")
existing_t=$(trim_var "$(get_var "$TMP_TEMPLATE" "existing_base_vm_name")")
if [[ -n "$iso_t" ]] || [[ -n "$iso_local_t" ]]; then mode_t="iso"; elif [[ -n "$tpl_t" ]]; then mode_t="template"; elif [[ -n "$existing_t" ]]; then mode_t="existing_base"; else mode_t="(none)"; fi
assert_equals "template mode when only template_path set" "template" "$mode_t"
# Case 2: Template name (no leading slash) – must come back exactly, script uses as-is or resolves via govc
echo 'template_path = "MyTemplate"' > "$TMP_TEMPLATE"
template_path_read=$(trim_var "$(get_var "$TMP_TEMPLATE" "template_path")")
assert_equals "template_path name as-is" "MyTemplate" "$template_path_read"
# No trailing/leading junk
assert_equals "template_path no trailing space" "MyTemplate" "$(trim_var "$(get_var "$TMP_TEMPLATE" "template_path")")"

echo ""
echo "=== ISO mode: template_name and vcenter_folder can be empty ==="
# build.sh: In ISO mode, Step 8 only runs when template_path or template_name is set. template_name and vcenter_folder are optional (empty = no rename, no move).
TMP_ISO=$(mktemp -t "vars-iso-XXXXXX.pkrvars.hcl")
TMP_FILES="$TMP_FILES $TMP_ISO"
echo 'iso_path = "[datastore1]/ISOs/win.iso"' > "$TMP_ISO"
echo 'template_name = ""' >> "$TMP_ISO"
echo 'vcenter_folder = ""' >> "$TMP_ISO"
# Mode must be iso
iso_i=$(trim_var "$(get_var "$TMP_ISO" "iso_path")")
tpl_i=$(trim_var "$(get_var "$TMP_ISO" "template_path")")
tname_i=$(trim_var "$(get_var "$TMP_ISO" "template_name")")
vf_i=$(trim_var "$(get_var "$TMP_ISO" "vcenter_folder")")
if [[ -n "$iso_i" ]]; then mode_i="iso"; elif [[ -n "$tpl_i" ]]; then mode_i="template"; else mode_i="(other)"; fi
assert_equals "ISO mode when iso_path set" "iso" "$mode_i"
assert_equals "template_name empty in ISO mode" "" "$tname_i"
assert_equals "vcenter_folder empty in ISO mode" "" "$vf_i"
# Script logic: empty template_name/vcenter_folder must not cause failure (we only rename if -n template_name, only move if -n vcenter_folder)
[[ -z "$tname_i" ]] && [[ -z "$vf_i" ]] && { echo "PASS: ISO mode accepts empty template_name and vcenter_folder (script uses them only when set)"; ((pass++)) || true; } || { echo "FAIL: expected empty template_name and vcenter_folder to be valid"; ((fail++)) || true; }
# Same with keys missing (not just empty value)
TMP_ISO2=$(mktemp -t "vars-iso2-XXXXXX.pkrvars.hcl")
TMP_FILES="$TMP_FILES $TMP_ISO2"
echo 'iso_path = "[ds]/path.iso"' > "$TMP_ISO2"
# no template_name or vcenter_folder keys
tname_i2=$(trim_var "$(get_var "$TMP_ISO2" "template_name")")
vf_i2=$(trim_var "$(get_var "$TMP_ISO2" "vcenter_folder")")
assert_equals "template_name missing key in ISO mode" "" "$tname_i2"
assert_equals "vcenter_folder missing key in ISO mode" "" "$vf_i2"
# When template_name is provided (non-empty), vcenter_folder can still be empty (optional)
TMP_ISO3=$(mktemp -t "vars-iso3-XXXXXX.pkrvars.hcl")
TMP_FILES="$TMP_FILES $TMP_ISO3"
printf 'iso_path = "[ds]/x.iso"\ntemplate_name = "my-template"\nvcenter_folder = ""\n' > "$TMP_ISO3"
tname_i3=$(trim_var "$(get_var "$TMP_ISO3" "template_name")")
vf_i3=$(trim_var "$(get_var "$TMP_ISO3" "vcenter_folder")")
assert_equals "template_name set with vcenter_folder empty" "my-template" "$tname_i3"
assert_equals "vcenter_folder empty when template_name set" "" "$vf_i3"

echo ""
print_test_results
