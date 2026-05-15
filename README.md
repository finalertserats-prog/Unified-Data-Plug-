# Unified Data Plug

**Unified Data Plug (UDP)** is a plug-and-play, Docker-based, AI-ready open lakehouse starter.

UDP creates a working data lakehouse with:

- **Apache Iceberg** as the raw and curated table layer
- **MinIO/S3** as object storage
- **Spark** for ingestion and transformation
- **StarRocks** as the application and analytics serving layer
- **Demo raw, curated, and analytics datasets** created during bootstrap
- **Smoke tests** to prove the lakehouse is ready

## One-command local/server install

```bash
git clone https://github.com/finalertserats-prog/Unified-Data-Plug-.git
cd Unified-Data-Plug-
bash install.sh
```

Or after downloading the package:

```bash
unzip unified-data-plug-v0.2.zip
cd unified-data-plug-v0.2
bash install.sh
```

## What install does

The installer asks only necessary questions, generates `.env`, checks Docker, starts the stack, bootstraps the demo lake, and runs smoke tests.

```text
install.sh
  ├─ check Docker
  ├─ generate .env
  ├─ start MinIO, Iceberg REST, Spark, StarRocks
  ├─ create demo raw Iceberg table
  ├─ create demo curated Iceberg table
  ├─ create StarRocks Iceberg catalog
  ├─ create analytics database/views
  └─ run smoke tests
```

## Access points

| Service | URL / Port |
|---|---|
| MinIO API | http://localhost:9000 |
| MinIO Console | http://localhost:9001 |
| Iceberg REST | http://localhost:8181 |
| Spark Notebook | http://localhost:8888 |
| StarRocks FE UI | http://localhost:8030 |
| StarRocks MySQL | localhost:9030 |

## Commands

```bash
./udp doctor
./udp start
./udp bootstrap
./udp smoke-test
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
examples/data/customers.csv
        ↓
Iceberg raw.demo_customers
        ↓
Iceberg curated.demo_customer_summary
        ↓
StarRocks app_analytics.vw_demo_customer_summary
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
docs/
examples/
```

## Production note

UDP v0.2 is a plug-and-play foundation. For production, configure secure credentials, persistent external storage, TLS, backup, monitoring, and access control.
