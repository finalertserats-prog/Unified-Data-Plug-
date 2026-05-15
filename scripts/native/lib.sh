# Common helpers for native install scripts. Sourced, not executed.
# shellcheck shell=bash

UDP_HOME_ROOT="${UDP_HOME_ROOT:-/opt/udp}"
UDP_DATA_ROOT="${UDP_DATA_ROOT:-/var/lib/udp}"
UDP_LOG_ROOT="${UDP_LOG_ROOT:-/var/log/udp}"
UDP_CONF_ROOT="${UDP_CONF_ROOT:-/etc/udp}"
UDP_USER="${UDP_USER:-udp}"
UDP_GROUP="${UDP_GROUP:-udp}"

# Component versions (override with env)
MINIO_VERSION="${MINIO_VERSION:-RELEASE.2025-04-22T22-12-26Z}"
HIVE_VERSION="${HIVE_VERSION:-4.0.0}"
SPARK_VERSION="${SPARK_VERSION:-3.5.1}"
SPARK_HADOOP_VERSION="${SPARK_HADOOP_VERSION:-3}"
ICEBERG_VERSION="${ICEBERG_VERSION:-1.5.2}"
HADOOP_AWS_VERSION="${HADOOP_AWS_VERSION:-3.3.4}"
AWS_SDK_VERSION="${AWS_SDK_VERSION:-1.12.262}"
POSTGRES_JDBC_VERSION="${POSTGRES_JDBC_VERSION:-42.7.3}"
STARROCKS_VERSION="${STARROCKS_VERSION:-3.3.0}"

log()  { printf '\033[1;34m[udp]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[udp warn]\033[0m %s\n' "$*" >&2; }
fail() { printf '\033[1;31m[udp fail]\033[0m %s\n' "$*" >&2; exit 1; }

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    fail "This step must run as root. Try: sudo bash install.sh"
  fi
}

detect_distro() {
  if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    echo "$ID"
  else
    echo "unknown"
  fi
}

ensure_distro_supported() {
  local id; id="$(detect_distro)"
  case "$id" in
    ubuntu|debian) return 0 ;;
    *) fail "Native install supports Ubuntu/Debian in v0.4. Detected: $id. Use --mode=docker instead." ;;
  esac
}

ensure_user() {
  if ! id "$UDP_USER" >/dev/null 2>&1; then
    log "Creating system user $UDP_USER"
    useradd --system --home "$UDP_HOME_ROOT" --shell /usr/sbin/nologin "$UDP_USER"
  fi
}

ensure_dirs() {
  mkdir -p "$UDP_HOME_ROOT" "$UDP_DATA_ROOT" "$UDP_LOG_ROOT" "$UDP_CONF_ROOT"
  chown -R "$UDP_USER:$UDP_GROUP" "$UDP_HOME_ROOT" "$UDP_DATA_ROOT" "$UDP_LOG_ROOT" "$UDP_CONF_ROOT"
}

download_to() {
  local url="$1" dest="$2"
  log "Downloading $(basename "$dest")"
  curl -fsSL "$url" -o "$dest" || fail "Download failed: $url"
}

load_env() {
  local env_file="${1:-$UDP_CONF_ROOT/udp.env}"
  if [ -r "$env_file" ]; then
    set -a
    # shellcheck disable=SC1090
    . "$env_file"
    set +a
  fi
}

systemd_enable_start() {
  local unit="$1"
  systemctl daemon-reload
  systemctl enable "$unit"
  systemctl restart "$unit"
}

wait_for_port() {
  local host="$1" port="$2" name="$3" tries="${4:-60}"
  log "Waiting for $name ($host:$port)..."
  for _ in $(seq 1 "$tries"); do
    if (echo > /dev/tcp/"$host"/"$port") >/dev/null 2>&1; then
      log "$name is ready"
      return 0
    fi
    sleep 2
  done
  fail "$name did not become ready on $host:$port"
}
