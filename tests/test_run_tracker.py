"""Tests for the run_tracker context manager. We monkeypatch _emit to avoid
needing a live StarRocks FE; the public contract is that record_start writes
a 'running' row, record_finish writes a 'succeeded'/'failed' row, and the
context manager records 'failed' on exception while re-raising."""
import pytest

from udp_core.observability import run_tracker


def test_track_records_succeeded(monkeypatch):
    emitted: list[tuple] = []
    monkeypatch.setattr(run_tracker, "_emit", lambda sql, params: emitted.append(params) or True)

    with run_tracker.track("test_pipeline") as run:
        run.rows_in = 10
        run.rows_out = 5

    # 2 emits: start (running) and finish (succeeded)
    assert len(emitted) == 2
    start_params = emitted[0]
    finish_params = emitted[1]
    assert start_params[1] == "test_pipeline"  # pipeline_name in start
    assert finish_params[4] == "succeeded"     # status in finish
    assert finish_params[5] == 10              # rows_in
    assert finish_params[6] == 5               # rows_out


def test_track_records_failed_on_exception(monkeypatch):
    emitted: list[tuple] = []
    monkeypatch.setattr(run_tracker, "_emit", lambda sql, params: emitted.append(params) or True)

    with pytest.raises(ValueError), run_tracker.track("test_pipeline"):
        raise ValueError("boom")

    assert len(emitted) == 2
    finish_params = emitted[1]
    assert finish_params[4] == "failed"
    assert "ValueError" in finish_params[7]    # error_message column


def test_track_continues_if_emit_fails(monkeypatch):
    # _emit returns False when DB unreachable. Tracker must not raise.
    monkeypatch.setattr(run_tracker, "_emit", lambda sql, params: False)

    with run_tracker.track("test_pipeline") as run:
        run.rows_out = 1
    # If we got here without raising, the contract is satisfied.
