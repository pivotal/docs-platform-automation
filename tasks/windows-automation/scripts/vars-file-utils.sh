#!/usr/bin/env bash
# Parse simple key = "value" or key = value from vars files (HCL-style).
# Source from build.sh or other scripts; no standalone usage.

# Usage: get_var <vars_file> <key>
# Outputs the value to stdout; empty if file missing or key not found.
# Always returns 0 so unset/missing keys do not trigger set -e.
# Only matches exact key (e.g. "iso_path" does not match "iso_path_local"); strips double and single quotes so "" and '' are empty.
get_var() {
    local vars_file="${1:-}" key="${2:-}" out
    [[ -z "$vars_file" ]] || [[ ! -f "$vars_file" ]] && { printf ''; return 0; }
    # Match exact key: ^key= or ^key space(s) = so "iso_path" does not match "iso_path_local"
    # (grep ... || true) so missing key never fails; parentheses required so pipe connects to grep output not to true
    out=$( ( grep -E "^${key}([[:space:]]+|=)" "$vars_file" 2>/dev/null || true ) | sed 's/#.*$//' | sed 's/.*=[[:space:]]*"\([^"]*\)".*/\1/' | sed 's/.*=[[:space:]]*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1 | sed 's/^"//;s/"$//' | sed "s/^'//;s/'\$//")
    printf '%s' "${out:-}"
    return 0
}
