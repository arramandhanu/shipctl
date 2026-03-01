#!/usr/bin/env bash
#==============================================================================
# Behavioral Tests - git.sh
#
# Tests actual git utility function behavior.
#==============================================================================

TEST_DIR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$TEST_DIR_PATH")"

# Source dependencies
source "${PROJECT_ROOT}/lib/colors.sh"
source "${PROJECT_ROOT}/lib/git.sh"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RESET='\033[0m'

log_pass() { echo -e "  ${GREEN}✓${RESET} $1"; ((TESTS_PASSED++)) || true; }
log_fail() { echo -e "  ${RED}✗${RESET} $1"; ((TESTS_FAILED++)) || true; }

assert_true() {
    local msg="${1:-assertion}"
    if eval "$2"; then log_pass "$msg"
    else log_fail "$msg"; fi
}

assert_false() {
    local msg="${1:-assertion}"
    if ! eval "$2"; then log_pass "$msg"
    else log_fail "$msg"; fi
}

assert_eq() {
    local expected="$1" actual="$2" msg="${3:-assertion}"
    if [[ "$expected" == "$actual" ]]; then log_pass "$msg"
    else log_fail "$msg (expected: '$expected', got: '$actual')"; fi
}

echo ""
echo -e "${CYAN}━━━ Behavioral Tests: git.sh ━━━${RESET}"
echo ""

#------------------------------------------------------------------------------
# is_git_url
#------------------------------------------------------------------------------
echo -e "${CYAN}[TEST] is_git_url${RESET}"

# Valid URLs
is_git_url "https://github.com/user/repo.git" && log_pass "is_git_url: HTTPS .git URL" || log_fail "is_git_url: HTTPS .git URL"
is_git_url "https://github.com/user/repo" && log_pass "is_git_url: HTTPS URL (no .git)" || log_fail "is_git_url: HTTPS URL (no .git)"
is_git_url "git@github.com:user/repo.git" && log_pass "is_git_url: SSH URL" || log_fail "SSH"
is_git_url "ssh://git@github.com/user/repo.git" && log_pass "is_git_url: SSH protocol URL" || log_fail "SSH protocol"
is_git_url "git://github.com/user/repo.git" && log_pass "is_git_url: git:// URL" || log_fail "git://"
is_git_url "https://gitlab.com/user/project.git" && log_pass "is_git_url: GitLab HTTPS" || log_fail "GitLab"
is_git_url "git@bitbucket.org:user/repo.git" && log_pass "is_git_url: Bitbucket SSH" || log_fail "Bitbucket"

# Invalid URLs
is_git_url "../relative/path" && log_fail "is_git_url: relative path should fail" || log_pass "is_git_url: rejects relative path"
is_git_url "/absolute/path" && log_fail "is_git_url: absolute path should fail" || log_pass "is_git_url: rejects absolute path"
is_git_url "" && log_fail "is_git_url: empty should fail" || log_pass "is_git_url: rejects empty string"

#------------------------------------------------------------------------------
# get_cache_dir
#------------------------------------------------------------------------------
echo ""
echo -e "${CYAN}[TEST] get_cache_dir${RESET}"

result=$(get_cache_dir "frontend")
if [[ "$result" == *"frontend"* ]]; then log_pass "get_cache_dir: includes service name"
else log_fail "get_cache_dir: should include service name (got: $result)"; fi

if [[ "$result" == *".git-cache"* ]]; then log_pass "get_cache_dir: includes .git-cache"
else log_fail "get_cache_dir: should include .git-cache (got: $result)"; fi

result_a=$(get_cache_dir "service-a")
result_b=$(get_cache_dir "service-b")
if [[ "$result_a" != "$result_b" ]]; then log_pass "get_cache_dir: different services get different dirs"
else log_fail "get_cache_dir: dirs should differ"; fi

#------------------------------------------------------------------------------
# Summary
#------------------------------------------------------------------------------
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "  Passed: ${GREEN}${TESTS_PASSED}${RESET}"
echo -e "  Failed: ${RED}${TESTS_FAILED}${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

[[ $TESTS_FAILED -gt 0 ]] && exit 1 || exit 0
