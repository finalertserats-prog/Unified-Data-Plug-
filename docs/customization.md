# UDP Customization Model

UDP is a **configurable lakehouse**, not an opinionated single-stack one. Each
major component is swappable at install time without forking the repo. This
document describes how the customization model works, the choices available
today, and the choices planned for upcoming phases.

## The pattern

Every customization axis follows the same three-step contract:

1. **Choice is recorded at install.** `install.sh` prompts the user (with a
   sensible default), the answer is written to `.env` as
   `UDP_<AXIS>=<choice>`.
2. **Docker Compose `profiles:` gates which services start.** Services that
   only apply to one choice carry `profiles: ["<choice>"]`. Services with no
   profile (the core stack) always start.
3. **The `udp` CLI exports `COMPOSE_PROFILES`** from the `.env` so every
   `docker compose` invocation honors the choice. Switching is a one-line
   `.env` edit followed by `./udp restart`.

This means: **no separate compose files, no separate branches, no helm
sub-charts at the local level.** One repo, one install command, multiple
deployable stacks.

## Choices today

| Axis | `.env` var | Options | Default | Phase introduced |
|---|---|---|---|---|
| **Orchestrator** | `UDP_ORCHESTRATOR` | `airflow` · `dagster` · `none` | `airflow` | 5 |

### `UDP_ORCHESTRATOR`

| Choice | Services activated | When to use |
|---|---|---|
| `airflow` | `airflow-init`, `airflow-webserver`, `airflow-scheduler` | Mature ecosystem, provider operators, team familiarity |
| `dagster` | `dagster` | Asset-first model, typed I/O, lighter footprint |
| `none` | — | External orchestration (existing Airflow elsewhere, dbt-cloud, Prefect, cron) |

See [orchestration.md](orchestration.md) for full detail.

## Choices in flight (Phase 6/7 will add)

These follow the same pattern. They're called out here so the design stays
consistent as they land:

| Axis | `.env` var (proposed) | Options | Default | Target phase |
|---|---|---|---|---|
| **Iceberg catalog** | `UDP_ICEBERG_CATALOG` | `tabulario` (current REST + JDBC) · `lakekeeper` · `polaris` · `nessie` | `tabulario` until Phase 6, then `lakekeeper` | 6 |
| **Object store** | `UDP_OBJECT_STORE` | `minio` · `s3` · `gcs` · `azure_blob` | `minio` | 6 |
| **Ingress** | `UDP_INGRESS` | `none` · `traefik` · `nginx` | `none` (loopback-only) → `traefik` once added | 6 |
| **Deployment target** | `UDP_DEPLOY_TARGET` | `compose` · `helm` (k8s) | `compose` | 6 |
| **Policy engine** | `UDP_POLICY_ENGINE` | `none` (YAML-only) · `opa` · `ranger` | `none` until Phase 7, then `opa` | 7 |
| **Observability log store** | `UDP_LOG_STORE` | `stdout` · `loki` · `elasticsearch` | `stdout` | 6 |

## Design rules

When adding a new customization axis, follow these:

1. **Default to the simplest viable option.** New installs must work with all
   defaults and zero questions answered.
2. **Generate every option's credentials at install time**, regardless of the
   current choice. Lets the user switch without re-installing.
3. **Profile names are lower-case, hyphen-free, and match the `.env` value
   verbatim.** `airflow`, not `Airflow` or `airflow-stack`.
4. **One axis = one `UDP_*` var.** Don't bundle multiple decisions into one
   variable (no `UDP_STACK=airflow-traefik-opa`). Composability beats
   compression.
5. **The core stack (MinIO/Postgres/Iceberg REST/Spark/StarRocks/Prometheus/
   Grafana) has no profile** — it always starts. Customization is layered on
   top, not folded into the foundation.
6. **`docker compose config` must validate** for every combination of choices.
   Add a CI matrix job once we have ≥ 2 axes with ≥ 2 options each.
7. **Document each axis as a row in this file's "Choices today" table** and
   link to the in-depth doc that covers the axis (`orchestration.md`,
   `ingress.md`, `policy.md`, etc.).

## Anti-pattern: the "uber-config"

We deliberately avoid one giant `config.yaml` that gates everything. Reasons:

- YAML in a YAML reader inside a shell installer is a layer too deep — debug
  paths get long.
- `.env` is the standard for Docker Compose; staying in that lane keeps
  on-ramp shallow.
- Most operators will only change one or two axes — a wizard with sensible
  defaults beats a 50-line config they need to read.

If the number of axes ever exceeds ~10, we revisit. Until then, `.env` wins.

## Anti-pattern: the "branch per stack"

We do not ship `chore/phase-5-airflow` and `chore/phase-5-dagster` as separate
deployable branches. That would fragment the codebase and double the
maintenance load. **One branch, one main, profile-gated services.**

## Migration path

When a user wants to migrate from one choice to another (e.g.,
`airflow` → `dagster`, or `minio` → `s3`):

1. Run `./udp backup` first.
2. Edit the relevant `UDP_*` line in `.env`.
3. For storage migrations: run a one-shot migration script (added per axis as
   we go — `scripts/migrate-storage.sh`, `scripts/migrate-catalog.sh`).
4. `./udp restart`.
5. Verify with `./udp smoke-test`.

Backups make migrations reversible.
