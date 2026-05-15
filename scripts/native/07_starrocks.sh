#!/usr/bin/env bash
# Install StarRocks (FE + BE) as systemd services.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

require_root
load_env

SR_HOME="$UDP_HOME_ROOT/starrocks"
mkdir -p "$SR_HOME"

if [ ! -d "$SR_HOME/fe" ]; then
  log "Downloading StarRocks ${STARROCKS_VERSION}"
  tmp="$(mktemp -d)"
  download_to "https://releases.starrocks.io/starrocks/StarRocks-${STARROCKS_VERSION}.tar.gz" "$tmp/starrocks.tgz"
  tar -xzf "$tmp/starrocks.tgz" -C "$tmp"
  mv "$tmp"/StarRocks-*/* "$SR_HOME/"
  rm -rf "$tmp"
fi

# FE storage + meta dirs
mkdir -p "$UDP_DATA_ROOT/starrocks/fe-meta" "$UDP_DATA_ROOT/starrocks/be-storage"

# Patch FE config
cat >> "$SR_HOME/fe/conf/fe.conf" <<EOF

# UDP overrides
meta_dir = ${UDP_DATA_ROOT}/starrocks/fe-meta
priority_networks = 127.0.0.1/8
EOF

# Patch BE config
cat >> "$SR_HOME/be/conf/be.conf" <<EOF

# UDP overrides
storage_root_path = ${UDP_DATA_ROOT}/starrocks/be-storage
priority_networks = 127.0.0.1/8
EOF

chown -R "$UDP_USER:$UDP_GROUP" "$SR_HOME" "$UDP_DATA_ROOT/starrocks"

log "Installing systemd units udp-starrocks-fe.service, udp-starrocks-be.service"
install -m 0644 "$REPO_ROOT/services/systemd/udp-starrocks-fe.service" /etc/systemd/system/udp-starrocks-fe.service
install -m 0644 "$REPO_ROOT/services/systemd/udp-starrocks-be.service" /etc/systemd/system/udp-starrocks-be.service

systemd_enable_start udp-starrocks-fe
wait_for_port 127.0.0.1 9030 "StarRocks FE" 90

# Register BE
log "Starting StarRocks BE and registering with FE"
systemd_enable_start udp-starrocks-be
wait_for_port 127.0.0.1 8040 "StarRocks BE" 90

mysql -h 127.0.0.1 -P 9030 -u root -e "ALTER SYSTEM ADD BACKEND '127.0.0.1:9050';" 2>/dev/null || true

log "StarRocks ready (FE UI http://127.0.0.1:8030, MySQL 127.0.0.1:9030)"
