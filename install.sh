#!/usr/bin/env bash
#==============================================================================
# shipctl - Quick Install Script
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/arramandhanu/shipctl/main/install.sh | bash
#
# Options:
#   INSTALL_DIR=/custom/path  - Install to custom directory
#
# Default installation paths:
#   - Binary:      /usr/local/bin/shipctl (or ~/.local/bin/shipctl)
#   - App files:   /usr/local/share/shipctl (or ~/.local/share/shipctl)
#   - Completions: /etc/bash_completion.d (or ~/.local/share/bash-completion/completions)
#
#==============================================================================
set -euo pipefail

REPO="arramandhanu/shipctl"

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
for cmd in curl tar; do
    if ! command -v $cmd &>/dev/null; then
        log_error "Required command not found: $cmd"
        exit 1
    fi
done

# Clean up old installation paths (from previous versions)
# Old versions installed to ~/.local/bin/shipctl as a directory
OLD_DIR="$HOME/.local/bin/shipctl"
if [[ -d "$OLD_DIR" ]] && [[ ! -L "$OLD_DIR" ]]; then
    log_info "Removing old installation at $OLD_DIR..."
    rm -rf "$OLD_DIR"
fi

# Also check /usr/local paths
if [[ -d "/usr/local/bin/shipctl" ]] && [[ ! -L "/usr/local/bin/shipctl" ]]; then
    if [[ -w "/usr/local/bin" ]]; then
        log_info "Removing old installation at /usr/local/bin/shipctl..."
        rm -rf "/usr/local/bin/shipctl"
    fi
fi

# Determine installation paths based on permissions
USE_SUDO=""
if [[ -w /usr/local/bin ]] || [[ $EUID -eq 0 ]]; then
    # System-wide installation
    BIN_DIR="${INSTALL_DIR:-/usr/local/bin}"
    SHARE_DIR="/usr/local/share/shipctl"
    COMPLETIONS_DIR="/etc/bash_completion.d"
    ZSH_COMPLETIONS_DIR="/usr/local/share/zsh/site-functions"
else
    # User installation
    BIN_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
    SHARE_DIR="$HOME/.local/share/shipctl"
    COMPLETIONS_DIR="$HOME/.local/share/bash-completion/completions"
    ZSH_COMPLETIONS_DIR="$HOME/.local/share/zsh/site-functions"
fi

# Check if sudo is needed for system paths
if [[ "$BIN_DIR" == /usr/local/bin ]] && [[ ! -w /usr/local/bin ]] && [[ $EUID -ne 0 ]]; then
    if command -v sudo &>/dev/null; then
        USE_SUDO="sudo"
        log_info "Will use sudo for system-wide installation"
    else
        log_warn "Cannot write to /usr/local/bin, falling back to ~/.local/bin"
        BIN_DIR="$HOME/.local/bin"
        SHARE_DIR="$HOME/.local/share/shipctl"
        COMPLETIONS_DIR="$HOME/.local/share/bash-completion/completions"
        ZSH_COMPLETIONS_DIR="$HOME/.local/share/zsh/site-functions"
    fi
fi

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
$USE_SUDO mkdir -p "$BIN_DIR"
$USE_SUDO mkdir -p "$SHARE_DIR"
$USE_SUDO mkdir -p "$COMPLETIONS_DIR" 2>/dev/null || true
$USE_SUDO mkdir -p "$ZSH_COMPLETIONS_DIR" 2>/dev/null || true

# Download and extract
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

log_info "Downloading..."
curl -sL "$DOWNLOAD_URL" -o "$TEMP_DIR/shipctl.tar.gz"

log_info "Extracting..."
tar -xzf "$TEMP_DIR/shipctl.tar.gz" -C "$TEMP_DIR"

# Install application files to share directory
log_info "Installing to $SHARE_DIR..."
$USE_SUDO rm -rf "$SHARE_DIR"
$USE_SUDO cp -r "$TEMP_DIR/$EXTRACT_DIR" "$SHARE_DIR"
$USE_SUDO chmod +x "$SHARE_DIR/shipctl"

# Create symlink in bin directory
log_info "Creating symlink in $BIN_DIR..."
$USE_SUDO rm -f "$BIN_DIR/shipctl"
$USE_SUDO ln -sf "$SHARE_DIR/shipctl" "$BIN_DIR/shipctl"

# Install bash completions
if [[ -f "$SHARE_DIR/completions/shipctl.bash" ]]; then
    if [[ -d "$COMPLETIONS_DIR" ]] && [[ -w "$COMPLETIONS_DIR" || -n "$USE_SUDO" ]]; then
        $USE_SUDO cp "$SHARE_DIR/completions/shipctl.bash" "$COMPLETIONS_DIR/shipctl"
        log_success "Bash completions installed"
    fi
fi

# Install zsh completions
if [[ -f "$SHARE_DIR/completions/shipctl.bash" ]]; then
    if [[ -d "$ZSH_COMPLETIONS_DIR" ]] && [[ -w "$ZSH_COMPLETIONS_DIR" || -n "$USE_SUDO" ]]; then
        $USE_SUDO cp "$SHARE_DIR/completions/shipctl.bash" "$ZSH_COMPLETIONS_DIR/_shipctl"
        log_success "Zsh completions installed"
    fi
fi

echo ""
log_success "Installed successfully!"
echo ""
echo -e "  Binary:    ${CYAN}$BIN_DIR/shipctl${RESET}"
echo -e "  App files: ${CYAN}$SHARE_DIR${RESET}"
echo ""

# Check if in PATH
if ! command -v shipctl &>/dev/null; then
    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        echo -e "${BOLD}Add to PATH:${RESET}"
        echo ""
        echo -e "  ${CYAN}export PATH=\"$BIN_DIR:\$PATH\"${RESET}"
        echo ""
        echo "  Add this line to ~/.bashrc or ~/.zshrc"
        echo ""
    fi
else
    log_success "shipctl is in your PATH"
    echo ""
fi

echo -e "${BOLD}Get started:${RESET}"
echo ""
echo -e "  ${CYAN}cd /path/to/your/project${RESET}"
echo -e "  ${CYAN}shipctl init${RESET}"
echo -e "  ${CYAN}shipctl --help${RESET}"
echo ""
