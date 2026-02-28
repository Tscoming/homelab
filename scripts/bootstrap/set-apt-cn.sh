#!/usr/bin/env bash
set -euo pipefail

############################################
# set-apt-cn.sh
# Switch Ubuntu APT mirror to China mirror
############################################

# List of all mirrors to test (including official)
ALL_MIRRORS=(
  "https://mirrors.aliyun.com/ubuntu"
  "https://mirrors.tuna.tsinghua.edu.cn/ubuntu"
  "https://mirrors.ustc.edu.cn/ubuntu"
  "https://repo.huaweicloud.com/ubuntu"
  "https://archive.ubuntu.com/ubuntu"
  "http://archive.ubuntu.com/ubuntu"
)

MIRROR=""
TIMESTAMP="$(date +%Y%m%d%H%M%S)"

log() {
  echo -e "\033[1;32m[APT]\033[0m $*" >&2
}

# Test if a mirror is accessible
test_mirror() {
  local mirror_url="$1"
  local codename="$2"

  # Try to fetch the Release file to check if mirror is accessible
  if curl -sf --connect-timeout 7 --max-time 10 \
    "${mirror_url}/dists/${codename}/Release" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

# Test mirror speed (returns time in milliseconds)
test_mirror_speed() {
  local mirror_url="$1"
  local codename="$2"

  local start_time end_time duration
  start_time=$(date +%s%3N)

  # Download a small file to test speed (InRelease is small)
  if curl -sf --connect-timeout 5 --max-time 15 \
    "${mirror_url}/dists/${codename}/InRelease" -o /dev/null 2>&1; then
    end_time=$(date +%s%3N)
    duration=$((end_time - start_time))
    echo "$duration"
    return 0
  fi
  return 1
}

# Find the fastest working mirror by testing all mirrors
find_fastest_mirror() {
  local codename="$1"
  local fastest_mirror=""
  local fastest_time=999999
  local accessible_mirrors=()

  log "Testing all mirrors for speed..."

  for mirror in "${ALL_MIRRORS[@]}"; do
    echo -e "\033[1;32m[APT]\033[0m Testing: ${mirror}" >&2

    # First check if mirror is accessible
    if test_mirror "$mirror" "$codename"; then
      echo -e "\033[1;32m[APT]\033[0m   - Accessible, measuring speed..." >&2

      # Test speed
      local speed
      speed=$(test_mirror_speed "$mirror" "$codename")

      if [[ -n "$speed" ]]; then
        echo -e "\033[1;32m[APT]\033[0m   - Speed: ${speed}ms" >&2
        accessible_mirrors+=("${mirror}|${speed}")

        # Track fastest
        if [[ "$speed" -lt "$fastest_time" ]]; then
          fastest_time=$speed
          fastest_mirror="$mirror"
        fi
      fi
    else
      echo -e "\033[1;32m[APT]\033[0m   - Not accessible or too slow" >&2
    fi
  done

  if [[ -z "$fastest_mirror" ]]; then
    err "All mirrors are inaccessible"
  fi

  log "Fastest mirror: ${fastest_mirror} (${fastest_time}ms)"
  echo "$fastest_mirror"
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

# Find the fastest working mirror
MIRROR=$(find_fastest_mirror "$CODENAME")
log "Selected mirror: ${MIRROR}"

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

