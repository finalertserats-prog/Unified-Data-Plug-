#!/usr/bin/env bash
# Top-level UDP installer. Dispatches to the chosen mode.
#
# Usage:
#   bash install.sh                  # asks (or auto-detects)
#   bash install.sh --mode=native    # native single-server (Ubuntu/Debian)
#   bash install.sh --mode=docker    # Docker Compose
#
# Native install requires root (sudo). Docker install does not.

set -euo pipefail

UDP_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$UDP_HOME"

MODE=""

for arg in "$@"; do
  case "$arg" in
    --mode=*) MODE="${arg#--mode=}" ;;
    -h|--help)
      sed -n '1,/^set -euo/p' "$0" | grep '^#' | sed 's/^# \{0,1\}//'
      exit 0
      ;;
  esac
done

if [ -z "$MODE" ]; then
  if [ -t 0 ]; then
    echo "Select install mode:"
    echo "  1) native  - install components directly on this host as systemd services"
    echo "  2) docker  - run components in Docker Compose"
    read -r -p "Choice [1]: " choice
    case "${choice:-1}" in
      1|native) MODE=native ;;
      2|docker) MODE=docker ;;
      *) echo "Invalid choice: $choice"; exit 1 ;;
    esac
  else
    MODE=native
  fi
fi

case "$MODE" in
  native)
    if [ "$(id -u)" -ne 0 ]; then
      echo "Native install needs root. Re-run with sudo:"
      echo "  sudo bash install.sh --mode=native"
      exit 1
    fi
    bash "$UDP_HOME/scripts/install-native.sh"
    ;;
  docker)
    bash "$UDP_HOME/scripts/install-docker.sh"
    ;;
  *)
    echo "Unknown mode: $MODE (expected: native|docker)"
    exit 1
    ;;
esac
