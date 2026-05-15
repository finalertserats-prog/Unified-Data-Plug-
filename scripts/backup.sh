#!/usr/bin/env bash
set -euo pipefail

# Snapshot UDP state to a single directory. Three components:
#   1. Iceberg catalog metadata — pg_dump of the Postgres catalog DB
#   2. Iceberg data — mc mirror of the MinIO bucket
#   3. StarRocks FE metadata — tar of the udp_starrocks_fe_meta volume
#
# Live-snapshot caveats:
#   - mc mirror is consistent at the object level but may straddle a multi-file
#     commit. Run during a quiet window for cross-table consistency.
#   - pg_dump uses a snapshot transaction — internally consistent.
#   - StarRocks FE tar is a hot copy. For a guaranteed point-in-time, stop the
#     FE first (./udp stop) then re-run this script. Otherwise treat the FE
#     metadata as best-effort.
#
# Usage: ./scripts/backup.sh [output-dir]
#        Default output: backups/udp-<YYYYMMDD-HHMMSS>

UDP_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$UDP_HOME"

if [ ! -f .env ]; then
  echo "ERROR: .env missing. Run install.sh first." >&2
  exit 1
fi
# shellcheck disable=SC1091
. ./.env

OUT_DIR="${1:-backups/udp-$(date -u +%Y%m%dT%H%M%SZ)}"
mkdir -p "$OUT_DIR"
umask 077

echo "Backing up to $OUT_DIR"

echo "[1/3] pg_dump of Postgres catalog..."
docker exec udp-postgres pg_dump \
  -U "${POSTGRES_USER:-iceberg}" \
  -d "${POSTGRES_DB:-iceberg_catalog}" \
  --format=custom \
  > "$OUT_DIR/iceberg_catalog.dump"
echo "  $(stat -c %s "$OUT_DIR/iceberg_catalog.dump" 2>/dev/null || stat -f %z "$OUT_DIR/iceberg_catalog.dump") bytes"

echo "[2/3] mc mirror of MinIO bucket..."
docker run --rm \
  --network "$(docker inspect udp-minio --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}}{{end}}')" \
  --env MC_ALIAS_UDP="http://${MINIO_ROOT_USER}:${MINIO_ROOT_PASSWORD}@minio:9000" \
  -v "$(pwd)/$OUT_DIR:/backup" \
  --entrypoint sh \
  minio/mc:RELEASE.2025-04-16T18-13-26Z \
  -c "mc alias set udp http://minio:9000 \$MINIO_ROOT_USER \$MINIO_ROOT_PASSWORD && mc mirror --overwrite udp/${MINIO_BUCKET} /backup/minio/${MINIO_BUCKET}" \
  || {
    # Fallback: alias passed by env didn't expand; do it explicitly.
    docker run --rm \
      --network "$(docker inspect udp-minio --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}}{{end}}')" \
      -v "$(pwd)/$OUT_DIR:/backup" \
      --entrypoint sh \
      minio/mc:RELEASE.2025-04-16T18-13-26Z \
      -c "mc alias set udp http://minio:9000 ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD} && mc mirror --overwrite udp/${MINIO_BUCKET} /backup/minio/${MINIO_BUCKET}"
  }

echo "[3/3] tar of StarRocks FE metadata volume..."
docker run --rm \
  -v udp_starrocks_fe_meta:/data:ro \
  -v "$(pwd)/$OUT_DIR:/backup" \
  alpine:3.20 \
  tar -czf /backup/starrocks_fe_meta.tar.gz -C /data .

cat > "$OUT_DIR/MANIFEST.txt" <<EOF
UDP backup
created_utc: $(date -u +%Y-%m-%dT%H:%M:%SZ)
udp_env: ${UDP_ENV:-local}
postgres_db: ${POSTGRES_DB:-iceberg_catalog}
minio_bucket: ${MINIO_BUCKET}
contents:
  - iceberg_catalog.dump  (pg_dump custom format)
  - minio/${MINIO_BUCKET}/  (mc mirror of bucket)
  - starrocks_fe_meta.tar.gz  (FE metadata snapshot)
restore: ./scripts/restore.sh $OUT_DIR
EOF

echo ""
echo "Backup complete: $OUT_DIR"
echo "  $(du -sh "$OUT_DIR" | awk '{print $1}') total"
echo "  Restore with: ./scripts/restore.sh $OUT_DIR"
