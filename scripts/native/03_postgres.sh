#!/usr/bin/env bash
# Create the Hive Metastore Postgres database and user.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

require_root
load_env

systemctl enable postgresql >/dev/null 2>&1 || true
systemctl restart postgresql

log "Creating Postgres role and database for Hive Metastore"
sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='${HMS_DB_USER}'" | grep -q 1 || \
  sudo -u postgres psql -c "CREATE ROLE ${HMS_DB_USER} WITH LOGIN PASSWORD '${HMS_DB_PASSWORD}';"

sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${HMS_DB_NAME}'" | grep -q 1 || \
  sudo -u postgres psql -c "CREATE DATABASE ${HMS_DB_NAME} OWNER ${HMS_DB_USER};"

sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${HMS_DB_NAME} TO ${HMS_DB_USER};" >/dev/null

log "Postgres ready (db=${HMS_DB_NAME}, user=${HMS_DB_USER})"
