# UDP Roadmap

## v0.2 (shipped)
- one-command installer
- Docker Compose stack (MinIO, Iceberg REST, Spark, StarRocks)
- demo raw/curated/app layers
- smoke tests
- semantic YAML sample
- governance YAML sample
- udp_core skeleton

## v0.3 (shipped)
- Iceberg catalog moved to **Hive Metastore** (replaces iceberg-rest)
  - multi-engine catalog; Ranger-ready; aligns with reference architecture
- **Apache Ranger** as opt-in compose profile (`./udp ranger up`)
  - policy admin plane; enforcement still v0.4
- demo CSV moved to `examples/customers.csv` (gitignore-safe)
- updated Spark catalog config, StarRocks external catalog config, doctor checks

## v0.4
- Ranger StarRocks enforcement plugin
- Postgres/MySQL/Mongo source connectors
- config-driven source onboarding
- Airflow/Dagster orchestration
- data quality checks
- schema drift detection

## v0.5
- AI analyst API
- MCP server
- embeddings and document search
- NL-to-SQL over semantic models
- Apache Superset out-of-the-box

## v1.0
- production hardening
- monitoring
- RBAC/ABAC integration
- Kubernetes deployment
