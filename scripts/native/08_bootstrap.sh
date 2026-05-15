#!/usr/bin/env bash
# Run the demo Spark bootstrap and create the StarRocks external catalog.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

require_root
load_env

SPARK_HOME="$UDP_HOME_ROOT/spark"

log "Copying demo CSV into UDP data dir"
install -d -o "$UDP_USER" -g "$UDP_GROUP" "$UDP_DATA_ROOT/examples"
install -m 0644 -o "$UDP_USER" -g "$UDP_GROUP" "$REPO_ROOT/examples/customers.csv" "$UDP_DATA_ROOT/examples/customers.csv"

# Patch the demo job to point at the host path for native install
sed "s#/home/iceberg/examples/customers.csv#${UDP_DATA_ROOT}/examples/customers.csv#" \
  "$REPO_ROOT/jobs/bootstrap_demo_lake.py" > /tmp/udp_bootstrap_demo_lake.py
chmod 0644 /tmp/udp_bootstrap_demo_lake.py

log "Running Spark bootstrap job"
sudo -u "$UDP_USER" \
  JAVA_HOME=/usr/lib/jvm/java-17-openjdk-${ARCH:-amd64} \
  SPARK_HOME="$SPARK_HOME" \
  "$SPARK_HOME/bin/spark-submit" \
  --master "local[*]" \
  /tmp/udp_bootstrap_demo_lake.py

log "Registering StarRocks Iceberg catalog"
mysql -h 127.0.0.1 -P 9030 -u root < "$REPO_ROOT/sql/starrocks/00_create_iceberg_catalog.sql" || true
mysql -h 127.0.0.1 -P 9030 -u root < "$REPO_ROOT/sql/starrocks/01_create_app_analytics.sql" || true

log "Bootstrap complete"
