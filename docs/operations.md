# UDP Operations Runbook

Day-2 operations: monitoring, common failures, recovery procedures, and the
backup/DR drill cadence.

## Daily checks

```bash
./udp status                       # all services Up + healthy
./udp doctor                       # host readiness
docker stats --no-stream           # confirm services within resource budget
```

Grafana dashboard at http://127.0.0.1:3000 (login from `.env`):
- **UDP Overview** — MinIO bucket count + disk usage, FE/BE up, per-job scrape success.

Pipeline run history:

```sql
mysql -h 127.0.0.1 -P 9030 -u analyst -p
SELECT * FROM app_observability.recent_runs;
```

## Capacity budget

The compose stack budgets:

| Service | CPU | Memory |
|---|---|---|
| minio | 2.0 | 2.0G |
| postgres | 1.0 | 0.5G |
| iceberg-rest | 1.0 | 1.0G |
| spark | 4.0 | 4.0G |
| starrocks-fe | 2.0 | 2.0G |
| starrocks-be | 4.0 | 4.0G |
| prometheus | 1.0 | 0.5G |
| grafana | 1.0 | 0.5G |
| **TOTAL** | **16.0** | **14.5G** |

Recommended host: ≥ 16 GB RAM, ≥ 8 physical cores, ≥ 100 GB SSD (more if you
ingest non-trivial data). On smaller hosts, edit `deploy.resources.limits` per
service or split services across machines.

## Common failure runbooks

### `./udp start` fails — port already in use

`./udp doctor` reports `WARN: port X appears to be in use`. Find the offender:

```bash
sudo lsof -i :9030   # or 9000, 8181, 9001, 8030, 3000, 9090
```

Stop it or change the host-side port in `docker-compose.yml`.

### Iceberg REST is unhealthy after restart

```bash
docker logs udp-iceberg-rest --tail 100
```

Look for `Could not initialize JdbcCatalog`. Causes:

1. **Postgres not ready** — check `docker ps` and `docker logs udp-postgres`.
2. **Wrong credential** — `.env` `POSTGRES_PASSWORD` drifted from the live DB.
   Reset with: `docker exec udp-postgres psql -U iceberg -c "ALTER USER iceberg WITH PASSWORD '<value-from-.env>';"`
3. **Catalog tables missing** — first start creates them on demand. If
   they were dropped, drop the namespaces and re-run `./udp bootstrap`.

### StarRocks FE healthcheck failing

```bash
docker logs udp-starrocks-fe --tail 200
```

Common causes:

- **Password drift** — `.env` `STARROCKS_ROOT_PASSWORD` does not match the live
  value. Re-run `bash scripts/set-starrocks-password.sh` (it reapplies from `.env`).
- **Metadata volume corruption** — `udp_starrocks_fe_meta`. Stop, restore from
  backup, or re-initialize:
  ```bash
  ./udp stop
  docker volume rm udp_starrocks_fe_meta
  ./udp start
  ./udp bootstrap
  ```
- **BE not registered** — `SHOW BACKENDS;` from the FE. Bootstrap reruns
  `ALTER SYSTEM ADD BACKEND` idempotently.

### MinIO bucket lost

Recover from the most recent backup:

```bash
./udp restore backups/udp-<latest-iso8601>
```

If no backup, recreate the bucket (data is lost):

```bash
docker run --rm --network udp_default \
  -e MC_HOST_udp=http://${MINIO_ROOT_USER}:${MINIO_ROOT_PASSWORD}@minio:9000 \
  minio/mc mb udp/${MINIO_BUCKET}
./udp bootstrap
```

### Container OOM'd

`docker ps -a` shows the container as `Exited (137)`. Causes:

1. Host RAM exhausted — raise the host budget or lower per-service limits.
2. Spark job blew its 4 GB heap — break the job into smaller batches or raise
   spark's `deploy.resources.limits.memory`.

### Smoke test fails after upgrade

```bash
./udp logs spark
./udp logs starrocks-fe
```

If schema drift is the cause (`createOrReplace()` rewrites tables without
schema-evolution), recreate the analytics database:

```bash
docker exec -i udp-starrocks-fe mysql -h 127.0.0.1 -P 9030 -u root -p"$STARROCKS_ROOT_PASSWORD" -e "DROP DATABASE IF EXISTS app_analytics;"
./udp bootstrap
```

## Disaster recovery

### Backup cadence

| Tier | Frequency | Retention |
|---|---|---|
| Dev / demo | weekly | 4 weeks |
| Pre-prod / small team | nightly | 14 days |
| Production-adjacent | hourly (catalog) + nightly (full) | 30 days local + offsite copy |

Wire `./udp backup /path/to/backups` into cron / systemd timer / orchestrator.

### Drill cadence

Run `./udp dr-drill` on a schedule. It backs up the current stack, wipes
volumes, starts fresh, restores, and smoke-tests against the restored data.
A passing drill is the only proof that backups actually work.

| Environment | Drill cadence |
|---|---|
| Dev | quarterly |
| Pre-prod | monthly |
| Production-adjacent | weekly |

Drill logs land in `backups/dr-drill-<id>.log`.

### RTO / RPO targets (recommended)

| Failure | RPO | RTO |
|---|---|---|
| Single container crash | 0 | < 1 min (auto-restart) |
| Single volume corruption | last backup | 30 min (restore one tier) |
| Host loss | last backup | 1–2 hr (re-provision + restore) |
| Region loss (offsite needed) | last offsite copy | 4–8 hr |

These assume you've automated the cron-based backup and drilled the restore.

## Upgrading

See [upgrade.md](upgrade.md) for the version-upgrade procedure.
