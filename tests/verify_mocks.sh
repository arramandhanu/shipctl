#!/usr/bin/env bash
#==============================================================================
# Mock Verification Script
#
# Tests the orchestrator and provider modules with mocked external commands.
# Does not require actual Docker, kubectl, or cloud CLI tools.
#
# Usage: ./tests/verify_mocks.sh
#
# Author: shipctl
# License: MIT
#==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

echo -e "${CYAN}╔══════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║   Mock Verification Tests                ║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════╝${RESET}"
echo ""

#------------------------------------------------------------------------------
# Create mock directory
#------------------------------------------------------------------------------
MOCK_DIR=$(mktemp -d)
trap "rm -rf $MOCK_DIR" EXIT

# Create mock commands
create_mock() {
    local cmd="$1"
    local output="${2:-mocked}"
    
    cat > "$MOCK_DIR/$cmd" <<EOF
#!/bin/bash
echo "$output"
exit 0
EOF
    chmod +x "$MOCK_DIR/$cmd"
}

# Create mocks for testing
create_mock "docker" "Docker version 24.0.0"
create_mock "docker-compose" "docker-compose version 2.20.0"
create_mock "kubectl" "Client Version: v1.28.0"
create_mock "aws" "aws-cli/2.0.0"
create_mock "gcloud" "Google Cloud SDK 400.0.0"
create_mock "az" "azure-cli 2.50.0"

# Prepend mock directory to PATH
export PATH="$MOCK_DIR:$PATH"

#------------------------------------------------------------------------------
# Verification tests
#------------------------------------------------------------------------------
echo -e "${YELLOW}Testing mock command availability...${RESET}"

verify_mock() {
    local cmd="$1"
    if command -v "$cmd" &>/dev/null; then
        local version
        version=$($cmd 2>&1 | head -1)
        echo -e "  ${GREEN}✓${RESET} $cmd: $version"
        return 0
    else
        echo -e "  ${RED}✗${RESET} $cmd: not found"
        return 1
    fi
}

verify_mock docker
verify_mock docker-compose
verify_mock kubectl
verify_mock aws
verify_mock gcloud
verify_mock az

echo ""
echo -e "${YELLOW}Loading library modules...${RESET}"

# Source utility functions first (required by other modules)
# Create minimal mock implementations for testing
log_info() { echo "[INFO] $*"; }
log_warn() { echo "[WARN] $*"; }
log_error() { echo "[ERROR] $*"; }
log_success() { echo "[SUCCESS] $*"; }
export CYAN="" GREEN="" YELLOW="" RED="" RESET=""

# Source orchestrator modules
if source "$PROJECT_ROOT/lib/orchestrator.sh" 2>/dev/null; then
    echo -e "  ${GREEN}✓${RESET} lib/orchestrator.sh loaded"
else
    echo -e "  ${RED}✗${RESET} lib/orchestrator.sh failed to load"
fi

if source "$PROJECT_ROOT/lib/orchestrators/compose.sh" 2>/dev/null; then
    echo -e "  ${GREEN}✓${RESET} lib/orchestrators/compose.sh loaded"
else
    echo -e "  ${RED}✗${RESET} lib/orchestrators/compose.sh failed to load"
fi

if source "$PROJECT_ROOT/lib/orchestrators/swarm.sh" 2>/dev/null; then
    echo -e "  ${GREEN}✓${RESET} lib/orchestrators/swarm.sh loaded"
else
    echo -e "  ${RED}✗${RESET} lib/orchestrators/swarm.sh failed to load"
fi

if source "$PROJECT_ROOT/lib/orchestrators/kubernetes.sh" 2>/dev/null; then
    echo -e "  ${GREEN}✓${RESET} lib/orchestrators/kubernetes.sh loaded"
else
    echo -e "  ${RED}✗${RESET} lib/orchestrators/kubernetes.sh failed to load"
fi

# Source provider module
if source "$PROJECT_ROOT/lib/provider.sh" 2>/dev/null; then
    echo -e "  ${GREEN}✓${RESET} lib/provider.sh loaded"
else
    echo -e "  ${RED}✗${RESET} lib/provider.sh failed to load"
fi

echo ""
echo -e "${YELLOW}Testing function availability...${RESET}"

# Test orchestrator functions
test_function() {
    local fn="$1"
    if declare -f "$fn" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${RESET} $fn()"
        return 0
    else
        echo -e "  ${RED}✗${RESET} $fn() not defined"
        return 1
    fi
}

echo ""
echo "Orchestrator functions:"
test_function orchestrator_detect
test_function orchestrator_validate
test_function orchestrator_deploy
test_function orchestrator_rollback

echo ""
echo "Compose functions:"
test_function compose_deploy
test_function compose_rollback

echo ""
echo "Swarm functions:"
test_function swarm_deploy
test_function swarm_rollback
test_function swarm_scale

echo ""
echo "Kubernetes functions:"
test_function k8s_deploy
test_function k8s_rollback
test_function k8s_scale

echo ""
echo "Provider functions:"
test_function provider_detect
test_function provider_deploy

echo ""
echo -e "${GREEN}✓ Mock verification complete${RESET}"
