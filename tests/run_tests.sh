#!/usr/bin/env bash
#==============================================================================
# shipctl Test Suite
#
# Runs verification tests for shipctl modules including:
# - Orchestrator modules (Compose, Swarm, Kubernetes)
# - Cloud provider modules (AWS, GCP, Azure, Alibaba)
# - Core library functions
#
# Usage: ./tests/run_tests.sh [options]
#
# Options:
#   --unit      Run unit tests only
#   --syntax    Run syntax checks only
#   --mock      Run with mock dependencies
#   --verbose   Enable verbose output
#
# Author: shipctl
# License: MIT
#==============================================================================

set -u  # Strict undefined variables, but allow command failures for assertions

# Test directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RESET='\033[0m'

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Options
RUN_UNIT=true
RUN_SYNTAX=true
USE_MOCK=false
VERBOSE=false

#------------------------------------------------------------------------------
# Parse arguments
#------------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --unit)
            RUN_SYNTAX=false
            shift
            ;;
        --syntax)
            RUN_UNIT=false
            shift
            ;;
        --mock)
            USE_MOCK=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--unit|--syntax] [--mock] [--verbose]"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

#------------------------------------------------------------------------------
# Test utilities
#------------------------------------------------------------------------------
log_test() {
    echo -e "${CYAN}[TEST]${RESET} $1"
}

log_pass() {
    echo -e "  ${GREEN}✓ PASS${RESET}: $1"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "  ${RED}✗ FAIL${RESET}: $1"
    ((TESTS_FAILED++))
}

log_skip() {
    echo -e "  ${YELLOW}○ SKIP${RESET}: $1"
    ((TESTS_SKIPPED++))
}

assert_eq() {
    local expected="$1"
    local actual="$2"
    local msg="${3:-assertion failed}"
    
    if [[ "$expected" == "$actual" ]]; then
        log_pass "$msg"
    else
        log_fail "$msg (expected: '$expected', got: '$actual')"
    fi
    return 0
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local msg="${3:-assertion failed}"
    
    if [[ "$haystack" == *"$needle"* ]]; then
        log_pass "$msg"
    else
        log_fail "$msg (expected to contain: '$needle')"
    fi
    return 0
}

assert_file_exists() {
    local file="$1"
    local msg="${2:-file should exist: $file}"
    
    if [[ -f "$file" ]]; then
        log_pass "$msg"
    else
        log_fail "$msg"
    fi
    return 0
}

assert_command_exists() {
    local cmd="$1"
    local msg="${2:-command should exist: $cmd}"
    
    if command -v "$cmd" &>/dev/null; then
        log_pass "$msg"
        return 0
    else
        log_skip "$msg (command not available)"
        return 0
    fi
}

#------------------------------------------------------------------------------
# Syntax check tests
#------------------------------------------------------------------------------
test_syntax() {
    log_test "Running syntax checks..."
    
    local files=(
        "$PROJECT_ROOT/shipctl"
        "$PROJECT_ROOT/lib/orchestrator.sh"
        "$PROJECT_ROOT/lib/provider.sh"
        "$PROJECT_ROOT/lib/ssh.sh"
        "$PROJECT_ROOT/lib/docker.sh"
        "$PROJECT_ROOT/lib/utils.sh"
        "$PROJECT_ROOT/lib/checks.sh"
        "$PROJECT_ROOT/lib/orchestrators/compose.sh"
        "$PROJECT_ROOT/lib/orchestrators/swarm.sh"
        "$PROJECT_ROOT/lib/orchestrators/kubernetes.sh"
        "$PROJECT_ROOT/lib/providers/aws.sh"
        "$PROJECT_ROOT/lib/providers/gcp.sh"
        "$PROJECT_ROOT/lib/providers/azure.sh"
        "$PROJECT_ROOT/lib/providers/alibaba.sh"
    )
    
    for file in "${files[@]}"; do
        if [[ -f "$file" ]]; then
            if bash -n "$file" 2>/dev/null; then
                log_pass "Syntax OK: $(basename "$file")"
            else
                log_fail "Syntax error: $(basename "$file")"
            fi
        else
            log_skip "File not found: $(basename "$file")"
        fi
    done
}

#------------------------------------------------------------------------------
# Module structure tests
#------------------------------------------------------------------------------
test_module_structure() {
    log_test "Testing module structure..."
    
    # Core files
    assert_file_exists "$PROJECT_ROOT/shipctl" "Main script exists"
    assert_file_exists "$PROJECT_ROOT/lib/orchestrator.sh" "Orchestrator interface exists"
    assert_file_exists "$PROJECT_ROOT/lib/provider.sh" "Provider interface exists"
    
    # Orchestrator modules
    assert_file_exists "$PROJECT_ROOT/lib/orchestrators/compose.sh" "Compose orchestrator exists"
    assert_file_exists "$PROJECT_ROOT/lib/orchestrators/swarm.sh" "Swarm orchestrator exists"
    assert_file_exists "$PROJECT_ROOT/lib/orchestrators/kubernetes.sh" "Kubernetes orchestrator exists"
    
    # Provider modules
    assert_file_exists "$PROJECT_ROOT/lib/providers/aws.sh" "AWS provider exists"
    assert_file_exists "$PROJECT_ROOT/lib/providers/gcp.sh" "GCP provider exists"
    assert_file_exists "$PROJECT_ROOT/lib/providers/azure.sh" "Azure provider exists"
    assert_file_exists "$PROJECT_ROOT/lib/providers/alibaba.sh" "Alibaba provider exists"
}

#------------------------------------------------------------------------------
# Function existence tests
#------------------------------------------------------------------------------
test_orchestrator_functions() {
    log_test "Testing orchestrator function definitions..."
    
    local orchestrator_file="$PROJECT_ROOT/lib/orchestrator.sh"
    
    local functions=(
        "orchestrator_detect"
        "orchestrator_validate"
        "orchestrator_deploy"
        "orchestrator_rollback"
        "orchestrator_status"
        "orchestrator_scale"
    )
    
    for fn in "${functions[@]}"; do
        if grep -q "^${fn}()" "$orchestrator_file" 2>/dev/null; then
            log_pass "Function exists: $fn"
        else
            log_fail "Missing function: $fn"
        fi
    done
}

test_compose_functions() {
    log_test "Testing Compose orchestrator functions..."
    
    local file="$PROJECT_ROOT/lib/orchestrators/compose.sh"
    
    local functions=(
        "compose_deploy"
        "compose_rollback"
        "compose_status"
    )
    
    for fn in "${functions[@]}"; do
        if grep -q "^${fn}()" "$file" 2>/dev/null; then
            log_pass "Function exists: $fn"
        else
            log_fail "Missing function: $fn"
        fi
    done
}

test_swarm_functions() {
    log_test "Testing Swarm orchestrator functions..."
    
    local file="$PROJECT_ROOT/lib/orchestrators/swarm.sh"
    
    local functions=(
        "swarm_deploy"
        "swarm_rollback"
        "swarm_status"
        "swarm_scale"
    )
    
    for fn in "${functions[@]}"; do
        if grep -q "^${fn}()" "$file" 2>/dev/null; then
            log_pass "Function exists: $fn"
        else
            log_fail "Missing function: $fn"
        fi
    done
}

test_kubernetes_functions() {
    log_test "Testing Kubernetes orchestrator functions..."
    
    local file="$PROJECT_ROOT/lib/orchestrators/kubernetes.sh"
    
    local functions=(
        "k8s_deploy"
        "k8s_rollback"
        "k8s_status"
        "k8s_scale"
        "k8s_validate"
    )
    
    for fn in "${functions[@]}"; do
        if grep -q "^${fn}()" "$file" 2>/dev/null; then
            log_pass "Function exists: $fn"
        else
            log_fail "Missing function: $fn"
        fi
    done
}

test_provider_functions() {
    log_test "Testing provider function definitions..."
    
    local provider_file="$PROJECT_ROOT/lib/provider.sh"
    
    local functions=(
        "provider_validate"
        "provider_deploy"
        "provider_registry_login"
        "provider_push_image"
        "provider_is_cloud"
    )
    
    for fn in "${functions[@]}"; do
        if grep -q "^${fn}()" "$provider_file" 2>/dev/null; then
            log_pass "Function exists: $fn"
        else
            log_fail "Missing function: $fn"
        fi
    done
}

test_aws_functions() {
    log_test "Testing AWS provider functions..."
    
    local file="$PROJECT_ROOT/lib/providers/aws.sh"
    
    local functions=(
        "aws_ecr_login"
        "aws_ecr_push"
        "aws_ecs_deploy"
        "validate_aws_prerequisites"
    )
    
    for fn in "${functions[@]}"; do
        if grep -q "^${fn}()" "$file" 2>/dev/null; then
            log_pass "Function exists: $fn"
        else
            log_fail "Missing function: $fn"
        fi
    done
}

test_gcp_functions() {
    log_test "Testing GCP provider functions..."
    
    local file="$PROJECT_ROOT/lib/providers/gcp.sh"
    
    local functions=(
        "gcp_gcr_login"
        "gcp_gcr_push"
        "gcp_cloudrun_deploy"
        "validate_gcp_prerequisites"
    )
    
    for fn in "${functions[@]}"; do
        if grep -q "^${fn}()" "$file" 2>/dev/null; then
            log_pass "Function exists: $fn"
        else
            log_fail "Missing function: $fn"
        fi
    done
}

#------------------------------------------------------------------------------
# Help and CLI tests
#------------------------------------------------------------------------------
test_cli_help() {
    log_test "Testing CLI help output..."
    
    local help_output
    help_output=$("$PROJECT_ROOT/shipctl" --help 2>&1 || true)
    
    assert_contains "$help_output" "--orchestrator" "Help shows --orchestrator flag"
    assert_contains "$help_output" "--provider" "Help shows --provider flag"
    assert_contains "$help_output" "--cluster" "Help shows --cluster flag"
    assert_contains "$help_output" "swarm" "Help mentions Swarm"
    assert_contains "$help_output" "aws" "Help mentions AWS"
    assert_contains "$help_output" "gcp" "Help mentions GCP"
}

#------------------------------------------------------------------------------
# Configuration tests
#------------------------------------------------------------------------------
test_config_template() {
    log_test "Testing configuration template..."
    
    local config_file="$PROJECT_ROOT/config/services.env.template"
    
    assert_file_exists "$config_file" "Config template exists"
    
    if [[ -f "$config_file" ]]; then
        local config_content
        config_content=$(cat "$config_file")
        
        assert_contains "$config_content" "ORCHESTRATOR" "Config has ORCHESTRATOR"
        assert_contains "$config_content" "CLOUD_PROVIDER" "Config has CLOUD_PROVIDER"
        assert_contains "$config_content" "AWS_REGION" "Config has AWS settings"
        assert_contains "$config_content" "GCP_PROJECT_ID" "Config has GCP settings"
    fi
}

#------------------------------------------------------------------------------
# Integration tests (with mocks)
#------------------------------------------------------------------------------
test_orchestrator_dispatch() {
    log_test "Testing orchestrator dispatch logic..."
    
    local orchestrator_file="$PROJECT_ROOT/lib/orchestrator.sh"
    local content
    content=$(cat "$orchestrator_file")
    
    # Check that switch cases exist
    assert_contains "$content" "compose)" "Dispatch handles compose"
    assert_contains "$content" "swarm)" "Dispatch handles swarm"
}

#------------------------------------------------------------------------------
# Run all tests
#------------------------------------------------------------------------------
main() {
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════╗${RESET}"
    echo -e "${BLUE}║      shipctl Test Suite                  ║${RESET}"
    echo -e "${BLUE}╚══════════════════════════════════════════╝${RESET}"
    echo ""
    
    if [[ "$RUN_SYNTAX" == "true" ]]; then
        test_syntax
        echo ""
    fi
    
    if [[ "$RUN_UNIT" == "true" ]]; then
        test_module_structure
        echo ""
        test_orchestrator_functions
        echo ""
        test_compose_functions
        echo ""
        test_swarm_functions
        echo ""
        test_kubernetes_functions
        echo ""
        test_provider_functions
        echo ""
        test_aws_functions
        echo ""
        test_gcp_functions
        echo ""
        test_cli_help
        echo ""
        test_config_template
        echo ""
        test_orchestrator_dispatch
        echo ""
    fi
    
    # Summary
    echo -e "${BLUE}══════════════════════════════════════════${RESET}"
    echo -e "  Tests Passed:  ${GREEN}${TESTS_PASSED}${RESET}"
    echo -e "  Tests Failed:  ${RED}${TESTS_FAILED}${RESET}"
    echo -e "  Tests Skipped: ${YELLOW}${TESTS_SKIPPED}${RESET}"
    echo -e "${BLUE}══════════════════════════════════════════${RESET}"
    
    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo -e "\n${RED}Some tests failed!${RESET}"
        exit 1
    else
        echo -e "\n${GREEN}All tests passed!${RESET}"
        exit 0
    fi
}

main "$@"
