#!/usr/bin/env bash
#==============================================================================
# Behavioral Tests - checks.sh
#
# Tests pre-flight check functions with mock environments.
#==============================================================================

TEST_DIR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$TEST_DIR_PATH")"

# Source mock helpers BEFORE libs (libs override SCRIPT_DIR)
source "${TEST_DIR_PATH}/helpers/mock.sh"

# Source dependencies
source "${PROJECT_ROOT}/lib/colors.sh"
source "${PROJECT_ROOT}/lib/utils.sh"
source "${PROJECT_ROOT}/lib/checks.sh"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RESET='\033[0m'

log_pass() { echo -e "  ${GREEN}✓${RESET} $1"; ((TESTS_PASSED++)) || true; }
log_fail() { echo -e "  ${RED}✗${RESET} $1"; ((TESTS_FAILED++)) || true; }

echo ""
echo -e "${CYAN}━━━ Behavioral Tests: checks.sh ━━━${RESET}"
echo ""

#------------------------------------------------------------------------------
# check_env_vars
#------------------------------------------------------------------------------
echo -e "${CYAN}[TEST] check_env_vars${RESET}"

(
    export DOCKERHUB_USERNAME="testuser"
    export DOCKERHUB_PASSWORD="testpass"
    export REMOTE_HOST="192.168.1.1"
    export REMOTE_USER="deploy"
    
    check_env_vars 2>/dev/null && log_pass "check_env_vars: passes with all vars set" || log_fail "check_env_vars"
)

(
    unset DOCKERHUB_USERNAME 2>/dev/null
    unset DOCKERHUB_PASSWORD 2>/dev/null
    unset REMOTE_HOST 2>/dev/null
    unset REMOTE_USER 2>/dev/null
    
    check_env_vars 2>/dev/null && log_fail "check_env_vars: should fail with unset vars" || log_pass "check_env_vars: fails with missing vars"
)

#------------------------------------------------------------------------------
# check_dockerfile
#------------------------------------------------------------------------------
echo ""
echo -e "${CYAN}[TEST] check_dockerfile${RESET}"

TEST_DIR=$(create_test_dir)

# With Dockerfile
touch "${TEST_DIR}/Dockerfile"
check_dockerfile "$TEST_DIR" 2>/dev/null && log_pass "check_dockerfile: passes with Dockerfile" || log_fail "check_dockerfile"

# Without Dockerfile
rm -f "${TEST_DIR}/Dockerfile"
check_dockerfile "$TEST_DIR" 2>/dev/null && log_fail "check_dockerfile: should fail without Dockerfile" || log_pass "check_dockerfile: fails without Dockerfile"

cleanup_test_dir "$TEST_DIR"

#------------------------------------------------------------------------------
# check_commands
#------------------------------------------------------------------------------
echo ""
echo -e "${CYAN}[TEST] check_commands${RESET}"

check_commands "bash" "cat" "echo" 2>/dev/null && log_pass "check_commands: passes for existing commands" || log_fail "check_commands"
check_commands "nonexistent_command_xyz_123" 2>/dev/null && log_fail "check_commands: should fail for missing" || log_pass "check_commands: fails for missing command"

#------------------------------------------------------------------------------
# check_ssh_key
#------------------------------------------------------------------------------
echo ""
echo -e "${CYAN}[TEST] check_ssh_key${RESET}"

TEST_DIR=$(create_test_dir)

# Create a fake SSH key
SSH_KEY_FILE="${TEST_DIR}/test_key"
echo "fake-key-content" > "$SSH_KEY_FILE"
chmod 600 "$SSH_KEY_FILE"

(
    export SSH_KEY="$SSH_KEY_FILE"
    check_ssh_key 2>/dev/null && log_pass "check_ssh_key: passes with valid key file" || log_fail "check_ssh_key"
)

(
    export SSH_KEY="/nonexistent/key"
    check_ssh_key 2>/dev/null && log_fail "check_ssh_key: should fail for missing key" || log_pass "check_ssh_key: fails for missing key"
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
