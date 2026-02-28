#!/usr/bin/env bash
# set -euo pipefail
# Temporarily disabled for debugging

############################################
# install-nodejs.sh
# Node.js & npm installation for Ubuntu
# Includes configuration with China mirror support
############################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Installation options
NODE_VERSION="${NODE_VERSION:-22}"
USE_CHINA_MIRROR="${USE_CHINA_MIRROR:-true}"
SKIP_INSTALL="${SKIP_INSTALL:-false}"
SKIP_CONFIG="${SKIP_CONFIG:-false}"

# Package options
INSTALL_PNPM="${INSTALL_PNPM:-true}"
INSTALL_YARN="${INSTALL_YARN:-false}"

# Configuration options
CONFIGURE_NPM_MIRROR="${CONFIGURE_NPM_MIRROR:-true}"
CONFIGURE_GLOBAL_DIR="${CONFIGURE_GLOBAL_DIR:-true}"

log() {
  echo -e "\033[1;32m[NODEJS]\033[0m $*"
}

err() {
  echo -e "\033[1;31m[NODEJS][ERROR]\033[0m $*" >&2
  exit 1
}

check_root() {
  [[ $EUID -ne 0 ]] && err "Please run as root"
}

check_architecture() {
  local arch
  arch=$(uname -m)

  case "$arch" in
    x86_64)  echo "x86_64" ;;
    aarch64|arm64)  echo "aarch64" ;;
    *)  err "Unsupported architecture: $arch" ;;
  esac
}

############################################
# Installation functions
############################################

remove_old_node() {
  log "Removing old Node.js packages..."
  apt remove -y nodejs npm 2>/dev/null || true
  rm -f /etc/apt/sources.list.d/nodesource.list 2>/dev/null || true
  rm -f /etc/apt/keyrings/nodesource.gpg 2>/dev/null || true
  apt autoremove -y
}

install_prerequisites() {
  log "Installing prerequisites..."
  apt update
  apt install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    apt-transport-https
}

add_nodejs_repository() {
  log "Adding Node.js repository..."

  local codename="$(lsb_release -cs)"
  local keyring_dir="/etc/apt/keyrings"
  mkdir -p "$keyring_dir"

  local gpg_url
  local repo_url
  local keyring_file="$keyring_dir/nodesource.gpg"

  # Try Aliyun mirror first, fall back to official
  if [[ "$USE_CHINA_MIRROR" == "true" ]]; then
    # Test if NodeSource Aliyun mirror is accessible
    if curl -sf --connect-timeout 5 --max-time 10 "https://mirrors.aliyun.com/nodesource/rpm/nodesource-repo-${NODE_VERSION}.el${codename}.repodata/repomd.xml.key" >/dev/null 2>&1 || \
       curl -sf --connect-timeout 5 --max-time 10 "https://deb.nodesource.com/node_${NODE_VERSION}.x/dists/${codename}/InRelease" >/dev/null 2>&1; then
      # Use official NodeSource but configure China mirror for npm later
      log "NodeSource repository accessible, will configure China npm mirror"
    fi
  fi

  # Always use official NodeSource repository (more reliable)
  log "Setting up NodeSource repository for Node.js ${NODE_VERSION}.x..."

  # Download and add NodeSource GPG key
  curl -fsSL "https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key" | gpg --dearmor -o "$keyring_file" 2>/dev/null || \
    curl -fsSL "https://mirrors.aliyun.com/nodesource/rpm/nodesource-release.el8.noarch.rpm" -o /tmp/nodesource.rpm 2>/dev/null || true

  if [[ -f "$keyring_file" ]]; then
    chmod a+r "$keyring_file"
  fi

  # Create repository file
  echo "deb [arch=$(dpkg --print-architecture) signed-by=$keyring_file] https://deb.nodesource.com/node_${NODE_VERSION}.x nodistro main" > /etc/apt/sources.list.d/nodesource.list
  echo "deb-src [arch=$(dpkg --print-architecture) signed-by=$keyring_file] https://deb.nodesource.com/node_${NODE_VERSION}.x nodistro main" >> /etc/apt/sources.list.d/nodesource.list
}

install_nodejs() {
  log "Installing Node.js ${NODE_VERSION}.x and npm..."

  apt update

  apt install -y nodejs

  # Install build tools for native modules
  apt install -y \
    build-essential \
    libssl-dev \
    python3
}

install_pnpm() {
  if [[ "$INSTALL_PNPM" != "true" ]]; then
    log "Skipping pnpm installation"
    return 0
  fi

  log "Installing pnpm..."

  if command -v npm >/dev/null 2>&1; then
    npm install -g pnpm
    log "pnpm installed successfully"
  else
    err "npm not found, cannot install pnpm"
  fi
}

install_yarn() {
  if [[ "$INSTALL_YARN" != "true" ]]; then
    log "Skipping yarn installation"
    return 0
  fi

  log "Installing yarn..."

  if command -v npm >/dev/null 2>&1; then
    npm install -g yarn
    log "yarn installed successfully"
  else
    err "npm not found, cannot install yarn"
  fi
}

############################################
# Configuration functions
############################################

configure_npm_mirror() {
  if [[ "$CONFIGURE_NPM_MIRROR" != "true" ]]; then
    log "Skipping npm mirror configuration"
    return 0
  fi

  log "Configuring npm registry mirror..."

  local registry_url

  if [[ "$USE_CHINA_MIRROR" == "true" ]]; then
    # Use Taobao npm mirror (official)
    registry_url="https://registry.npmmirror.com"
    log "Using China npm mirror: $registry_url"
  else
    registry_url="https://registry.npmjs.org"
    log "Using official npm registry: $registry_url"
  fi

  # Configure npm registry
  npm config set registry "$registry_url"

  # Set default timeout
  npm config set fetch-timeout 120000
  npm config set fetch-retries 5
  npm config set fetch-retry-mintimeout 20000
  npm config set fetch-retry-maxtimeout 120000

  # Enable prefer-online to avoid cache issues
  npm config set prefer-online true

  log "npm registry configured successfully"
}

configure_npm_global() {
  if [[ "$CONFIGURE_GLOBAL_DIR" != "true" ]]; then
    log "Skipping npm global directory configuration"
    return 0
  fi

  log "Configuring npm global directory..."

  # Create npm global directory
  local npm_global_dir="/usr/local/lib/npm-global"
  mkdir -p "$npm_global_dir"

  # Configure npm global directory
  npm config set prefix "$npm_global_dir"

  # Add to PATH in profile
  local profile_file="/etc/profile.d/npm-global.sh"
  echo "export PATH=\"$npm_global_dir/bin:\$PATH\"" > "$profile_file"
  chmod +x "$profile_file"

  # Configure npm to use global directory without sudo
  npm config set prefix "$npm_global_dir"

  log "npm global directory configured: $npm_global_dir"
}

configure_npm() {
  log "Configuring npm..."

  # Set npm to use colors
  npm config set color true

  # Set default init config
  npm config set init-author-name "Homelab"
  npm config set init-license "MIT"

  # Enable progress bar
  npm config set progress true

  # Set log level
  npm config set loglevel "warn"

  log "npm configuration completed"
}

configure_pnpm_mirror() {
  if [[ "$INSTALL_PNPM" != "true" ]]; then
    return 0
  fi

  log "Configuring pnpm registry mirror..."

  if command -v pnpm >/dev/null 2>&1; then
    if [[ "$USE_CHINA_MIRROR" == "true" ]]; then
      pnpm config set registry "https://registry.npmmirror.com"
      log "pnpm mirror configured for China"
    else
      pnpm config set registry "https://registry.npmjs.org"
    fi
  fi
}

verify_installation() {
  log "Verifying installation..."

  command -v node || err "Node.js not installed"
  command -v npm || err "npm not installed"

  log "Node.js version: $(node --version)"
  log "npm version: $(npm --version)"

  if command -v pnpm >/dev/null 2>&1; then
    log "pnpm version: $(pnpm --version)"
  fi

  if command -v yarn >/dev/null 2>&1; then
    log "yarn version: $(yarn --version)"
  fi

  # Test npm can fetch packages
  npm --version >/dev/null || err "npm not working"

  log "Installation verified successfully"
}

show_completion_info() {
  log "============================================"
  log "Node.js installation completed!"
  log "============================================"
  log ""
  log "Versions installed:"
  log "  Node.js: $(node --version)"
  log "  npm: $(npm --version)"
  if command -v pnpm >/dev/null 2>&1; then
    log "  pnpm: $(pnpm --version)"
  fi
  if command -v yarn >/dev/null 2>&1; then
    log "  yarn: $(yarn --version)"
  fi
  log ""
  log "npm registry: $(npm config get registry)"
  log ""
  log "Usage:"
  log "  node -v                    - Check Node.js version"
  log "  npm -v                     - Check npm version"
  log "  npm install <package>     - Install package locally"
  log "  npm install -g <package>  - Install package globally"
  log "  pnpm add <package>         - Install with pnpm"
  log ""
  log "Environment variables:"
  log "  NODE_VERSION=18           - Install Node.js 18.x"
  log "  NODE_VERSION=22           - Install Node.js 22.x (default)"
  log "  USE_CHINA_MIRROR=false     - Use official npm registry"
  log "  INSTALL_PNPM=false         - Skip pnpm installation"
  log ""
}

############################################
# Main
############################################

main() {
  check_root

  if [[ "$SKIP_INSTALL" != "true" ]]; then
    remove_old_node
    install_prerequisites
    add_nodejs_repository
    install_nodejs
    install_pnpm
    install_yarn
  fi

  if [[ "$SKIP_CONFIG" != "true" ]]; then
    configure_npm
    configure_npm_mirror
    configure_npm_global
    configure_pnpm_mirror
  fi

  verify_installation

  show_completion_info
}

main "$@"
