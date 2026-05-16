# Installation

UDP installs in two modes, both via the same top-level script.

## Native (default, Ubuntu/Debian server)

```bash
sudo bash install.sh --mode=native
```

Installs MinIO, Postgres, Hive Metastore, Spark, and StarRocks directly on the host as systemd services. No Docker required.

Resource floor: **16 GB RAM, 4 vCPU, 100 GB disk.**

What it does (in order, one phase per script under `scripts/native/`):
1. `01_prereqs.sh` — apt: openjdk-17, postgresql, mysql-client, python3; kernel tuning; fd limits
2. `02_users_dirs.sh` — system user `udp`; `/opt/udp`, `/var/lib/udp`, `/etc/udp`, `/var/log/udp`
3. `03_postgres.sh` — Hive Metastore DB + role
4. `04_minio.sh` — MinIO binary, systemd unit, bucket creation
5. `05_hive_metastore.sh` — Hive 4.0.0 tarball, schema init, systemd unit
6. `06_spark.sh` — Spark 3.5.1 + Iceberg/S3A/AWS-SDK jars
7. `07_starrocks.sh` — StarRocks 3.3 FE + BE, register BE
8. `08_bootstrap.sh` — demo Spark job + StarRocks Iceberg catalog

## Docker

```bash
bash install.sh --mode=docker
```

The v0.3 path. Brings the whole stack up in Docker Compose. Includes the optional Ranger admin profile (`./udp ranger up`) and dual catalog (HMS + REST).

## Interactive

```bash
bash install.sh
```

Asks which mode to use.

## Access points

| Service | Native | Docker |
|---|---|---|
| MinIO API | http://&lt;host&gt;:9000 | http://localhost:9000 |
| MinIO Console | http://&lt;host&gt;:9001 | http://localhost:9001 |
| Hive Metastore | thrift://&lt;host&gt;:9083 | thrift://localhost:9083 |
| Iceberg REST | — *(v0.5)* | http://localhost:8181 |
| Spark UI | — *(local mode)* | http://localhost:8888 |
| StarRocks FE | http://&lt;host&gt;:8030 | http://localhost:8030 |
| StarRocks MySQL | &lt;host&gt;:9030 | localhost:9030 |
| Ranger Admin | — *(v0.5)* | http://localhost:6080 |

## Day-to-day

```bash
./udp status         # service / container status
./udp logs minio     # tail logs
./udp stop / start / restart
./udp smoke-test
./udp ranger up      # docker only
./udp mode           # which mode is installed
```

`./udp` auto-detects the mode. To override: `UDP_MODE=native ./udp status`.
