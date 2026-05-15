#!/usr/bin/env bash
set -euo pipefail

UDP_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$UDP_HOME"

banner() {
  echo ""
  echo "============================================================"
  echo "$1"
  echo "============================================================"
}

ask_default() {
  local prompt="$1"
  local default="$2"
  local answer
  read -r -p "$prompt [$default]: " answer || true
  echo "${answer:-$default}"
}

ask_secret() {
  # Like ask_default, but echoes "<random>" placeholder when generating
  local prompt="$1"
  local generated="$2"
  local answer
  read -r -p "$prompt [press Enter for generated random]: " answer || true
  echo "${answer:-$generated}"
}

gen_password() {
  # 32 hex chars, shell-safe (no quotes, slashes, dollar signs)
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 16
  elif [ -r /dev/urandom ]; then
    LC_ALL=C tr -dc 'a-f0-9' </dev/urandom | head -c 32
  else
    echo "ERROR: need openssl or /dev/urandom to generate passwords" >&2
    exit 1
  fi
}

banner "Unified Data Plug installer"

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required. Install Docker first, then rerun: bash install.sh"
  exit 1
fi

if docker compose version >/dev/null 2>&1; then
  COMPOSE="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE="docker-compose"
else
  echo "Docker Compose is required. Install Docker Compose first."
  exit 1
fi

if [ ! -f .env ]; then
  echo "Creating .env with secure random credentials."
  MINIO_USER="$(ask_default 'MinIO admin user' 'udp_admin')"
  MINIO_PASS_GEN="$(gen_password)"
  MINIO_PASS="$(ask_secret 'MinIO admin password' "$MINIO_PASS_GEN")"
  MINIO_BUCKET="$(ask_default 'Lake bucket name' 'datalake')"
  STARROCKS_PASS_GEN="$(gen_password)"
  STARROCKS_PASS="$(ask_secret 'StarRocks root password' "$STARROCKS_PASS_GEN")"

  umask 077
  cat > .env <<EOF
UDP_PROJECT_NAME=unified-data-plug
UDP_ENV=local

MINIO_ROOT_USER=$MINIO_USER
MINIO_ROOT_PASSWORD=$MINIO_PASS
MINIO_BUCKET=$MINIO_BUCKET

AWS_ACCESS_KEY_ID=$MINIO_USER
AWS_SECRET_ACCESS_KEY=$MINIO_PASS
AWS_REGION=us-east-1
S3_ENDPOINT=http://minio:9000
ICEBERG_WAREHOUSE=s3://$MINIO_BUCKET/warehouse
ICEBERG_REST_URI=http://iceberg-rest:8181

STARROCKS_HOST=127.0.0.1
STARROCKS_MYSQL_PORT=9030
STARROCKS_ROOT_PASSWORD=$STARROCKS_PASS
EOF
  chmod 600 .env
  echo ""
  echo "Credentials saved to .env (mode 600). NOT printed to terminal."
  echo "View them with:  cat .env  (only readable by your user)"
  echo "Move them into your secret manager and remove .env when done."
  echo ""
else
  echo ".env already exists; keeping existing config."
fi

chmod +x udp scripts/*.sh

banner "Rendering config templates"
bash scripts/render-templates.sh

banner "Doctor checks"
./udp doctor

banner "Starting UDP"
./udp start

banner "Setting StarRocks root password"
bash scripts/set-starrocks-password.sh

banner "Bootstrapping demo lakehouse"
./udp bootstrap

banner "Running smoke test"
./udp smoke-test

banner "UDP installation complete"
echo "MinIO Console:     http://localhost:9001"
echo "Iceberg REST:      http://localhost:8181"
echo "StarRocks FE UI:   http://localhost:8030"
echo "StarRocks MySQL:   mysql -h 127.0.0.1 -P 9030 -u root -p"
echo ""
echo "Try:"
echo "  ./udp status"
echo "  ./udp smoke-test"
