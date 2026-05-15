#!/bin/sh
# Runs inside the airflow-init container. POSIX-compatible — the script gets
# re-execed by /bin/sh (busybox/dash on minimal images) regardless of shebang
# when invoked via `su airflow -c 'bash <path>'`, so we avoid bashisms.
#
# Responsibilities:
#   1. Wait for Postgres to accept connections.
#   2. Create the airflow_meta database if it does not exist.
#   3. Run `airflow db migrate` (idempotent).
#   4. Create the admin user if it does not exist.
set -eu

: "${POSTGRES_USER:?missing}"
: "${POSTGRES_PASSWORD:?missing}"
: "${AIRFLOW_ADMIN_PASSWORD:?missing}"

PG_HOST="${POSTGRES_HOST:-postgres}"
PG_PORT="${POSTGRES_PORT:-5432}"
AIRFLOW_DB="${AIRFLOW_DB:-airflow_meta}"
ADMIN_USER="${AIRFLOW_ADMIN_USER:-admin}"
ADMIN_EMAIL="${AIRFLOW_ADMIN_EMAIL:-admin@udp.local}"

# 1. Wait for Postgres.
for i in $(seq 1 60); do
  if PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$PG_HOST" -p "$PG_PORT" \
       -U "$POSTGRES_USER" -d postgres -c 'SELECT 1' >/dev/null 2>&1; then
    echo "[airflow-init] Postgres ready"
    break
  fi
  echo "[airflow-init] waiting for Postgres ($i)..."
  sleep 2
done

# 2. Ensure airflow_meta exists.
EXISTS=$(PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$PG_HOST" -p "$PG_PORT" \
  -U "$POSTGRES_USER" -d postgres -tAc \
  "SELECT 1 FROM pg_database WHERE datname='$AIRFLOW_DB'")
if [ "$EXISTS" != "1" ]; then
  echo "[airflow-init] creating database $AIRFLOW_DB"
  PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$PG_HOST" -p "$PG_PORT" \
    -U "$POSTGRES_USER" -d postgres -c "CREATE DATABASE $AIRFLOW_DB OWNER $POSTGRES_USER"
else
  echo "[airflow-init] database $AIRFLOW_DB already exists"
fi

# 3. Airflow schema (idempotent).
echo "[airflow-init] airflow db migrate"
airflow db migrate

# 4. Admin user (idempotent — `users create` is a no-op if username exists).
if airflow users list 2>/dev/null | awk 'NR>2 {print $2}' | grep -qx "$ADMIN_USER"; then
  echo "[airflow-init] admin user $ADMIN_USER already exists"
else
  echo "[airflow-init] creating admin user $ADMIN_USER"
  airflow users create \
    --username "$ADMIN_USER" \
    --firstname UDP \
    --lastname Admin \
    --role Admin \
    --email "$ADMIN_EMAIL" \
    --password "$AIRFLOW_ADMIN_PASSWORD"
fi

echo "[airflow-init] done"
