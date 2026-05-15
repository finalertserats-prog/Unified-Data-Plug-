#!/usr/bin/env bash
set -euo pipefail

name="$1"
shift
tries="${TRIES:-60}"

echo "Waiting for $name..."
for i in $(seq 1 "$tries"); do
  if "$@" >/dev/null 2>&1; then
    echo "$name is ready"
    exit 0
  fi
  sleep 2
done

echo "Timed out waiting for $name"
exit 1
