#!/usr/bin/env bash
set -euo pipefail

export MSYS_NO_PATHCONV=1

UDP_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$UDP_HOME"

# shellcheck disable=SC1091
. ./.env

if [ -z "${STARROCKS_ROOT_PASSWORD:-}" ]; then
  echo "ERROR: STARROCKS_ROOT_PASSWORD not set in .env" >&2
  exit 1
fi

bash scripts/wait-for.sh "StarRocks FE" \
  docker exec udp-starrocks-fe mysql -h 127.0.0.1 -P 9030 -u root -e "SELECT 1"

# Detect whether root already requires a passphrase by trying without one.
if docker exec udp-starrocks-fe mysql -h 127.0.0.1 -P 9030 -u root \
     -e "SELECT 1" >/dev/null 2>&1; then
  echo "Root currently has empty credential — applying generated value..."
  docker exec udp-starrocks-fe mysql -h 127.0.0.1 -P 9030 -u root \
    -e "SET PASSWORD FOR 'root'@'%' = PASSWORD('${STARROCKS_ROOT_PASSWORD}');" \
    >/dev/null
  echo "Root credential applied."
else
  # Verify the .env credential actually works.
  if docker exec udp-starrocks-fe mysql -h 127.0.0.1 -P 9030 -u root \
       -p"${STARROCKS_ROOT_PASSWORD}" -e "SELECT 1" >/dev/null 2>&1; then
    echo "Root credential already applied and matches .env — skipping."
  else
    echo "ERROR: root requires a credential, but the one in .env does not match." >&2
    echo "Either fix .env to match the live value, or reset via './udp clean' (DESTRUCTIVE)." >&2
    exit 1
  fi
fi
