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
- **Two Iceberg catalogs side-by-side** over the same warehouse:
  - HMS-backed (`udp` / `iceberg_catalog`) — default, Ranger-ready
  - REST-backed (`udp_rest` / `iceberg_rest_catalog`) — cloud-native
- **Apache Ranger** as opt-in compose profile (`./udp ranger up`)
  - policy admin plane; enforcement still v0.5
- demo CSV moved to `examples/customers.csv` (gitignore-safe)
- updated Spark catalog config, StarRocks external catalog SQL, doctor checks

## v0.4 (shipped)
- **Native single-server installer** (Ubuntu/Debian) — no Docker required
  - `sudo bash install.sh --mode=native` installs MinIO, Postgres, Hive Metastore, Spark, StarRocks as systemd services
  - `scripts/native/` orchestrator with 8 phase scripts
  - `services/systemd/` unit files
- **Mode-aware `./udp` CLI** — auto-detects systemd vs docker compose
- **Mode-aware `smoke-test` and `doctor`**
- Docker path preserved at `scripts/install-docker.sh`; original `install.sh` becomes the dispatcher
- Native install ships HMS catalog only (iceberg-rest, Ranger remain docker-mode)

## v0.5
- iceberg-rest catalog support in native install
- Apache Ranger in native install (currently docker-only)
- Ranger StarRocks enforcement plugin
- Postgres/MySQL/Mongo source connectors
- config-driven source onboarding
- Airflow/Dagster orchestration
- data quality checks
- schema drift detection

## v0.6
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
- multi-host installs (Ansible playbook)
