#!/usr/bin/env bash
#==============================================================================
# Behavioral Tests - retry.sh
#
# Tests retry mechanism and timeout utilities.
#==============================================================================

TEST_DIR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$TEST_DIR_PATH")"

# Source test helpers BEFORE libs
source "${TEST_DIR_PATH}/helpers/mock.sh"

# Source dependencies
source "${PROJECT_ROOT}/lib/colors.sh"
source "${PROJECT_ROOT}/lib/retry.sh"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RESET='\033[0m'

log_pass() { echo -e "  ${GREEN}✓${RESET} $1"; ((TESTS_PASSED++)) || true; }
log_fail() { echo -e "  ${RED}✗${RESET} $1"; ((TESTS_FAILED++)) || true; }

assert_eq() {
    local expected="$1" actual="$2" msg="${3:-assertion}"
    if [[ "$expected" == "$actual" ]]; then log_pass "$msg"
    else log_fail "$msg (expected: '$expected', got: '$actual')"; fi
}

echo ""
echo -e "${CYAN}━━━ Behavioral Tests: retry.sh ━━━${RESET}"
echo ""

#------------------------------------------------------------------------------
# retry - successful on first attempt
#------------------------------------------------------------------------------
echo -e "${CYAN}[TEST] retry - success on first attempt${RESET}"

output=$(retry --attempts 3 --delay 1 -- echo "hello" 2>/dev/null)
assert_eq "hello" "$output" "retry: returns output on success"

#------------------------------------------------------------------------------
# retry - fails then succeeds
#------------------------------------------------------------------------------
echo ""
echo -e "${CYAN}[TEST] retry - eventual success${RESET}"

# Create a counter file to track attempts
COUNTER_FILE="/tmp/shipctl-retry-test-$$"
echo "0" > "$COUNTER_FILE"

test_retry_cmd() {
    local count
    count=$(cat "$COUNTER_FILE")
    count=$((count + 1))
    echo "$count" > "$COUNTER_FILE"
    
    if [[ $count -lt 3 ]]; then
        return 1
    fi
    echo "success-on-attempt-$count"
    return 0
}

output=$(retry --attempts 5 --delay 0 -- bash -c "
    count=\$(cat $COUNTER_FILE)
    count=\$((count + 1))
    echo \$count > $COUNTER_FILE
    if [ \$count -lt 3 ]; then exit 1; fi
    echo success
" 2>/dev/null)

if [[ "$output" == *"success"* ]]; then
    log_pass "retry: succeeds after failures"
else
    log_fail "retry: should succeed after initial failures (got: $output)"
fi

# Verify it took 3 attempts
attempts=$(cat "$COUNTER_FILE")
assert_eq "3" "$attempts" "retry: took exactly 3 attempts"

rm -f "$COUNTER_FILE"

#------------------------------------------------------------------------------
# retry - all attempts fail
#------------------------------------------------------------------------------
echo ""
echo -e "${CYAN}[TEST] retry - all attempts fail${RESET}"

# Create a script that always fails
FAIL_SCRIPT="/tmp/shipctl-always-fail-$$"
printf '#!/usr/bin/env bash\nexit 1\n' > "$FAIL_SCRIPT"
chmod +x "$FAIL_SCRIPT"

retry --attempts 2 --delay 0 -- "$FAIL_SCRIPT" 2>/dev/null
exit_code=$?

rm -f "$FAIL_SCRIPT"

if [[ $exit_code -ne 0 ]]; then
    log_pass "retry: returns non-zero after all failures"
else
    log_fail "retry: should return non-zero"
fi

#------------------------------------------------------------------------------
# with_timeout - command completes in time
#------------------------------------------------------------------------------
echo ""
echo -e "${CYAN}[TEST] with_timeout - within limit${RESET}"

output=$(with_timeout 5 echo "fast" 2>/dev/null)
assert_eq "fast" "$output" "with_timeout: returns output for fast command"

#------------------------------------------------------------------------------
# Default configuration values
#------------------------------------------------------------------------------
echo ""
echo -e "${CYAN}[TEST] Default configuration${RESET}"

assert_eq "3" "$RETRY_MAX_ATTEMPTS" "default: RETRY_MAX_ATTEMPTS is 3"
assert_eq "5" "$RETRY_DELAY" "default: RETRY_DELAY is 5"
assert_eq "2" "$RETRY_BACKOFF" "default: RETRY_BACKOFF is 2"
assert_eq "60" "$RETRY_MAX_DELAY" "default: RETRY_MAX_DELAY is 60"
assert_eq "10" "$SSH_CONNECT_TIMEOUT" "default: SSH_CONNECT_TIMEOUT is 10"
assert_eq "300" "$SSH_COMMAND_TIMEOUT" "default: SSH_COMMAND_TIMEOUT is 300"
assert_eq "600" "$DOCKER_BUILD_TIMEOUT" "default: DOCKER_BUILD_TIMEOUT is 600"
assert_eq "60" "$HEALTH_CHECK_TIMEOUT" "default: HEALTH_CHECK_TIMEOUT is 60"
assert_eq "5" "$HEALTH_CHECK_INTERVAL" "default: HEALTH_CHECK_INTERVAL is 5"

#------------------------------------------------------------------------------
# Summary
#------------------------------------------------------------------------------
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "  Passed: ${GREEN}${TESTS_PASSED}${RESET}"
echo -e "  Failed: ${RED}${TESTS_FAILED}${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

[[ $TESTS_FAILED -gt 0 ]] && exit 1 || exit 0
