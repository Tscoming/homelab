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
# 2. Timezone & time sync (must be BEFORE APT mirror config)
############################################
log "Configuring timezone and NTP..."

timedatectl set-timezone Asia/Shanghai

# Use Chinese NTP servers for better performance
cat > /etc/systemd/timesyncd.conf <<EOF
[Time]
NTP=ntp.aliyun.com ntp.tencent.com
FallbackNTP=ntp.ntsc.ac.cn
EOF

systemctl enable systemd-timesyncd
systemctl start systemd-timesyncd

# Wait briefly for time sync
sleep 2

log "Time sync status: $(timedatectl show-timesync --property=SystemClockSynchronized --value)"

############################################
# 3. APT mirror
############################################
log "Configuring APT China mirror..."

# If set-apt-cn.sh exists locally, use it; otherwise download from GitHub
if [[ -x "${SCRIPT_DIR}/set-apt-cn.sh" ]]; then
  log "Using local set-apt-cn.sh..."
  "${SCRIPT_DIR}/set-apt-cn.sh"
else
  log "Downloading set-apt-cn.sh from GitHub..."
  SET_APT_CN_URL="https://raw.githubusercontent.com/Tscoming/homelab/main/scripts/bootstrap/set-apt-cn.sh"
  SET_APT_CN_TMP="/tmp/set-apt-cn.sh"
  
  if ! curl -fsSL "$SET_APT_CN_URL" -o "$SET_APT_CN_TMP"; then
    err "Failed to download set-apt-cn.sh"
  fi
  
  chmod +x "$SET_APT_CN_TMP"
  "$SET_APT_CN_TMP"
fi

############################################
# 4. System tuning
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
# 5. SSH hardening (minimal & safe)
############################################
log "Configuring SSH..."

# Install openssh-server if not present
if ! command -v sshd &>/dev/null; then
  log "Installing openssh-server..."
  apt install -y openssh-server
fi

# Ensure sshd_config.d directory exists
mkdir -p /etc/ssh/sshd_config.d

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

