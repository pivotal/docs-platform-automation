#!/usr/bin/env bash
# Common logging and script-runner for windows-automation.
# Source using SCRIPT_DIR so the path works from any working directory:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "$SCRIPT_DIR/scripts/common.sh"   # when caller is in windows-automation/
#   source "$SCRIPT_DIR/common.sh"            # when caller is in scripts/
# Callers should set SCRIPT_DIR to the directory containing the *caller* script.
# Optional: [[ -f "$SCRIPT_DIR/.../common.sh" ]] || { echo "ERROR: common.sh not found" >&2; exit 1; } before source.

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging: all go to stderr so they don't interfere with function return values or captured output.
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

log_debug() {
    if [[ "${LOG_LEVEL:-INFO}" == "DEBUG" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
    fi
}

# Run a script; when DEBUG_MODE is true, run with bash -x for trace output.
# Usage: run_script script_path [args...]
run_script() {
    if [[ "${DEBUG_MODE:-}" == "true" ]]; then
        bash -x "$@"
    else
        "$@"
    fi
}
