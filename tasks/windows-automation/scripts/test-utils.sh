#!/usr/bin/env bash
# Common test helpers for windows-automation unit tests.
# Source from test scripts the same way build.sh sources scripts (vars-file-utils.sh, etc.).
# Caller must set: pass=0 fail=0 before running tests; assert_* increment pass/fail.
# Optional: call print_test_results at end to echo results and exit 0/1.

assert_equals() {
    local name="$1" expected="$2" actual="$3"
    if [[ "$actual" == "$expected" ]]; then
        echo "PASS: $name"
        ((pass++)) || true
        return 0
    fi
    echo "FAIL: $name (expected '${expected}', got '${actual}')"
    ((fail++)) || true
    return 1
}

assert_exit0() {
    local name="$1"
    shift
    if "$@" 1>/dev/null 2>&1; then
        echo "PASS: $name"
        ((pass++)) || true
        return 0
    fi
    echo "FAIL: $name (expected exit 0)"
    ((fail++)) || true
    return 1
}

assert_exit1() {
    local name="$1"
    shift
    if "$@" 1>/dev/null 2>&1; then
        echo "FAIL: $name (expected exit non-zero)"
        ((fail++)) || true
        return 1
    fi
    echo "PASS: $name"
    ((pass++)) || true
    return 0
}

assert_file_contains() {
    local name="$1" file="$2" pattern="$3"
    if [[ -f "$file" ]] && grep -q "$pattern" "$file" 2>/dev/null; then
        echo "PASS: $name"
        ((pass++)) || true
        return 0
    fi
    echo "FAIL: $name (file missing or pattern not found: $pattern)"
    ((fail++)) || true
    return 1
}

assert_file_not_contains() {
    local name="$1" file="$2" pattern="$3"
    if [[ ! -f "$file" ]] || ! grep -q "$pattern" "$file" 2>/dev/null; then
        echo "PASS: $name"
        ((pass++)) || true
        return 0
    fi
    echo "FAIL: $name (pattern should be absent: $pattern)"
    ((fail++)) || true
    return 1
}

assert_no_placeholders() {
    local name="$1" file="$2"
    if grep -q '{{\.' "$file" 2>/dev/null; then
        echo "FAIL: $name (unreplaced placeholders still in file)"
        grep '{{\.' "$file" 2>/dev/null || true
        ((fail++)) || true
        return 1
    fi
    echo "PASS: $name"
    ((pass++)) || true
    return 0
}

# Print pass/fail counts and exit 0 if no failures, 1 otherwise.
print_test_results() {
    echo "=========================================="
    echo "  Results: $pass passed, $fail failed"
    echo "=========================================="
    [[ $fail -eq 0 ]] && exit 0 || exit 1
}
