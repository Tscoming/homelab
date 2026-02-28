#!/usr/bin/env bash
# set -euo pipefail

############################################
# install-remote-access.sh
# Ubuntu network remote access tools installer
# Includes: Rustdesk, Tailscale
############################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
  echo -e "${BLUE}[REMOTE-ACCESS]${NC} $*"
}

success() {
  echo -e "${GREEN}[REMOTE-ACCESS][OK]${NC} $*"
}

warn() {
  echo -e "${YELLOW}[REMOTE-ACCESS][WARN]${NC} $*"
}

err() {
  echo -e "${RED}[REMOTE-ACCESS][ERROR]${NC} $*"
  exit 1
}

# Check if running as root
[[ $EUID -ne 0 ]] && err "Please run as root"

# Default values
INSTALL_RUSTDESK=true
INSTALL_TAILSCALE=true

# Usage information
usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Install network remote access tools on Ubuntu.

OPTIONS:
  --rustdesk              Install Rustdesk (default: true)
  --no-rustdesk           Skip Rustdesk installation
  --tailscale             Install Tailscale (default: true)
  --no-tailscale          Skip Tailscale installation
  -h, --help              Show this help message

EXAMPLES:
  # Install both tools
  $0

  # Install only Tailscale
  $0 --no-rustdesk

  # Install only Rustdesk
  $0 --no-tailscale

EOF
  exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --rustdesk)
      INSTALL_RUSTDESK=true
      shift
      ;;
    --no-rustdesk)
      INSTALL_RUSTDESK=false
      shift
      ;;
    --tailscale)
      INSTALL_TAILSCALE=true
      shift
      ;;
    --no-tailscale)
      INSTALL_TAILSCALE=false
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      err "Unknown option: $1"
      ;;
  esac
done

############################################
# 1. Update system
############################################
log "Updating system packages..."
apt update -qq
apt upgrade -y -qq

############################################
# 2. Install Rustdesk
############################################
if [[ "$INSTALL_RUSTDESK" == "true" ]]; then
  log "Installing Rustdesk..."

  # Get latest version
  log "Getting latest Rustdesk version..."
  if command -v jq &>/dev/null; then
    RUSTDESK_VERSION=$(curl -fsSL https://api.github.com/repos/rustdesk/rustdesk/releases/latest | jq -r '.tag_name' | sed 's/^v//')
  else
    RUSTDESK_VERSION=$(curl -fsSL https://api.github.com/repos/rustdesk/rustdesk/releases/latest | grep -oP '"tag_name":\s*"\K[^"]+' | sed 's/^v//')
  fi
  if [[ -z "$RUSTDESK_VERSION" ]]; then
    err "Failed to get Rustdesk version"
  fi

  log "Latest Rustdesk version: $RUSTDESK_VERSION"

  # Check architecture and set correct package name
  ARCH=$(dpkg --print-architecture)
  case $ARCH in
    amd64)
      RUSTDESK_DEB="rustdesk-${RUSTDESK_VERSION}-x86_64.deb"
      ;;
    arm64)
      RUSTDESK_DEB="rustdesk-${RUSTDESK_VERSION}-aarch64.deb"
      ;;
    *)
      err "Unsupported architecture: $ARCH"
      ;;
  esac

  # Download Rustdesk
  RUSTDESK_TMP="/tmp/${RUSTDESK_DEB}"
  RUSTDESK_DOWNLOAD_URL="https://github.com/rustdesk/rustdesk/releases/download/${RUSTDESK_VERSION}/${RUSTDESK_DEB}"

  log "Downloading Rustdesk from GitHub..."
  if ! curl -fsSL "$RUSTDESK_DOWNLOAD_URL" -o "$RUSTDESK_TMP"; then
    err "Failed to download Rustdesk"
  fi

  # Install Rustdesk
  log "Installing Rustdesk package..."
  apt install -y "$RUSTDESK_TMP"

  # Clean up
  rm -f "$RUSTDESK_TMP"

  success "Rustdesk installed"
  log "Run 'rustdesk' to start configuration"
else
  log "Skipping Rustdesk installation"
fi

############################################
# 3. Install Tailscale
############################################
if [[ "$INSTALL_TAILSCALE" == "true" ]]; then
  log "Installing Tailscale..."

  # Add Tailscale repository
  log "Adding Tailscale GPG key and repository..."

  # Install required packages for adding repositories
  apt install -y apt-transport-https gnupg

  # Add Tailscale GPG key
  curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.noarmor.gpg | gpg --dearmor -o /usr/share/keyrings/tailscale-archive-keyring.gpg

  # Add Tailscale repository
  echo "deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] https://pkgs.tailscale.com/stable/ubuntu jammy main" > /etc/apt/sources.list.d/tailscale.list

  # Update and install
  apt update -qq
  apt install -y tailscale

  success "Tailscale installed"
  log "Run 'tailscale up' to connect"
else
  log "Skipping Tailscale installation"
fi

############################################
# 4. Summary
############################################
echo ""
log "=============================================="
success "Installation complete!"
log "=============================================="
echo ""

if [[ "$INSTALL_RUSTDESK" == "true" ]]; then
  log "Rustdesk:"
  log "  - Start: rustdesk"
  log "  - Docs:  https://rustdesk.com/docs/"
  echo ""
fi

if [[ "$INSTALL_TAILSCALE" == "true" ]]; then
  log "Tailscale:"
  log "  - Connect: tailscale up"
  log "  - Status:  tailscale status"
  log "  - Docs:    https://tailscale.com/kb/"
  echo ""
fi
