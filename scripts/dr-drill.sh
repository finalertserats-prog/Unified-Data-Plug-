#!/usr/bin/env bash
set -euo pipefail

# End-to-end disaster-recovery drill:
#   1. backup the running stack
#   2. tear it down (volumes wiped)
#   3. start a fresh stack
#   4. restore from the backup
#   5. run smoke-test against the restored stack
#   6. report PASS / FAIL
#
# This proves that backup + restore actually works. Run on a schedule
# (cron / systemd timer) in production-adjacent environments.
#
# Usage: ./scripts/dr-drill.sh
#        UDP_DR_KEEP=1 ./scripts/dr-drill.sh   # keep backup dir on success

UDP_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$UDP_HOME"

DRILL_ID="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_DIR="backups/dr-drill-$DRILL_ID"
LOG_FILE="backups/dr-drill-$DRILL_ID.log"
mkdir -p backups

banner() {
  echo ""
  echo "============================================================"
  echo " DR DRILL :: $1"
  echo "============================================================"
}

cleanup_on_fail() {
  local exit_code=$?
  echo "DR drill FAILED (exit $exit_code) — log: $LOG_FILE" | tee -a "$LOG_FILE"
  exit "$exit_code"
}
trap cleanup_on_fail ERR

{
  banner "Stage 1/5 — backup current stack"
  bash scripts/backup.sh "$BACKUP_DIR"

  banner "Stage 2/5 — capture baseline row counts"
  if [ ! -f .env ]; then
    echo "ERROR: .env missing — cannot capture baseline" >&2
    exit 1
  fi
  # shellcheck disable=SC1091
  . ./.env
  SR_AUTH=()
  if [ -n "${STARROCKS_ROOT_PASSWORD:-}" ]; then
    SR_AUTH=(-p"${STARROCKS_ROOT_PASSWORD}")
  fi
  BASELINE_ROWS="$(docker exec udp-starrocks-fe mysql -h 127.0.0.1 -P 9030 -u root \
    "${SR_AUTH[@]}" -N -e \
    "SELECT COUNT(*) FROM app_analytics.demo_customer_summary;" 2>/dev/null || echo "?")"
  echo "Baseline app_analytics.demo_customer_summary rows: $BASELINE_ROWS"

  banner "Stage 3/5 — tear down (wipe volumes)"
  echo "wipe" | bash udp clean

  banner "Stage 4/5 — start fresh stack and restore"
  ./udp start
  # Wait for Postgres + StarRocks FE to come up before restoring.
  bash scripts/wait-for.sh "Postgres" docker exec udp-postgres pg_isready -U "${POSTGRES_USER:-iceberg}"
  bash scripts/wait-for.sh "StarRocks FE" \
    docker exec udp-starrocks-fe mysql -h 127.0.0.1 -P 9030 -u root "${SR_AUTH[@]}" -e "SELECT 1"
  # Non-interactive restore — the script normally prompts for 'restore', but
  # the drill is unattended.
  echo "restore" | bash scripts/restore.sh "$BACKUP_DIR"
  # FE metadata restore step is manual in restore.sh; do it explicitly here.
  ./udp stop
  docker volume rm udp_starrocks_fe_meta || true
  docker volume create udp_starrocks_fe_meta
  docker run --rm \
    -v udp_starrocks_fe_meta:/data \
    -v "$(realpath "$BACKUP_DIR"):/backup:ro" \
    alpine:3.20 \
    sh -c 'cd /data && tar -xzf /backup/starrocks_fe_meta.tar.gz'
  ./udp start
  bash scripts/wait-for.sh "StarRocks FE post-restore" \
    docker exec udp-starrocks-fe mysql -h 127.0.0.1 -P 9030 -u root "${SR_AUTH[@]}" -e "SELECT 1"
  docker restart udp-iceberg-rest
  bash scripts/wait-for.sh "Iceberg REST post-restore" curl -fsS http://localhost:8181/v1/config

  banner "Stage 5/5 — verify smoke test against restored stack"
  bash scripts/smoke-test.sh
  RESTORED_ROWS="$(docker exec udp-starrocks-fe mysql -h 127.0.0.1 -P 9030 -u root \
    "${SR_AUTH[@]}" -N -e \
    "SELECT COUNT(*) FROM app_analytics.demo_customer_summary;")"
  echo "Restored rows: $RESTORED_ROWS (baseline was $BASELINE_ROWS)"
  if [ "$BASELINE_ROWS" != "?" ] && [ "$RESTORED_ROWS" != "$BASELINE_ROWS" ]; then
    echo "FAIL: row count drift — baseline=$BASELINE_ROWS restored=$RESTORED_ROWS" >&2
    exit 1
  fi

  banner "DR DRILL PASSED"
  echo "Drill ID:    $DRILL_ID"
  echo "Backup dir:  $BACKUP_DIR"
  echo "Log:         $LOG_FILE"

  if [ -z "${UDP_DR_KEEP:-}" ]; then
    echo "Cleaning up drill backup (set UDP_DR_KEEP=1 to retain)..."
    rm -rf "$BACKUP_DIR"
  fi
} 2>&1 | tee "$LOG_FILE"

trap - ERR
