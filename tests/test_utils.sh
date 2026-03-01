#!/usr/bin/env bash
#==============================================================================
# Behavioral Tests - utils.sh
#
# Tests actual function behavior, not just existence.
#==============================================================================

TEST_DIR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$TEST_DIR_PATH")"

# Source test helpers BEFORE libs (libs override SCRIPT_DIR)
source "${TEST_DIR_PATH}/helpers/mock.sh"

# Source the module under test (need colors.sh for log functions)
source "${PROJECT_ROOT}/lib/colors.sh"
source "${PROJECT_ROOT}/lib/utils.sh"

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

assert_not_empty() {
    local value="$1" msg="${2:-should not be empty}"
    if [[ -n "$value" ]]; then log_pass "$msg"
    else log_fail "$msg (was empty)"; fi
}

echo ""
echo -e "${CYAN}━━━ Behavioral Tests: utils.sh ━━━${RESET}"
echo ""

#------------------------------------------------------------------------------
# is_empty / is_not_empty
#------------------------------------------------------------------------------
echo -e "${CYAN}[TEST] is_empty / is_not_empty${RESET}"

is_empty "" && log_pass "is_empty: empty string returns true" || log_fail "is_empty: empty string"
is_empty "hello" && log_fail "is_empty: non-empty string should be false" || log_pass "is_empty: non-empty returns false"
is_not_empty "hello" && log_pass "is_not_empty: non-empty returns true" || log_fail "is_not_empty: non-empty"
is_not_empty "" && log_fail "is_not_empty: empty should be false" || log_pass "is_not_empty: empty returns false"

#------------------------------------------------------------------------------
# command_exists
#------------------------------------------------------------------------------
echo ""
echo -e "${CYAN}[TEST] command_exists${RESET}"

command_exists "bash" && log_pass "command_exists: bash exists" || log_fail "command_exists: bash"
command_exists "nonexistent_cmd_xyz" && log_fail "command_exists: fake cmd should fail" || log_pass "command_exists: fake cmd returns false"

#------------------------------------------------------------------------------
# format_bytes
#------------------------------------------------------------------------------
echo ""
echo -e "${CYAN}[TEST] format_bytes${RESET}"

assert_eq "500B" "$(format_bytes 500)" "format_bytes: 500 bytes"
assert_eq "1KB" "$(format_bytes 1024)" "format_bytes: 1 KB"
assert_eq "5KB" "$(format_bytes 5120)" "format_bytes: 5 KB"
assert_eq "1MB" "$(format_bytes 1048576)" "format_bytes: 1 MB"
assert_eq "1GB" "$(format_bytes 1073741824)" "format_bytes: 1 GB"

#------------------------------------------------------------------------------
# relative_time
#------------------------------------------------------------------------------
echo ""
echo -e "${CYAN}[TEST] relative_time${RESET}"

assert_eq "30s" "$(relative_time 30)" "relative_time: 30 seconds"
assert_eq "2m 30s" "$(relative_time 150)" "relative_time: 2m 30s"
assert_eq "1h 5m" "$(relative_time 3900)" "relative_time: 1h 5m"

#------------------------------------------------------------------------------
# load_env_file
#------------------------------------------------------------------------------
echo ""
echo -e "${CYAN}[TEST] load_env_file${RESET}"

# Create temp env file
TEST_DIR=$(create_test_dir)
cat > "${TEST_DIR}/test.env" <<'EOF'
# This is a comment
TEST_VAR_ONE="hello"
TEST_VAR_TWO=world

# Another comment
TEST_VAR_THREE="value with spaces"
EOF

(
    load_env_file "${TEST_DIR}/test.env"
    # Note: export preserves surrounding quotes as part of the value
    assert_eq '"hello"' "$TEST_VAR_ONE" "load_env_file: reads quoted value"
    assert_eq "world" "$TEST_VAR_TWO" "load_env_file: reads unquoted value"
    assert_eq '"value with spaces"' "$TEST_VAR_THREE" "load_env_file: reads value with spaces"
)

# Test missing file
load_env_file "/nonexistent/file.env" 2>/dev/null
if [[ $? -ne 0 ]]; then log_pass "load_env_file: returns error for missing file"
else log_fail "load_env_file: should fail for missing file"; fi

cleanup_test_dir "$TEST_DIR"

#------------------------------------------------------------------------------
# get_env / require_env
#------------------------------------------------------------------------------
echo ""
echo -e "${CYAN}[TEST] get_env / require_env${RESET}"

export TEST_GET_ENV="myvalue"
assert_eq "myvalue" "$(get_env TEST_GET_ENV)" "get_env: returns set variable"
assert_eq "fallback" "$(get_env UNSET_VAR_XYZ fallback)" "get_env: returns fallback for unset"
assert_eq "" "$(get_env UNSET_VAR_XYZ)" "get_env: returns empty for unset with no fallback"
unset TEST_GET_ENV

export TEST_REQUIRE="present"
require_env "TEST_REQUIRE" 2>/dev/null && log_pass "require_env: passes for set var" || log_fail "require_env"
require_env "TOTALLY_UNSET_REQUIRE_XYZ" 2>/dev/null && log_fail "require_env: should fail for unset" || log_pass "require_env: fails for unset var"
unset TEST_REQUIRE

#------------------------------------------------------------------------------
# generate_deploy_id
#------------------------------------------------------------------------------
echo ""
echo -e "${CYAN}[TEST] generate_deploy_id${RESET}"

DEPLOY_ID=$(generate_deploy_id)
assert_not_empty "$DEPLOY_ID" "generate_deploy_id: returns non-empty"
if [[ "$DEPLOY_ID" == deploy-* ]]; then log_pass "generate_deploy_id: starts with 'deploy-'"
else log_fail "generate_deploy_id: should start with 'deploy-' (got: $DEPLOY_ID)"; fi

#------------------------------------------------------------------------------
# create_lock / remove_lock
#------------------------------------------------------------------------------
echo ""
echo -e "${CYAN}[TEST] create_lock / remove_lock${RESET}"

LOCK_FILE="/tmp/shipctl-test-lock-$$"
(
    create_lock "$LOCK_FILE" "test-service"
    if [[ -f "$LOCK_FILE" ]]; then log_pass "create_lock: creates lock file"
    else log_fail "create_lock: lock file should exist"; fi
    
    # Verify lock content
    lock_content=$(cat "$LOCK_FILE")
    if [[ "$lock_content" == *"test-service"* ]]; then log_pass "create_lock: contains service name"
    else log_fail "create_lock: should contain service name"; fi
)

remove_lock "$LOCK_FILE"
if [[ ! -f "$LOCK_FILE" ]]; then log_pass "remove_lock: removes lock file"
else log_fail "remove_lock: lock file should be removed"; fi

#------------------------------------------------------------------------------
# list_services / service_exists
#------------------------------------------------------------------------------
echo ""
echo -e "${CYAN}[TEST] list_services / service_exists${RESET}"

TEST_DIR=$(create_test_dir)
mkdir -p "${TEST_DIR}/config"
cat > "${TEST_DIR}/config/services.env" <<'EOF'
SERVICES="frontend,backend,api"
FRONTEND_IMAGE="test/frontend"
BACKEND_IMAGE="test/backend"
API_IMAGE="test/api"
EOF

(
    export DEPLOY_ROOT="$TEST_DIR"
    
    services=$(list_services)
    if [[ "$services" == *"frontend"* ]]; then log_pass "list_services: contains frontend"
    else log_fail "list_services: should contain frontend"; fi
    
    if [[ "$services" == *"backend"* ]]; then log_pass "list_services: contains backend"
    else log_fail "list_services: missing backend"; fi
    
    service_exists "frontend" && log_pass "service_exists: frontend exists" || log_fail "service_exists"
    service_exists "nonexistent" && log_fail "service_exists: should fail" || log_pass "service_exists: nonexistent returns false"
)

cleanup_test_dir "$TEST_DIR"

#------------------------------------------------------------------------------
# get_service_config
#------------------------------------------------------------------------------
echo ""
echo -e "${CYAN}[TEST] get_service_config${RESET}"

TEST_DIR=$(create_test_dir)
mkdir -p "${TEST_DIR}/config"
cat > "${TEST_DIR}/config/services.env" <<'EOF'
SERVICES="frontend,backend"
FRONTEND_IMAGE="myuser/frontend"
FRONTEND_SERVICE_NAME="web-frontend"
FRONTEND_HEALTH_PORT="3000"
BACKEND_IMAGE="myuser/backend"
EOF

(
    export DEPLOY_ROOT="$TEST_DIR"
    
    result=$(get_service_config "frontend" "image")
    assert_eq "myuser/frontend" "$result" "get_service_config: reads FRONTEND_IMAGE"
    
    result=$(get_service_config "frontend" "service_name")
    assert_eq "web-frontend" "$result" "get_service_config: reads FRONTEND_SERVICE_NAME"
    
    result=$(get_service_config "frontend" "health_port")
    assert_eq "3000" "$result" "get_service_config: reads FRONTEND_HEALTH_PORT"
    
    result=$(get_service_config "nonexistent" "image")
    assert_eq "" "$result" "get_service_config: returns empty for unknown service"
)

cleanup_test_dir "$TEST_DIR"

#------------------------------------------------------------------------------
# Summary
#------------------------------------------------------------------------------
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "  Passed: ${GREEN}${TESTS_PASSED}${RESET}"
echo -e "  Failed: ${RED}${TESTS_FAILED}${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

[[ $TESTS_FAILED -gt 0 ]] && exit 1 || exit 0
