#!/usr/bin/env bash
# Bootstraps the Dagster container on the python:3.11-slim base.
#
# Why a startup script instead of a Dockerfile:
#   keeps the repo "single-source-of-truth" for orchestrator choice — switching
#   between Airflow and Dagster is profile-only, no image rebuild. The pip
#   install runs once per container lifetime (~30s); subsequent restarts of an
#   already-installed image skip the install.
set -euo pipefail

DAGSTER_VERSION="${DAGSTER_VERSION:-1.9.0}"
DAGSTER_LIBS_VERSION="${DAGSTER_LIBS_VERSION:-0.25.0}"

if ! python -c "import dagster" 2>/dev/null; then
  echo "[dagster-entrypoint] installing Dagster ${DAGSTER_VERSION} + libs ${DAGSTER_LIBS_VERSION}"
  pip install --quiet --no-cache-dir \
    "dagster==${DAGSTER_VERSION}" \
    "dagster-webserver==${DAGSTER_VERSION}" \
    "dagster-postgres==${DAGSTER_LIBS_VERSION}" \
    "docker==7.1.0" \
    "psycopg2-binary==2.9.9" \
    "pymysql==1.1.1" \
    "pyyaml==6.0.2"
else
  echo "[dagster-entrypoint] Dagster already present; skipping install"
fi

# Ensure dagster_meta DB exists.
python - <<'PY'
import os
import psycopg2

cfg = {
    "host": os.environ["DAGSTER_PG_HOSTNAME"],
    "user": os.environ["DAGSTER_PG_USERNAME"],
    "password": os.environ["DAGSTER_PG_PASSWORD"],
    "dbname": "postgres",
}
db = os.environ["DAGSTER_PG_DB"]

conn = psycopg2.connect(**cfg)
conn.autocommit = True
with conn.cursor() as cur:
    cur.execute("SELECT 1 FROM pg_database WHERE datname=%s", (db,))
    if cur.fetchone() is None:
        cur.execute(f'CREATE DATABASE "{db}"')
        print(f"[dagster-entrypoint] created database {db}")
    else:
        print(f"[dagster-entrypoint] database {db} already exists")
conn.close()
PY

echo "[dagster-entrypoint] starting dagster-webserver + daemon"
exec dagster dev \
  --host 0.0.0.0 --port 3000 \
  -m dagster_project.definitions
