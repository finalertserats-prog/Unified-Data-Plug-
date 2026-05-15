#!/usr/bin/env bash
set -euo pipefail

echo "UDP smoke test"

bash scripts/wait-for.sh "Hive Metastore" docker exec udp-hive-metastore /bin/sh -c "ss -ltn 2>/dev/null | grep -q ':9083' || netstat -ltn 2>/dev/null | grep -q ':9083'"
bash scripts/wait-for.sh "Iceberg REST" curl -fsS http://localhost:8181/v1/config
bash scripts/wait-for.sh "StarRocks FE" docker exec udp-starrocks-fe mysql -h 127.0.0.1 -P 9030 -u root -e "SELECT 1"

echo "Testing Iceberg raw and curated tables through Spark..."
docker exec udp-spark spark-submit /home/iceberg/jobs/smoke_test_iceberg.py

echo "Testing StarRocks analytics view..."
docker exec udp-starrocks-fe mysql -h 127.0.0.1 -P 9030 -u root -e "
SHOW CATALOGS;
SHOW DATABASES;
SELECT COUNT(*) AS customer_summary_rows FROM app_analytics.demo_customer_summary;
"

echo "UDP smoke test passed"
