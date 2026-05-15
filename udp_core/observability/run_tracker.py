"""Pipeline-run tracker — emits a row to app_observability.pipeline_runs.

Used by jobs/*.py to record start, success, and failure. The tracker writes
via MySQL protocol against the StarRocks FE. Connection params come from
environment (set by the bootstrap shell via .env) so this works inside the
Spark container without local config files.

Usage:

    from udp_core.observability.run_tracker import track

    with track(pipeline="demo_csv_to_raw") as run:
        df = ...
        run.rows_in = df.count()
        ...
        run.rows_out = curated.count()

The context manager records `running` on entry, then `succeeded` or `failed`
on exit. If MySQL is unreachable the tracker logs a warning and proceeds —
observability must not break the pipeline.
"""
from __future__ import annotations

import contextlib
import os
import socket
import uuid
from collections.abc import Iterator
from dataclasses import dataclass
from datetime import datetime, timezone


@dataclass
class Run:
    run_id: str
    pipeline_name: str
    started_at: datetime
    rows_in: int | None = None
    rows_out: int | None = None


def _now() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


def _connect():
    """Lazy-import pymysql so the tracker is importable in environments without it."""
    try:
        import pymysql  # type: ignore
    except ImportError:
        return None
    host = os.environ.get("STARROCKS_FE_HOST", "starrocks-fe")
    port = int(os.environ.get("STARROCKS_FE_PORT", "9030"))
    user = os.environ.get("STARROCKS_OBS_USER", "root")
    password = os.environ.get("STARROCKS_ROOT_PASSWORD", "")
    try:
        return pymysql.connect(
            host=host, port=port, user=user, password=password,
            connect_timeout=5, autocommit=True,
        )
    except Exception:
        return None


def _emit(sql: str, params: tuple) -> bool:
    conn = _connect()
    if conn is None:
        return False
    try:
        with conn.cursor() as cur:
            cur.execute(sql, params)
        return True
    except Exception:
        return False
    finally:
        with contextlib.suppress(Exception):
            conn.close()


def record_start(pipeline_name: str) -> Run:
    run = Run(
        run_id=str(uuid.uuid4()),
        pipeline_name=pipeline_name,
        started_at=_now(),
    )
    _emit(
        "INSERT INTO app_observability.pipeline_runs "
        "(run_id, pipeline_name, started_at, status, host, udp_env) "
        "VALUES (%s, %s, %s, 'running', %s, %s)",
        (run.run_id, run.pipeline_name, run.started_at,
         socket.gethostname(), os.environ.get("UDP_ENV", "local")),
    )
    return run


def record_finish(run: Run, status: str, error: str | None = None) -> None:
    finished_at = _now()
    # StarRocks DUPLICATE KEY tables don't support UPDATE; insert a "finished"
    # row alongside the "running" row. recent_runs view filters by status.
    _emit(
        "INSERT INTO app_observability.pipeline_runs "
        "(run_id, pipeline_name, started_at, finished_at, status, rows_in, rows_out, error_message, host, udp_env) "
        "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
        (run.run_id, run.pipeline_name, run.started_at, finished_at, status,
         run.rows_in, run.rows_out,
         (error[:1024] if error else None),
         socket.gethostname(), os.environ.get("UDP_ENV", "local")),
    )


@contextlib.contextmanager
def track(pipeline: str) -> Iterator[Run]:
    run = record_start(pipeline)
    try:
        yield run
    except BaseException as exc:
        record_finish(run, "failed", error=f"{type(exc).__name__}: {exc}")
        raise
    else:
        record_finish(run, "succeeded")
