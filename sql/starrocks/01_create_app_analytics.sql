-- Demo analytics view. References iceberg_rest_catalog (the REST-backed
-- one defined in 00b) instead of iceberg_catalog (the HMS-backed one),
-- because:
--   1. REST catalog works without hive-metastore (which is now opt-in
--      via the `hms` docker-compose profile)
--   2. StarRocks 3.3.12 reads REST-backed Iceberg tables on MinIO
--      reliably; the HMS-backed path needs additional config
-- If you start the stack with `--profile hms` you can also reference
-- iceberg_catalog directly — both catalogs see the same physical data.
CREATE DATABASE IF NOT EXISTS app_analytics;

DROP VIEW IF EXISTS app_analytics.demo_customer_summary;

CREATE VIEW app_analytics.demo_customer_summary AS
SELECT
    region,
    customer_count,
    total_order_amount,
    curated_timestamp
FROM iceberg_rest_catalog.curated.demo_customer_summary;
