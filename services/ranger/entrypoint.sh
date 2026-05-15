#!/usr/bin/env bash
set -euo pipefail

if [ ! -f "${RANGER_HOME}/.installed" ]; then
  echo "First-time Ranger setup..."
  "${RANGER_HOME}/install.sh"
  touch "${RANGER_HOME}/.installed"
fi

exec "${RANGER_HOME}/ews/ranger-admin-services.sh" start-foreground
