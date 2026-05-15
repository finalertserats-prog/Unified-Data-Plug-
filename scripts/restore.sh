#!/usr/bin/env bash
set -euo pipefail

# Restore a UDP backup created by ./scripts/backup.sh.
#
# IMPORTANT: this is destructive. The current Postgres catalog DB and MinIO
# bucket contents are replaced. StarRocks FE metadata volume is replaced only
# if you confirm separately (it's the riskiest step).
#
# Usage: ./scripts/restore.sh <backup-dir>

UDP_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$UDP_HOME"

if [ $# -lt 1 ]; then
  echo "Usage: $0 <backup-dir>" >&2
  exit 1
fi
SRC="$1"
if [ ! -d "$SRC" ] || [ ! -f "$SRC/MANIFEST.txt" ]; then
  echo "ERROR: $SRC does not look like a UDP backup (no MANIFEST.txt)" >&2
  exit 1
fi

if [ ! -f .env ]; then
  echo "ERROR: .env missing. Run install.sh first." >&2
  exit 1
fi
# shellcheck disable=SC1091
. ./.env

echo "About to restore from: $SRC"
cat "$SRC/MANIFEST.txt"
echo ""
read -r -p "Type 'restore' to proceed: " confirm || true
if [ "$confirm" != "restore" ]; then
  echo "Aborted."
  exit 1
fi

echo "[1/3] Restoring Postgres catalog (pg_restore)..."
docker exec -i udp-postgres dropdb -U "${POSTGRES_USER:-iceberg}" --if-exists "${POSTGRES_DB:-iceberg_catalog}"
docker exec -i udp-postgres createdb -U "${POSTGRES_USER:-iceberg}" "${POSTGRES_DB:-iceberg_catalog}"
docker exec -i udp-postgres pg_restore \
  -U "${POSTGRES_USER:-iceberg}" \
  -d "${POSTGRES_DB:-iceberg_catalog}" \
  --clean --if-exists --no-owner \
  < "$SRC/iceberg_catalog.dump"

echo "[2/3] Restoring MinIO bucket via mc mirror..."
docker run --rm \
  --network "$(docker inspect udp-minio --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}}{{end}}')" \
  -v "$(realpath "$SRC"):/backup:ro" \
  --entrypoint sh \
  minio/mc:RELEASE.2025-04-16T18-13-26Z \
  -c "mc alias set udp http://minio:9000 ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD} && mc mirror --overwrite --remove /backup/minio/${MINIO_BUCKET} udp/${MINIO_BUCKET}"

echo ""
echo "[3/3] StarRocks FE metadata is the riskiest step. To restore it:"
echo "      ./udp stop"
echo "      docker volume rm udp_starrocks_fe_meta"
echo "      docker volume create udp_starrocks_fe_meta"
echo "      docker run --rm -v udp_starrocks_fe_meta:/data -v $(realpath "$SRC"):/backup:ro alpine:3.20 \\"
echo "        sh -c 'cd /data && tar -xzf /backup/starrocks_fe_meta.tar.gz'"
echo "      ./udp start"
echo ""
echo "Restore of Postgres + MinIO complete. Iceberg REST should pick up changes after a restart:"
echo "      docker restart udp-iceberg-rest"
