#!/usr/bin/env bash
#==============================================================================
# shipctl - Quick Install Script
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/arramandhanu/shipctl/main/install.sh | bash
#
# Options:
#   INSTALL_DIR=/custom/path  - Install to custom directory (default: ~/.local/bin)
#
#==============================================================================
set -euo pipefail

REPO="arramandhanu/shipctl"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
COMPLETIONS_DIR="${HOME}/.local/share/bash-completion/completions"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

log_info() { echo -e "${CYAN}ℹ${RESET} $1"; }
log_success() { echo -e "${GREEN}✓${RESET} $1"; }
log_warn() { echo -e "${YELLOW}⚠${RESET} $1"; }
log_error() { echo -e "${RED}✗${RESET} $1"; }

echo ""
echo -e "${BOLD}shipctl Installer${RESET}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check dependencies
for cmd in curl tar git; do
    if ! command -v $cmd &>/dev/null; then
        log_error "Required command not found: $cmd"
        exit 1
    fi
done

# Get latest version
log_info "Fetching latest version..."
LATEST_VERSION=$(curl -sL "https://api.github.com/repos/${REPO}/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')

if [[ -z "$LATEST_VERSION" ]]; then
    log_warn "Could not fetch latest release, using main branch"
    LATEST_VERSION="main"
    DOWNLOAD_URL="https://github.com/${REPO}/archive/refs/heads/main.tar.gz"
    EXTRACT_DIR="shipctl-main"
else
    log_success "Latest version: ${LATEST_VERSION}"
    DOWNLOAD_URL="https://github.com/${REPO}/archive/refs/tags/${LATEST_VERSION}.tar.gz"
    EXTRACT_DIR="shipctl-${LATEST_VERSION#v}"
fi

# Create directories
mkdir -p "$INSTALL_DIR"
mkdir -p "$COMPLETIONS_DIR"

# Download and extract
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

log_info "Downloading..."
curl -sL "$DOWNLOAD_URL" -o "$TEMP_DIR/shipctl.tar.gz"

log_info "Extracting..."
tar -xzf "$TEMP_DIR/shipctl.tar.gz" -C "$TEMP_DIR"

# Install
SHIPCTL_HOME="${INSTALL_DIR}/shipctl"
rm -rf "$SHIPCTL_HOME"
mv "$TEMP_DIR/$EXTRACT_DIR" "$SHIPCTL_HOME"

# Create symlink
ln -sf "$SHIPCTL_HOME/shipctl" "$INSTALL_DIR/shipctl"
chmod +x "$INSTALL_DIR/shipctl"

# Install completions
if [[ -f "$SHIPCTL_HOME/completions/shipctl.bash" ]]; then
    cp "$SHIPCTL_HOME/completions/shipctl.bash" "$COMPLETIONS_DIR/shipctl"
    log_success "Completions installed"
fi

log_success "Installed to: $INSTALL_DIR/shipctl"

echo ""
echo -e "${BOLD}Next steps:${RESET}"
echo ""

# Check if in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo "  1. Add to PATH (add to ~/.bashrc or ~/.zshrc):"
    echo ""
    echo -e "     ${CYAN}export PATH=\"\$HOME/.local/bin:\$PATH\"${RESET}"
    echo ""
fi

echo "  2. Configure your project:"
echo ""
echo -e "     ${CYAN}cd /path/to/your/project${RESET}"
echo -e "     ${CYAN}shipctl init${RESET}"
echo ""
echo "  3. Run shipctl:"
echo ""
echo -e "     ${CYAN}shipctl --help${RESET}"
echo ""
log_success "Installation complete!"
