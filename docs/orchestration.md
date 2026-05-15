# UDP Orchestration

UDP ships with two orchestrators. **Pick one at install time**; the other's
services stay dormant.

| Pick | Why pick it | Don't pick if |
|---|---|---|
| `airflow` | Mature ecosystem (provider operators for nearly every source), familiar to most data teams, broad community | You want asset-first lineage and freshness without writing it yourself |
| `dagster` | Asset-first model fits lakehouse semantics natively, typed I/O, software-defined assets, lighter ops weight | Your team already has Airflow muscle memory and 50+ existing DAGs |
| `none` | You want UDP as a pure ingestion + serving stack and orchestrate elsewhere (existing Airflow, dbt-cloud, Prefect, your own cron) | Demo wants to run on a schedule out of the box |

## How the choice is wired

- `install.sh` prompts and writes `UDP_ORCHESTRATOR={airflow|dagster|none}` to `.env`.
- The `udp` CLI exports `COMPOSE_PROFILES=$UDP_ORCHESTRATOR` before invoking
  `docker compose`, so only the selected orchestrator's services start.
- Every service still gets digest-pinned, resource-limited, healthchecked, and
  observed by the same `app_observability.pipeline_runs` table.

## Switching after install

```bash
sed -i 's/^UDP_ORCHESTRATOR=.*/UDP_ORCHESTRATOR=dagster/' .env
./udp restart
```

Credentials for both orchestrators are generated at install time and live in
`.env`, so switching needs no re-init.

## Profile: `airflow`

| Service | Image | Port (loopback) |
|---|---|---|
| `airflow-init` | apache/airflow:2.10.3-python3.11 (digest-pinned) | — |
| `airflow-webserver` | same | 8080 |
| `airflow-scheduler` | same | — |

LocalExecutor (no Celery/Redis). Metadata DB: `airflow_meta` on `udp-postgres`.
Encryption keys (`AIRFLOW_FERNET_KEY`, `AIRFLOW_WEBSERVER_SECRET_KEY`)
generated at install. Docker socket mounted into webserver + scheduler so
the DAG can `docker exec` into `udp-spark`.

### DAGs

| DAG | Schedule | Description |
|---|---|---|
| `udp_demo_lake` | `0 2 * * *` | Materialize raw → curated Iceberg + run smoke test |

DAGs live in `airflow/dags/`. The dir is mounted read-only into both webserver
and scheduler. CI validates DAG imports via `DagBag`.

### Ad-hoc trigger

```bash
docker exec udp-airflow-webserver airflow dags trigger udp_demo_lake
docker exec udp-airflow-webserver airflow dags list-runs -d udp_demo_lake
```

## Profile: `dagster`

| Service | Image | Port (loopback) |
|---|---|---|
| `dagster` | python:3.11-slim (digest-pinned) + Dagster installed on startup | 3001 (→ container 3000) |

Single dev container running `dagster dev` (webserver + daemon in one process).
Metadata DB: `dagster_meta` on `udp-postgres`. The Postgres-backed event log
and run storage are configured in `config/dagster/dagster.yaml`. Docker socket
mounted so asset materializations can `docker exec` into `udp-spark`.

### Assets

| Asset | Group | Description |
|---|---|---|
| `demo_lake` | demo_lake | Materializes raw + curated Iceberg via Spark |
| `demo_lake_smoke` | demo_lake | Asserts curated table is populated (depends on `demo_lake`) |

Both grouped under `demo_lake_job`. A daily schedule exists but is **stopped
by default** — enable it in the UI when you're ready.

Asset definitions: `dagster_project/definitions.py`.

### Ad-hoc trigger

UI → Assets → Materialize, or:

```bash
docker exec udp-dagster dagster job execute -m dagster_project.definitions -j demo_lake_job
```

## Shared observability

Both orchestrators call the same Spark jobs in `jobs/*.py`. Those jobs already
wrap themselves in `udp_core.observability.run_tracker.track(...)`, so every
materialization — Airflow task, Dagster asset, or direct `./udp bootstrap` —
lands in `app_observability.pipeline_runs`. Recent runs:

```sql
SELECT pipeline_name, started_at, finished_at, status, rows_in, rows_out
FROM app_observability.recent_runs;
```

The orchestrator name is **not** stored in that table (intentionally — we
treat the runs as data-side events, not orchestrator state). For
orchestrator-native lineage and trigger history, use each tool's own UI.

## CI

Two static-validity jobs run on every push/PR:

- `dag-validity` — installs the Airflow constraints file and imports every DAG
  via `DagBag`. Any import error or syntax error fails the build.
- `dagster-validity` — imports `dagster_project.definitions` and asserts
  `Definitions` loads cleanly.

Both are cheap (no orchestrator runtime needed) and run in parallel.

## What's NOT in Phase 5 yet (v0.3 follow-ons)

- Source connector DAGs/assets (Postgres/MySQL/Mongo/Kafka)
- Config-driven generation from `pipelines/sources/*.yaml`
- Data quality (Great Expectations / Soda) per layer
- Lineage emission (OpenLineage → Marquez/DataHub)
- CeleryExecutor / Dagster-K8s for multi-host (Phase 6)
