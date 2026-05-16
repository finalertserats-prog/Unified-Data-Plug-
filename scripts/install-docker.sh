#!/usr/bin/env bash
# Docker-Compose installer for UDP (the v0.3 path, kept for users who prefer Docker).
set -euo pipefail

UDP_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$UDP_HOME"

banner() {
  echo ""
  echo "============================================================"
  echo "$1"
  echo "============================================================"
}

ask_default() {
  local prompt="$1" default="$2" answer
  read -r -p "$prompt [$default]: " answer || true
  echo "${answer:-$default}"
}

banner "Unified Data Plug installer (Docker mode)"

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required for --mode=docker. Install Docker first, or run with --mode=native."
  exit 1
fi

if docker compose version >/dev/null 2>&1; then
  COMPOSE="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE="docker-compose"
else
  echo "Docker Compose is required for --mode=docker."
  exit 1
fi

if [ ! -f .env ]; then
  echo "Creating .env. Press Enter to accept secure local defaults."
  MINIO_USER="$(ask_default 'MinIO admin user' 'admin')"
  MINIO_PASS="$(ask_default 'MinIO admin password' 'udp_admin_12345')"
  MINIO_BUCKET="$(ask_default 'Lake bucket name' 'datalake')"
  cat > .env <<EOF
UDP_PROJECT_NAME=unified-data-plug
UDP_ENV=local

MINIO_ROOT_USER=$MINIO_USER
MINIO_ROOT_PASSWORD=$MINIO_PASS
MINIO_BUCKET=$MINIO_BUCKET

AWS_ACCESS_KEY_ID=$MINIO_USER
AWS_SECRET_ACCESS_KEY=$MINIO_PASS
AWS_REGION=us-east-1
AWS_S3_US_EAST_1_REGIONAL_ENDPOINT=regional
S3_ENDPOINT=http://minio:9000
ICEBERG_WAREHOUSE=s3a://$MINIO_BUCKET/warehouse

HMS_URI=thrift://hive-metastore:9083
HMS_DB_NAME=metastore
HMS_DB_USER=hive
HMS_DB_PASSWORD=hive

ICEBERG_REST_URI=http://iceberg-rest:8181

STARROCKS_HOST=127.0.0.1
STARROCKS_MYSQL_PORT=9030
STARROCKS_ROOT_PASSWORD=

RANGER_DB_NAME=ranger
RANGER_DB_USER=ranger
RANGER_DB_PASSWORD=ranger
RANGER_ADMIN_PASSWORD=$MINIO_PASS
EOF
fi

chmod +x udp scripts/*.sh

banner "Doctor checks"
./udp doctor

banner "Starting UDP"
./udp start

banner "Bootstrapping demo lakehouse"
./udp bootstrap

banner "Running smoke test"
./udp smoke-test

banner "UDP installation complete"
echo "MinIO Console:     http://localhost:9001"
echo "Hive Metastore:    thrift://localhost:9083  (default Iceberg catalog)"
echo "Iceberg REST:      http://localhost:8181    (secondary Iceberg catalog)"
echo "Spark Notebook:    http://localhost:8888"
echo "StarRocks FE UI:   http://localhost:8030"
echo "StarRocks MySQL:   mysql -h 127.0.0.1 -P 9030 -u root"
