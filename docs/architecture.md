# UDP Architecture

UDP follows this flow:

```text
Sources
  ↓
Spark ingestion
  ↓
Apache Iceberg raw layer        ←→  Hive Metastore (default)  AND  Iceberg REST (secondary)
  ↓
Apache Iceberg curated layer
  ↓
StarRocks application and analytics layer
   ├─ iceberg_catalog       (HMS-backed external catalog)
   └─ iceberg_rest_catalog  (REST-backed external catalog)
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
| Catalog (default) | Hive Metastore (+Postgres) | Iceberg catalog for multi-engine flows, Ranger-ready |
| Catalog (secondary) | Iceberg REST (`tabulario/iceberg-rest`) | Cloud-native Iceberg API, kept side-by-side |
| Processing | Spark (with Iceberg extensions) | Ingestion and transformation |
| Serving | StarRocks | Low-latency analytics; two external catalogs registered |
| Semantic | YAML models | Business metrics and NL-ready definitions |
| Governance | Apache Ranger (optional) + YAML policies | Policy-admin plane; enforcement v0.4 |

## Dual-catalog setup

Both catalogs sit over the same MinIO warehouse (`s3://datalake/warehouse`). Choose per workload — they are not mirrors. A table created via one catalog only exists in that catalog.

| Spark catalog | Type | URI | Use when |
|---|---|---|---|
| `udp` (default) | HMS-backed Iceberg | `thrift://hive-metastore:9083` | Multi-engine, governance-ready, ecosystem tools (Trino, Hue, Superset, Ranger) |
| `udp_rest` | REST-backed Iceberg | `http://iceberg-rest:8181` | Cloud-native flows, newer Iceberg REST features, language-agnostic clients |

StarRocks sees both:

| StarRocks catalog | Backed by |
|---|---|
| `iceberg_catalog` | Hive Metastore |
| `iceberg_rest_catalog` | Iceberg REST |

## Why dual instead of pick-one

- **Default is HMS** so the architecture deck, Ranger integration, and the existing Hive ecosystem all work without configuration.
- **REST is kept** so cloud-native, language-agnostic, and newer Iceberg-REST-only features remain available without standing up a second stack.
- The demo flow runs against the HMS catalog (default); flipping the namespace prefix (`udp_rest.raw.demo_customers`) reroutes everything to REST.
