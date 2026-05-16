#!/usr/bin/env bash
# Create udp system user and directory layout.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

require_root
ensure_user
ensure_dirs
log "User and directories ready"
