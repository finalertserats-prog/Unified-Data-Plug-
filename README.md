# Unified Data Plug

**Unified Data Plug (UDP)** is a plug-and-play, Docker-based, AI-ready open lakehouse starter.

Iceberg is the core of the lake. UDP creates a working data lakehouse with:

- **Apache Iceberg** as the raw and curated table format
- **Two Iceberg catalogs side-by-side** over the same warehouse:
  - **Hive Metastore** (default, `udp` catalog) — multi-engine, Ranger-ready
  - **Iceberg REST** (`udp_rest` catalog) — cloud-native, language-agnostic
- **MinIO/S3** as object storage
- **Spark** for ingestion and transformation
- **StarRocks** as the application and analytics serving layer (both catalogs registered)
- **Apache Ranger** as the optional governance plane (opt-in compose profile)
- **Demo raw, curated, and analytics datasets** created during bootstrap
- **Smoke tests** to prove the lakehouse is ready

## One-command local/server install

```bash
git clone https://github.com/finalertserats-prog/Unified-Data-Plug-.git
cd Unified-Data-Plug-
bash install.sh
```

## What install does

The installer asks only necessary questions, generates `.env`, checks Docker, starts the stack, bootstraps the demo lake, and runs smoke tests.

```text
install.sh
  ├─ check Docker
  ├─ generate .env
  ├─ start MinIO, Hive Metastore (+Postgres), Iceberg REST, Spark, StarRocks
  ├─ create demo raw Iceberg table (in default HMS catalog)
  ├─ create demo curated Iceberg table
  ├─ register both StarRocks external catalogs (iceberg_catalog, iceberg_rest_catalog)
  ├─ create analytics database/views
  └─ run smoke tests
```

## Access points

| Service | URL / Port |
|---|---|
| MinIO API | http://localhost:9000 |
| MinIO Console | http://localhost:9001 |
| Hive Metastore (Thrift) | thrift://localhost:9083  (default Iceberg catalog) |
| Iceberg REST | http://localhost:8181  (secondary Iceberg catalog) |
| Spark Notebook | http://localhost:8888 |
| StarRocks FE UI | http://localhost:8030 |
| StarRocks MySQL | localhost:9030 |
| Ranger Admin (optional) | http://localhost:6080 |

## Commands

```bash
./udp doctor
./udp start            # core stack
./udp bootstrap
./udp smoke-test
./udp ranger up        # optional governance plane
./udp stop
./udp logs
./udp status
```

or

```bash
make doctor
make start
make bootstrap
make smoke-test
```

## Demo data flow

```text
examples/customers.csv
        ↓ Spark
Iceberg raw.demo_customers          (registered in Hive Metastore)
        ↓ Spark
Iceberg curated.demo_customer_summary
        ↓ StarRocks Iceberg catalog (HMS-backed)
StarRocks app_analytics.demo_customer_summary
```

## Repository structure

```text
install.sh
udp
docker-compose.yml
Makefile
.env.example
scripts/
sql/
jobs/
udp_core/
semantic/
governance/
observability/
services/ranger/
docs/
examples/
```

## Ranger (v0.3 preview)

Apache Ranger ships as an opt-in compose profile and provides the policy-admin plane only. Enforcement against StarRocks is on the v0.4 roadmap.

```bash
./udp ranger up
# Open http://localhost:6080
# First run builds the Ranger admin image from upstream source (~10 min).
```

See `services/ranger/README.md` for details and known limitations.

## Production note

UDP v0.3 is a plug-and-play foundation. For production, configure secure credentials, persistent external storage, TLS, backup, monitoring, and access control.
