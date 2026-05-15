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

All ports are bound to `127.0.0.1` only — reachable from the install host,
not from the LAN. To access from another machine, tunnel via SSH:
`ssh -L 9001:127.0.0.1:9001 udp-host`.

| Service | URL / Port |
|---|---|
| MinIO API | http://127.0.0.1:9000 |
| MinIO Console | http://127.0.0.1:9001 |
| Iceberg REST | http://127.0.0.1:8181 |
| Spark Notebook | http://127.0.0.1:8888 |
| StarRocks FE UI | http://127.0.0.1:8030 |
| StarRocks MySQL | mysql -h 127.0.0.1 -P 9030 -u root -p |

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

## Security

UDP generates random credentials at install time, gates `udp clean` behind
explicit confirmation, pins every image to a `@sha256:` digest, and binds all
ports to localhost. **Before deploying outside a trusted local network, read
[docs/security.md](docs/security.md)** — it documents what is and isn't
protected today and the production-deploy checklist.

## Production note

UDP is a plug-and-play foundation. Production deploys still require external
object storage (S3/GCS/Blob or distributed MinIO), a Postgres-backed Iceberg
catalog, TLS ingress, backups, observability, and a real secret manager. See
[docs/roadmap.md](docs/roadmap.md).
