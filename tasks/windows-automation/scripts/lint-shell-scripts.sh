#!/usr/bin/env bash
# Lint all shell scripts under windows-automation using shellcheck.
# Fails on error-level issues only (e.g. SC3043 local outside function, unquoted vars that can break).
# Warnings and style are reported but do not fail the run; fix them over time or add -S warning to fail on warnings too.
# Usage: run from repo root or from windows-automation: ./scripts/lint-shell-scripts.sh
#        Or: WINDOWS_AUTOMATION_DIR=/path/to/windows-automation ./scripts/lint-shell-scripts.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WINDOWS_AUTOMATION_DIR="${WINDOWS_AUTOMATION_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
cd "$WINDOWS_AUTOMATION_DIR"

if ! command -v shellcheck >/dev/null 2>&1; then
    echo "ERROR: shellcheck is not installed. Install it to run script linting." >&2
    echo "  macOS: brew install shellcheck" >&2
    echo "  Linux: apt-get install shellcheck  or  https://github.com/koalaman/shellcheck" >&2
    exit 1
fi

echo "Linting shell scripts under: $WINDOWS_AUTOMATION_DIR"
echo "shellcheck version: $(shellcheck -V | head -1)"
if [[ "${LINT_STRICT:-0}" == "1" ]]; then
    echo "Severity: warning (strict mode - warnings fail)"
    sev="warning"
else
    echo "Severity: error (warnings/style shown but do not fail; set LINT_STRICT=1 to fail on warnings)"
    sev="error"
fi
echo ""

failed=0
while IFS= read -r -d '' f; do
    if ! shellcheck -s bash -x -a -S "$sev" "$f"; then
        failed=1
    fi
done < <(find "$WINDOWS_AUTOMATION_DIR" -maxdepth 2 -name "*.sh" -print0 | sort -z)

if [[ $failed -eq 1 ]]; then
    echo ""
    echo "One or more scripts failed shellcheck. Fix the issues above (e.g. SC3043 = local outside function)."
    exit 1
fi

echo "All shell scripts passed shellcheck (${sev} level)."
