# UDP Roadmap

## v0.2
- one-command installer
- Docker Compose stack
- demo raw/curated/app layers
- smoke tests
- semantic YAML sample
- governance YAML sample
- udp_core skeleton

## v0.3
- Postgres/MySQL/Mongo connectors
- config-driven source onboarding (DAG factory from `pipelines/sources/*.yaml`)
- ~~Airflow orchestration~~ ✅ Phase 5 (Airflow LocalExecutor + demo DAG)
- data quality checks (Great Expectations or Soda as Airflow operators)
- schema drift detection
- lineage emission via apache-airflow-providers-openlineage

## v0.4
- AI analyst API
- MCP server
- embeddings and document search
- NL-to-SQL over semantic models

## v1.0
- production hardening
- monitoring
- RBAC/ABAC integration
- Kubernetes deployment
