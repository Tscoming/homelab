#!/usr/bin/env bash
set -euo pipefail

############################################
# init-ubuntu.sh
# Ubuntu base system bootstrap
############################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() {
  echo -e "\033[1;34m[INIT]\033[0m $*"
}

err() {
  echo -e "\033[1;31m[INIT][ERROR]\033[0m $*" >&2
  exit 1
}

[[ $EUID -ne 0 ]] && err "Please run as root"

log "Starting Ubuntu initialization..."

############################################
# 1. Base packages (lsb-release required for set-apt-cn.sh)
############################################
log "Installing base packages..."

apt install -y \
  ca-certificates \
  curl \
  wget \
  gnupg \
  lsb-release \
  apt-transport-https \
  software-properties-common \
  vim \
  git \
  htop \
  tmux \
  net-tools \
  dnsutils \
  unzip \
  zip \
  rsync \
  jq

############################################
# 2. APT mirror
############################################
if [[ -x "${SCRIPT_DIR}/set-apt-cn.sh" ]]; then
  log "Configuring APT China mirror..."
  "${SCRIPT_DIR}/set-apt-cn.sh"
else
  err "set-apt-cn.sh not found or not executable"
fi

############################################
# 3. System tuning
############################################
log "Applying system tuning..."

# Increase file limits
cat > /etc/security/limits.d/99-homelab.conf <<EOF
* soft nofile 1048576
* hard nofile 1048576
EOF

# sysctl tuning
cat > /etc/sysctl.d/99-homelab.conf <<EOF
fs.file-max = 2097152
net.ipv4.ip_forward = 1
net.core.somaxconn = 65535
EOF

sysctl --system >/dev/null

############################################
# 4. Timezone & time sync
############################################
log "Configuring timezone and NTP..."

timedatectl set-timezone Asia/Shanghai
timedatectl set-ntp true

############################################
# 5. SSH hardening (minimal & safe)
############################################
log "Configuring SSH..."

SSHD_CONF="/etc/ssh/sshd_config.d/homelab.conf"

cat > "$SSHD_CONF" <<EOF
ClientAliveInterval 300
ClientAliveCountMax 2
TCPKeepAlive yes
UseDNS no
EOF

systemctl reload sshd 2>/dev/null || systemctl reload ssh 2>/dev/null || true

############################################
# 6. Clean up
############################################
log "Cleaning up..."
apt autoremove -y
apt autoclean -y

log "Ubuntu initialization completed 🎉"
log "Recommended: reboot the system"

