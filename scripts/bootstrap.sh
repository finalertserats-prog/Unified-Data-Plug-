#!/usr/bin/env bash
set -euo pipefail

UDP_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$UDP_HOME"

if [ ! -f .env ]; then
  echo "ERROR: .env missing. Run install.sh first." >&2
  exit 1
fi
# shellcheck disable=SC1091
. ./.env

if docker compose version >/dev/null 2>&1; then
  COMPOSE="docker compose"
else
  COMPOSE="docker-compose"
fi

# Re-render templates in case .env or templates changed.
bash scripts/render-templates.sh

# Auth flag for mysql — only add -p when STARROCKS_ROOT_PASSWORD is set.
SR_AUTH=()
if [ -n "${STARROCKS_ROOT_PASSWORD:-}" ]; then
  SR_AUTH=(-p"${STARROCKS_ROOT_PASSWORD}")
fi

echo "Waiting for core services..."
bash scripts/wait-for.sh "Iceberg REST" curl -fsS http://localhost:8181/v1/config
bash scripts/wait-for.sh "StarRocks FE" \
  docker exec udp-starrocks-fe mysql -h 127.0.0.1 -P 9030 -u root "${SR_AUTH[@]}" -e "SELECT 1"

echo "Registering StarRocks backend if needed..."
docker exec udp-starrocks-fe mysql -h 127.0.0.1 -P 9030 -u root "${SR_AUTH[@]}" -e "
SHOW BACKENDS;
" 2>&1 | grep -q "starrocks-be:9050" || \
  docker exec udp-starrocks-fe mysql -h 127.0.0.1 -P 9030 -u root "${SR_AUTH[@]}" -e "
ALTER SYSTEM ADD BACKEND 'starrocks-be:9050';
"

echo "Running Spark demo bootstrap..."
docker exec udp-spark spark-submit /home/iceberg/jobs/bootstrap_demo_lake.py

echo "Creating StarRocks external catalog and analytics views..."
docker exec -i udp-starrocks-fe mysql -h 127.0.0.1 -P 9030 -u root "${SR_AUTH[@]}" \
  < sql/starrocks/00_create_iceberg_catalog.sql
docker exec -i udp-starrocks-fe mysql -h 127.0.0.1 -P 9030 -u root "${SR_AUTH[@]}" \
  < sql/starrocks/01_create_app_analytics.sql

echo "UDP bootstrap complete"
