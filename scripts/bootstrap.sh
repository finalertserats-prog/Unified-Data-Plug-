#!/usr/bin/env bash
set -euo pipefail

# Stop Git Bash on Windows from rewriting absolute container-side paths like
# "/home/iceberg/jobs/x.py" into "C:/Program Files/Git/home/iceberg/jobs/x.py"
# when passed as positional args to `docker exec`.
export MSYS_NO_PATHCONV=1

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

# Regenerate RBAC SQL from policy YAML (idempotent — reuses .env values), then
# re-render templates in case .env or templates changed.
python3 scripts/generate-starrocks-users.py
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
# StarRocks SHOW BACKENDS reports by IP, not by hostname, so a hostname grep
# can't reliably tell whether the BE is already registered. Just attempt the
# ALTER SYSTEM and treat "already exists" as success — the registration is
# durable and we don't want re-runs to fail on it.
add_be_out=$(docker exec udp-starrocks-fe mysql -h 127.0.0.1 -P 9030 -u root "${SR_AUTH[@]}" \
  -e "ALTER SYSTEM ADD BACKEND 'starrocks-be:9050';" 2>&1) || true
if echo "$add_be_out" | grep -qE "already exists|Query OK|^$"; then
  echo "  BE registered (or already was)"
else
  echo "ERROR registering BE: $add_be_out" >&2
  exit 1
fi

echo "Ensuring pymysql is available in the Spark container (for run tracker)..."
docker exec udp-spark sh -c "python -c 'import pymysql' 2>/dev/null || pip install --quiet pymysql"

echo "Running Spark demo bootstrap..."
docker exec udp-spark spark-submit /home/iceberg/jobs/bootstrap_demo_lake.py

echo "Creating StarRocks external catalog and analytics views..."
docker exec -i udp-starrocks-fe mysql -h 127.0.0.1 -P 9030 -u root "${SR_AUTH[@]}" \
  < sql/starrocks/00_create_iceberg_catalog.sql
docker exec -i udp-starrocks-fe mysql -h 127.0.0.1 -P 9030 -u root "${SR_AUTH[@]}" \
  < sql/starrocks/01_create_app_analytics.sql

echo "Creating observability schema..."
docker exec -i udp-starrocks-fe mysql -h 127.0.0.1 -P 9030 -u root "${SR_AUTH[@]}" \
  < sql/starrocks/03_create_observability.sql

echo "Applying StarRocks RBAC users from policy YAML..."
docker exec -i udp-starrocks-fe mysql -h 127.0.0.1 -P 9030 -u root "${SR_AUTH[@]}" \
  < sql/starrocks/02_create_users.sql

echo "UDP bootstrap complete"
