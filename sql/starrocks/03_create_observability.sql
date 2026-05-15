-- Observability schema — pipeline run tracking.
-- Populated by udp_core.observability.record_run() from Python jobs (Phase 4 wires this).

CREATE DATABASE IF NOT EXISTS app_observability;

CREATE TABLE IF NOT EXISTS app_observability.pipeline_runs (
    run_id         VARCHAR(64)  NOT NULL,
    pipeline_name  VARCHAR(128) NOT NULL,
    started_at     DATETIME     NOT NULL,
    finished_at    DATETIME,
    status         VARCHAR(16)  NOT NULL,  -- running | succeeded | failed
    rows_in        BIGINT,
    rows_out       BIGINT,
    error_message  VARCHAR(1024),
    host           VARCHAR(128),
    udp_env        VARCHAR(32)
)
DUPLICATE KEY(run_id)
DISTRIBUTED BY HASH(run_id) BUCKETS 4
PROPERTIES ("replication_num" = "1");

CREATE VIEW IF NOT EXISTS app_observability.recent_runs AS
SELECT
    pipeline_name,
    started_at,
    finished_at,
    status,
    rows_in,
    rows_out,
    timestampdiff(SECOND, started_at, finished_at) AS duration_seconds
FROM app_observability.pipeline_runs
ORDER BY started_at DESC
LIMIT 100;
