"""UDP Dagster project — asset definitions for the demo lakehouse.

The Spark jobs in jobs/*.py already wrap themselves in
udp_core.observability.run_tracker.track(...), so each asset
materialization records a row in app_observability.pipeline_runs
alongside Dagster's own run history.

This module is the Dagster-equivalent of airflow/dags/udp_demo_lake.py
— same Spark jobs, same observability tracker, different scheduler.
The orchestrator choice is made at install time and gated by compose
profiles.
"""
from __future__ import annotations

import logging

from dagster import (
    AssetExecutionContext,
    Definitions,
    ScheduleDefinition,
    asset,
    define_asset_job,
)

log = logging.getLogger(__name__)


def _exec_in_spark(context: AssetExecutionContext, cmd: str) -> None:
    """Run `cmd` inside the running udp-spark container via the Docker SDK.

    We attach to the already-running container that has the Iceberg/MinIO env
    wired up, rather than launching a fresh one each time. The Docker socket
    is mounted into the dagster container — same security tradeoff as the
    Airflow profile.
    """
    import docker  # type: ignore  # installed by scripts/dagster-entrypoint.sh

    client = docker.from_env()
    try:
        container = client.containers.get("udp-spark")
    except docker.errors.NotFound as exc:
        raise RuntimeError(
            "udp-spark container not running — start the stack first"
        ) from exc

    result = container.exec_run(cmd, demux=True, stream=False)
    stdout_bytes, stderr_bytes = (
        result.output if result.output else (None, None)
    )
    stdout = stdout_bytes.decode("utf-8", errors="replace") if stdout_bytes else ""
    stderr = stderr_bytes.decode("utf-8", errors="replace") if stderr_bytes else ""

    if stdout:
        context.log.info(stdout)
    if stderr:
        context.log.info(stderr)

    if result.exit_code != 0:
        raise RuntimeError(
            f"spark-submit failed with exit {result.exit_code}: {stderr[:500]}"
        )


@asset(
    description="Raw + curated demo Iceberg tables materialized by Spark.",
    group_name="demo_lake",
)
def demo_lake(context: AssetExecutionContext) -> None:
    _exec_in_spark(context, "spark-submit /home/iceberg/jobs/bootstrap_demo_lake.py")


@asset(
    description="Smoke-test that asserts demo tables are populated.",
    deps=[demo_lake],
    group_name="demo_lake",
)
def demo_lake_smoke(context: AssetExecutionContext) -> None:
    _exec_in_spark(context, "spark-submit /home/iceberg/jobs/smoke_test_iceberg.py")


demo_lake_job = define_asset_job(
    name="demo_lake_job",
    selection=[demo_lake, demo_lake_smoke],
)

daily_schedule = ScheduleDefinition(
    job=demo_lake_job,
    cron_schedule="0 2 * * *",
    # Schedules start in STOPPED state — operator must enable in the UI.
    # This avoids surprise runs the moment the stack comes up.
    default_status=None,
)


defs = Definitions(
    assets=[demo_lake, demo_lake_smoke],
    jobs=[demo_lake_job],
    schedules=[daily_schedule],
)
