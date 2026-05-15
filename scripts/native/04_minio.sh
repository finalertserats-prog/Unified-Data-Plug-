#!/usr/bin/env bash
# Install MinIO + mc as a systemd service.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

require_root
load_env

MINIO_HOME="$UDP_HOME_ROOT/minio"
MINIO_DATA="$UDP_DATA_ROOT/minio"
mkdir -p "$MINIO_HOME/bin" "$MINIO_DATA"

ARCH="$(uname -m)"
case "$ARCH" in
  x86_64) MARCH=amd64 ;;
  aarch64|arm64) MARCH=arm64 ;;
  *) fail "Unsupported architecture: $ARCH" ;;
esac

if [ ! -x "$MINIO_HOME/bin/minio" ]; then
  download_to "https://dl.min.io/server/minio/release/linux-${MARCH}/archive/minio.${MINIO_VERSION}" "$MINIO_HOME/bin/minio"
  chmod +x "$MINIO_HOME/bin/minio"
fi
if [ ! -x "$MINIO_HOME/bin/mc" ]; then
  download_to "https://dl.min.io/client/mc/release/linux-${MARCH}/mc" "$MINIO_HOME/bin/mc"
  chmod +x "$MINIO_HOME/bin/mc"
fi

chown -R "$UDP_USER:$UDP_GROUP" "$MINIO_HOME" "$MINIO_DATA"

log "Installing systemd unit udp-minio.service"
install -m 0644 "$REPO_ROOT/services/systemd/udp-minio.service" /etc/systemd/system/udp-minio.service
systemd_enable_start udp-minio

wait_for_port 127.0.0.1 9000 "MinIO"

log "Creating bucket ${MINIO_BUCKET}"
sudo -u "$UDP_USER" "$MINIO_HOME/bin/mc" alias set udp "http://127.0.0.1:9000" "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" >/dev/null
sudo -u "$UDP_USER" "$MINIO_HOME/bin/mc" mb -p "udp/${MINIO_BUCKET}" >/dev/null 2>&1 || true

log "MinIO ready (http://127.0.0.1:9000, console http://127.0.0.1:9001)"
