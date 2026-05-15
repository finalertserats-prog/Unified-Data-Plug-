#!/usr/bin/env bash
# Install OS packages required by UDP native install.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

require_root
ensure_distro_supported

log "Updating apt and installing prerequisites"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq \
  curl wget tar gzip \
  ca-certificates \
  netcat-openbsd \
  openjdk-17-jre-headless \
  postgresql postgresql-contrib \
  mysql-client \
  python3 python3-pip \
  jq

# Kernel knobs StarRocks BE needs
log "Applying StarRocks kernel tuning"
cat > /etc/sysctl.d/99-udp-starrocks.conf <<'EOF'
vm.max_map_count = 262144
vm.swappiness = 1
EOF
sysctl --system >/dev/null

# File descriptor limits
log "Raising file descriptor limits for $UDP_USER"
cat > /etc/security/limits.d/99-udp.conf <<EOF
$UDP_USER soft nofile 65536
$UDP_USER hard nofile 65536
$UDP_USER soft nproc 65536
$UDP_USER hard nproc 65536
EOF

log "Prereqs installed"
