#!/usr/bin/env bash
set -euo pipefail

echo "UDP doctor check"

fail=0

check_cmd() {
  if command -v "$1" >/dev/null 2>&1; then
    echo "OK: $1 found"
  else
    echo "MISSING: $1"
    fail=1
  fi
}

check_cmd docker

if docker compose version >/dev/null 2>&1 || command -v docker-compose >/dev/null 2>&1; then
  echo "OK: Docker Compose found"
else
  echo "MISSING: Docker Compose"
  fail=1
fi

if docker info >/dev/null 2>&1; then
  echo "OK: Docker daemon running"
else
  echo "ERROR: Docker daemon is not running or current user cannot access it"
  fail=1
fi

for port in 9000 9001 8181 8888 8030 9030; do
  if command -v lsof >/dev/null 2>&1 && lsof -i ":$port" >/dev/null 2>&1; then
    echo "WARN: port $port appears to be in use"
  else
    echo "OK: port $port not detected as busy"
  fi
done

mem_kb="$(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)"
# Compose stack now has resource limits totaling ~14GB across services.
# Below 16GB on the host, expect contention / swap thrash.
if [ "$mem_kb" -lt 15000000 ]; then
  echo "WARN: less than 16GB RAM detected. UDP compose limits total ~14GB; expect contention."
else
  echo "OK: RAM looks sufficient (compose stack budgeted at ~14GB)"
fi

# Port 5432 added for Postgres in Phase 2 — but Postgres is internal-only
# (no host port exposed), so we don't probe it here.

exit "$fail"
