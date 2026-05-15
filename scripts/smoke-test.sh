#!/usr/bin/env bash
# Mode-aware smoke test. Validates Iceberg tables via Spark and StarRocks view.
set -euo pipefail

# Detect mode the same way ./udp does
if systemctl list-unit-files 2>/dev/null | grep -q '^udp-minio.service'; then
  MODE=native
elif command -v docker >/dev/null 2>&1; then
  MODE=docker
else
  echo "Cannot detect install mode."; exit 1
fi

echo "UDP smoke test (mode: $MODE)"

case "$MODE" in
  native)
    set -a
    # shellcheck disable=SC1091
    . /etc/udp/udp.env
    set +a

    /opt/udp/spark/bin/spark-submit --master 'local[*]' /opt/udp/spark/jobs/smoke_test_iceberg.py 2>/dev/null \
      || sudo -u udp /opt/udp/spark/bin/spark-submit --master 'local[*]' "$(pwd)/jobs/smoke_test_iceberg.py"

    mysql -h 127.0.0.1 -P 9030 -u root -e "
      SHOW CATALOGS;
      SHOW DATABASES;
      SELECT COUNT(*) AS customer_summary_rows FROM app_analytics.demo_customer_summary;
    "
    ;;
  docker)
    bash scripts/wait-for.sh "Hive Metastore" docker exec udp-hive-metastore /bin/sh -c "ss -ltn 2>/dev/null | grep -q ':9083' || netstat -ltn 2>/dev/null | grep -q ':9083'"
    bash scripts/wait-for.sh "Iceberg REST" curl -fsS http://localhost:8181/v1/config
    bash scripts/wait-for.sh "StarRocks FE" docker exec udp-starrocks-fe mysql -h 127.0.0.1 -P 9030 -u root -e "SELECT 1"

    docker exec udp-spark spark-submit /home/iceberg/jobs/smoke_test_iceberg.py

    docker exec udp-starrocks-fe mysql -h 127.0.0.1 -P 9030 -u root -e "
      SHOW CATALOGS;
      SHOW DATABASES;
      SELECT COUNT(*) AS customer_summary_rows FROM app_analytics.demo_customer_summary;
    "
    ;;
esac

echo "UDP smoke test passed"
