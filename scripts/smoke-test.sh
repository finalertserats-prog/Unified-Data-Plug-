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

SR_AUTH=()
if [ -n "${STARROCKS_ROOT_PASSWORD:-}" ]; then
  SR_AUTH=(-p"${STARROCKS_ROOT_PASSWORD}")
fi

echo "UDP smoke test"

bash scripts/wait-for.sh "Iceberg REST" curl -fsS http://localhost:8181/v1/config
bash scripts/wait-for.sh "StarRocks FE" \
  docker exec udp-starrocks-fe mysql -h 127.0.0.1 -P 9030 -u root "${SR_AUTH[@]}" -e "SELECT 1"

echo "Testing Iceberg raw and curated tables through Spark..."
docker exec udp-spark spark-submit /home/iceberg/jobs/smoke_test_iceberg.py

echo "Testing StarRocks analytics view..."
docker exec udp-starrocks-fe mysql -h 127.0.0.1 -P 9030 -u root "${SR_AUTH[@]}" -e "
SHOW CATALOGS;
SHOW DATABASES;
SELECT COUNT(*) AS customer_summary_rows FROM app_analytics.demo_customer_summary;
"

echo "UDP smoke test passed"
