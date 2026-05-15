# UDP Persistence Model

This document describes where UDP stores data, what can be lost on a failure,
and how to back it up and restore.

## What gets persisted

| Tier | Storage | Volume | What it holds |
|---|---|---|---|
| Object | MinIO | `udp_minio_data` | Iceberg data files (Parquet), manifests, metadata.json |
| Catalog | Postgres | `udp_postgres_data` | Iceberg table-of-tables — namespaces, table refs, snapshot history |
| Serving FE | StarRocks FE | `udp_starrocks_fe_meta` | Catalog metadata, user accounts, GRANTs, views |
| Serving BE | StarRocks BE | `udp_starrocks_be_storage` | Materialized data segments (regenerable from Iceberg) |

### Phase 2 change — Iceberg catalog is now durable

Before Phase 2 the Iceberg REST server used its default backing (SQLite/in-memory
inside the container). A container restart would wipe namespaces and table
references — even though the data files remained in MinIO. Phase 2 swaps in a
**Postgres-backed JDBC catalog** (`org.apache.iceberg.jdbc.JdbcCatalog`), so the
catalog now survives restarts. Postgres data is in its own named volume,
`udp_postgres_data`.

## Failure modes and recovery

| Failure | Data loss | Recovery |
|---|---|---|
| Iceberg REST container crashes/restarts | None | Auto-restart; reconnects to Postgres |
| Postgres container crashes | None (catalog on volume) | `docker restart udp-postgres` |
| Postgres volume corruption | Catalog lost; MinIO data files still present but orphaned | Restore from `pg_dump` backup |
| MinIO container crashes | None | Auto-restart |
| MinIO volume loss (single-node!) | **All Iceberg data lost** | Restore from `mc mirror` backup; no erasure coding to recover from |
| StarRocks FE volume corruption | Catalogs, users, views lost — but Iceberg data intact | Re-run `bootstrap.sh` to recreate external catalog + views; restore users from `governance/policies/*.yaml` |
| StarRocks BE volume loss | Cached materializations lost | Auto-rebuild on first query |
| Host loss | Everything | Restore from backup directory |

## Backup

```bash
./udp backup                    # default: backups/udp-<ISO8601>
./udp backup /mnt/snapshots/udp # custom location
```

The script produces a single directory with:

- `iceberg_catalog.dump` — pg_dump custom format of the catalog DB
- `minio/<bucket>/` — `mc mirror` of every object in the lake bucket
- `starrocks_fe_meta.tar.gz` — tar of the StarRocks FE metadata volume
- `MANIFEST.txt` — backup metadata and restore command

### Live-snapshot consistency caveats

- `mc mirror` is consistent per-object but can straddle a multi-file table
  commit. For cross-table point-in-time consistency, briefly quiesce writers
  (Spark, StarRocks loaders) before backup.
- `pg_dump` uses a snapshot transaction — internally consistent.
- StarRocks FE `tar` is a hot copy. For a guaranteed point-in-time, run
  `./udp stop` first, take the snapshot, then `./udp start`.

For most demo and small-team workloads, hot backup at a quiet hour is
acceptable. Production workloads should ship to a real backup target on a
schedule (cron / systemd timer / orchestrator).

## Restore

```bash
./udp restore backups/udp-20260515T100000Z
```

The script:

1. Drops and recreates the Postgres catalog DB, then `pg_restore`s the dump.
2. Mirrors the MinIO objects back into the bucket (`--remove` deletes objects
   that aren't in the backup).
3. Prints the manual commands to restore the StarRocks FE metadata — this step
   is deliberately not automated because it requires stopping the FE.

After Postgres + MinIO are restored, restart Iceberg REST to refresh its
connection pool: `docker restart udp-iceberg-rest`.

## Resource budget

The compose stack declares the following resource limits (`deploy.resources.limits`).
Modern `docker compose` honors these without Swarm. Stack total ≈ 14 CPU / 13.5 GB.

| Service | CPU | Memory |
|---|---|---|
| minio | 2.0 | 2.0G |
| postgres | 1.0 | 0.5G |
| iceberg-rest | 1.0 | 1.0G |
| spark | 4.0 | 4.0G |
| starrocks-fe | 2.0 | 2.0G |
| starrocks-be | 4.0 | 4.0G |

Below 16 GB host RAM, expect contention. `./udp doctor` warns.

## What's NOT yet covered (future phases)

- **Distributed MinIO** — single-node erasure coding is off; a single MinIO
  volume loss = all object data lost. Production deploys should use multi-node
  MinIO (≥4 nodes) or managed object storage. Tracked in Phase 6.
- **Postgres HA / streaming replication** — single-instance. Phase 6.
- **StarRocks HA (3-FE, multi-BE)** — single-FE today. Phase 6.
- **Offsite backup target** — local directory only. Wire a cron job that
  ships `./udp backup` to S3/GCS once you have credentials.
- **Restore drills** — automate a periodic drill that backups + restores into
  a sandbox compose and runs the smoke test against the restored stack.
