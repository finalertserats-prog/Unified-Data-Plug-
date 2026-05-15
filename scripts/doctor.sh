#!/usr/bin/env bash
# Mode-aware host preflight.
set -euo pipefail

if systemctl list-unit-files 2>/dev/null | grep -q '^udp-minio.service'; then
  MODE=native
elif command -v docker >/dev/null 2>&1; then
  MODE=docker
else
  MODE=unknown
fi

echo "UDP doctor (mode: $MODE)"

fail=0

mem_kb="$(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)"
if [ "$mem_kb" -lt 15000000 ]; then
  echo "WARN: less than 16 GB RAM detected. Native install may OOM (StarRocks BE)."
else
  echo "OK: RAM looks sufficient (>=16 GB)"
fi

free_disk="$(df --output=avail / 2>/dev/null | tail -n1 || echo 0)"
if [ "${free_disk:-0}" -lt 50000000 ]; then
  echo "WARN: less than ~50 GB free on / — UDP needs ~100 GB headroom"
else
  echo "OK: disk free looks sufficient"
fi

case "$MODE" in
  native)
    command -v systemctl >/dev/null 2>&1 && echo "OK: systemd present" || { echo "MISSING: systemd"; fail=1; }
    command -v java >/dev/null 2>&1 && echo "OK: java present" || echo "INFO: java will be installed by phase 01"
    command -v psql >/dev/null 2>&1 && echo "OK: postgres client present" || echo "INFO: postgres will be installed by phase 01"
    for port in 9000 9001 9083 8030 9030 8040 5432; do
      if command -v lsof >/dev/null 2>&1 && lsof -i ":$port" >/dev/null 2>&1; then
        echo "WARN: port $port appears to be in use"
      else
        echo "OK: port $port not busy"
      fi
    done
    ;;
  docker)
    command -v docker >/dev/null 2>&1 && echo "OK: docker present" || { echo "MISSING: docker"; fail=1; }
    if docker compose version >/dev/null 2>&1 || command -v docker-compose >/dev/null 2>&1; then
      echo "OK: Docker Compose found"
    else
      echo "MISSING: Docker Compose"
      fail=1
    fi
    docker info >/dev/null 2>&1 && echo "OK: docker daemon running" || { echo "ERROR: docker daemon not running"; fail=1; }
    for port in 9000 9001 8181 9083 8888 8030 9030 6080; do
      if command -v lsof >/dev/null 2>&1 && lsof -i ":$port" >/dev/null 2>&1; then
        echo "WARN: port $port appears to be in use"
      else
        echo "OK: port $port not busy"
      fi
    done
    ;;
  unknown)
    echo "INFO: no install detected. Run bash install.sh to choose a mode."
    ;;
esac

exit "$fail"
