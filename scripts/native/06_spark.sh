#!/usr/bin/env bash
# Install Spark 3.5.1 with Iceberg + S3A jars.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

require_root
load_env

SPARK_HOME="$UDP_HOME_ROOT/spark"
mkdir -p "$SPARK_HOME"

if [ ! -d "$SPARK_HOME/jars" ]; then
  log "Downloading Spark ${SPARK_VERSION}"
  tmp="$(mktemp -d)"
  download_to "https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop${SPARK_HADOOP_VERSION}.tgz" "$tmp/spark.tgz"
  tar -xzf "$tmp/spark.tgz" -C "$tmp"
  mv "$tmp/spark-${SPARK_VERSION}-bin-hadoop${SPARK_HADOOP_VERSION}"/* "$SPARK_HOME/"
  rm -rf "$tmp"
fi

# Iceberg + S3A jars
fetch_jar() {
  local url="$1" dest="$SPARK_HOME/jars/$(basename "$1")"
  [ -f "$dest" ] || download_to "$url" "$dest"
}

log "Fetching Iceberg + Hadoop AWS jars"
fetch_jar "https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-spark-runtime-3.5_2.12/${ICEBERG_VERSION}/iceberg-spark-runtime-3.5_2.12-${ICEBERG_VERSION}.jar"
fetch_jar "https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-aws-bundle/${ICEBERG_VERSION}/iceberg-aws-bundle-${ICEBERG_VERSION}.jar"
fetch_jar "https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/${HADOOP_AWS_VERSION}/hadoop-aws-${HADOOP_AWS_VERSION}.jar"
fetch_jar "https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/${AWS_SDK_VERSION}/aws-java-sdk-bundle-${AWS_SDK_VERSION}.jar"

# Render spark-defaults.conf (HMS catalog only in native install)
cat > "$SPARK_HOME/conf/spark-defaults.conf" <<EOF
spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions

spark.sql.catalog.udp=org.apache.iceberg.spark.SparkCatalog
spark.sql.catalog.udp.type=hive
spark.sql.catalog.udp.uri=${HMS_URI}
spark.sql.catalog.udp.warehouse=${ICEBERG_WAREHOUSE}
spark.sql.catalog.udp.io-impl=org.apache.iceberg.aws.s3.S3FileIO
spark.sql.catalog.udp.s3.endpoint=${S3_ENDPOINT}
spark.sql.catalog.udp.s3.path-style-access=true
spark.sql.defaultCatalog=udp

spark.hadoop.fs.s3a.endpoint=${S3_ENDPOINT}
spark.hadoop.fs.s3a.access.key=${AWS_ACCESS_KEY_ID}
spark.hadoop.fs.s3a.secret.key=${AWS_SECRET_ACCESS_KEY}
spark.hadoop.fs.s3a.path.style.access=true
spark.hadoop.fs.s3a.connection.ssl.enabled=false
spark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem
EOF

chown -R "$UDP_USER:$UDP_GROUP" "$SPARK_HOME"

log "Spark ready ($SPARK_HOME)"
