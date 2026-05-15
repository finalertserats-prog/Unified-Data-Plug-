"""udp_demo_lake — daily DAG that materializes the demo Iceberg lakehouse.

Two tasks:
  1. bootstrap_lake — invokes the Spark job inside udp-spark via the Docker
     SDK. The Spark script already wraps its work in
     `udp_core.observability.run_tracker.track(...)`, so each run lands in
     app_observability.pipeline_runs alongside any Airflow-tracked metadata.
  2. validate_smoke — runs the existing smoke-test Spark job to assert the
     curated table is populated.

This is a thin orchestration layer over the existing scripts — it does not
duplicate the bootstrap logic, just schedules it.
"""
from __future__ import annotations

import logging
from datetime import datetime, timedelta

from airflow.decorators import dag, task

log = logging.getLogger(__name__)


def _exec_in_spark(cmd: str) -> None:
    """Run `cmd` inside the running udp-spark container. Raises on non-zero exit.

    We use the Docker SDK rather than DockerOperator so we attach to the
    already-running container that has the Iceberg/MinIO env wired up,
    rather than launching a fresh one each time.
    """
    import docker  # type: ignore  # installed via _PIP_ADDITIONAL_REQUIREMENTS

    client = docker.from_env()
    try:
        container = client.containers.get("udp-spark")
    except docker.errors.NotFound as exc:
        raise RuntimeError("udp-spark container not running — start the stack first") from exc

    exec_result = container.exec_run(cmd, demux=True, stream=False)
    stdout_bytes, stderr_bytes = exec_result.output if exec_result.output else (None, None)
    stdout = stdout_bytes.decode("utf-8", errors="replace") if stdout_bytes else ""
    stderr = stderr_bytes.decode("utf-8", errors="replace") if stderr_bytes else ""

    if stdout:
        log.info("stdout:\n%s", stdout)
    if stderr:
        log.info("stderr:\n%s", stderr)

    if exec_result.exit_code != 0:
        raise RuntimeError(
            f"spark-submit failed with exit code {exec_result.exit_code}: {stderr[:500]}"
        )


@dag(
    dag_id="udp_demo_lake",
    description="Materialize the UDP demo lakehouse (raw + curated Iceberg + analytics view).",
    schedule="0 2 * * *",  # daily at 02:00 UTC
    start_date=datetime(2026, 1, 1),
    catchup=False,
    max_active_runs=1,
    tags=["udp", "demo", "iceberg"],
    default_args={
        "owner": "udp",
        "retries": 2,
        "retry_delay": timedelta(minutes=5),
        "execution_timeout": timedelta(minutes=30),
    },
)
def udp_demo_lake():
    @task(task_id="bootstrap_lake")
    def bootstrap_lake() -> None:
        _exec_in_spark("spark-submit /home/iceberg/jobs/bootstrap_demo_lake.py")

    @task(task_id="validate_smoke")
    def validate_smoke() -> None:
        _exec_in_spark("spark-submit /home/iceberg/jobs/smoke_test_iceberg.py")

    bootstrap_lake() >> validate_smoke()


udp_demo_lake()
