# UDP Upgrade Procedure

How to move UDP from one tagged version to the next safely.

## Pre-flight (do every time)

1. **Read the changelog** — note any breaking schema or config changes.
2. **Back up the running stack:**
   ```bash
   ./udp backup backups/pre-upgrade-$(date -u +%Y%m%dT%H%M%SZ)
   ```
3. **Run the DR drill** in a sandbox (clone the repo to a different directory,
   `./udp install`, restore the backup, smoke-test). If drill fails, do not
   proceed.
4. **Pin the new image digests** before pulling — never trust floating tags
   even if the upstream points to a `:3.4-latest`. Update `docker-compose.yml`
   `@sha256:...` values, run the `pinned-images` and `trivy-config` CI gates
   locally before merging.
5. **Compose-validate the new file:**
   ```bash
   docker compose config --quiet
   ```

## Standard upgrade

```bash
# In the repo on the upgrade branch:
git pull
docker compose pull         # fetches new digests for pinned images
./udp stop
./udp start                 # picks up new images
bash scripts/wait-for.sh "StarRocks FE" \
  docker exec udp-starrocks-fe mysql -h 127.0.0.1 -P 9030 -u root \
  -p"$STARROCKS_ROOT_PASSWORD" -e "SELECT 1"
./udp smoke-test
```

If smoke-test fails, immediately roll back (see below).

## Schema-evolving upgrade

When the new release introduces non-backwards-compatible schema changes:

1. **Quiesce writers** — stop Spark jobs and any external producers.
2. **Backup** (already done in pre-flight).
3. **Apply the migration SQL** — release notes list the file paths.
4. **Re-run bootstrap to rebuild views:**
   ```bash
   ./udp bootstrap
   ```
5. **Verify with smoke-test.**
6. **Resume writers.**

## Iceberg-format upgrades

Iceberg tables have format-version bumps (V1 → V2 enabled row-level operations,
etc.). Set per-table:

```sql
ALTER TABLE udp.raw.demo_customers SET TBLPROPERTIES ('format-version' = '2');
```

After this, older readers (Spark/Iceberg combinations below the version that
introduced V2) can no longer read the table. Make sure every consumer is on
a compatible version before bumping.

## Postgres major-version upgrade (e.g., 16 → 17)

In-place upgrade of the Postgres data directory is **not** supported when
just bumping the image tag — the new server refuses to start on an older
data directory. Procedure:

```bash
./udp backup backups/pre-pg-upgrade-$(date -u +%Y%m%dT%H%M%SZ)
./udp stop
docker volume rm udp_postgres_data
# Edit docker-compose.yml: postgres image → new digest for postgres:17-alpine
./udp start
./udp restore backups/pre-pg-upgrade-<id>   # pg_restore is version-tolerant
```

## StarRocks version upgrade

StarRocks supports rolling minor-version upgrades; major upgrades may require
running upgrade scripts inside the FE container. Always:

1. Back up FE metadata volume.
2. Read the upstream release notes for migration scripts.
3. Apply scripts (typically `docker exec udp-starrocks-fe ...`).
4. Restart FE first, then BE.

## Rollback

If a deploy goes sideways:

```bash
./udp stop
git checkout <previous-tag>
# Restore backup if data was changed:
docker volume rm udp_postgres_data udp_starrocks_fe_meta
./udp start
./udp restore backups/pre-upgrade-<id>
```

Image digests revert with the git checkout — that's why digest-pinning matters.

## Skipping versions

Don't skip more than one minor version. Multi-version jumps stack migration
risk. If you need to leapfrog from `v0.2` → `v0.6`, walk through each:
`v0.2 → v0.3 → v0.4 → v0.5 → v0.6`, validating each step.

## Post-upgrade

- Run `./udp smoke-test` and confirm row counts match pre-upgrade.
- Check Grafana scrape success for every job.
- Review the Postgres + StarRocks logs for warnings (`docker logs ... 2>&1 | grep -i 'warn\|error'`).
- Update `notebook/decisions/` (if you maintain ADRs) with the version delta.
