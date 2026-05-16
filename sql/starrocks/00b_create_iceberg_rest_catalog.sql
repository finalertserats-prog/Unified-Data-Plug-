-- Secondary Iceberg catalog using the REST gateway.
-- Coexists with iceberg_catalog (HMS-backed). Tables created via Spark's
-- `udp` catalog are visible here under `iceberg_catalog`; tables created via
-- `udp_rest` are visible here under `iceberg_rest_catalog`.
--
-- The three properties added here (warehouse, vended-credentials-enabled,
-- enable_ssl) are required by StarRocks 3.3.12+ (PR #55416) for correct
-- propagation to the Iceberg S3 FileIO when reading from non-AWS object
-- storage like MinIO.
DROP CATALOG IF EXISTS iceberg_rest_catalog;
CREATE EXTERNAL CATALOG iceberg_rest_catalog
PROPERTIES
(
    "type" = "iceberg",
    "iceberg.catalog.type" = "rest",
    "iceberg.catalog.uri" = "http://iceberg-rest:8181",
    "iceberg.catalog.warehouse" = "s3://datalake/warehouse",
    "iceberg.catalog.vended-credentials-enabled" = "false",
    "aws.s3.endpoint" = "http://minio:9000",
    "aws.s3.enable_ssl" = "false",
    "aws.s3.enable_path_style_access" = "true",
    "aws.s3.region" = "us-east-1",
    "aws.s3.access_key" = "admin",
    "aws.s3.secret_key" = "udp_admin_12345"
);
