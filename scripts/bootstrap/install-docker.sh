#!/usr/bin/env bash
#set -euo pipefail
# Temporarily disabled for debugging

############################################
# install-docker.sh
# Docker & Compose installation for Ubuntu
# Includes configuration
############################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Installation options
DOCKER_VERSION="${DOCKER_VERSION:-latest}"
COMPOSE_VERSION="${COMPOSE_VERSION:-v2.24.0}"
USE_CHINA_MIRROR="${USE_CHINA_MIRROR:-true}"
SKIP_INSTALL="${SKIP_INSTALL:-false}"
SKIP_CONFIG="${SKIP_CONFIG:-false}"

# Configuration options
CONFIGURE_LOGGING="${CONFIGURE_LOGGING:-true}"
CONFIGURE_NETWORK="${CONFIGURE_NETWORK:-true}"
CONFIGURE_STORAGE="${CONFIGURE_STORAGE:-true}"

log() {
  echo -e "\033[1;34m[DOCKER]\033[0m $*"
}

err() {
  echo -e "\033[1;31m[DOCKER][ERROR]\033[0m $*" >&2
  exit 1
}

check_root() {
  [[ $EUID -ne 0 ]] && err "Please run as root"
}

############################################
# Installation functions
############################################

remove_old_docker() {
  log "Removing old Docker packages..."
  apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
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
    apt-transport-https \
    software-properties-common \
    jq
}

add_docker_repository() {
  log "Adding Docker repository..."

  local codename="$(lsb_release -cs)"
  local keyring_dir="/etc/apt/keyrings"
  mkdir -p "$keyring_dir"

  local gpg_url
  local repo_url

  # Try Aliyun mirror first, fall back to official if it fails
  if [[ "$USE_CHINA_MIRROR" == "true" ]]; then
    # Test if Aliyun Docker mirror is accessible
    if curl -sf --connect-timeout 5 --max-time 10 "https://mirrors.aliyun.com/docker-ce/linux/ubuntu/dists/${codename}/InRelease" >/dev/null 2>&1; then
      gpg_url="https://mirrors.aliyun.com/docker-ce/linux/gpg"
      repo_url="deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://mirrors.aliyun.com/docker-ce/linux/ubuntu ${codename} stable"
      log "Using Aliyun Docker mirror"
    else
      # Fall back to official Docker repository
      gpg_url="https://download.docker.com/linux/ubuntu/gpg"
      repo_url="deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${codename} stable"
      log "Aliyun Docker mirror unavailable, using official Docker repository"
    fi
  else
    gpg_url="https://download.docker.com/linux/ubuntu/gpg"
    repo_url="deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${codename} stable"
  fi

  # Always use official Docker GPG key (more reliable)
  log "Downloading GPG key from official Docker repository..."
  gpg_url="https://download.docker.com/linux/ubuntu/gpg"
  rm -f "$keyring_dir/docker.gpg" 2>/dev/null || true
  if ! curl -fsSL --retry 3 --retry-delay 2 "$gpg_url" | gpg --dearmor -o "$keyring_dir/docker.gpg" 2>/dev/null; then
    # If curl fails, try using gpg directly
    log "Trying alternative GPG key download method..."
    gpg --keyserver "keyserver.ubuntu.com" --recv-keys 7EA0A9C3F273FCD8 2>/dev/null || true
    gpg --export 7EA0A9C3F273FCD8 | gpg --dearmor -o "$keyring_dir/docker.gpg" 2>/dev/null || true
  fi
  
  if [[ -f "$keyring_dir/docker.gpg" ]]; then
    chmod a+r "$keyring_dir/docker.gpg"
  else
    err "Failed to download Docker GPG key"
  fi

  echo "$repo_url" > /etc/apt/sources.list.d/docker.list

  # Try to add the Docker GPG key to apt's trusted keys to avoid NO_PUBKEY errors
  log "Ensuring Docker GPG key is trusted by apt..."
  if command -v gpg >/dev/null 2>&1; then
    gpg --keyserver "keyserver.ubuntu.com" --recv-keys 7EA0A9C3F273FCD8 2>/dev/null || true
    gpg --export 7EA0A9C3F273FCD8 | apt-key add - 2>/dev/null || true
  fi
}

install_docker() {
  log "Installing Docker Engine..."

  apt update

  if [[ "$DOCKER_VERSION" == "latest" ]]; then
    apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  else
    apt install -y "docker-ce=${DOCKER_VERSION}*" "docker-ce-cli=${DOCKER_VERSION}*" containerd.io docker-buildx-plugin docker-compose-plugin
  fi
}

get_architecture() {
  local arch
  arch=$(uname -m)

  case "$arch" in
    x86_64)  echo "x86_64" ;;
    aarch64|arm64)  echo "aarch64" ;;
    armv7)  echo "armv7" ;;
    *)  err "Unsupported architecture: $arch" ;;
  esac
}

install_docker_compose_standalone() {
  log "Installing Docker Compose standalone..."

  # Skip if Docker Compose plugin is already installed
  if docker compose version &>/dev/null 2>&1; then
    log "Docker Compose plugin already installed, skipping standalone"
    return 0
  fi

  local arch
  arch=$(get_architecture)

  local download_url
  local download_path="/tmp/docker-compose"

  # Try Aliyun mirror first, fall back to GitHub releases
  if [[ "$USE_CHINA_MIRROR" == "true" ]]; then
    # Test if Aliyun mirror is accessible for Docker Compose
    if curl -sf --connect-timeout 5 --max-time 10 "https://mirrors.aliyun.com/docker-toolbox/linux/v2.24.0/docker-compose-linux-${arch}" -o /dev/null 2>&1; then
      download_url="https://mirrors.aliyun.com/docker-toolbox/linux/${COMPOSE_VERSION}/docker-compose-linux-${arch}"
      log "Using Aliyun Docker Compose mirror"
    else
      # Fall back to GitHub releases (using a China-friendly approach)
      download_url="https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-${arch}"
      log "Aliyun Docker Compose mirror unavailable, using GitHub releases"
    fi
  else
    download_url="https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-${arch}"
  fi

  log "Downloading Docker Compose from $download_url"
  if ! curl -fsSL "$download_url" -o "$download_path"; then
    # Try alternative version format (without 'v' prefix)
    local alt_version="${COMPOSE_VERSION#v}"
    local alt_url="https://github.com/docker/compose/releases/download/${alt_version}/docker-compose-linux-${arch}"
    log "Trying alternative URL: $alt_url"
    if ! curl -fsSL "$alt_url" -o "$download_path"; then
      err "Failed to download Docker Compose from all available sources"
    fi
  fi
  chmod +x "$download_path"

  # Install to /usr/local/bin
  if [[ -f /usr/local/bin/docker-compose ]]; then
    mv /usr/local/bin/docker-compose "/usr/local/bin/docker-compose.backup.$(date +%Y%m%d%H%M%S)"
  fi
  mv "$download_path" /usr/local/bin/docker-compose

  log "Docker Compose installed to /usr/local/bin/docker-compose"
}

############################################
# Configuration functions
############################################

configure_daemon() {
  log "Configuring Docker daemon..."

  mkdir -p /etc/docker

  local daemon_config='{}'

  # Configure logging
  if [[ "$CONFIGURE_LOGGING" == "true" ]]; then
    daemon_config=$(echo "$daemon_config" | jq '. * {
      "log-driver": "json-file",
      "log-opts": {
        "max-size": "100m",
        "max-file": "5"
      }
    }')
  fi

  # Configure storage driver
  if [[ "$CONFIGURE_STORAGE" == "true" ]]; then
    daemon_config=$(echo "$daemon_config" | jq '. + { "storage-driver": "overlay2" }')
  fi

  # Configure network
  if [[ "$CONFIGURE_NETWORK" == "true" ]]; then
    daemon_config=$(echo "$daemon_config" | jq '. * {
      "icc": false,
      "live-restore": true,
      "default-address-pools": [{ "base": "172.17.0.0/12", "size": 24 }]
    }')
  fi

  # Configure registry mirrors for China
  if [[ "$USE_CHINA_MIRROR" == "true" ]]; then
    daemon_config=$(echo "$daemon_config" | jq '. + {
      "registry-mirrors": [
        "https://docker.mirrors.aliyun.com",
        "https://hub-mirror.c.163.com",
        "https://mirror.baidubce.com",
        "https://docker.m.daocloud.io",
        "https://dockerpull.com",
        "https://docker.1ms.run"
      ]
    }')
  fi

  # Add container resource limits
  daemon_config=$(echo "$daemon_config" | jq '. + {
    "default-ulimits": {
      "nofile": { "Name": "nofile", "Hard": 65536, "Soft": 65536 },
      "nproc": { "Name": "nproc", "Hard": 65536, "Soft": 65536 }
    }
  }')

  echo "$daemon_config" > /etc/docker/daemon.json
  log "Docker daemon configuration updated"
}

configure_docker_service() {
  log "Configuring Docker service..."

  mkdir -p /etc/systemd/system/docker.service.d

  cat > /etc/systemd/system/docker.service.d/override.conf <<'EOF'
[Service]
TimeoutStartSec=300
EOF

  systemctl daemon-reload
}

configure_network() {
  log "Configuring Docker network..."

  # Enable iptables forwarding
  if ! iptables -C FORWARD -j ACCEPT 2>/dev/null; then
    iptables -A FORWARD -j ACCEPT
  fi

  # Create custom network if needed
  if ! docker network ls | grep -q "homelab-net"; then
    docker network create --driver bridge --subnet 172.20.0.0/16 homelab-net 2>/dev/null || true
  fi
}

configure_docker_socket() {
  if [[ -S /var/run/docker.sock ]]; then
    chmod 666 /var/run/docker.sock 2>/dev/null || true
  fi
}

restart_docker() {
  log "Restarting Docker service..."
  systemctl restart docker
  sleep 3
  systemctl is-active --quiet docker || err "Failed to start Docker service"
  log "Docker service restarted successfully"
}

verify_installation() {
  log "Verifying installation..."

  docker --version || err "Docker not installed"
  docker compose version 2>/dev/null || log "Docker Compose plugin not available"

  docker info >/dev/null 2>&1 || err "Docker daemon not running"

  log "Installation verified successfully"
}

add_user_to_docker_group() {
  local user="${SUDO_USER:-$(whoami)}"
  [[ -z "$user" ]] || [[ "$user" == "root" ]] && return 0

  log "Adding user '$user' to docker group..."
  usermod -aG docker "$user"
  log "User '$user' added to docker group. Please log out and back in, or run: newgrp docker"
}

show_completion_info() {
  log "============================================"
  log "Docker installation completed! 🎉"
  log "============================================"
  log ""
  log "Usage:"
  log "  docker ps                    - List containers"
  log "  docker compose up -d         - Start services"
  log "  docker compose logs -f       - View logs"
  log ""
  log "Docker Compose files: ./docker/compose/"
  log ""
  log "Next steps:"
  log "  1. Add user to docker group: usermod -aG docker <user>"
  log "  2. Log out and back in"
  log "  3. Test: docker run hello-world"
  log ""
}

############################################
# Main
############################################

main() {
  check_root

  if [[ "$SKIP_INSTALL" != "true" ]]; then
    remove_old_docker
    install_prerequisites
    add_docker_repository
    install_docker
    install_docker_compose_standalone
  fi

  if [[ "$SKIP_CONFIG" != "true" ]]; then
    configure_daemon
    configure_docker_service
    configure_docker_socket

    if [[ "$CONFIGURE_NETWORK" == "true" ]]; then
      configure_network
    fi

    restart_docker
  fi

  verify_installation

  # Add user to docker group
  if [[ -n "${SUDO_USER:-}" ]]; then
    add_user_to_docker_group "$SUDO_USER"
  fi

  show_completion_info
}

main "$@"
