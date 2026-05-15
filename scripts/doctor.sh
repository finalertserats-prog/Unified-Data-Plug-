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

for port in 9000 9001 9083 8888 8030 9030 6080; do
  if command -v lsof >/dev/null 2>&1 && lsof -i ":$port" >/dev/null 2>&1; then
    echo "WARN: port $port appears to be in use"
  else
    echo "OK: port $port not detected as busy"
  fi
done

mem_kb="$(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)"
if [ "$mem_kb" -lt 7000000 ]; then
  echo "WARN: less than 8GB RAM detected. UDP may run slowly."
else
  echo "OK: RAM looks sufficient"
fi

exit "$fail"
