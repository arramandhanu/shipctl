#!/usr/bin/env bash
#==============================================================================
# shipctl - CI Integration Install Script
#
# A lightweight installer designed for CI/CD environments.
# Downloads shipctl to the current directory (no system-wide installation).
#
# Usage in CI:
#   curl -fsSL https://raw.githubusercontent.com/arramandhanu/shipctl/main/scripts/ci-install.sh | bash
#
# Options (via environment variables):
#   SHIPCTL_VERSION=v1.0.0    - Install specific version (default: latest)
#   SHIPCTL_DIR=/custom/path  - Install to custom directory (default: ./shipctl)
#
# Examples:
#   # Install latest version
#   curl -fsSL https://raw.githubusercontent.com/arramandhanu/shipctl/main/scripts/ci-install.sh | bash
#
#   # Install specific version
#   curl -fsSL https://raw.githubusercontent.com/arramandhanu/shipctl/main/scripts/ci-install.sh | SHIPCTL_VERSION=v1.0.0 bash
#
#   # Install to custom directory
#   curl -fsSL https://raw.githubusercontent.com/arramandhanu/shipctl/main/scripts/ci-install.sh | SHIPCTL_DIR=/opt/shipctl bash
#
#==============================================================================
set -euo pipefail

REPO="arramandhanu/shipctl"
INSTALL_DIR="${SHIPCTL_DIR:-.}"
VERSION="${SHIPCTL_VERSION:-latest}"

# Colors (disabled if not a terminal)
if [[ -t 1 ]]; then
    GREEN='\033[0;32m'
    CYAN='\033[0;36m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    RESET='\033[0m'
else
    GREEN='' CYAN='' YELLOW='' RED='' RESET=''
fi

log_info() { echo -e "${CYAN}[INFO]${RESET} $1"; }
log_success() { echo -e "${GREEN}[OK]${RESET} $1"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $1" >&2; }

echo ""
echo "shipctl CI Installer"
echo "━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check for curl or wget
if command -v curl &>/dev/null; then
    DOWNLOAD_CMD="curl -fsSL"
elif command -v wget &>/dev/null; then
    DOWNLOAD_CMD="wget -qO-"
else
    log_error "Neither curl nor wget found. Please install one of them."
    exit 1
fi

# Resolve version
if [[ "$VERSION" == "latest" ]]; then
    log_info "Fetching latest release..."
    LATEST_TAG=$($DOWNLOAD_CMD "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/' || echo "")
    
    if [[ -n "$LATEST_TAG" ]]; then
        VERSION="$LATEST_TAG"
        log_success "Latest version: ${VERSION}"
    else
        log_info "No releases found, using main branch"
        VERSION="main"
    fi
fi

# Build download URL
if [[ "$VERSION" == "main" ]]; then
    DOWNLOAD_URL="https://github.com/${REPO}/archive/refs/heads/main.tar.gz"
    EXTRACT_DIR="shipctl-main"
else
    DOWNLOAD_URL="https://github.com/${REPO}/archive/refs/tags/${VERSION}.tar.gz"
    EXTRACT_DIR="shipctl-${VERSION#v}"
fi

# Create temp directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Download
log_info "Downloading shipctl ${VERSION}..."
if command -v curl &>/dev/null; then
    curl -fsSL "$DOWNLOAD_URL" -o "$TEMP_DIR/shipctl.tar.gz"
else
    wget -qO "$TEMP_DIR/shipctl.tar.gz" "$DOWNLOAD_URL"
fi

# Extract
log_info "Extracting..."
tar -xzf "$TEMP_DIR/shipctl.tar.gz" -C "$TEMP_DIR"

# Install to target directory
mkdir -p "$INSTALL_DIR"

# Copy essential files only (minimal footprint for CI)
cp -r "$TEMP_DIR/$EXTRACT_DIR/shipctl" "$INSTALL_DIR/"
cp -r "$TEMP_DIR/$EXTRACT_DIR/lib" "$INSTALL_DIR/"
cp -r "$TEMP_DIR/$EXTRACT_DIR/config" "$INSTALL_DIR/"

chmod +x "$INSTALL_DIR/shipctl"

# Verify installation
if [[ -x "$INSTALL_DIR/shipctl" ]]; then
    log_success "Installed to: $INSTALL_DIR"
    echo ""
    
    # Show version
    "$INSTALL_DIR/shipctl" --version 2>/dev/null || echo "shipctl installed"
    echo ""
    
    # CI usage hint
    echo "Usage in CI:"
    echo "  chmod +x ./shipctl"
    echo "  ./shipctl --list"
    echo "  ./shipctl <service> --yes"
    echo ""
else
    log_error "Installation failed"
    exit 1
fi
