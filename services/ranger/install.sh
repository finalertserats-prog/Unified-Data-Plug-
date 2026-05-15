#!/usr/bin/env bash
# Renders ${RANGER_HOME}/install.properties from environment variables expected
# by the Apache Ranger setup script, then invokes it.
set -euo pipefail

cat > "${RANGER_HOME}/install.properties" <<EOF
PYTHON_COMMAND_INVOKER=python3
DB_FLAVOR=POSTGRES
SQL_CONNECTOR_JAR=/opt/ranger-admin/ews/lib/postgresql.jar
db_root_user=${RANGER_DB_USER}
db_root_password=${RANGER_DB_PASSWORD}
db_host=${RANGER_DB_HOST}
db_name=${RANGER_DB_NAME}
db_user=${RANGER_DB_USER}
db_password=${RANGER_DB_PASSWORD}
rangerAdmin_password=${RANGER_ADMIN_PASSWORD}
rangerTagsync_password=${RANGER_ADMIN_PASSWORD}
rangerUsersync_password=${RANGER_ADMIN_PASSWORD}
keyadmin_password=${RANGER_ADMIN_PASSWORD}
audit_store=
unix_user=ranger
unix_group=ranger
authentication_method=UNIX
policymgr_external_url=http://0.0.0.0:6080
policymgr_http_enabled=true
EOF

cd "${RANGER_HOME}"
./setup.sh
