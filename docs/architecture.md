# UDP Architecture

UDP follows this flow:

```text
Sources
  ↓
Spark ingestion
  ↓
Apache Iceberg raw layer
  ↓
Apache Iceberg curated layer
  ↓
StarRocks application and analytics layer
  ↓
BI / AI / applications
```

## Layers

| Layer | Technology | Purpose |
|---|---|---|
| Storage | MinIO/S3 | Object storage |
| Table | Apache Iceberg | Raw and curated lakehouse tables |
| Processing | Spark | Ingestion and transformation |
| Serving | StarRocks | Low-latency analytics and app queries |
| Semantic | YAML models | Business metrics and NL-ready definitions |
| Governance | YAML policies | Policy-as-code foundation |
