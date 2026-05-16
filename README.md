# Unified Data Plug

**Unified Data Plug (UDP)** is a plug-and-play, AI-ready open lakehouse starter. Iceberg is the core of the lake.

UDP runs in **two modes**, both driven by a single `install.sh`:

| Mode | What it does | When to use |
|---|---|---|
| **native** (default) | Installs MinIO, Postgres, Hive Metastore, Spark, StarRocks directly on the host as systemd services | You have a Linux server and want UDP installed on it. No Docker required. |
| **docker** | Brings the whole stack up in Docker Compose | Local dev, ephemeral demos, or hosts where you'd rather not touch system packages |

The native mode is what most teams want for a real server install. The Docker mode is fastest for laptops and POCs.

## One-command install

```bash
git clone https://github.com/finalertserats-prog/Unified-Data-Plug.git
cd Unified-Data-Plug

# Native (Ubuntu/Debian, single server, requires sudo):
sudo bash install.sh --mode=native

# Or Docker:
bash install.sh --mode=docker

# Or interactive (asks):
bash install.sh
```

## Stack

| Layer | Component | Both modes |
|---|---|---|
| Object storage | MinIO | ✓ |
| Table format | Apache Iceberg | ✓ |
| Catalog (default) | Iceberg REST | ✓ |
| Catalog (opt-in) | Hive Metastore (+Postgres) | docker: `./udp hms up` |
| Processing | Spark | ✓ |
| Serving | StarRocks 3.3.12 (FE+BE) | ✓ |
| Governance (opt-in) | Apache Ranger | docker: `./udp ranger up` |

**Docker mode profiles:** the core stack (MinIO + Iceberg REST + Spark + StarRocks) comes up with `./udp start`. Hive Metastore and Apache Ranger are opt-in via compose profiles — start them with `./udp hms up` or `./udp ranger up`. This keeps the cold-start RAM footprint small (the core stack fits in 16 GB; HMS + Ranger add several more services).

## What native install does

```text
sudo bash install.sh --mode=native
  ├─ apt: openjdk-17, postgresql, curl, mysql-client, python3
  ├─ create system user `udp` + /opt/udp, /var/lib/udp, /var/log/udp, /etc/udp
  ├─ Postgres: create metastore DB + hive role
  ├─ MinIO:    install binary, systemd unit, start, create bucket
  ├─ Hive:     download 4.0.0, init schema, systemd unit, start
  ├─ Spark:    download 3.5.1 + Iceberg/S3A jars, render spark-defaults.conf
  ├─ StarRocks: install FE+BE, register BE
  ├─ Bootstrap: run demo Spark job (raw + curated Iceberg tables)
  └─ Create StarRocks external Iceberg catalog + analytics view
```

Resource floor: **16 GB RAM, 4 vCPU, 100 GB disk.**

## Access points

| Service | URL / Port |
|---|---|
| MinIO API | http://&lt;host&gt;:9000 |
| MinIO Console | http://&lt;host&gt;:9001 |
| Hive Metastore (Thrift) | thrift://&lt;host&gt;:9083 |
| Spark | local-mode, no UI in native install |
| StarRocks FE UI | http://&lt;host&gt;:8030 |
| StarRocks MySQL | &lt;host&gt;:9030 |
| Iceberg REST *(docker only)* | http://localhost:8181 |
| Ranger Admin *(docker only)* | http://localhost:6080 |

## Day-to-day CLI

`./udp` auto-detects the mode (native systemd or docker compose).

```bash
./udp status       # systemctl status ... | docker compose ps
./udp logs minio   # journalctl -u udp-minio  | docker compose logs minio
./udp stop
./udp start
./udp smoke-test
./udp ranger up    # docker mode only
./udp mode         # prints "native" or "docker"
```

## Repository structure

```text
install.sh                  # top-level dispatcher
scripts/
  install-native.sh         # native installer orchestrator
  install-docker.sh         # docker installer
  native/
    01_prereqs.sh           # apt packages, kernel knobs
    02_users_dirs.sh        # udp user + /opt/udp /var/lib/udp /etc/udp
    03_postgres.sh          # HMS DB/role
    04_minio.sh             # MinIO binary + systemd unit
    05_hive_metastore.sh    # Hive 4.0.0 tarball + schema init
    06_spark.sh             # Spark 3.5.1 + Iceberg/S3A jars
    07_starrocks.sh         # StarRocks FE+BE + register
    08_bootstrap.sh         # demo Spark job + StarRocks catalog
    lib.sh                  # common helpers
  bootstrap.sh              # docker bootstrap (compose path)
  smoke-test.sh             # mode-aware
  doctor.sh                 # mode-aware host preflight
services/
  systemd/                  # native systemd unit files
  ranger/                   # docker-only Ranger admin build
docker-compose.yml          # docker mode topology
sql/                        # StarRocks DDL (mode-agnostic)
jobs/                       # Spark jobs (mode-agnostic)
udp_core/                   # shared library (config, logging, retry, ack)
config/                     # hive-site.xml, spark-defaults.conf
examples/                   # demo CSV
semantic/  governance/  observability/
docs/
```

## Production note

UDP v0.4 is a plug-and-play foundation. For production, configure TLS, secrets management (vault), persistent external storage, backups, monitoring, and access control on top.
