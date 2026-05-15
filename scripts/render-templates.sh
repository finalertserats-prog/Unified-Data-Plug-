#!/usr/bin/env bash
set -euo pipefail

# Render every *.template file in config/ and sql/ by substituting ${VAR}
# placeholders with values from .env. Generated files have 600 perms and
# are .gitignore'd — never commit them.

UDP_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$UDP_HOME"

if [ ! -f .env ]; then
  echo "ERROR: .env not found. Run install.sh first." >&2
  exit 1
fi

# Pick a renderer: envsubst preferred, python3 fallback.
if command -v envsubst >/dev/null 2>&1; then
  RENDER="envsubst"
elif command -v python3 >/dev/null 2>&1; then
  RENDER="python3"
else
  echo "ERROR: need envsubst (gettext) or python3 to render templates" >&2
  exit 1
fi

render_one() {
  local input="$1"
  local output="${input%.template}"
  case "$RENDER" in
    envsubst)
      ( set -a; . ./.env; envsubst <"$input" >"$output" )
      ;;
    python3)
      ( set -a; . ./.env; python3 - "$input" "$output" <<'PY'
import os, re, sys
src, dst = sys.argv[1], sys.argv[2]
with open(src) as f:
    content = f.read()
def sub(m):
    var = m.group(1)
    if var not in os.environ:
        sys.stderr.write(f"ERROR: missing env var {var} in {src}\n")
        sys.exit(1)
    return os.environ[var]
result = re.sub(r"\$\{([A-Z_][A-Z0-9_]*)\}", sub, content)
with open(dst, "w") as f:
    f.write(result)
PY
      )
      ;;
  esac
  chmod 600 "$output"
  echo "rendered $output"
}

shopt -s nullglob globstar
for tmpl in config/**/*.template sql/**/*.template; do
  render_one "$tmpl"
done
