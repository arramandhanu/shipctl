#!/usr/bin/env bash
#==============================================================================
# Behavioral Tests - notify.sh & history.sh
#
# Tests notification building and deployment history tracking.
#==============================================================================

TEST_DIR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$TEST_DIR_PATH")"

# Source test helpers BEFORE libs
source "${TEST_DIR_PATH}/helpers/mock.sh"

# Source dependencies
source "${PROJECT_ROOT}/lib/colors.sh"
source "${PROJECT_ROOT}/lib/notify.sh"
source "${PROJECT_ROOT}/lib/history.sh"

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
echo -e "${CYAN}━━━ Behavioral Tests: notify.sh & history.sh ━━━${RESET}"
echo ""

#------------------------------------------------------------------------------
# notify_is_configured
#------------------------------------------------------------------------------
echo -e "${CYAN}[TEST] notify_is_configured${RESET}"

(
    unset NOTIFY_SLACK_WEBHOOK NOTIFY_DISCORD_WEBHOOK NOTIFY_TEAMS_WEBHOOK NOTIFY_WEBHOOK_URL 2>/dev/null
    NOTIFY_SLACK_WEBHOOK=""
    NOTIFY_DISCORD_WEBHOOK=""
    NOTIFY_TEAMS_WEBHOOK=""
    NOTIFY_WEBHOOK_URL=""
    notify_is_configured && log_fail "should be false when no webhooks" || log_pass "notify_is_configured: false when unconfigured"
)

(
    NOTIFY_SLACK_WEBHOOK="https://hooks.slack.com/test"
    notify_is_configured && log_pass "notify_is_configured: true with Slack webhook" || log_fail "should be true with Slack"
)

(
    NOTIFY_DISCORD_WEBHOOK="https://discord.com/api/webhooks/test"
    notify_is_configured && log_pass "notify_is_configured: true with Discord webhook" || log_fail "should be true with Discord"
)

#------------------------------------------------------------------------------
# notify_build_message
#------------------------------------------------------------------------------
echo ""
echo -e "${CYAN}[TEST] notify_build_message${RESET}"

msg=$(notify_build_message "frontend" "success" "production" "v1.0" "30s")
if [[ "$msg" == *"✅"* ]]; then log_pass "build_message: success has ✅ emoji"
else log_fail "build_message: should have ✅"; fi

if [[ "$msg" == *"frontend"* ]]; then log_pass "build_message: contains service name"
else log_fail "build_message: should contain service name"; fi

if [[ "$msg" == *"production"* ]]; then log_pass "build_message: contains environment"
else log_fail "build_message: should contain environment"; fi

msg_fail=$(notify_build_message "backend" "failure" "staging" "" "" "Connection refused")
if [[ "$msg_fail" == *"❌"* ]]; then log_pass "build_message: failure has ❌ emoji"
else log_fail "build_message: should have ❌"; fi

if [[ "$msg_fail" == *"Connection refused"* ]]; then log_pass "build_message: contains error message"
else log_fail "build_message: should contain error"; fi

#------------------------------------------------------------------------------
# history_record & history_show
#------------------------------------------------------------------------------
echo ""
echo -e "${CYAN}[TEST] history_record & history_show${RESET}"

# Use temp directory for test history
export SHIPCTL_HISTORY_DIR="/tmp/shipctl-test-history-$$"
HISTORY_DIR="$SHIPCTL_HISTORY_DIR"
HISTORY_FILE="${HISTORY_DIR}/history.log"

history_init

if [[ -d "$HISTORY_DIR" ]]; then log_pass "history_init: creates directory"
else log_fail "history_init: should create directory"; fi

if [[ -f "$HISTORY_FILE" ]]; then log_pass "history_init: creates history file"
else log_fail "history_init: should create file"; fi

# Record some deployments
history_record "frontend" "success" "production" "v1.0" "45"
history_record "backend" "failure" "staging" "v0.9" "12"
history_record "api" "success" "production" "v2.1" "30"

line_count=$(wc -l < "$HISTORY_FILE" | tr -d ' ')
assert_eq "3" "$line_count" "history_record: recorded 3 entries"

# Verify JSON format
first_line=$(head -1 "$HISTORY_FILE")
if [[ "$first_line" == *'"service":"frontend"'* ]]; then log_pass "history_record: writes JSON with service"
else log_fail "history_record: should write JSON"; fi

if [[ "$first_line" == *'"status":"success"'* ]]; then log_pass "history_record: writes JSON with status"
else log_fail "history_record: should write status"; fi

if [[ "$first_line" == *'"duration":45'* ]]; then log_pass "history_record: writes JSON with duration"
else log_fail "history_record: should write duration"; fi

#------------------------------------------------------------------------------
# history_last
#------------------------------------------------------------------------------
echo ""
echo -e "${CYAN}[TEST] history_last${RESET}"

last=$(history_last "frontend")
if [[ "$last" == *'"service":"frontend"'* ]]; then log_pass "history_last: finds frontend"
else log_fail "history_last: should find frontend"; fi

last_prod=$(history_last "frontend" "production")
if [[ "$last_prod" == *'"environment":"production"'* ]]; then log_pass "history_last: filters by environment"
else log_fail "history_last: should filter by environment"; fi

#------------------------------------------------------------------------------
# history_show (JSON mode)
#------------------------------------------------------------------------------
echo ""
echo -e "${CYAN}[TEST] history_show --json${RESET}"

json_output=$(history_show --json --last 10)
json_lines=$(echo "$json_output" | wc -l | tr -d ' ')
assert_eq "3" "$json_lines" "history_show: returns all 3 entries as JSON"

# Filtered
filtered=$(history_show --json --service "frontend")
if [[ "$filtered" == *'"service":"frontend"'* ]]; then log_pass "history_show: filters by service"
else log_fail "history_show: should filter by service"; fi

filtered_env=$(history_show --json --env "staging")
if [[ "$filtered_env" == *'"environment":"staging"'* ]]; then log_pass "history_show: filters by environment"
else log_fail "history_show: should filter by env"; fi

#------------------------------------------------------------------------------
# history_clear
#------------------------------------------------------------------------------
echo ""
echo -e "${CYAN}[TEST] history_clear${RESET}"

history_clear 2>/dev/null
line_count=$(wc -l < "$HISTORY_FILE" | tr -d ' ')
assert_eq "0" "$line_count" "history_clear: empties history file"

# Cleanup
rm -rf "$SHIPCTL_HISTORY_DIR"

#------------------------------------------------------------------------------
# Summary
#------------------------------------------------------------------------------
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "  Passed: ${GREEN}${TESTS_PASSED}${RESET}"
echo -e "  Failed: ${RED}${TESTS_FAILED}${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

[[ $TESTS_FAILED -gt 0 ]] && exit 1 || exit 0
