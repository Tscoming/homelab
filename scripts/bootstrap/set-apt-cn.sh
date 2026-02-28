#!/usr/bin/env bash
set -euo pipefail

############################################
# set-apt-cn.sh
# Switch Ubuntu APT mirror to China mirror
############################################

MIRROR="https://mirrors.tuna.tsinghua.edu.cn/ubuntu"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"

log() {
  echo -e "\033[1;32m[APT]\033[0m $*"
}

err() {
  echo -e "\033[1;31m[APT][ERROR]\033[0m $*" >&2
  exit 1
}

[[ $EUID -ne 0 ]] && err "Please run as root"

command -v lsb_release >/dev/null 2>&1 || err "lsb_release not found"

CODENAME="$(lsb_release -cs)"
VERSION="$(lsb_release -rs)"

log "Ubuntu version: ${VERSION} (${CODENAME})"
log "Mirror: ${MIRROR}"

backup() {
  local file="$1"
  [[ -f "$file" ]] || return
  cp "$file" "${file}.bak.${TIMESTAMP}"
  log "Backup created: ${file}.bak.${TIMESTAMP}"
}

# Ubuntu 24.04+ (deb822)
if [[ -f /etc/apt/sources.list.d/ubuntu.sources ]]; then
  log "Detected deb822 source format"

  FILE="/etc/apt/sources.list.d/ubuntu.sources"
  backup "$FILE"

  # Handle deb822 format (Ubuntu 24.04+) - match URIs with optional leading whitespace
  sed -i -E "s|(^\s*)URIs:.*|\1URIs: ${MIRROR}|" "$FILE"

else
  log "Detected traditional sources.list"

  FILE="/etc/apt/sources.list"
  backup "$FILE"

  cat > "$FILE" <<EOF
deb ${MIRROR} ${CODENAME} main restricted universe multiverse
deb ${MIRROR} ${CODENAME}-updates main restricted universe multiverse
deb ${MIRROR} ${CODENAME}-backports main restricted universe multiverse
deb ${MIRROR} ${CODENAME}-security main restricted universe multiverse
EOF
fi

log "Running apt update..."
apt update -y

log "APT mirror switched successfully ✅"

