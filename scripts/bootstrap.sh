#!/usr/bin/env bash
set -euo pipefail

if docker compose version >/dev/null 2>&1; then
  COMPOSE="docker compose"
else
  COMPOSE="docker-compose"
fi

# Detect which optional services are running. hive-metastore is now opt-in
# via the `hms` compose profile (was always-on before); skip its wait + its
# HMS-backed catalog SQL if it isn't running.
hms_running=$(docker ps --filter "name=udp-hive-metastore" -q 2>/dev/null | head -1)

echo "Waiting for core services..."
if [ -n "$hms_running" ]; then
  bash scripts/wait-for.sh "Hive Metastore" docker exec udp-hive-metastore /bin/sh -c "ss -ltn 2>/dev/null | grep -q ':9083' || netstat -ltn 2>/dev/null | grep -q ':9083'"
else
  echo "  (hive-metastore not running — skipping HMS wait; using REST catalog only)"
fi
bash scripts/wait-for.sh "Iceberg REST" curl -fsS http://localhost:8181/v1/config
bash scripts/wait-for.sh "StarRocks FE" docker exec udp-starrocks-fe mysql -h 127.0.0.1 -P 9030 -u root -e "SELECT 1"

echo "Registering StarRocks backend if needed..."
docker exec udp-starrocks-fe mysql -h 127.0.0.1 -P 9030 -u root -e "
ALTER SYSTEM ADD BACKEND 'starrocks-be:9050';
" >/tmp/udp_add_backend.log 2>&1 || true

echo "Running Spark demo bootstrap..."
docker exec udp-spark spark-submit /home/iceberg/jobs/bootstrap_demo_lake.py

echo "Creating StarRocks external catalogs and analytics views..."
# HMS-backed catalog only when hive-metastore is up
if [ -n "$hms_running" ]; then
  docker exec -i udp-starrocks-fe mysql -h 127.0.0.1 -P 9030 -u root < sql/starrocks/00_create_iceberg_catalog.sql || true
fi
docker exec -i udp-starrocks-fe mysql -h 127.0.0.1 -P 9030 -u root < sql/starrocks/00b_create_iceberg_rest_catalog.sql
docker exec -i udp-starrocks-fe mysql -h 127.0.0.1 -P 9030 -u root < sql/starrocks/01_create_app_analytics.sql

echo "UDP bootstrap complete"
