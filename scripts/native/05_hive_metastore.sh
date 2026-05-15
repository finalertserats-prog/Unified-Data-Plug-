#!/usr/bin/env bash
# Install Apache Hive 4.0.0 in standalone Metastore mode.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

require_root
load_env

HMS_HOME="$UDP_HOME_ROOT/hive"
mkdir -p "$HMS_HOME"

if [ ! -d "$HMS_HOME/lib" ]; then
  log "Downloading Apache Hive ${HIVE_VERSION}"
  tmp="$(mktemp -d)"
  download_to "https://archive.apache.org/dist/hive/hive-${HIVE_VERSION}/apache-hive-${HIVE_VERSION}-bin.tar.gz" "$tmp/hive.tgz"
  tar -xzf "$tmp/hive.tgz" -C "$tmp"
  mv "$tmp/apache-hive-${HIVE_VERSION}-bin"/* "$HMS_HOME/"
  rm -rf "$tmp"
fi

# Postgres JDBC driver
if [ ! -f "$HMS_HOME/lib/postgresql.jar" ]; then
  download_to "https://jdbc.postgresql.org/download/postgresql-${POSTGRES_JDBC_VERSION}.jar" "$HMS_HOME/lib/postgresql.jar"
fi

# Render hive-site.xml from template
cp "$REPO_ROOT/config/hive/hive-site.xml" "$HMS_HOME/conf/hive-site.xml"

chown -R "$UDP_USER:$UDP_GROUP" "$HMS_HOME"

# Init schema if not already done
log "Initialising Hive Metastore schema in Postgres (idempotent)"
HMS_FLAG="$HMS_HOME/.schema-initialised"
if [ ! -f "$HMS_FLAG" ]; then
  sudo -u "$UDP_USER" \
    JAVA_HOME=/usr/lib/jvm/java-17-openjdk-${ARCH:-amd64} \
    HIVE_HOME="$HMS_HOME" \
    "$HMS_HOME/bin/schematool" -dbType postgres -initSchema \
      -url "jdbc:postgresql://127.0.0.1:5432/${HMS_DB_NAME}" \
      -driver org.postgresql.Driver \
      -userName "${HMS_DB_USER}" -passWord "${HMS_DB_PASSWORD}" \
    || warn "schematool returned non-zero (may already be initialised)"
  touch "$HMS_FLAG"
  chown "$UDP_USER:$UDP_GROUP" "$HMS_FLAG"
fi

log "Installing systemd unit udp-hive-metastore.service"
install -m 0644 "$REPO_ROOT/services/systemd/udp-hive-metastore.service" /etc/systemd/system/udp-hive-metastore.service
systemd_enable_start udp-hive-metastore

wait_for_port 127.0.0.1 9083 "Hive Metastore"
log "Hive Metastore ready (thrift://127.0.0.1:9083)"
