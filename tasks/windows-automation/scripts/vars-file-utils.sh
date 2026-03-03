#!/usr/bin/env bash
# Parse simple key = "value" or key = value from vars files (HCL-style).
# Source from build.sh or other scripts; no standalone usage.

# Usage: get_var <vars_file> <key>
# Outputs the value to stdout; empty if file missing or key not found.
get_var() {
    local vars_file="${1:-}" key="${2:-}"
    [[ -z "$vars_file" ]] || [[ ! -f "$vars_file" ]] && return 0
    grep -E "^${key}\s*=" "$vars_file" 2>/dev/null | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1 | sed 's/^"//;s/"$//'
}
