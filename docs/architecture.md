# UDP Architecture

UDP follows this flow:

```text
Sources
  ↓
Spark ingestion
  ↓
Apache Iceberg raw layer        ←→  Hive Metastore (Iceberg catalog)
  ↓
Apache Iceberg curated layer    ←→  Hive Metastore
  ↓
StarRocks application and analytics layer  (HMS-backed Iceberg external catalog)
  ↓
BI / AI / applications

Governance (optional, opt-in):
  Apache Ranger admin → policy bundles → enforcement plugins (v0.4)
```

## Layers

| Layer | Technology | Purpose |
|---|---|---|
| Storage | MinIO/S3 | Object storage for Iceberg data + metadata files |
| Table | Apache Iceberg | Raw and curated lakehouse tables |
| Catalog | Hive Metastore (+Postgres) | Iceberg catalog; multi-engine table registry |
| Processing | Spark (with Iceberg extensions) | Ingestion and transformation |
| Serving | StarRocks | Low-latency analytics; reads Iceberg via HMS-backed external catalog |
| Semantic | YAML models | Business metrics and NL-ready definitions |
| Governance | Apache Ranger (optional) + YAML policies | Policy-admin plane; enforcement v0.4 |

## Why Hive Metastore for the Iceberg catalog

- **Ranger integration.** Ranger's mature plugin model is built around HMS — fine-grained authorisation over schemas/tables flows through metastore interception.
- **Multi-engine reach.** Trino, Spark Thrift Server, Hue, Superset, BI tools all default to HMS. Tables created by Spark are visible to every engine without extra catalog config.
- **Production parity.** Aligns with the standard data-platform reference architecture and existing operational stacks that already speak HMS.

The Iceberg REST catalog (v0.2 default) was removed in v0.3 in favour of HMS for the reasons above. Switching back to REST is a single-property change in `config/spark/spark-defaults.conf` and `sql/starrocks/00_create_iceberg_catalog.sql`.
