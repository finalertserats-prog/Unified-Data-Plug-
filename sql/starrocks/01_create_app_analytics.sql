CREATE DATABASE IF NOT EXISTS app_analytics;

DROP VIEW IF EXISTS app_analytics.demo_customer_summary;

CREATE VIEW app_analytics.demo_customer_summary AS
SELECT
    region,
    customer_count,
    total_order_amount,
    curated_timestamp
FROM iceberg_catalog.curated.demo_customer_summary;
