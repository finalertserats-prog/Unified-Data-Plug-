#!/usr/bin/env bash
# Native single-server installer for UDP. Ubuntu/Debian only (v0.4).
# Runs each phase script in /scripts/native/ in order.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=native/lib.sh
. "$SCRIPT_DIR/native/lib.sh"

require_root
ensure_distro_supported

log "Writing /etc/udp/udp.env from .env"
mkdir -p "$UDP_CONF_ROOT"
if [ -f "$REPO_ROOT/.env" ]; then
  install -m 0640 "$REPO_ROOT/.env" "$UDP_CONF_ROOT/udp.env"
else
  install -m 0640 "$REPO_ROOT/.env.example" "$UDP_CONF_ROOT/udp.env"
fi
chown root:"$UDP_GROUP" "$UDP_CONF_ROOT/udp.env" 2>/dev/null || true

for phase in 01_prereqs 02_users_dirs 03_postgres 04_minio 05_hive_metastore 06_spark 07_starrocks 08_bootstrap; do
  log "===== Phase: $phase ====="
  bash "$SCRIPT_DIR/native/${phase}.sh"
done

log ""
log "Native UDP install complete"
log "  MinIO console: http://$(hostname -I | awk '{print $1}'):9001"
log "  StarRocks FE:  http://$(hostname -I | awk '{print $1}'):8030"
log "  HMS Thrift:    thrift://127.0.0.1:9083"
log ""
log "Service status:  systemctl status udp-minio udp-hive-metastore udp-starrocks-fe udp-starrocks-be"
log "Logs:            journalctl -u udp-minio -f"
